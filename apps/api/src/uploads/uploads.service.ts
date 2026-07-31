import { BadRequestException, Injectable } from '@nestjs/common';
import { createHash } from 'crypto';
import { FieldValue } from 'firebase-admin/firestore';
import { UploadResponseDto } from '../common/dto/api-response.dto';
import { CreateUploadDto } from '../common/dto/api.dto';
import { BusinessStoreService } from '../common/firebase/business-store.service';
import { FirebaseAdminService } from '../common/firebase/firebase-admin.service';

@Injectable()
export class UploadsService {
  constructor(
    private readonly store: BusinessStoreService,
    private readonly firebase: FirebaseAdminService,
  ) {}

  async create(
    businessId: string,
    dto: CreateUploadDto,
  ): Promise<UploadResponseDto> {
    const bytes = Buffer.from(
      dto.base64.replace(/^data:[^;]+;base64,/, ''),
      'base64',
    );
    if (!bytes.length || bytes.length > 10 * 1024 * 1024)
      throw new BadRequestException('Upload must be between 1 byte and 10 MB.');
    const sha256 = createHash('sha256').update(bytes).digest('hex');
    const duplicate = await this.store
      .collection(businessId, 'uploads')
      .where('sha256', '==', sha256)
      .limit(1)
      .get();
    if (!duplicate.empty)
      return { id: duplicate.docs[0].id, sha256, status: 'uploaded' };
    const ref = this.store.collection(businessId, 'uploads').doc();
    const path = `businesses/${businessId}/uploads/${ref.id}`;
    await this.firebase.storage
      .bucket()
      .file(path)
      .save(bytes, {
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
    return { id: ref.id, sha256, status: 'uploaded' };
  }
}
