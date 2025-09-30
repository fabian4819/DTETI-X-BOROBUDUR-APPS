import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_colors.dart';

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
          message: data['message'] ?? 'Registrasi berhasil',
          data: data,
        );
      } else {
        return AuthResult.error(
          message: data['message'] ?? 'Registrasi gagal',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return AuthResult.error(message: 'Terjadi kesalahan jaringan: $e');
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
        // Handle successful verification similar to login
        final userData = data['data']?['data'];

        if (userData != null) {
          // Save tokens and user data for auto-login
          final prefs = await SharedPreferences.getInstance();
          if (userData['access_token'] != null) {
            await prefs.setString('access_token', userData['access_token']);
          }
          if (userData['refresh_token'] != null) {
            await prefs.setString('refresh_token', userData['refresh_token']);
          }

          // Save user data
          final userDataForStorage = {
            'id': userData['id'],
            'name': userData['name'],
            'email': userData['email'],
            'role': userData['role'] ?? 'user',
          };
          await prefs.setString('user_data', jsonEncode(userDataForStorage));
        }

        return AuthResult.success(
          message: data['message'] ?? 'Email berhasil diverifikasi!',
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
          message: data['message'] ?? 'Verifikasi email gagal',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return AuthResult.error(message: 'Terjadi kesalahan jaringan: $e');
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
          message: data['message'] ?? 'Kode verifikasi telah dikirim ulang!',
          data: data,
        );
      } else {
        return AuthResult.error(
          message: data['message'] ?? 'Gagal mengirim ulang kode verifikasi',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return AuthResult.error(message: 'Terjadi kesalahan jaringan: $e');
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
          message: data['message'] ?? 'Login berhasil',
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
          message: data['message'] ?? 'Login gagal',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return AuthResult.error(message: 'Terjadi kesalahan jaringan: $e');
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

      return AuthResult.info(message: 'Logout berhasil');
    } catch (e) {
      // Even if network fails, clear local data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
      await prefs.remove('user_data');
      
      return AuthResult.info(message: 'Logout berhasil');
    }
  }

  Future<AuthResult> refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');

      if (refreshToken == null) {
        return AuthResult.warning(message: 'Token refresh tidak tersedia');
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

        return AuthResult.info(
          message: 'Token berhasil diperbarui',
          data: data,
        );
      } else {
        // If refresh fails, clear stored tokens
        await prefs.remove('access_token');
        await prefs.remove('refresh_token');
        await prefs.remove('user_data');
        
        return AuthResult.error(
          message: data['message'] ?? 'Gagal memperbarui token',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return AuthResult.error(message: 'Terjadi kesalahan jaringan: $e');
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
        return AuthResult.info(
          message: data['message'] ?? 'Kode reset password telah dikirim',
          data: data,
        );
      } else {
        return AuthResult.error(
          message: data['message'] ?? 'Gagal mengirim kode reset password',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return AuthResult.error(message: 'Terjadi kesalahan jaringan: $e');
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
          message: data['message'] ?? 'Reset password berhasil',
          data: data,
        );
      } else {
        return AuthResult.error(
          message: data['message'] ?? 'Reset password gagal',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return AuthResult.error(message: 'Terjadi kesalahan jaringan: $e');
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
  final Color color;

  AuthResult.success({
    required this.message,
    this.data,
    this.color = AppColors.success,
  }) : success = true, statusCode = null;

  AuthResult.error({
    required this.message,
    this.statusCode,
    this.color = AppColors.error,
  }) : success = false, data = null;

  AuthResult.warning({
    required this.message,
    this.data,
    this.color = AppColors.warning,
  }) : success = true, statusCode = null;

  AuthResult.info({
    required this.message,
    this.data,
    this.color = AppColors.primary,
  }) : success = true, statusCode = null;
}