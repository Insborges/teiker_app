import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

        if (isAdmin) {
          return MainScreen(role: MainRole.admin);
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
        final exists = snapshot.data?.exists ?? true;
        if (!exists) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _logoutIfDeleted();
            }
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return const MainScreen(role: MainRole.teiker);
      },
    );
  }
}
