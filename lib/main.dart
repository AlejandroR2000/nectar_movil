import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nectar Móvil',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'ES'),
        Locale('en', 'US'),
      ],
      locale: const Locale('es', 'ES'),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 72, 189, 144), // Verde para el theme del néctar
        ),
        useMaterial3: true,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 76, 175, 117),
            foregroundColor: Colors.white,
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
