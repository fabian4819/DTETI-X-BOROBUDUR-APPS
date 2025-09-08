import 'package:flutter/material.dart';
import 'auth/login_screen.dart';
import 'main_navigation.dart';
import '../services/auth_manager.dart';
import '../utils/app_colors.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    await AuthManager.instance.initialize();
    setState(() {
      _isInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: AuthManager.instance,
      builder: (context, child) {
        if (AuthManager.instance.isLoading) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          );
        }

        if (AuthManager.instance.isLoggedIn) {
          return const MainNavigation();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}