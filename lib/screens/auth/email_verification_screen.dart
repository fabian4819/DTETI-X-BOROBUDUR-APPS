import 'package:flutter/material.dart';
import '../auth_wrapper.dart';
import '../../utils/app_colors.dart';
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
        title: const Text(
          'Verifikasi Email',
          style: TextStyle(
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
                const Text(
                  'Verifikasi Email Anda',
                  style: TextStyle(
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
                const Text(
                  'Kode Verifikasi',
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
                      return 'Kode verifikasi tidak boleh kosong';
                    }
                    if (value.length != 6) {
                      return 'Kode verifikasi harus 6 karakter';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    hintText: 'Masukkan kode verifikasi (6 digit)',
                    prefixIcon: Icon(
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
                        : const Text(
                            'Verifikasi Email',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Resend code
                Center(
                  child: Column(
                    children: [
                      const Text(
                        'Tidak menerima kode?',
                        style: TextStyle(
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
                            : const Text(
                                'Kirim Ulang Kode',
                                style: TextStyle(
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
        
        // Show success message with proper green color
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email berhasil diverifikasi! Selamat datang!'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );

        // Check if user data is returned and auto-login
        if (result.data != null && result.data!['user'] != null) {
          // Auto-login the user after successful verification
          await AuthManager.instance.initialize();
          
          // Navigate directly to main app
          await Future.delayed(const Duration(seconds: 1));
          
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => const AuthWrapper(),
              ),
              (route) => false,
            );
          }
        } else {
          // Reinitialize auth manager to clear any cached state
          await AuthManager.instance.reinitialize();

          // Wait a moment then navigate to auth wrapper
          await Future.delayed(const Duration(seconds: 2));
          
          if (mounted) {
            // Navigate back to auth wrapper to properly handle authentication state
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => const AuthWrapper(),
              ),
              (route) => false,
            );
          }
        }
      } else {
        if (!mounted) return;
        
        // Show error message with proper red color
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $e'),
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

  Future<void> _handleResendCode() async {
    setState(() {
      _isResending = true;
    });

    try {
      final result = await AuthManager.instance.resendVerification(
        email: widget.email,
      );

      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kode verifikasi telah dikirim ulang!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
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
          content: Text('Terjadi kesalahan: $e'),
          backgroundColor: AppColors.error,
        ),
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