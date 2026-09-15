import 'package:flutter/material.dart';
import 'package:antivirus_mobile/features/auth/data/remote/auth_service.dart';
import 'package:antivirus_mobile/features/auth/presentation/widgets/google_oauth_button.dart';
import 'package:antivirus_mobile/features/auth/presentation/pages/login_screen.dart';
import 'package:antivirus_mobile/shared/services/device_id_service.dart';
import 'package:antivirus_mobile/shared/services/native_google_auth_service.dart';
import 'package:antivirus_mobile/shared/widgets/register_success_dialog.dart';
import 'package:antivirus_mobile/shared/widgets/email_already_registered_dialog.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback? onRegisterSuccess;
  final VoidCallback? onNavigateToLogin;

  const RegisterScreen({
    super.key,
    this.onRegisterSuccess,
    this.onNavigateToLogin,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final targetEmail = _emailController.text.trim();

    try {
      final deviceId = await DeviceIdService.getMotherboardDeviceId();
      final deviceName = await DeviceIdService.getDeviceModelName();
      final osVersion = await DeviceIdService.getDeviceOsVersion();
      final response = await _authService.registerWithEmailPassword(
        fullName: _fullNameController.text.trim(),
        email: targetEmail,
        password: _passwordController.text,
        deviceId: deviceId,
        deviceName: deviceName,
        osVersion: osVersion,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (response.success) {
          widget.onRegisterSuccess?.call();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              RegisterSuccessDialog.show(
                context,
                onLoginPressed: () {
                  if (widget.onNavigateToLogin != null) {
                    widget.onNavigateToLogin!();
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LoginScreen(
                          onLoginSuccess: widget.onRegisterSuccess,
                        ),
                      ),
                    );
                  }
                },
              );
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        final errString = e.toString();
        final errLower = errString.toLowerCase();
        final isAlreadyRegistered = errLower.contains('terdaftar') ||
            errLower.contains('already') ||
            errLower.contains('exist') ||
            errLower.contains('400');

        setState(() {
          _isLoading = false;
          _errorMessage = isAlreadyRegistered ? null : errString.replaceAll('Exception: ', '');
        });

        if (isAlreadyRegistered) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              EmailAlreadyRegisteredDialog.show(
                context,
                email: targetEmail,
                onLoginPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LoginScreen(
                        onLoginSuccess: widget.onRegisterSuccess,
                      ),
                    ),
                  );
                },
              );
            }
          });
        }
      }
    }
  }

  void _handleGoogleOAuth() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    NativeGoogleAuthResult? googleResult;

    try {
      googleResult = await NativeGoogleAuthService.signIn(context);
      if (googleResult == null) {
        if (mounted) {
          setState(() {
            _isGoogleLoading = false;
          });
        }
        return;
      }

      final deviceId = await DeviceIdService.getMotherboardDeviceId();
      final deviceName = await DeviceIdService.getDeviceModelName();
      final osVersion = await DeviceIdService.getDeviceOsVersion();
      final response = await _authService.loginWithGoogle(
        idToken: googleResult.idToken,
        email: googleResult.email,
        fullName: googleResult.fullName,
        deviceId: deviceId,
        deviceName: deviceName,
        osVersion: osVersion,
        isRegistration: true,
      );

      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });

        if (response.success) {
          final registeredEmail = response.user?.email ?? googleResult.email;
          final isExistingUser = response.isNewUser == false ||
              (response.isNewUser == null && !response.message.toLowerCase().contains('registered'));

          await Future.delayed(const Duration(milliseconds: 300));
          if (!mounted) return;

          if (isExistingUser) {
            EmailAlreadyRegisteredDialog.show(
              context,
              email: registeredEmail,
              onLoginPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LoginScreen(
                      onLoginSuccess: widget.onRegisterSuccess,
                    ),
                  ),
                );
              },
            );
          } else {
            widget.onRegisterSuccess?.call();
            RegisterSuccessDialog.show(
              context,
              onLoginPressed: () {
                if (widget.onNavigateToLogin != null) {
                  widget.onNavigateToLogin!();
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LoginScreen(
                        onLoginSuccess: widget.onRegisterSuccess,
                      ),
                    ),
                  );
                }
              },
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        final errorStr = e.toString();
        final errLower = errorStr.toLowerCase();
        final isAlreadyRegistered = errLower.contains('terdaftar') ||
            errLower.contains('already') ||
            errLower.contains('exist');

        setState(() {
          _isGoogleLoading = false;
          if (errorStr.contains('10:') || errorStr.contains('DEVELOPER_ERROR')) {
            _errorMessage = 'Google Sign-In memerlukan SHA-1 fingerprint di Google Cloud Console.';
          } else {
            _errorMessage = isAlreadyRegistered ? null : errorStr.replaceAll('Exception: ', '');
          }
        });

        if (isAlreadyRegistered) {
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            final regEmail = googleResult?.email ?? '';
            EmailAlreadyRegisteredDialog.show(
              context,
              email: regEmail,
              onLoginPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LoginScreen(
                      onLoginSuccess: widget.onRegisterSuccess,
                    ),
                  ),
                );
              },
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F5F7);
    final cardBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Logo & Header Banner
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF10B981), width: 2),
                    ),
                    child: const Icon(
                      Icons.person_add_rounded,
                      color: Color(0xFF10B981),
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Buat Akun Baru',
                    style: TextStyle(
                      color: primaryTextColor,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Daftar untuk perlindungan cloud Machine Learning',
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  // Main Form Container Card
                  Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Error Alert Notice
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12.0),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.red.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // 1. Full Name Input Field
                          Text(
                            'Nama Lengkap',
                            style: TextStyle(
                              color: primaryTextColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _fullNameController,
                            keyboardType: TextInputType.name,
                            style: TextStyle(color: primaryTextColor, fontSize: 15),
                            decoration: InputDecoration(
                              hintText: 'Nama Lengkap Anda',
                              hintStyle: TextStyle(color: secondaryTextColor),
                              prefixIcon: Icon(Icons.person_outline, color: secondaryTextColor, size: 20),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.8),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Nama lengkap tidak boleh kosong';
                              }
                              if (value.trim().length < 3) {
                                return 'Nama minimal 3 karakter';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          // 2. Email Input Field
                          Text(
                            'Email',
                            style: TextStyle(
                              color: primaryTextColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(color: primaryTextColor, fontSize: 15),
                            decoration: InputDecoration(
                              hintText: 'nama@gmail.com',
                              hintStyle: TextStyle(color: secondaryTextColor),
                              prefixIcon: Icon(Icons.email_outlined, color: secondaryTextColor, size: 20),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.8),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Email tidak boleh kosong';
                              }
                              if (!value.contains('@') || !value.contains('.')) {
                                return 'Format email tidak valid';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          // 3. Password Input Field
                          Text(
                            'Password',
                            style: TextStyle(
                              color: primaryTextColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: TextStyle(color: primaryTextColor, fontSize: 15),
                            decoration: InputDecoration(
                              hintText: 'Minimal 6 karakter',
                              hintStyle: TextStyle(color: secondaryTextColor),
                              prefixIcon: Icon(Icons.lock_outline, color: secondaryTextColor, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: secondaryTextColor,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.8),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password tidak boleh kosong';
                              }
                              if (value.length < 6) {
                                return 'Password minimal 6 karakter';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Primary Register Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleRegister,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      'Daftar',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Visual Divider
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                child: Text(
                                  'Atau daftar dengan',
                                  style: TextStyle(
                                    color: secondaryTextColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Google OAuth Button
                          GoogleOAuthButton(
                            onPressed: _handleGoogleOAuth,
                            isLoading: _isGoogleLoading,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Login Navigation Option Footer
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Sudah punya akun? ',
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (widget.onNavigateToLogin != null) {
                            widget.onNavigateToLogin!();
                          } else {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LoginScreen(
                                  onLoginSuccess: widget.onRegisterSuccess,
                                  onNavigateToRegister: () {
                                    Navigator.pop(context);
                                  },
                                ),
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Masuk',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
