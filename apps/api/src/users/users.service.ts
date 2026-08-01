import { Injectable, NotFoundException } from '@nestjs/common';
import { FieldValue } from 'firebase-admin/firestore';
import {
  UserProfileResponseDto,
  toIsoString,
} from '../common/dto/api-response.dto';
import { UpdateUserProfileDto } from '../common/dto/api.dto';
import { FirebaseAdminService } from '../common/firebase/firebase-admin.service';

@Injectable()
export class UsersService {
  constructor(private readonly firebase: FirebaseAdminService) {}

  async get(uid: string, email: string | null): Promise<UserProfileResponseDto> {
    const snapshot = await this.doc(uid).get();
    if (!snapshot.exists) {
      throw new NotFoundException('User profile not found.');
    }
    return this.toResponse(uid, email, snapshot.data() as Record<string, unknown>);
  }

  async upsert(
    uid: string,
    dto: UpdateUserProfileDto,
    email: string | null,
  ): Promise<UserProfileResponseDto> {
    const ref = this.doc(uid);
    const existing = await ref.get();
    const name = dto.name.trim();
    const phone = dto.phone.trim();

    if (existing.exists) {
      await ref.update({
        name,
        phone,
        updatedAt: FieldValue.serverTimestamp(),
      });
    } else {
      await ref.set({
        name,
        phone,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    const snapshot = await ref.get();
    return this.toResponse(uid, email, snapshot.data() as Record<string, unknown>);
  }

  private doc(uid: string) {
    return this.firebase.firestore.collection('users').doc(uid);
  }

  private toResponse(
    uid: string,
    email: string | null,
    data: Record<string, unknown>,
  ): UserProfileResponseDto {
    return {
      uid,
      email,
      name: typeof data.name === 'string' ? data.name : '',
      phone: typeof data.phone === 'string' ? data.phone : '',
      createdAt: toIsoString(data.createdAt),
      updatedAt: toIsoString(data.updatedAt),
    };
  }
}
