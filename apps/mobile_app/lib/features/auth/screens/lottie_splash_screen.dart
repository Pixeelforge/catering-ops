import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LottieSplashScreen extends StatefulWidget {
  final Widget nextScreen;
  const LottieSplashScreen({super.key, required this.nextScreen});

  @override
  State<LottieSplashScreen> createState() => _LottieSplashScreenState();
}

class _LottieSplashScreenState extends State<LottieSplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  void _navigateToNext() async {
    // Wait for animation or a fixed duration
    await Future.delayed(const Duration(seconds: 4));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => widget.nextScreen),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFF1A1A2E,
      ), // Using current app background as default
      body: Center(
        child: Lottie.asset(
          'assets/splash_animation.json',
          fit: BoxFit.cover,
          repeat: false, // Ensure it only plays once
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
        ),
      ),
    );
  }
}
