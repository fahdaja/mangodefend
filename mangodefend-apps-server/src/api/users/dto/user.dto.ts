import { IsEmail, IsNotEmpty, ValidateIf } from "class-validator";

export class CreateUserDto {
    @IsNotEmpty({ message: 'Email is required' })
    @IsEmail({}, { message: 'Invalid email format' })
    email!: string;

    @IsNotEmpty({ message: 'Password is required' })
    password!: string;
}

export class UserResponseDto {
    id!: number;
    email!: string;
    createdAt!: Date;
}

