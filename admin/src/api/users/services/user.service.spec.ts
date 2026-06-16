import { UserService } from './user.service';
import { User } from '../entity/user.entity';
import { CreateUserDto } from '../dto/user.dto';
import { BadRequestException } from '@nestjs/common';

describe('UserService', () => {
  let userService: UserService;
  let mockRepository: any;
  let mockBcryptService: any;

  beforeEach(() => {
    mockRepository = {
      create: jest.fn().mockImplementation((user: User) => user),
      save: jest.fn().mockImplementation(async (user: User) => user),
      findOne: jest.fn(),
    };

    mockBcryptService = {
      hashPassword: jest.fn().mockResolvedValue('hashed-password'),
    };

    userService = new UserService(mockRepository, mockBcryptService);
  });

  it('should create user with hashed password', async () => {
    const createUserDto: CreateUserDto = {
      email: 'testuser@example.com',
      password: 'plaintextpassword',
    };

    mockRepository.findOne.mockResolvedValue(null); // No existing user

    const createdUser = await userService.createUser(createUserDto);

    expect(mockRepository.findOne).toHaveBeenCalledWith({ where: { email: 'testuser@example.com' } });
    expect(mockBcryptService.hashPassword).toHaveBeenCalledWith('plaintextpassword');
    expect(mockRepository.create).toHaveBeenCalledWith(createUserDto);
    expect(mockRepository.save).toHaveBeenCalled();

    expect(createdUser).toBeDefined();
    expect(createdUser.password).toBe('hashed-password');
  });

  it('should handle email uniqueness constraint', async () => {
    const createUserDto: CreateUserDto = {
      email: 'testuser@example.com',
      password: 'plaintextpassword',
    };

    mockRepository.findOne.mockResolvedValue({ id: 1, email: 'testuser@example.com' }); // Existing user

    await expect(userService.createUser(createUserDto)).rejects.toThrow(BadRequestException);
    await expect(userService.createUser(createUserDto)).rejects.toThrow('Email already exists');
  });
  it('should handle character limit for email', async () => {
    const user = new User();
    user.email = 'a'.repeat(256) + '@example.com'; // 256 characters + domain
    user.password = 'plaintextpassword';

    // Simulate a case where the email exceeds character limit
    mockRepository.create.mockImplementation(() => {
      const error = new Error('Email exceeds character limit');
      (error as any).code = '22001'; // PostgreSQL string data right truncation error code
      throw error;
    });

    await expect(userService.createUser(user)).rejects.toThrow('Email exceeds character limit');
  });
});