import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    // Laisse le temps complet à toutes les animations de se jouer (~2.6 secondes)
    await Future.delayed(const Duration(milliseconds: 2600));
    
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      context.go('/home');
    } else {
      context.go('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KiwiColors.primary,
      body: Stack(
        children: [
          // Animation centrale : Emoji Kiwi + Titre KIWI
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🥝', style: TextStyle(fontSize: 110))
                    .animate()
                    .scale(duration: 800.ms, curve: Curves.elasticOut)
                    .then()
                    .shimmer(duration: 1200.ms, color: Colors.white60),
                const SizedBox(height: 16),
                const Text(
                  'KIWI',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 10,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 600.ms)
                    .slideY(begin: 0.3, curve: Curves.easeOut),
              ],
            ),
          ),

          // Animation du bas : from NEHEMIE
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text(
                  'from',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    letterSpacing: 1.5,
                  ),
                ).animate().fadeIn(delay: 1000.ms, duration: 500.ms),
                const SizedBox(height: 4),
                const Text(
                  'NEHEMIE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 1300.ms, duration: 600.ms)
                    .slideY(begin: 0.2, curve: Curves.easeOut),
              ],
            ),
          ),
        ],
      ),
    );
  }
}