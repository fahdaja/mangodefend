import {
  IsEnum,
  IsInt,
  IsNotEmpty,
  Min,
  IsOptional,
  IsBoolean,
} from 'class-validator';
import { Type, Transform } from 'class-transformer';
import { ScanType } from '../enum/scan.enum';

export class CreateScanDto {
  @IsNotEmpty()
  @Type(() => Number)
  @IsInt()
  userId: number;

  @IsNotEmpty()
  @IsEnum(ScanType)
  scanType: ScanType;

  @IsNotEmpty()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  totalFiles: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  totalMalware?: number;

  @IsOptional()
  @Transform(({ value }) => value === 'true' || value === true)
  @IsBoolean()
  isMalware?: boolean;
}
