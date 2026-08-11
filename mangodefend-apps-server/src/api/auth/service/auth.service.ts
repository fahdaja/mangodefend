import { BcryptService } from "../../../common/hash/bcrypt.service";
import { UserService } from "../../users/service/user.service";
import { BadRequestException, ForbiddenException, forwardRef, Inject, Injectable, UnauthorizedException } from "@nestjs/common";
import { DeactivateDeviceDto, ForgotPasswordDto, LoginDto, PayloadDto, ResetPasswordDto, SessionDevice, SignOutDto } from "../dto/auth.dto";
import { FirebaseLoginDto } from "../dto/firebase-auth.dto";
import { JwtService } from "@nestjs/jwt";
import { application_type, os_type } from "../../users/enum/devices.enum";
import { AuthProvider } from "../../users/enum/auth-provider.enum";
import { ConfigService } from "@nestjs/config";
import { FirebaseService } from "../../../common/firebase/firebase.service";
import { MailService } from "../../../common/mail/mail.service";
import { RedisService } from "../../../common/redis/redis.service";

@Injectable()
export class AuthService {
    constructor(
        @Inject(forwardRef(() => UserService)) private readonly userService: UserService,
        private readonly bcryptService: BcryptService,
        private readonly jwtService: JwtService,
        private readonly configService: ConfigService,
        private readonly firebaseService: FirebaseService,
        private readonly mailService: MailService,
        private readonly redisService: RedisService,
    ) {}

    async signIn(user: LoginDto, device: SessionDevice, requiredRole?: 'admin' | 'client'): Promise<any> {
        const { email, password } = user;
        const existingUser = await this.userService.findByEmail(email);
        if (!existingUser) {
            throw new UnauthorizedException('User not found');
        }
        if (requiredRole) {
            if (requiredRole === 'admin' && existingUser.role !== 'admin') {
                throw new UnauthorizedException('Invalid email or password');
            }
            if (requiredRole === 'client' && existingUser.role !== 'client') {
                throw new UnauthorizedException('Invalid email or password');
            }
        }
        // User OAuth tidak bisa login pakai password
        if (!existingUser.password) {
            throw new UnauthorizedException(
                `Akun ini terdaftar via ${existingUser.auth_provider}. Silahkan login menggunakan ${existingUser.auth_provider}.`
            );
        }
        if (!password) {
            throw new UnauthorizedException('Invalid email or password');
        }
        const isPasswordValid = await this.bcryptService.comparePassword(password, existingUser.password);
        if (!isPasswordValid) {
            throw new UnauthorizedException('Invalid email or password');
        }
        if (!device || !device.hardware_id || !device.os_type || !device.app_type) {
            throw new BadRequestException('Data device tidak lengkap. Harap sertakan object device dengan property: hardware_id, hostname, os_type, dan app_type');
        }

        // Cek apakah email user sudah terverifikasi
        if (!existingUser.is_email_verified) {
            const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
            await this.redisService.setVerificationToken(existingUser.email, otpCode, 300);
            await this.mailService.sendVerificationEmail(existingUser.email, otpCode);
            throw new ForbiddenException('Email Anda belum diverifikasi. Kode verifikasi registrasi baru telah dikirimkan ke email Anda.');
        }

        // Cek apakah perangkat sudah terdaftar/dikenali untuk user ini
        const existingDevice = await this.userService.findDevice(existingUser.id, device.hardware_id);

        if (existingDevice) {
            // Perangkat sudah dikenali -> langsung login tanpa OTP 2FA
            try {
                await this.userService.recordUserDevice(existingUser.id, {
                    hardware_id: device.hardware_id,
                    hostname: device.hostname,
                    os_type: device.os_type,
                    app_type: device.app_type,
                    last_login: new Date(),
                    last_active: null,
                    is_active: true,
                });
            } catch (error: any) {
                throw new BadRequestException(`Gagal mencatat perangkat: ${error.message}`);
            }

            const token = await this.generateToken({
                id: existingUser.id,
                email: existingUser.email,
                role: existingUser.role,
            });

            return {
                status: 'success',
                message: 'Login successful',
                data: {
                    access_token: token.access_token,
                    token_type: 'Bearer',
                    expires_in: token.expires_in,
                    user: {
                        id: existingUser.id,
                        email: existingUser.email,
                        role: existingUser.role,
                        display_name: existingUser.display_name,
                        photo_url: existingUser.photo_url,
                        auth_provider: existingUser.auth_provider,
                        is_email_verified: existingUser.is_email_verified,
                    },
                },
            };
        }

        // Perangkat belum dikenali (New Device) -> minta OTP 2FA
        const loginOtp = Math.floor(100000 + Math.random() * 900000).toString();
        await this.redisService.setLoginOtp(existingUser.email, loginOtp, 600);
        await this.mailService.sendLoginOtpEmail(existingUser.email, loginOtp);

        return {
            status: 'pending_otp',
            message: 'Perangkat baru terdeteksi. Kode OTP login (2FA) telah dikirimkan ke email Anda.',
            data: {
                email: existingUser.email,
                requires_otp: true,
                is_new_device: true,
            },
        };
    }

    async signOut(signOutDto: SignOutDto): Promise<any> {
       const device = await this.userService.findDevice(signOutDto.user_id!,signOutDto.hardware_id);
       if (!device) {
        throw new BadRequestException('Device not found');
       }
       await this.userService.recordUserDevice(signOutDto.user_id!,  { ...device, last_active: new Date(), is_active: false });
       return {
            status: 'success',
            message: 'Successfully logged out and session terminated',
            data: null
       }
    } 

    async deactivateDevice(deactivateDeviceDto: DeactivateDeviceDto): Promise<void> {
        const {user_id, hardware_id } = deactivateDeviceDto;

        const device = await this.userService.findDevice(user_id, hardware_id);
        if (!device) {
            throw new BadRequestException('Device not found');
        }

        await this.userService.recordUserDevice(user_id,{
            hardware_id: device.hardware_id,
            hostname: '',
            os_type: os_type.UNKNOWN,
            app_type: application_type.UNKNOWN,
            last_active: null,
            last_login: null,
            is_active: false
        });
    }

    async firebaseSignIn(firebaseLoginDto: FirebaseLoginDto): Promise<any> {
        const decodedToken = await this.firebaseService.verifyIdToken(firebaseLoginDto.idToken);

        if (!decodedToken.email) {
            throw new BadRequestException('Firebase account tidak memiliki email. Email diperlukan untuk registrasi.');
        }

        const providerMap: Record<string, AuthProvider> = {
            'google.com': AuthProvider.GOOGLE,
            'github.com': AuthProvider.GITHUB,
            'password': AuthProvider.LOCAL,
        };
        const authProvider = providerMap[decodedToken.firebase.sign_in_provider] || AuthProvider.GOOGLE;

        const { user, isNewUser } = await this.userService.findOrCreateFirebaseUser({
            firebase_uid: decodedToken.uid,
            email: decodedToken.email,
            auth_provider: authProvider,
            display_name: decodedToken.name,
            photo_url: decodedToken.picture,
        });

        if (isNewUser) {
            const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
            await this.redisService.setVerificationToken(user.email, otpCode, 300);
            await this.mailService.sendVerificationEmail(user.email, otpCode);

            return {
                status: 'pending_verification',
                message: 'Registrasi via OAuth berhasil. Silakan verifikasi email Anda dengan kode OTP yang dikirimkan.',
                data: {
                    email: user.email,
                    requires_registration_verification: true,
                    user: {
                        id: user.id,
                        email: user.email,
                        role: user.role,
                        is_email_verified: false,
                    },
                },
            };
        }

        if (!user.is_email_verified) {
            const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
            await this.redisService.setVerificationToken(user.email, otpCode, 300);
            await this.mailService.sendVerificationEmail(user.email, otpCode);
            throw new ForbiddenException('Email Anda belum diverifikasi. Kode verifikasi registrasi baru telah dikirimkan ke email Anda.');
        }

        // Cek ketersediaan perangkat
        if (firebaseLoginDto.device && firebaseLoginDto.device.hardware_id) {
            const existingDevice = await this.userService.findDevice(user.id, firebaseLoginDto.device.hardware_id);

            if (existingDevice) {
                // Perangkat sudah dikenali -> langsung login
                try {
                    await this.userService.recordUserDevice(user.id, {
                        hardware_id: firebaseLoginDto.device.hardware_id,
                        hostname: firebaseLoginDto.device.hostname,
                        os_type: firebaseLoginDto.device.os_type,
                        app_type: firebaseLoginDto.device.app_type,
                        last_login: new Date(),
                        last_active: null,
                        is_active: true,
                    });
                } catch (error: any) {
                    console.warn(`Gagal mencatat perangkat: ${error.message}`);
                }

                const token = await this.generateToken({
                    id: user.id,
                    email: user.email,
                    role: user.role,
                });

                return {
                    status: 'success',
                    message: 'Login via OAuth successful',
                    data: {
                        access_token: token.access_token,
                        token_type: 'Bearer',
                        expires_in: token.expires_in,
                        is_new_user: false,
                        user: {
                            id: user.id,
                            email: user.email,
                            role: user.role,
                            display_name: user.display_name,
                            photo_url: user.photo_url,
                            auth_provider: user.auth_provider,
                            is_email_verified: user.is_email_verified,
                        },
                    },
                };
            }
        }

        // Perangkat belum dikenali (New Device) -> minta OTP 2FA
        const loginOtp = Math.floor(100000 + Math.random() * 900000).toString();
        await this.redisService.setLoginOtp(user.email, loginOtp, 600);
        await this.mailService.sendLoginOtpEmail(user.email, loginOtp);

        return {
            status: 'pending_otp',
            message: 'Perangkat baru terdeteksi. Kode OTP login (2FA) telah dikirimkan ke email Anda.',
            data: {
                email: user.email,
                requires_otp: true,
                is_new_device: true,
            },
        };
    }

    async verifyRegistrationOtp(dto: { email: string; code: string }): Promise<any> {
        const token = await this.redisService.getVerificationToken(dto.email);
        if (!token || token !== dto.code) {
            throw new BadRequestException('Kode verifikasi registrasi tidak valid atau telah kedaluwarsa.');
        }

        const user = await this.userService.findByEmail(dto.email);
        if (!user) {
            throw new BadRequestException('User tidak ditemukan.');
        }

        await this.userService.markEmailAsVerified(user.id);
        await this.redisService.delVerificationToken(dto.email);

        return {
            status: 'success',
            message: 'Email berhasil diverifikasi. Silakan login untuk melanjutkan.',
        };
    }

    async verifyLoginOtp(dto: { email: string; otp: string; device?: SessionDevice }): Promise<any> {
        const savedOtp = await this.redisService.getLoginOtp(dto.email);
        if (!savedOtp || savedOtp !== dto.otp) {
            throw new BadRequestException('Kode OTP login tidak valid atau telah kedaluwarsa.');
        }

        const user = await this.userService.findByEmail(dto.email);
        if (!user) {
            throw new BadRequestException('User tidak ditemukan.');
        }

        if (!user.is_email_verified) {
            throw new ForbiddenException('Email belum diverifikasi. Silakan verifikasi email Anda terlebih dahulu.');
        }

        if (dto.device && dto.device.hardware_id) {
            try {
                await this.userService.recordUserDevice(user.id, {
                    hardware_id: dto.device.hardware_id,
                    hostname: dto.device.hostname,
                    os_type: dto.device.os_type,
                    app_type: dto.device.app_type,
                    last_login: new Date(),
                    last_active: null,
                    is_active: true,
                });
            } catch (error: any) {
                console.warn(`Gagal mencatat perangkat: ${error.message}`);
            }
        }

        await this.redisService.delLoginOtp(dto.email);
        const token = await this.generateToken({
            id: user.id,
            email: user.email,
            role: user.role,
        });

        return {
            status: 'success',
            message: 'Login successful',
            data: {
                access_token: token.access_token,
                token_type: 'Bearer',
                expires_in: token.expires_in,
                user: {
                    id: user.id,
                    email: user.email,
                    role: user.role,
                    display_name: user.display_name,
                    photo_url: user.photo_url,
                    auth_provider: user.auth_provider,
                    is_email_verified: user.is_email_verified,
                },
            },
        };
    }

    async resendOtp(dto: { email: string; type?: 'registration' | 'login' }): Promise<any> {
        const user = await this.userService.findByEmail(dto.email);
        if (!user) {
            throw new BadRequestException('User tidak ditemukan.');
        }

        if (dto.type === 'registration') {
            if (user.is_email_verified) {
                throw new BadRequestException('Email Anda sudah terverifikasi.');
            }
            const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
            await this.redisService.setVerificationToken(dto.email, otpCode, 300);
            await this.mailService.sendVerificationEmail(dto.email, otpCode);
            return {
                status: 'success',
                message: 'Kode verifikasi registrasi baru telah dikirim ke email Anda.',
            };
        } else {
            if (!user.is_email_verified) {
                throw new ForbiddenException('Email belum diverifikasi.');
            }
            const loginOtp = Math.floor(100000 + Math.random() * 900000).toString();
            await this.redisService.setLoginOtp(dto.email, loginOtp, 600);
            await this.mailService.sendLoginOtpEmail(dto.email, loginOtp);
            return {
                status: 'success',
                message: 'Kode OTP login baru telah dikirim ke email Anda.',
            };
        }
    }

    async generateToken(payload: PayloadDto): Promise<{ access_token: string, expires_in: number}> {
        const expiresIn = 86400;
        const secret = this.configService.get<string>('JWT_SECRET');
        const access_token = await this.jwtService.signAsync(payload, {
            secret: secret,
            expiresIn: `${expiresIn}s`
        });
        return {
            access_token,
            expires_in: expiresIn
        }
    }

    async forgotPassword(dto: ForgotPasswordDto): Promise<any> {
        const user = await this.userService.findByEmail(dto.email);
        if (user && user.password) {
            const otpToken = Math.floor(100000 + Math.random() * 900000).toString();
            await this.redisService.setResetToken(dto.email, otpToken, 900);
            await this.mailService.sendForgotPasswordEmail(dto.email, otpToken);
        }
        return {
            status: 'success',
            message: 'Jika email terdaftar, kode verifikasi reset password telah dikirimkan ke email Anda.',
        };
    }

    async resetPassword(dto: ResetPasswordDto): Promise<any> {
        const savedToken = await this.redisService.getResetToken(dto.email);
        if (!savedToken || savedToken !== dto.token) {
            throw new BadRequestException('Kode verifikasi reset password tidak valid atau telah kedaluwarsa.');
        }

        const user = await this.userService.findByEmail(dto.email);
        if (!user) {
            throw new BadRequestException('User tidak ditemukan.');
        }

        const hashedPassword = await this.bcryptService.hashPassword(dto.newPassword);
        await this.userService.updatePassword(user.id, hashedPassword);
        await this.redisService.delResetToken(dto.email);

        return {
            status: 'success',
            message: 'Password berhasil diperbarui. Silakan login dengan password baru Anda.',
        };
    }
}