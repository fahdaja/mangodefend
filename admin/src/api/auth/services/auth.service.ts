import { BcryptService } from "../../../common/hash/bcrypt.service";
import { UserService } from "../../users/services/user.service";
import { BadRequestException, forwardRef, Inject, Injectable, UnauthorizedException } from "@nestjs/common";
import { DeactivateDeviceDto, LoginDto, PayloadDto, SessionDevice, SignOutDto } from "../dto/auth.dto";
import { FirebaseLoginDto } from "../dto/firebase-auth.dto";
import { JwtService } from "@nestjs/jwt";
import { application_type, os_type } from "../../users/enum/devices.enum";
import { AuthProvider } from "../../users/enum/auth-provider.enum";
import { ConfigService } from "@nestjs/config";
import { FirebaseService } from "../../../common/firebase/firebase.service";

@Injectable()
export class AuthService {
    constructor(
        @Inject(forwardRef(() => UserService)) private readonly userService: UserService,
        private readonly bcryptService: BcryptService,
        private readonly jwtService: JwtService,
        private readonly configService: ConfigService,
        private readonly firebaseService: FirebaseService,
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
        const isPasswordValid = await this.bcryptService.comparePassword(password, existingUser.password);
        if (!isPasswordValid) {
            throw new UnauthorizedException('Invalid email or password');
        }
        if (!device || !device.hardware_id || !device.os_type || !device.app_type) {
            throw new BadRequestException('Data device tidak lengkap. Harap sertakan object device dengan property: hardware_id, hostname, os_type, dan app_type');
        }

        try {
            await this.userService.recordUserDevice(existingUser.id, { 
                hardware_id: device.hardware_id, 
                hostname: device.hostname, 
                os_type: device.os_type, 
                app_type: device.app_type, 
                last_login: new Date(), 
                last_active: null, 
                is_active: true 
            });
        } catch (error: any) {
            throw new BadRequestException(`Gagal mencatat perangkat: ${error.message}`);
        }
        const token = await this.generateToken({
            id: existingUser.id, email: existingUser.email, role: existingUser.role
        })
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
                    role: existingUser.role
                }
            }
        }
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
    /**
     * Firebase OAuth Login Flow:
     * 1. Verify Firebase ID Token
     * 2. Find or create user in our database
     * 3. Optionally record device
     * 4. Return our own JWT token
     */
    async firebaseSignIn(firebaseLoginDto: FirebaseLoginDto): Promise<any> {
        // 1. Verify Firebase token
        const decodedToken = await this.firebaseService.verifyIdToken(firebaseLoginDto.idToken);

        if (!decodedToken.email) {
            throw new BadRequestException('Firebase account tidak memiliki email. Email diperlukan untuk registrasi.');
        }

        // 2. Map Firebase provider ke AuthProvider enum
        const providerMap: Record<string, AuthProvider> = {
            'google.com': AuthProvider.GOOGLE,
            'github.com': AuthProvider.GITHUB,
            'password': AuthProvider.LOCAL,
        };
        const authProvider = providerMap[decodedToken.firebase.sign_in_provider] || AuthProvider.GOOGLE;

        // 3. Find or create user
        const { user, isNewUser } = await this.userService.findOrCreateFirebaseUser({
            firebase_uid: decodedToken.uid,
            email: decodedToken.email,
            auth_provider: authProvider,
            display_name: decodedToken.name,
            photo_url: decodedToken.picture,
        });

        // 4. Record device (optional - jika device data dikirim)
        if (firebaseLoginDto.device && firebaseLoginDto.device.hardware_id) {
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
                // Device recording failure should not block login
                console.warn(`Gagal mencatat perangkat: ${error.message}`);
            }
        }

        // 5. Generate internal JWT
        const token = await this.generateToken({
            id: user.id,
            email: user.email,
            role: user.role,
        });

        return {
            status: 'success',
            message: isNewUser ? 'Registration via OAuth successful' : 'Login via OAuth successful',
            data: {
                access_token: token.access_token,
                token_type: 'Bearer',
                expires_in: token.expires_in,
                is_new_user: isNewUser,
                user: {
                    id: user.id,
                    email: user.email,
                    role: user.role,
                    display_name: user.display_name,
                    photo_url: user.photo_url,
                    auth_provider: user.auth_provider,
                },
            },
        };
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
}