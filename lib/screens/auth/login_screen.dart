import 'package:flutter/material.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../../utils/app_colors.dart';
import '../../services/auth_manager.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Reinitialize auth manager when returning to login screen
    // This ensures any cached authentication state is cleared
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AuthManager.instance.reinitialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 15),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Image.asset(
                        'assets/images/splash-screen.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.temple_buddhist,
                            size: 60,
                            color: AppColors.primary,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Bergabung Seperti Lainnya!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkGray,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Jadikan Setiap Kunjungan Bermakna',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.mediumGray,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Toggle buttons
              Container(
                decoration: BoxDecoration(
                  color: AppColors.lightGray.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          'Masuk',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkGray,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: const Text(
                            'Daftar',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.mediumGray),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Email field
              const Text(
                'Email',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkGray,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Email tidak boleh kosong';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Format email tidak valid';
                  }
                  return null;
                },
                decoration: const InputDecoration(
                  hintText: 'Masukkan alamat email anda',
                  prefixIcon: Icon(
                    Icons.email_outlined,
                    color: AppColors.mediumGray,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Password field
              const Text(
                'Password',
                style: TextStyle(
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
                    return 'Password tidak boleh kosong';
                  }
                  if (value.length < 6) {
                    return 'Password minimal 6 karakter';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: 'Masukkan password anda',
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

              const SizedBox(height: 14),

              // Remember me and forgot password
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (value) {
                      setState(() {
                        _rememberMe = value ?? false;
                      });
                    },
                    activeColor: AppColors.primary,
                  ),
                  const Text('Ingat saya'),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Lupa password?',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // Login button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
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
                          'Masuk',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),

              const SizedBox(height: 24),


              const Center(
                child: Text(
                  'Atau masuk dengan',
                  style: TextStyle(color: AppColors.mediumGray),
                ),
              ),

              const SizedBox(height: 24),

              // Social login buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            FontAwesomeIcons.google,
                            color: Colors.red,
                            size: 20,
                          ),
                        ),
                      ),
                      label: const Text('Google'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: AppColors.lightGray),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  // const SizedBox(width: 16),
                  // Expanded(
                  //   child: OutlinedButton.icon(
                  //     onPressed: () {},
                  //     icon: Container(
                  //       width: 20,
                  //       height: 20,
                  //       color: AppColors.mediumGray,
                  //     ),
                  //     label: const Text('Facebook'),
                  //     style: OutlinedButton.styleFrom(
                  //       padding: const EdgeInsets.symmetric(vertical: 16),
                  //       side: const BorderSide(color: AppColors.lightGray),
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(12),
                  //       ),
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await AuthManager.instance.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (result.success) {
        if (!mounted) return;
        
        // Don't navigate manually - let AuthWrapper handle it
        // AuthManager has already updated the state, so AuthWrapper
        // will automatically navigate to MainNavigation
      } else {
        if (!mounted) return;
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $e'),
          backgroundColor: Colors.red,
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
