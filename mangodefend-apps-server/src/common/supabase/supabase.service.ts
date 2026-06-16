import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import 'multer';

@Injectable()
export class SupabaseService {
  private supabase: SupabaseClient;
  private bucketName: string;

  constructor(private configService: ConfigService) {
    const url = this.configService.get<string>('SUPABASE_URL');
    const key = this.configService.get<string>('SUPABASE_KEY');
    const bucket = this.configService.get<string>('SUPABASE_BUCKET_NAME');

    if (!url || !key || !bucket) {
      throw new InternalServerErrorException(
        'Environment variables not set for Supabase',
      );
    }

    this.supabase = createClient(url, key);
    this.bucketName = bucket;
  }

  async uploadScanImage(
    file: Express.Multer.File,
    folderName: string = 'scans',
    fileHash?: string,
  ): Promise<string> {
    // Gunakan hash sebagai nama file supaya path unik per konten
    // Kalau hash tidak disediakan, fallback ke timestamp + nama original
    const extension = file.originalname.split('.').pop() || 'bin';
    const fileName = fileHash
      ? `${fileHash}.${extension}`
      : `${Date.now()}-${file.originalname.replace(/\s/g, '-')}`;
    const filePath = `${folderName}/${fileName}`;

    // Upload ke Supabase
    const { data, error } = await this.supabase.storage
      .from(this.bucketName)
      .upload(filePath, file.buffer, {
        contentType: file.mimetype,
        upsert: false,
      });

    if (error) {
      // Jika file dengan path yang sama sudah ada (duplikat), skip upload
      // dan langsung return public URL yang sudah ada
      if (error.message?.includes('Duplicate') || error.message?.includes('already exists')) {
        const { data: urlData } = this.supabase.storage
          .from(this.bucketName)
          .getPublicUrl(filePath);
        return urlData.publicUrl;
      }

      throw new InternalServerErrorException(
        'Gagal upload ke Supabase: ' + error.message,
      );
    }

    // Ambil Public URL-nya
    const { data: urlData } = this.supabase.storage
      .from(this.bucketName)
      .getPublicUrl(filePath);

    return urlData.publicUrl;
  }
}
