class RegisterRequest {
  final String fullName;
  final String email;
  final String password;
  final String? deviceId;
  final String? deviceName;
  final String? osVersion;

  const RegisterRequest({
    required this.fullName,
    required this.email,
    required this.password,
    this.deviceId,
    this.deviceName,
    this.osVersion,
  });

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'email': email,
      'password': password,
      if (deviceId != null) 'device_id': deviceId,
      if (deviceName != null) 'device_name': deviceName,
      if (osVersion != null) 'os_version': osVersion,
    };
  }
}

class LoginRequest {
  final String email;
  final String password;
  final String? deviceId;
  final String? deviceName;
  final String? osVersion;

  const LoginRequest({
    required this.email,
    required this.password,
    this.deviceId,
    this.deviceName,
    this.osVersion,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      if (deviceId != null) 'device_id': deviceId,
      if (deviceName != null) 'device_name': deviceName,
      if (osVersion != null) 'os_version': osVersion,
    };
  }
}

class GoogleOAuthRequest {
  final String idToken;
  final String? email;
  final String? fullName;
  final String? deviceId;
  final String? deviceName;
  final String? osVersion;
  final bool isRegistration;

  const GoogleOAuthRequest({
    required this.idToken,
    this.email,
    this.fullName,
    this.deviceId,
    this.deviceName,
    this.osVersion,
    this.isRegistration = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id_token': idToken,
      if (email != null) 'email': email,
      if (fullName != null) 'full_name': fullName,
      if (deviceId != null) 'device_id': deviceId,
      if (deviceName != null) 'device_name': deviceName,
      if (osVersion != null) 'os_version': osVersion,
      'is_registration': isRegistration,
    };
  }
}

class UserModel {
  final int id;
  final String username;
  final String email;

  const UserModel({
    required this.id,
    required this.username,
    required this.email,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int? ?? 0,
      username: json['full_name'] as String? ?? json['username'] as String? ?? 'User',
      email: json['email'] as String? ?? '',
    );
  }
}

class AuthResponse {
  final bool success;
  final String message;
  final String? accessToken;
  final String? refreshToken;
  final UserModel? user;
  final bool? isNewUser;

  const AuthResponse({
    required this.success,
    required this.message,
    this.accessToken,
    this.refreshToken,
    this.user,
    this.isNewUser,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final tokenData = data['token'] as Map<String, dynamic>?;
    final hasDirectId = json['id'] != null;
    final isSuccess = (json['success'] as bool?) ?? hasDirectId;

    return AuthResponse(
      success: isSuccess,
      message: json['message'] as String? ?? 'Authentication completed',
      accessToken: tokenData?['access_token'] as String?,
      refreshToken: tokenData?['refresh_token'] as String?,
      isNewUser: data['is_new_user'] as bool? ?? json['is_new_user'] as bool?,
      user: data.isNotEmpty
          ? UserModel.fromJson(data)
          : (hasDirectId ? UserModel.fromJson(json) : null),
    );
  }
}
