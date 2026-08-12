import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHash } from 'crypto';
import { App, cert, getApps, initializeApp } from 'firebase-admin/app';
import { Auth, DecodedIdToken, getAuth } from 'firebase-admin/auth';
import { Firestore, getFirestore } from 'firebase-admin/firestore';

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

type B2Auth = {
  accountId: string;
  apiUrl: string;
  authorizationToken: string;
  downloadUrl: string;
  expiresAt: number;
};

type B2UploadUrl = {
  uploadUrl: string;
  authorizationToken: string;
  expiresAt: number;
};

@Injectable()
export class FirebaseAdminService {
  private readonly logger = new Logger(FirebaseAdminService.name);
  private app?: App;
  private db?: Firestore;
  private storageAdapter?: StorageBucketAdapter;
  private b2Auth?: B2Auth;
  private b2BucketId?: string;
  private b2UploadUrl?: B2UploadUrl;

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
    if (!this.db) {
      const db = getFirestore(this.firebaseApp);
      // Safety net behind the explicit field mapping in each service: an
      // optional DTO field that was never sent is `undefined`, not absent,
      // and Firestore throws on undefined values by default. settings() must
      // run once, before the client issues any request.
      db.settings({ ignoreUndefinedProperties: true });
      this.db = db;
    }
    return this.db;
  }

  get storage(): StorageBucketAdapter {
    if (!this.storageAdapter) {
      this.storageAdapter = this.createBlazeBucketStorage();
    }
    return this.storageAdapter;
  }

  private createBlazeBucketStorage(): StorageBucketAdapter {
    const bucketName = this.required('B2_BUCKET');

    return {
      bucket: () => ({
        file: (key: string) => ({
          save: async (
            bytes: Buffer,
            options?: {
              contentType?: string;
              resumable?: boolean;
              metadata?: Record<string, string>;
            },
          ) => {
            const body = Buffer.isBuffer(bytes) ? bytes : Buffer.from(bytes);
            await this.uploadToB2(
              bucketName,
              key,
              body,
              options?.contentType ?? 'application/octet-stream',
            );
          },
          download: async () => {
            const buffer = await this.downloadFromB2(bucketName, key);
            return [buffer];
          },
        }),
      }),
    };
  }

  private async uploadToB2(
    bucketName: string,
    fileName: string,
    body: Buffer,
    contentType: string,
  ): Promise<void> {
    const startedAt = Date.now();
    this.logger.log(
      `B2 upload started bucket=${bucketName} fileName=${fileName} sizeBytes=${body.length} contentType=${contentType}`,
    );
    const upload = await this.getB2UploadUrl(bucketName);
    const sha1 = createHash('sha1').update(body).digest('hex');
    const requestBody = Uint8Array.from(body);
    const response = await fetch(upload.uploadUrl, {
      method: 'POST',
      headers: {
        Authorization: upload.authorizationToken,
        'X-Bz-File-Name': encodeB2FileName(fileName),
        'Content-Type': contentType,
        'Content-Length': String(requestBody.byteLength),
        'X-Bz-Content-Sha1': sha1,
      },
      body: requestBody,
    });

    if (!response.ok) {
      // Upload URLs can expire; retry once with a fresh URL.
      if (response.status === 401 || response.status === 503) {
        this.logger.warn(
          `B2 upload auth/url stale; retrying fileName=${fileName} status=${response.status}`,
        );
        this.b2UploadUrl = undefined;
        const retryUpload = await this.getB2UploadUrl(bucketName);
        const retry = await fetch(retryUpload.uploadUrl, {
          method: 'POST',
          headers: {
            Authorization: retryUpload.authorizationToken,
            'X-Bz-File-Name': encodeB2FileName(fileName),
            'Content-Type': contentType,
            'Content-Length': String(requestBody.byteLength),
            'X-Bz-Content-Sha1': sha1,
          },
          body: requestBody,
        });
        if (!retry.ok) {
          const detail = await retry.text();
          this.logger.error(
            `B2 upload retry failed fileName=${fileName} status=${retry.status} detail=${detail.slice(0, 300)}`,
          );
          throw new Error(
            `BlazeBucket upload failed (${retry.status}): ${detail}`,
          );
        }
        this.logger.log(
          `B2 upload completed after retry fileName=${fileName} durationMs=${Date.now() - startedAt}`,
        );
        return;
      }
      const detail = await response.text();
      this.logger.error(
        `B2 upload failed fileName=${fileName} status=${response.status} detail=${detail.slice(0, 300)}`,
      );
      throw new Error(
        `BlazeBucket upload failed (${response.status}): ${detail}`,
      );
    }
    this.logger.log(
      `B2 upload completed fileName=${fileName} durationMs=${Date.now() - startedAt}`,
    );
  }

  private async downloadFromB2(
    bucketName: string,
    fileName: string,
  ): Promise<Buffer> {
    const startedAt = Date.now();
    this.logger.log(
      `B2 download started bucket=${bucketName} fileName=${fileName}`,
    );
    const auth = await this.getB2Auth();
    const url = `${auth.downloadUrl}/file/${encodeURIComponent(bucketName)}/${fileName
      .split('/')
      .map(encodeURIComponent)
      .join('/')}`;
    const response = await fetch(url, {
      headers: {
        Authorization: auth.authorizationToken,
      },
    });
    if (!response.ok) {
      const detail = await response.text();
      this.logger.error(
        `B2 download failed fileName=${fileName} status=${response.status} detail=${detail.slice(0, 300)}`,
      );
      throw new Error(
        `BlazeBucket download failed (${response.status}): ${detail}`,
      );
    }
    const buffer = Buffer.from(await response.arrayBuffer());
    this.logger.log(
      `B2 download completed fileName=${fileName} sizeBytes=${buffer.length} durationMs=${Date.now() - startedAt}`,
    );
    return buffer;
  }

  private async getB2UploadUrl(bucketName: string): Promise<B2UploadUrl> {
    if (this.b2UploadUrl && this.b2UploadUrl.expiresAt > Date.now()) {
      return this.b2UploadUrl;
    }

    const auth = await this.getB2Auth();
    const bucketId = await this.getB2BucketId(auth, bucketName);
    const response = await fetch(`${auth.apiUrl}/b2api/v2/b2_get_upload_url`, {
      method: 'POST',
      headers: {
        Authorization: auth.authorizationToken,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ bucketId }),
    });
    if (!response.ok) {
      throw new Error(
        `BlazeBucket get_upload_url failed (${response.status}): ${await response.text()}`,
      );
    }
    const data = (await response.json()) as {
      uploadUrl: string;
      authorizationToken: string;
    };
    this.b2UploadUrl = {
      uploadUrl: data.uploadUrl,
      authorizationToken: data.authorizationToken,
      expiresAt: Date.now() + 20 * 60 * 1000,
    };
    return this.b2UploadUrl;
  }

  private async getB2BucketId(
    auth: B2Auth,
    bucketName: string,
  ): Promise<string> {
    if (this.b2BucketId) return this.b2BucketId;

    const response = await fetch(`${auth.apiUrl}/b2api/v2/b2_list_buckets`, {
      method: 'POST',
      headers: {
        Authorization: auth.authorizationToken,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        accountId: auth.accountId,
        bucketName,
      }),
    });
    if (!response.ok) {
      throw new Error(
        `BlazeBucket list_buckets failed (${response.status}): ${await response.text()}`,
      );
    }
    const data = (await response.json()) as {
      buckets?: Array<{ bucketId: string; bucketName: string }>;
    };
    const bucket = data.buckets?.find((item) => item.bucketName === bucketName);
    if (!bucket) {
      throw new Error(`BlazeBucket bucket "${bucketName}" was not found.`);
    }
    this.b2BucketId = bucket.bucketId;
    return this.b2BucketId;
  }

  private async getB2Auth(): Promise<B2Auth> {
    if (this.b2Auth && this.b2Auth.expiresAt > Date.now()) {
      return this.b2Auth;
    }

    const keyId = this.required('B2_KEY_ID');
    const applicationKey = this.required('B2_APPLICATION_KEY');
    const basic = Buffer.from(`${keyId}:${applicationKey}`).toString('base64');
    const response = await fetch(
      'https://api.backblazeb2.com/b2api/v2/b2_authorize_account',
      {
        headers: {
          Authorization: `Basic ${basic}`,
        },
      },
    );
    if (!response.ok) {
      throw new Error(
        `BlazeBucket authorize failed (${response.status}): ${await response.text()}`,
      );
    }
    const data = (await response.json()) as {
      accountId: string;
      apiUrl: string;
      authorizationToken: string;
      downloadUrl: string;
    };
    this.b2Auth = {
      accountId: data.accountId,
      apiUrl: data.apiUrl,
      authorizationToken: data.authorizationToken,
      downloadUrl: data.downloadUrl,
      expiresAt: Date.now() + 20 * 60 * 1000,
    };
    return this.b2Auth;
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

function encodeB2FileName(fileName: string): string {
  return fileName
    .split('/')
    .map((segment) => encodeURIComponent(segment))
    .join('/');
}
