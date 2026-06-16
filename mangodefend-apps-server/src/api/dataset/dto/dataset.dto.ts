import { IsNotEmpty, IsString } from 'class-validator';

export class CreateDatasetDto {
  @IsNotEmpty()
  @IsString()
  file_hash: string;

  @IsNotEmpty()
  @IsString()
  label: string;
}
