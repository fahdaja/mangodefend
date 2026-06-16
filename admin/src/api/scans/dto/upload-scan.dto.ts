import { IsBoolean, IsInt, IsNotEmpty, IsOptional } from 'class-validator';
import { Type, Transform } from 'class-transformer';

export class UploadScanDto {
  @IsNotEmpty()
  @Type(() => Number)
  @IsInt()
  summaryId: number;

  @IsOptional()
  @Transform(({ value }) => value === 'true' || value === true)
  @IsBoolean()
  isMalware?: boolean;
}
