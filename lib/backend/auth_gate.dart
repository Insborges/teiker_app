import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teiker_app/Screens/EcrasPrincipais/MainScreen.dart';
import 'package:teiker_app/Screens/LoginScreen.dart';
import 'package:teiker_app/Widgets/AppSnackBar.dart';
import 'package:teiker_app/auth/app_user_role.dart';
import 'package:teiker_app/auth/auth_notifier.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final role = ref.watch(userRoleProvider);

    return authState.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(
        body: Center(child: Text("Erro ao carregar autenticação. ")),
      ),
      data: (user) {
        if (user == null) return LoginScreen();

        if (role == AppUserRole.admin) {
          return MainScreen(role: MainRole.admin);
        }
        if (role == AppUserRole.hr) {
          return MainScreen(role: MainRole.hr);
        }

        return _TeikerFirestoreGuard(user: user);
      },
    );
  }
}

class _TeikerFirestoreGuard extends ConsumerStatefulWidget {
  const _TeikerFirestoreGuard({required this.user});

  final User user;

  @override
  ConsumerState<_TeikerFirestoreGuard> createState() =>
      _TeikerFirestoreGuardState();
}

class _TeikerFirestoreGuardState extends ConsumerState<_TeikerFirestoreGuard> {
  bool _loggingOut = false;
  bool _missingAccountNotified = false;

  Future<void> _logoutIfDeleted() async {
    if (_loggingOut) return;
    _loggingOut = true;
    try {
      await FirebaseAuth.instance.signOut();
    } finally {
      _loggingOut = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('teikers')
          .doc(widget.user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final exists = snapshot.data?.exists ?? false;
        if (!exists) {
          if (!_missingAccountNotified) {
            _missingAccountNotified = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              AppSnackBar.show(
                context,
                message: 'Conta Não Existente',
                icon: Icons.error_outline,
                background: Colors.red.shade700,
              );
              _logoutIfDeleted();
            });
          }
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        _missingAccountNotified = false;
        return const MainScreen(role: MainRole.teiker);
      },
    );
  }
}
