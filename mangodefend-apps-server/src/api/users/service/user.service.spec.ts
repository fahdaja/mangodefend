import { UserService } from './user.service';
import { User } from '../entity/user.entity';
import { CreateUserDto } from '../dto/user.dto';
import { ConflictException } from '@nestjs/common';

describe('UserService', () => {
  let userService: UserService;
  let mockUserRepository: any;
  let mockDeviceRepository: any;
  let mockPlanRepository: any;
  let mockSubscriptionRepository: any;
  let mockBcryptService: any;
  let mockMailService: any;
  let mockRedisService: any;

  beforeEach(() => {
    mockUserRepository = {
      create: jest.fn().mockImplementation((user: User) => user),
      save: jest.fn().mockImplementation(async (user: User) => user),
      findOne: jest.fn(),
      remove: jest.fn().mockResolvedValue(true),
    };

    mockDeviceRepository = {
      findOne: jest.fn(),
      save: jest.fn(),
      find: jest.fn(),
      delete: jest.fn().mockResolvedValue(true),
    };

    mockPlanRepository = {
      findOne: jest.fn(),
    };

    mockSubscriptionRepository = {
      create: jest.fn(),
      save: jest.fn(),
      delete: jest.fn().mockResolvedValue(true),
    };

    mockBcryptService = {
      hashPassword: jest.fn().mockResolvedValue('hashed-password'),
    };

    mockMailService = {
      sendVerificationEmail: jest.fn().mockResolvedValue(true),
    };

    mockRedisService = {
      setVerificationToken: jest.fn().mockResolvedValue(undefined),
      getVerificationToken: jest.fn().mockResolvedValue(null),
    };

    userService = new UserService(
      mockUserRepository,
      mockDeviceRepository,
      mockPlanRepository,
      mockSubscriptionRepository,
      mockBcryptService,
      mockMailService,
      mockRedisService,
    );
  });

  it('should create user with hashed password and send registration OTP', async () => {
    const createUserDto: CreateUserDto = {
      email: 'testuser@example.com',
      password: 'plaintextpassword',
    };

    mockUserRepository.findOne.mockResolvedValue(null); // No existing user

    const createdUser = await userService.createUser(createUserDto);

    expect(mockUserRepository.findOne).toHaveBeenCalledWith({ where: { email: 'testuser@example.com' } });
    expect(mockBcryptService.hashPassword).toHaveBeenCalledWith('plaintextpassword');
    expect(mockUserRepository.create).toHaveBeenCalledWith(
      expect.objectContaining({
        email: 'testuser@example.com',
        is_email_verified: false,
      }),
    );
    expect(mockUserRepository.save).toHaveBeenCalled();
    expect(mockRedisService.setVerificationToken).toHaveBeenCalledWith('testuser@example.com', expect.any(String), 300);
    expect(mockMailService.sendVerificationEmail).toHaveBeenCalledWith('testuser@example.com', expect.any(String));

    expect(createdUser).toBeDefined();
    expect(createdUser.password).toBe('hashed-password');
  });

  it('should handle email uniqueness constraint', async () => {
    const createUserDto: CreateUserDto = {
      email: 'testuser@example.com',
      password: 'plaintextpassword',
    };

    mockUserRepository.findOne.mockResolvedValue({ id: 1, email: 'testuser@example.com', is_email_verified: true }); // Existing verified user

    await expect(userService.createUser(createUserDto)).rejects.toThrow(ConflictException);
    await expect(userService.createUser(createUserDto)).rejects.toThrow('Email already exists');
  });

  it('should remove old unverified account and register fresh user when OTP is expired', async () => {
    const createUserDto: CreateUserDto = {
      email: 'testuser@example.com',
      password: 'newpassword',
    };

    const expiredUser = { id: 1, email: 'testuser@example.com', is_email_verified: false, createdAt: new Date(Date.now() - 90000 * 1000) };
    mockUserRepository.findOne.mockResolvedValue(expiredUser);
    mockRedisService.getVerificationToken.mockResolvedValue(null);

    const result = await userService.createUser(createUserDto);

    expect(mockUserRepository.remove).toHaveBeenCalledWith(expiredUser);
    expect(mockBcryptService.hashPassword).toHaveBeenCalledWith('newpassword');
    expect(mockUserRepository.save).toHaveBeenCalled();
    expect(mockRedisService.setVerificationToken).toHaveBeenCalledWith('testuser@example.com', expect.any(String), 300);
    expect(mockMailService.sendVerificationEmail).toHaveBeenCalledWith('testuser@example.com', expect.any(String));
    expect(result).toBeDefined();
  });

  it('should handle character limit for email', async () => {
    const user: CreateUserDto = {
      email: 'a'.repeat(256) + '@example.com',
      password: 'plaintextpassword',
    };

    // Simulate a case where the email exceeds character limit
    mockUserRepository.create.mockImplementation(() => {
      const error = new Error('Email exceeds character limit');
      (error as any).code = '22001'; // PostgreSQL string data right truncation error code
      throw error;
    });

    await expect(userService.createUser(user)).rejects.toThrow('Email exceeds character limit');
  });
});