import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { App, cert, getApps, initializeApp } from 'firebase-admin/app';
import { Auth, DecodedIdToken, getAuth } from 'firebase-admin/auth';
import { Firestore, getFirestore } from 'firebase-admin/firestore';
import {
  GetObjectCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { Readable } from 'stream';

type StorageBucketAdapter = {
  bucket: () => {
    file: (key: string) => {
      save: (
        bytes: Buffer,
        options?: {
          contentType?: string;
          resumable?: boolean;
          metadata?: Record<string, string>;
        },
      ) => Promise<void>;
      download: () => Promise<[Buffer]>;
    };
  };
};

@Injectable()
export class FirebaseAdminService {
  private app?: App;
  private storageAdapter?: StorageBucketAdapter;

  constructor(private readonly config: ConfigService) {}

  async verifyIdToken(token: string): Promise<DecodedIdToken> {
    try {
      return await this.auth.verifyIdToken(token);
    } catch {
      throw new UnauthorizedException(
        'Firebase ID token is invalid or expired.',
      );
    }
  }

  get firestore(): Firestore {
    return getFirestore(this.firebaseApp);
  }

  get storage(): StorageBucketAdapter {
    if (!this.storageAdapter) {
      this.storageAdapter = this.createBlazeBucketStorage();
    }
    return this.storageAdapter;
  }

  private createBlazeBucketStorage(): StorageBucketAdapter {
    const bucketName = this.required('B2_BUCKET');
    const endpoint = this.required('B2_ENDPOINT');
    const region = this.config.get<string>('B2_REGION') ?? 'us-west-004';
    const accessKeyId = this.required('B2_KEY_ID');
    const secretAccessKey = this.required('B2_APPLICATION_KEY');

    // B2's S3 API rejects AWS SDK v3 default flexible checksums
    // ("IncompleteBody: The request body was too small").
    const s3 = new S3Client({
      region,
      endpoint,
      credentials: {
        accessKeyId,
        secretAccessKey,
      },
      forcePathStyle: true,
      requestChecksumCalculation: 'WHEN_REQUIRED',
      responseChecksumValidation: 'WHEN_REQUIRED',
    });

    return {
      bucket: () => ({
        file: (key: string) => ({
          async save(bytes: Buffer, options?: {
            contentType?: string;
            resumable?: boolean;
            metadata?: Record<string, string>;
          }) {
            const body = Buffer.isBuffer(bytes) ? bytes : Buffer.from(bytes);
            const params: {
              Bucket: string;
              Key: string;
              Body: Buffer;
              ContentLength: number;
              ContentType?: string;
              CacheControl?: string;
              Metadata?: Record<string, string>;
            } = {
              Bucket: bucketName,
              Key: key,
              Body: body,
              ContentLength: body.length,
              ContentType: options?.contentType,
            };

            if (options?.metadata) {
              const { cacheControl, ...metadata } = options.metadata;
              if (Object.keys(metadata).length > 0) {
                params.Metadata = metadata;
              }
              if (cacheControl) {
                params.CacheControl = cacheControl;
              }
            }

            await s3.send(new PutObjectCommand(params));
          },
          async download() {
            const res = await s3.send(
              new GetObjectCommand({
                Bucket: bucketName,
                Key: key,
              }),
            );
            const body = res.Body as unknown;
            let buffer: Buffer;
            if (body instanceof Uint8Array) buffer = Buffer.from(body);
            else if (body instanceof Readable)
              buffer = await streamToBuffer(body);
            else if (typeof body === 'string') buffer = Buffer.from(body);
            else buffer = Buffer.from([]);
            return [buffer];
          },
        }),
      }),
    };
  }

  private get auth(): Auth {
    return getAuth(this.firebaseApp);
  }

  private get firebaseApp(): App {
    if (!this.app) {
      this.app =
        getApps()[0] ??
        initializeApp({
          credential: cert({
            projectId: this.required('FIREBASE_PROJECT_ID'),
            clientEmail: this.required('FIREBASE_CLIENT_EMAIL'),
            privateKey: this.required('FIREBASE_PRIVATE_KEY').replace(
              /\\n/g,
              '\n',
            ),
          }),
        });
    }
    return this.app;
  }

  private required(name: string): string {
    const value = this.config.get<string>(name);
    if (!value) {
      throw new Error(
        `${name} must be configured before using Firebase Admin services.`,
      );
    }
    return value;
  }
}

async function streamToBuffer(stream: Readable): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const chunks: Uint8Array[] = [];
    stream.on('data', (chunk) =>
      chunks.push(typeof chunk === 'string' ? Buffer.from(chunk) : chunk),
    );
    stream.on('end', () => resolve(Buffer.concat(chunks)));
    stream.on('error', reject);
  });
}
