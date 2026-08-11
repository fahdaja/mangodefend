import { IsEnum, IsNotEmpty, IsOptional, IsString } from 'class-validator';
import { Transform } from 'class-transformer';
import { application_type, os_type, normalizeOsType, normalizeAppType } from '../../users/enum/devices.enum';

export class RegisterDeviceDto {
  @IsString()
  @IsNotEmpty()
  hardware_id!: string;

  @IsString()
  @IsNotEmpty()
  hostname!: string;

  @Transform(({ value }) => normalizeOsType(value))
  @IsEnum(os_type)
  os_type!: os_type;

  @Transform(({ value }) => normalizeAppType(value))
  @IsEnum(application_type)
  app_type!: application_type;

  @IsString()
  @IsOptional()
  fcm_token?: string;
}

export class DeactivateDeviceDto {
  @IsString()
  @IsNotEmpty()
  hardware_id!: string;
}
