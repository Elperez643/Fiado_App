import 'dart:async';

import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: AppConstants.splashDurationSeconds), () {
      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3EFE7),
      body: Center(
        child: Container(
          width: 188,
          height: 188,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(44),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F17322C),
                blurRadius: 28,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: Image.asset(
              'assets/images/fiado_logo.jpg',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}
