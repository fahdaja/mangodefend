import { IsNotEmpty, IsString } from "class-validator";

export class CreateMlModelDto {
    @IsNotEmpty()
    @IsString()
    version!: string;

    @IsNotEmpty()
    @IsString()
    file_path!: string;

    @IsNotEmpty()
    @IsString()
    checksum!: string;
}
