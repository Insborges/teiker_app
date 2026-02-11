import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teiker_app/Screens/EcrasPrincipais/MainScreen.dart';
import 'package:teiker_app/Screens/LoginScreen.dart';
import 'package:teiker_app/auth/auth_notifier.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return authState.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(
        body: Center(child: Text("Erro ao carregar autenticação. ")),
      ),
      data: (user) {
        if (user == null) return LoginScreen();

        return MainScreen(role: isAdmin ? MainRole.admin : MainRole.teiker);
      },
    );
  }
}
