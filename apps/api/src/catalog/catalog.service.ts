import { Injectable } from '@nestjs/common';
import { FieldValue } from 'firebase-admin/firestore';
import { CreateCatalogProductDto } from '../common/dto/api.dto';
import { BusinessStoreService } from '../common/firebase/business-store.service';

@Injectable()
export class CatalogService {
  constructor(private readonly store: BusinessStoreService) {}
  async create(
    businessId: string,
    dto: CreateCatalogProductDto,
  ): Promise<{ id: string }> {
    const ref = this.store.collection(businessId, 'catalogProducts').doc();
    // Explicit fields only: spreading the DTO writes `undefined` for omitted
    // optional fields, which Firestore rejects.
    await ref.set({
      name: dto.name,
      urduName: dto.urduName ?? null,
      sku: dto.sku ?? null,
      aliases: dto.aliases ?? [],
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { id: ref.id };
  }
  async list(
    businessId: string,
  ): Promise<Array<Record<string, unknown> & { id: string }>> {
    const snapshot = await this.store
      .collection(businessId, 'catalogProducts')
      .orderBy('name')
      .get();
    return snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  }
}
