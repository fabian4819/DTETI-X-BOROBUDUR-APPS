import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../auth_wrapper.dart';
import '../main_navigation.dart';
import '../../utils/app_colors.dart';
import '../../utils/notification_helper.dart';
import '../../services/auth_manager.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  
  const EmailVerificationScreen({
    super.key,
    required this.email,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;

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
          'auth.verification_title'.tr(),
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
                    Icons.mark_email_unread_outlined,
                    size: 80,
                    color: AppColors.primary,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Title and description
                Text(
                  'auth.verification_title'.tr(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkGray,
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  'Kami telah mengirimkan kode verifikasi ke:\n${widget.email}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.mediumGray,
                    height: 1.5,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Verification code field
                Text(
                  'Kode Verifikasi',
                  style: const TextStyle(
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
                      return 'Kode verifikasi harus 6 karakter';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'auth.verification_subtitle'.tr(),
                    prefixIcon: const Icon(
                      Icons.confirmation_number_outlined,
                      color: AppColors.mediumGray,
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Verify button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleVerifyEmail,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'auth.verify'.tr(),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // Resend code
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Tidak menerima kode?',
                        style: const TextStyle(
                          color: AppColors.mediumGray,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _isResending ? null : _handleResendCode,
                        child: _isResending
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                ),
                              )
                            : Text(
                                'auth.resend_code'.tr(),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Back to login
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AuthWrapper(),
                        ),
                        (route) => false,
                      );
                    },
                    child: Text(
                      'Kembali ke Login',
                      style: const TextStyle(
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

  Future<void> _handleVerifyEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await AuthManager.instance.verifyEmail(
        email: widget.email,
        code: _codeController.text.trim().toUpperCase(),
      );

      if (result.success) {
        if (!mounted) return;
        
        // Show success notification
        NotificationHelper.showCustomNotification(
          context: context,
          message: result.message,
          color: Colors.black,
          isSuccess: result.success,
        );

        // Wait briefly for the user to see the success message
        await Future.delayed(const Duration(milliseconds: 1500));

        if (mounted) {
          // Navigate directly to main navigation (home page)
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const MainNavigation(),
            ),
            (route) => false,
          );
        }
      } else {
        if (!mounted) return;
        
        // Show error notification
        NotificationHelper.showCustomNotification(
          context: context,
          message: result.message,
          color: Colors.black,
          isSuccess: result.success,
        );
      }
    } catch (e) {
      if (!mounted) return;

      NotificationHelper.showError(
        context,
        'auth.messages.network_error'.tr(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleResendCode() async {
    setState(() {
      _isResending = true;
    });

    try {
      final result = await AuthManager.instance.resendVerification(
        email: widget.email,
      );

      if (!mounted) return;

      NotificationHelper.showCustomNotification(
        context: context,
        message: result.message,
        color: Colors.black,
        isSuccess: result.success,
      );
    } catch (e) {
      if (!mounted) return;

      NotificationHelper.showError(
        context,
        'auth.messages.network_error'.tr(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }
}