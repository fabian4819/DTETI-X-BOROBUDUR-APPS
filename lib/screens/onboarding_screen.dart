import 'package:flutter/material.dart';
import 'dart:ui'; // Import for ImageFilter
import 'auth_wrapper.dart';
import '../utils/app_colors.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Set the background image
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              'assets/images/borobudur-onboarding.png',
            ), // Use AssetImage for local assets
            fit: BoxFit.cover, // Cover the entire screen
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Spacer to push content to the bottom (optional, adjust flex as needed)
              const Expanded(
                flex:
                    3, // Adjust this flex to control how much space the top empty part takes
                child: SizedBox.shrink(), // Empty space
              ),
              Expanded(
                flex: 2,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                    child: Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                      ),
                      child: SingleChildScrollView(
                        // Tambahkan ini
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Pelajari Lebih Dekat,\nLebih Bermakna',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkGray,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Jelajahi setiap sudut Candi Borobudur dengan panduan interaktif dan informasi mendalam tentang warisan budaya dunia ini.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.mediumGray,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const AuthWrapper(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  elevation: 5,
                                ),
                                child: const Text(
                                  'Mulai Menjelajah',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
