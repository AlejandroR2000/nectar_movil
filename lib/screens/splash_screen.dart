import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Esperar un poco para mostrar el splash
    await Future.delayed(const Duration(seconds: 2));
    
    // Solo verificar si hay un token guardado localmente
    final isLoggedIn = await AuthService.isLoggedIn();
    
    if (mounted) {
      if (isLoggedIn) {
        // Si hay token, ir directamente al home
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        // Si no hay token, ir al login
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 150,
              width: 150,
              child: Image.asset(
                'assets/images/NECTARlogo.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.local_drink,
                    size: 100,
                    color: Theme.of(context).primaryColor,
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Nectar Móvil',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Cargando...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}