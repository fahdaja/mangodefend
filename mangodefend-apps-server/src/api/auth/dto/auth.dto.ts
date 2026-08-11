import { IsNotEmpty, IsOptional, IsString } from "class-validator";
import { application_type, os_type } from "src/api/users/enum/devices.enum";

export class LoginDto {

    @IsNotEmpty({ message: 'Email is required' })
    email!: string;

    @IsNotEmpty({ message: 'Password is required' })
    password!: string;
}

export class SessionDevice{

    @IsNotEmpty()
    hardware_id !: string

    @IsNotEmpty()
    hostname !: string

    @IsNotEmpty()
    app_type!: application_type

    @IsNotEmpty()
    os_type!: os_type

}

export class PayloadDto {
    @IsOptional()
    role?: string;
    
    @IsNotEmpty({ message: 'Email is required' })
    email!: string;

    @IsNotEmpty({ message: 'User ID is required' })
    id!: number;
}


export class SignOutDto {
    @IsNotEmpty()
    user_id?: number

    @IsNotEmpty()
    @IsString()
    hardware_id!: string
}

export class DeactivateDeviceDto {
    @IsNotEmpty({ message: 'ID is required '})
    id!: number;

    @IsNotEmpty({ message: 'User ID is Required' })
    user_id!: number;

    @IsNotEmpty({ message: 'Hardware ID is Required'})
    hardware_id!: string;
}

export class LoginResponseDto{
    access_token?: string;
    refresh_token?: string;
    expiresIn?: number;
}

export class VerifyRegistrationOtpDto {
    @IsNotEmpty({ message: 'Email is required' })
    email!: string;

    @IsNotEmpty({ message: 'Verification code is required' })
    code!: string;
}

export class VerifyLoginOtpDto {
    @IsNotEmpty({ message: 'Email is required' })
    email!: string;

    @IsNotEmpty({ message: 'OTP is required' })
    otp!: string;

    @IsOptional()
    device?: SessionDevice;
}

export class ResendOtpDto {
    @IsNotEmpty({ message: 'Email is required' })
    email!: string;

    @IsOptional()
    type?: 'registration' | 'login';
}

export class ForgotPasswordDto {
    @IsNotEmpty({ message: 'Email is required' })
    email!: string;
}

export class ResetPasswordDto {
    @IsNotEmpty({ message: 'Email is required' })
    email!: string;

    @IsNotEmpty({ message: 'Token/OTP is required' })
    token!: string;

    @IsNotEmpty({ message: 'New password is required' })
    newPassword!: string;
}