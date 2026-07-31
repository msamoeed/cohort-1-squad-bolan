import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { FieldValue } from 'firebase-admin/firestore';
import { ReminderDraftResponseDto } from '../common/dto/api-response.dto';
import { CreateReminderDraftDto } from '../common/dto/api.dto';
import { BusinessStoreService } from '../common/firebase/business-store.service';
import { summarizeContactReceivables } from '../receivables/receivable-calculations';

@Injectable()
export class RemindersService {
  constructor(private readonly store: BusinessStoreService) {}

  async draft(
    businessId: string,
    actorId: string,
    contactId: string,
    dto: CreateReminderDraftDto,
  ): Promise<ReminderDraftResponseDto> {
    const contact = await this.store
      .collection(businessId, 'contacts')
      .doc(contactId)
      .get();
    if (!contact.exists) throw new NotFoundException('Contact not found.');
    const entries = await this.store
      .collection(businessId, 'receivableEntries')
      .where('contactId', '==', contactId)
      .get();
    const balance = summarizeContactReceivables(
      entries.docs.map((entry) => {
        const data = entry.data() as Record<string, unknown>;
        return {
          id: entry.id,
          type: stringValue(data.type),
          contactId: stringValue(data.contactId),
          signedAmount: Number(data.signedAmount ?? 0),
          occurredAt: data.occurredAt,
          dueDate: data.dueDate,
          createdAt: data.createdAt,
        };
      }),
    ).currentBalance;
    if (balance <= 0)
      throw new BadRequestException('This contact has no outstanding balance.');
    const data = contact.data()! as { name: string; phone: string };
    const message =
      dto.message ??
      `Assalam-o-alaikum ${data.name}, aap ka Rs ${balance.toFixed(0)} balance due hai. Meherbani farma kar payment ka update share kar dein. Shukriya.`;
    const ref = this.store.collection(businessId, 'reminders').doc();
    const phone = data.phone.replace(/\D/g, '');
    await ref.set({
      contactId,
      balanceAtDraft: balance,
      message,
      channel: 'whatsapp_deep_link',
      status: 'drafted',
      createdBy: actorId,
      createdAt: FieldValue.serverTimestamp(),
    });
    return {
      id: ref.id,
      message,
      whatsappUrl: `https://wa.me/${phone}?text=${encodeURIComponent(message)}`,
    };
  }
}

function stringValue(value: unknown): string {
  return typeof value === 'string' ? value : '';
}
