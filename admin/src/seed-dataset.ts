import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { DatasetSeederService } from './api/dataset/service/dataset-seeder.service';
import { Logger } from '@nestjs/common';

/**
 * Standalone script untuk menjalankan dataset seeder.
 *
 * Cara pakai:
 *   npx ts-node -r tsconfig-paths/register src/seed-dataset.ts ./path/to/dataset
 *
 * Struktur folder yang diharapkan:
 *   dataset/
 *     ├── malware/    ← file-file malware sample
 *     └── benign/     ← file-file benign sample
 */
async function bootstrap() {
  const logger = new Logger('DatasetSeeder');

  // Ambil folder path dari argument CLI
  const folderPath = process.argv[2];

  if (!folderPath) {
    logger.error('Harap berikan path folder dataset sebagai argument.');
    logger.error('Contoh: npx ts-node -r tsconfig-paths/register src/seed-dataset.ts ./dataset');
    process.exit(1);
  }

  // Buat NestJS app context (tanpa HTTP server)
  const app = await NestFactory.createApplicationContext(AppModule);

  try {
    const seeder = app.get(DatasetSeederService);
    const result = await seeder.seedFromFolder(folderPath);

    logger.log('=== HASIL SEEDING ===');
    logger.log(`Total diproses : ${result.total_processed}`);
    logger.log(`Total diupload : ${result.total_uploaded}`);
    logger.log(`Total di-skip  : ${result.total_skipped}`);
  } catch (error) {
    logger.error('Seeding gagal: ' + error.message);
  } finally {
    await app.close();
  }
}

bootstrap();
