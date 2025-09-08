import 'package:flutter/foundation.dart';
import '../models/user.dart';
import 'auth_service.dart';

class AuthManager extends ChangeNotifier {
  static AuthManager? _instance;
  static AuthManager get instance => _instance ??= AuthManager._();
  AuthManager._();

  User? _currentUser;
  bool _isLoading = false;
  bool _isLoggedIn = false;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;

  Future<void> initialize() async {
    _setLoading(true);
    
    try {
      _isLoggedIn = await AuthService.instance.isLoggedIn();
      
      if (_isLoggedIn) {
        final userData = await AuthService.instance.getCurrentUser();
        if (userData != null) {
          _currentUser = User.fromJson(userData);
        }
      }
    } catch (e) {
      debugPrint('Error initializing auth manager: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    
    try {
      final result = await AuthService.instance.login(
        email: email,
        password: password,
      );

      if (result.success && result.data != null) {
        _isLoggedIn = true;
        if (result.data!['user'] != null) {
          _currentUser = User.fromJson(result.data!['user']);
        }
        notifyListeners();
      }

      return result;
    } finally {
      _setLoading(false);
    }
  }

  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    
    try {
      final result = await AuthService.instance.register(
        name: name,
        email: email,
        password: password,
      );

      return result;
    } finally {
      _setLoading(false);
    }
  }

  Future<AuthResult> verifyEmail({
    required String email,
    required String code,
  }) async {
    _setLoading(true);
    
    try {
      final result = await AuthService.instance.verifyEmail(
        email: email,
        code: code,
      );

      return result;
    } finally {
      _setLoading(false);
    }
  }

  Future<AuthResult> resendVerification({
    required String email,
  }) async {
    _setLoading(true);
    
    try {
      final result = await AuthService.instance.resendVerification(
        email: email,
      );

      return result;
    } finally {
      _setLoading(false);
    }
  }

  Future<AuthResult> forgotPassword({
    required String email,
  }) async {
    _setLoading(true);
    
    try {
      final result = await AuthService.instance.forgotPassword(
        email: email,
      );

      return result;
    } finally {
      _setLoading(false);
    }
  }

  Future<AuthResult> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    _setLoading(true);
    
    try {
      final result = await AuthService.instance.resetPassword(
        email: email,
        code: code,
        newPassword: newPassword,
      );

      return result;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    _setLoading(true);
    
    try {
      await AuthService.instance.logout();
      _isLoggedIn = false;
      _currentUser = null;
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

}