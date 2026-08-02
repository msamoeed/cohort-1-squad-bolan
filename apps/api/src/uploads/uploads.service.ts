import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { createHash } from 'crypto';
import { FieldValue } from 'firebase-admin/firestore';
import { UploadResponseDto } from '../common/dto/api-response.dto';
import { CreateUploadDto } from '../common/dto/api.dto';
import { BusinessStoreService } from '../common/firebase/business-store.service';
import { FirebaseAdminService } from '../common/firebase/firebase-admin.service';

@Injectable()
export class UploadsService {
  private readonly logger = new Logger(UploadsService.name);

  constructor(
    private readonly store: BusinessStoreService,
    private readonly firebase: FirebaseAdminService,
  ) {}

  async create(
    businessId: string,
    dto: CreateUploadDto,
  ): Promise<UploadResponseDto> {
    const startedAt = Date.now();
    this.logger.log(
      `Upload started businessId=${businessId} filename=${dto.filename ?? 'invoice'} contentType=${dto.contentType}`,
    );

    const bytes = Buffer.from(
      dto.base64.replace(/^data:[^;]+;base64,/, ''),
      'base64',
    );
    if (!bytes.length || bytes.length > 10 * 1024 * 1024) {
      this.logger.warn(
        `Upload rejected businessId=${businessId} sizeBytes=${bytes.length}`,
      );
      throw new BadRequestException('Upload must be between 1 byte and 10 MB.');
    }

    const sha256 = createHash('sha256').update(bytes).digest('hex');
    const duplicate = await this.store
      .collection(businessId, 'uploads')
      .where('sha256', '==', sha256)
      .limit(1)
      .get();
    if (!duplicate.empty) {
      this.logger.log(
        `Upload reused existing file businessId=${businessId} uploadId=${duplicate.docs[0].id} sha256=${sha256.slice(0, 12)}…`,
      );
      return { id: duplicate.docs[0].id, sha256, status: 'uploaded' };
    }

    const ref = this.store.collection(businessId, 'uploads').doc();
    const path = `businesses/${businessId}/uploads/${ref.id}`;
    this.logger.log(
      `Uploading to BlazeBucket businessId=${businessId} uploadId=${ref.id} path=${path} sizeBytes=${bytes.length}`,
    );

    try {
      await this.firebase.storage.bucket().file(path).save(bytes, {
        contentType: dto.contentType,
        resumable: false,
        metadata: { cacheControl: 'private, max-age=0' },
      });
      await ref.set({
        path,
        filename: dto.filename ?? 'invoice',
        contentType: dto.contentType,
        sha256,
        status: 'uploaded',
        createdAt: FieldValue.serverTimestamp(),
      });
    } catch (error) {
      this.logger.error(
        `Upload failed businessId=${businessId} uploadId=${ref.id} path=${path}`,
        error instanceof Error ? error.stack : undefined,
      );
      throw error;
    }

    this.logger.log(
      `Upload completed businessId=${businessId} uploadId=${ref.id} durationMs=${Date.now() - startedAt}`,
    );
    return { id: ref.id, sha256, status: 'uploaded' };
  }
}
