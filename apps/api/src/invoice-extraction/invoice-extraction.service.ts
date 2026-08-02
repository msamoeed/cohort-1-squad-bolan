import {
  BadRequestException,
  Injectable,
  Logger,
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
  private readonly logger = new Logger(InvoiceExtractionService.name);

  constructor(
    private readonly store: BusinessStoreService,
    private readonly firebase: FirebaseAdminService,
    private readonly config: ConfigService,
  ) {}

  async create(
    businessId: string,
    dto: CreateExtractionDto,
  ): Promise<InvoiceExtractionResponseDto> {
    const startedAt = Date.now();
    this.logger.log(
      `Extraction started businessId=${businessId} uploadId=${dto.uploadId}`,
    );

    const upload = await this.store
      .collection(businessId, 'uploads')
      .doc(dto.uploadId)
      .get();
    if (!upload.exists) {
      this.logger.warn(
        `Extraction aborted; upload missing businessId=${businessId} uploadId=${dto.uploadId}`,
      );
      throw new NotFoundException('Upload not found.');
    }

    const ref = this.store.collection(businessId, 'invoiceExtractions').doc();
    await ref.set({
      uploadId: dto.uploadId,
      status: 'processing',
      model: this.model,
      promptVersion: 'invoice-v1',
      createdAt: FieldValue.serverTimestamp(),
    });
    this.logger.log(
      `Extraction record created businessId=${businessId} extractionId=${ref.id} model=${this.model}`,
    );

    try {
      const draft = await this.extract(
        upload.data()! as { path: string; contentType: string },
        ref.id,
      );
      await ref.update({
        status: 'needs_review',
        draft,
        completedAt: FieldValue.serverTimestamp(),
      });
      this.logger.log(
        `Extraction completed businessId=${businessId} extractionId=${ref.id} status=needs_review items=${countDraftItems(draft)} durationMs=${Date.now() - startedAt}`,
      );
      return this.get(businessId, ref.id);
    } catch (error) {
      const failureReason =
        error instanceof Error ? error.message : 'Unknown extraction error';
      await ref.update({
        status: 'failed',
        failureReason,
        completedAt: FieldValue.serverTimestamp(),
      });
      this.logger.error(
        `Extraction failed businessId=${businessId} extractionId=${ref.id} reason=${failureReason} durationMs=${Date.now() - startedAt}`,
        error instanceof Error ? error.stack : undefined,
      );
      throw error;
    }
  }

  async get(
    businessId: string,
    id: string,
  ): Promise<InvoiceExtractionResponseDto> {
    this.logger.debug(
      `Fetching extraction businessId=${businessId} extractionId=${id}`,
    );
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
    return this.config.get<string>('GEMINI_MODEL') ?? 'gemini-3.6-flash';
  }

  private async extract(
    upload: {
      path: string;
      contentType: string;
    },
    extractionId: string,
  ): Promise<unknown> {
    const apiKey = this.config.get<string>('GEMINI_API_KEY')?.trim();
    if (!apiKey)
      throw new ServiceUnavailableException(
        'Invoice extraction is not configured. Set GEMINI_API_KEY in apps/api/.env.',
      );

    this.logger.log(
      `Downloading invoice image for OCR extractionId=${extractionId} path=${upload.path} contentType=${upload.contentType}`,
    );
    const downloadStartedAt = Date.now();
    const [bytes] = await this.firebase.storage
      .bucket()
      .file(upload.path)
      .download();
    this.logger.log(
      `Image downloaded for OCR extractionId=${extractionId} sizeBytes=${bytes.length} durationMs=${Date.now() - downloadStartedAt}`,
    );

    this.logger.log(
      `Calling Gemini OCR extractionId=${extractionId} model=${this.model}`,
    );
    const geminiStartedAt = Date.now();
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

    if (!response.ok) {
      const errorBody = await response.text();
      this.logger.error(
        `Gemini OCR HTTP failure extractionId=${extractionId} status=${response.status} body=${errorBody.slice(0, 300)}`,
      );
      throw new ServiceUnavailableException(
        `Gemini extraction failed (${response.status}).`,
      );
    }

    const payload = (await response.json()) as GeminiResponse;
    const text =
      payload.candidates?.[0]?.content?.parts
        ?.map((part) => part.text ?? '')
        .join('') ?? '';
    if (!text) {
      this.logger.warn(
        `Gemini returned empty text extractionId=${extractionId} durationMs=${Date.now() - geminiStartedAt}`,
      );
      throw new BadRequestException('Gemini returned an empty extraction.');
    }

    try {
      const draft = JSON.parse(text) as unknown;
      this.logger.log(
        `Gemini OCR parsed extractionId=${extractionId} items=${countDraftItems(draft)} durationMs=${Date.now() - geminiStartedAt}`,
      );
      return draft;
    } catch {
      this.logger.warn(
        `Gemini returned invalid JSON extractionId=${extractionId} preview=${text.slice(0, 200)}`,
      );
      throw new BadRequestException('Gemini returned invalid structured data.');
    }
  }
}

function countDraftItems(draft: unknown): number {
  if (
    draft &&
    typeof draft === 'object' &&
    Array.isArray((draft as { items?: unknown }).items)
  ) {
    return ((draft as { items: unknown[] }).items).length;
  }
  return 0;
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
