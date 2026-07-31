import {
  BadRequestException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { FieldValue } from 'firebase-admin/firestore';
import {
  InvoiceExtractionResponseDto,
  InvoiceExtractionStatus,
  toIsoString,
} from '../common/dto/api-response.dto';
import { CreateExtractionDto } from '../common/dto/api.dto';
import { BusinessStoreService } from '../common/firebase/business-store.service';
import { FirebaseAdminService } from '../common/firebase/firebase-admin.service';

type GeminiResponse = {
  candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
};

@Injectable()
export class InvoiceExtractionService {
  constructor(
    private readonly store: BusinessStoreService,
    private readonly firebase: FirebaseAdminService,
    private readonly config: ConfigService,
  ) {}

  async create(
    businessId: string,
    dto: CreateExtractionDto,
  ): Promise<InvoiceExtractionResponseDto> {
    const upload = await this.store
      .collection(businessId, 'uploads')
      .doc(dto.uploadId)
      .get();
    if (!upload.exists) throw new NotFoundException('Upload not found.');
    const ref = this.store.collection(businessId, 'invoiceExtractions').doc();
    await ref.set({
      uploadId: dto.uploadId,
      status: 'processing',
      model: this.model,
      promptVersion: 'invoice-v1',
      createdAt: FieldValue.serverTimestamp(),
    });
    try {
      const draft = await this.extract(
        upload.data()! as { path: string; contentType: string },
      );
      await ref.update({
        status: 'needs_review',
        draft,
        completedAt: FieldValue.serverTimestamp(),
      });
      return this.get(businessId, ref.id);
    } catch (error) {
      await ref.update({
        status: 'failed',
        failureReason:
          error instanceof Error ? error.message : 'Unknown extraction error',
        completedAt: FieldValue.serverTimestamp(),
      });
      throw error;
    }
  }

  async get(
    businessId: string,
    id: string,
  ): Promise<InvoiceExtractionResponseDto> {
    const snapshot = await this.store
      .collection(businessId, 'invoiceExtractions')
      .doc(id)
      .get();
    if (!snapshot.exists) throw new NotFoundException('Extraction not found.');
    const data = snapshot.data()!;
    return {
      id: snapshot.id,
      uploadId: String(data.uploadId ?? ''),
      status: data.status as InvoiceExtractionStatus,
      model: String(data.model ?? ''),
      promptVersion: String(data.promptVersion ?? ''),
      draft: data.draft ?? null,
      failureReason:
        typeof data.failureReason === 'string' ? data.failureReason : null,
      approvedInvoiceId:
        typeof data.approvedInvoiceId === 'string'
          ? data.approvedInvoiceId
          : null,
      createdAt: toIsoString(data.createdAt),
      completedAt: toIsoString(data.completedAt),
      approvedAt: toIsoString(data.approvedAt),
    };
  }

  private get model(): string {
    return this.config.get<string>('GEMINI_MODEL') ?? 'gemini-2.5-flash';
  }

  private async extract(upload: {
    path: string;
    contentType: string;
  }): Promise<unknown> {
    const apiKey = this.config.get<string>('GEMINI_API_KEY');
    if (!apiKey)
      throw new ServiceUnavailableException(
        'Invoice extraction is not configured.',
      );
    const [bytes] = await this.firebase.storage
      .bucket()
      .file(upload.path)
      .download();
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${this.model}:generateContent?key=${apiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          systemInstruction: {
            parts: [
              {
                text: 'You extract Pakistani distributor invoice data. Transcribe only visible information. Never guess. Use null for absent or unreadable values. Keep each item’s OCR text and confidence. This response is a draft for mandatory human review; never infer an amount, date, or product.',
              },
            ],
          },
          contents: [
            {
              parts: [
                {
                  inlineData: {
                    mimeType: upload.contentType,
                    data: bytes.toString('base64'),
                  },
                },
                { text: 'Extract this invoice.' },
              ],
            },
          ],
          generationConfig: {
            responseMimeType: 'application/json',
            responseJsonSchema: invoiceSchema,
          },
        }),
      },
    );
    if (!response.ok)
      throw new ServiceUnavailableException(
        `Gemini extraction failed (${response.status}).`,
      );
    const payload = (await response.json()) as GeminiResponse;
    const text =
      payload.candidates?.[0]?.content?.parts
        ?.map((part) => part.text ?? '')
        .join('') ?? '';
    if (!text)
      throw new BadRequestException('Gemini returned an empty extraction.');
    try {
      return JSON.parse(text) as unknown;
    } catch {
      throw new BadRequestException('Gemini returned invalid structured data.');
    }
  }
}

const invoiceSchema = {
  type: 'object',
  properties: {
    invoiceNumber: { type: ['string', 'null'] },
    invoiceDate: { type: ['string', 'null'] },
    dueDate: { type: ['string', 'null'] },
    customerName: { type: ['string', 'null'] },
    total: { type: ['number', 'null'] },
    items: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          ocrText: { type: ['string', 'null'] },
          normalizedProduct: { type: ['string', 'null'] },
          quantity: { type: ['number', 'null'] },
          unitPrice: { type: ['number', 'null'] },
          lineTotal: { type: ['number', 'null'] },
          confidence: { type: 'string', enum: ['high', 'medium', 'low'] },
          crossedOut: { type: 'boolean' },
        },
        required: [
          'ocrText',
          'normalizedProduct',
          'quantity',
          'unitPrice',
          'lineTotal',
          'confidence',
          'crossedOut',
        ],
      },
    },
  },
  required: [
    'invoiceNumber',
    'invoiceDate',
    'dueDate',
    'customerName',
    'total',
    'items',
  ],
};
