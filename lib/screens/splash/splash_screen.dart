import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_mya/routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      context.go(AppRoutes.login);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment, size: 100, color: Colors.blue),
            SizedBox(height: 20),
            Text('Field Survey', style: TextStyle(fontSize: 28)),
            Text('Aplikasi Mobile Berbasis Flutter'),
          ],
        ),
      ),
    );
  }
}