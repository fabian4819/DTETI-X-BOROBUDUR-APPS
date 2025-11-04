import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'login_screen.dart';
import '../../utils/app_colors.dart';
import '../../services/auth_manager.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  
  const ResetPasswordScreen({
    super.key,
    required this.email,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.darkGray),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'auth.reset_password'.tr(),
          style: const TextStyle(
            color: AppColors.darkGray,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                
                // Icon
                const Center(
                  child: Icon(
                    Icons.lock_reset_outlined,
                    size: 80,
                    color: AppColors.primary,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Title and description
                Text(
                  'auth.reset_password'.tr(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkGray,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                Text(
                  'Masukkan kode reset yang telah dikirim ke:\n${widget.email}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.mediumGray,
                    height: 1.5,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Reset code field
                Text(
                  'Kode Reset',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkGray,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'auth.validation.code_required'.tr();
                    }
                    if (value.length != 6) {
                      return 'Kode reset harus 6 karakter';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    hintText: 'Masukkan kode reset (6 digit)',
                    prefixIcon: Icon(
                      Icons.confirmation_number_outlined,
                      color: AppColors.mediumGray,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // New password field
                Text(
                  'auth.new_password'.tr(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkGray,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'auth.validation.password_required'.tr();
                    }
                    if (value.length < 6) {
                      return 'auth.validation.password_min'.tr();
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'auth.password_hint'.tr(),
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: AppColors.mediumGray,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppColors.mediumGray,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Confirm password field
                Text(
                  'auth.confirm_password'.tr(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkGray,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'auth.validation.password_required'.tr();
                    }
                    if (value != _passwordController.text) {
                      return 'auth.validation.password_mismatch'.tr();
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'auth.confirm_password_hint'.tr(),
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: AppColors.mediumGray,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppColors.mediumGray,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Reset password button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleResetPassword,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Reset Password',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Back to login
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                    },
                    child: const Text(
                      'Kembali ke Login',
                      style: TextStyle(
                        color: AppColors.mediumGray,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await AuthManager.instance.resetPassword(
        email: widget.email,
        code: _codeController.text.trim().toUpperCase(),
        newPassword: _passwordController.text,
      );

      if (result.success) {
        if (!mounted) return;
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('auth.messages.reset_success'.tr()),
            backgroundColor: AppColors.success,
          ),
        );

        // Navigate to login screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
          (route) => false,
        );
      } else {
        if (!mounted) return;
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('auth.error_occurred'.tr().replaceAll('{}', e.toString())),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}