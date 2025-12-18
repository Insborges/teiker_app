import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:teiker_app/Screens/EcrasPrincipais/AdminScreen.dart';
import 'package:teiker_app/Screens/EcrasPrincipais/TeikersMainScreen.dart';
import 'package:teiker_app/Screens/LoginScreen.dart';
import 'package:teiker_app/backend/auth_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // LOADING
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // SEM LOGIN → LoginScreen
        if (!snapshot.hasData) {
          return LoginScreen();
        }

        // COM LOGIN → Verifica se é admin
        final isAdmin = AuthService().isAdmin();

        if (isAdmin) {
          return const Adminscreen();
        }

        return const TeikersMainscreen();
      },
    );
  }
}
