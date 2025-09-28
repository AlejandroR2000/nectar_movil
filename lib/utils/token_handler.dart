import 'package:flutter/material.dart';
import '../services/auth_service.dart';

// Mixin para manejar la expiración del token en cualquier pantalla
mixin TokenExpirationHandler<T extends StatefulWidget> on State<T> {
  
  // Método para manejar cuando el token expira
  void handleTokenExpiration() {
    if (mounted) {
      // Mostrar mensaje de sesión expirada
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu sesión ha expirado. Por favor, inicia sesión nuevamente.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );

      // Navegar al login después de un pequeño delay
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
            (route) => false, // Remover todas las rutas anteriores
          );
        }
      });
    }
  }

  // Método para hacer peticiones autenticadas con manejo automático de expiración
  Future<Map<String, dynamic>> makeAuthenticatedRequest({
    required String endpoint,
    required String method,
    Map<String, dynamic>? body,
  }) async {
    final result = await AuthService.makeAuthenticatedRequest(
      endpoint: endpoint,
      method: method,
      body: body,
    );

    // Si el token expiró, manejar automáticamente
    if (result['tokenExpired'] == true) {
      handleTokenExpiration();
    }

    return result;
  }

  // Método para verificar si el token es válido antes de hacer operaciones críticas
  Future<bool> checkTokenValidity() async {
    // Usar la validación real del servidor
    final isValid = await AuthService.isTokenValid();
    if (!isValid) {
      handleTokenExpiration();
      return false;
    }
    return true;
  }
}

// Clase base para pantallas que requieren autenticación
abstract class AuthenticatedScreen extends StatefulWidget {
  const AuthenticatedScreen({super.key});
}

abstract class AuthenticatedScreenState<T extends AuthenticatedScreen> 
    extends State<T> with TokenExpirationHandler {
  
  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  // Verificar autenticación al iniciar la pantalla
  Future<void> _checkAuthentication() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    if (!isLoggedIn && mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }
    
    // No validar automáticamente el token en el servidor
    // Solo verificar que esté logueado localmente
  }
}
