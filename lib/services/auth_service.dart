import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl = 'https://borobudurbackend.context.my.id/v1/auth';
  
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();
  AuthService._();

  Future<Map<String, String>> get _headers async {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }


  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: await _headers,
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return AuthResult.success(
          message: data['message'] ?? 'Registration successful',
          data: data,
        );
      } else {
        return AuthResult.error(
          message: data['message'] ?? 'Registration failed',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return AuthResult.error(message: 'Network error: $e');
    }
  }

  Future<AuthResult> verifyEmail({
    required String email,
    required String code,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify-email'),
        headers: await _headers,
        body: jsonEncode({
          'email': email,
          'code': code,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return AuthResult.success(
          message: data['message'] ?? 'Email verified successfully',
          data: data,
        );
      } else {
        return AuthResult.error(
          message: data['message'] ?? 'Email verification failed',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return AuthResult.error(message: 'Network error: $e');
    }
  }

  Future<AuthResult> resendVerification({
    required String email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/resend-verification'),
        headers: await _headers,
        body: jsonEncode({
          'email': email,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return AuthResult.success(
          message: data['message'] ?? 'Verification code sent',
          data: data,
        );
      } else {
        return AuthResult.error(
          message: data['message'] ?? 'Failed to resend verification',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return AuthResult.error(message: 'Network error: $e');
    }
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: await _headers,
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // API returns nested structure: data.data contains the actual user data
        final userData = data['data']?['data'];
        
        // Save tokens to shared preferences
        final prefs = await SharedPreferences.getInstance();
        if (userData?['access_token'] != null) {
          await prefs.setString('access_token', userData['access_token']);
        }
        if (userData?['refresh_token'] != null) {
          await prefs.setString('refresh_token', userData['refresh_token']);
        }
        if (userData != null) {
          // Create user object without tokens for storage
          final userDataForStorage = {
            'id': userData['id'],
            'name': userData['name'],
            'email': userData['email'],
            'role': userData['role'] ?? 'user',
          };
          await prefs.setString('user_data', jsonEncode(userDataForStorage));
        }

        return AuthResult.success(
          message: data['message'] ?? 'Login successful',
          data: {
            'user': userData != null ? {
              'id': userData['id'],
              'name': userData['name'], 
              'email': userData['email'],
              'role': userData['role'] ?? 'user',
            } : null,
            'access_token': userData?['access_token'],
            'refresh_token': userData?['refresh_token'],
          },
        );
      } else {
        return AuthResult.error(
          message: data['message'] ?? 'Login failed',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return AuthResult.error(message: 'Network error: $e');
    }
  }

  Future<AuthResult> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');

      if (refreshToken != null) {
        await http.post(
          Uri.parse('$baseUrl/logout'),
          headers: await _headers,
          body: jsonEncode({
            'refreshToken': refreshToken,
          }),
        );
      }

      // Clear all stored data
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
      await prefs.remove('user_data');

      return AuthResult.success(message: 'Logout successful');
    } catch (e) {
      // Even if network fails, clear local data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
      await prefs.remove('user_data');
      
      return AuthResult.success(message: 'Logout successful');
    }
  }

  Future<AuthResult> refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');

      if (refreshToken == null) {
        return AuthResult.error(message: 'No refresh token available');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/refresh-token'),
        headers: await _headers,
        body: jsonEncode({
          'refresh_token': refreshToken,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Update stored tokens
        if (data['access_token'] != null) {
          await prefs.setString('access_token', data['access_token']);
        }
        if (data['refresh_token'] != null) {
          await prefs.setString('refresh_token', data['refresh_token']);
        }

        return AuthResult.success(
          message: 'Token refreshed successfully',
          data: data,
        );
      } else {
        // If refresh fails, clear stored tokens
        await prefs.remove('access_token');
        await prefs.remove('refresh_token');
        await prefs.remove('user_data');
        
        return AuthResult.error(
          message: data['message'] ?? 'Token refresh failed',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return AuthResult.error(message: 'Network error: $e');
    }
  }

  Future<AuthResult> forgotPassword({
    required String email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/forgot-password'),
        headers: await _headers,
        body: jsonEncode({
          'email': email,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return AuthResult.success(
          message: data['message'] ?? 'Password reset code sent',
          data: data,
        );
      } else {
        return AuthResult.error(
          message: data['message'] ?? 'Failed to send reset code',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return AuthResult.error(message: 'Network error: $e');
    }
  }

  Future<AuthResult> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reset-password'),
        headers: await _headers,
        body: jsonEncode({
          'email': email,
          'code': code,
          'newPassword': newPassword,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return AuthResult.success(
          message: data['message'] ?? 'Password reset successful',
          data: data,
        );
      } else {
        return AuthResult.error(
          message: data['message'] ?? 'Password reset failed',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return AuthResult.error(message: 'Network error: $e');
    }
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('access_token');
    return accessToken != null && accessToken.isNotEmpty;
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user_data');
    if (userData != null) {
      return jsonDecode(userData);
    }
    return null;
  }
}

class AuthResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;
  final int? statusCode;

  AuthResult.success({
    required this.message,
    this.data,
  }) : success = true, statusCode = null;

  AuthResult.error({
    required this.message,
    this.statusCode,
  }) : success = false, data = null;
}