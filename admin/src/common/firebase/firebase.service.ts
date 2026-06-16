import { Injectable, OnModuleInit, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as admin from 'firebase-admin';

export interface FirebaseDecodedToken {
  uid: string;
  email?: string;
  name?: string;
  picture?: string;
  firebase: {
    sign_in_provider: string;
    identities: Record<string, any>;
  };
}

@Injectable()
export class FirebaseService implements OnModuleInit {
  private app: admin.app.App;

  constructor(private readonly configService: ConfigService) {}

  onModuleInit() {
    const projectId = this.configService.get<string>('FIREBASE_PROJECT_ID');

    if (!projectId) {
      throw new Error(
        'FIREBASE_PROJECT_ID is not set in environment variables',
      );
    }

    // Initialize Firebase Admin dengan application default credentials
    // atau hanya project ID (untuk verifikasi token saja)
    if (!admin.apps.length) {
      this.app = admin.initializeApp({
        projectId: projectId,
      });
    } else {
      this.app = admin.apps[0]!;
    }
  }

  /**
   * Verifikasi Firebase ID Token yang dikirim dari client
   */
  async verifyIdToken(idToken: string): Promise<FirebaseDecodedToken> {
    try {
      const decodedToken = await this.app.auth().verifyIdToken(idToken);
      return decodedToken as unknown as FirebaseDecodedToken;
    } catch (error: any) {
      throw new UnauthorizedException(
        `Firebase token tidak valid: ${error.message}`,
      );
    }
  }
}
