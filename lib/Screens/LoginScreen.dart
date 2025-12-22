import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teiker_app/Screens/EcrasPrincipais/AdminScreen.dart';
import 'package:teiker_app/Screens/EcrasPrincipais/TeikersMainScreen.dart';
import 'package:teiker_app/Widgets/AppButton.dart';
import 'package:teiker_app/Widgets/AppSnackBar.dart';
import 'package:teiker_app/Widgets/ResetPasswordDialog.dart';
import 'package:teiker_app/auth/auth_notifier.dart';
import 'package:teiker_app/auth/auth_state.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  final Color primaryColor = const Color.fromARGB(255, 4, 76, 32);

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool obscurePassword = true;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final authNotifier = ref.read(authProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          _header(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 32),

                  _input(
                    label: "Email",
                    controller: emailCtrl,
                    icon: Icons.email_outlined,
                    keyboard: TextInputType.emailAddress,
                  ),

                  const SizedBox(height: 16),

                  _inputPassword(),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _openResetDialog(context, authNotifier),
                      child: Text(
                        "Esqueci a password",
                        style: TextStyle(
                          color: widget.primaryColor,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  AppButton(
                    text: authState.status == AuthStatus.loading
                        ? "A carregar..."
                        : "Login",
                    color: widget.primaryColor,
                    enabled: authState.status != AuthStatus.loading,
                    onPressed: () => _login(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------
  // COMPONENTES
  // --------------------

  Widget _header(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Container(
      width: double.infinity,
      height: h * 0.35,
      decoration: BoxDecoration(
        color: widget.primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Image.asset('assets/IconCasaSuica.png', height: 120),
          const SizedBox(height: 16),
          const Text(
            "Bem-vindas Teikers",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Acede à tua conta para continuar",
            style: TextStyle(fontSize: 16, color: Colors.white70),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _input({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required TextInputType keyboard,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(icon, color: widget.primaryColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _inputPassword() {
    return TextFormField(
      controller: passCtrl,
      obscureText: obscurePassword,
      decoration: InputDecoration(
        labelText: "Password",
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(Icons.lock_outline, color: widget.primaryColor),
        suffixIcon: IconButton(
          icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => obscurePassword = !obscurePassword),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // --------------------
  // LÓGICA DE AÇÕES
  // --------------------

  Future<void> _login(BuildContext context) async {
    final email = emailCtrl.text.trim();
    final password = passCtrl.text.trim();
    final authNotifier = ref.read(authProvider.notifier);

    final ok = await authNotifier.login(email, password);

    if (!ok) {
      final msg = ref.read(authProvider).errorMessage ?? "Erro inesperado";
      AppSnackBar.show(
        context,
        message: msg,
        icon: Icons.error,
        background: Colors.red.shade700,
      );
      return;
    }

    AppSnackBar.show(
      context,
      message: "Login efetuado com sucesso!",
      icon: Icons.login,
      background: Colors.green.shade700,
    );

    // Admin -> email termina @teiker.ch
    if (ref.read(authProvider).isAdmin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => Adminscreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => TeikersMainscreen()),
      );
    }
  }

  void _openResetDialog(BuildContext context, dynamic authNotifier) {
    showResetPasswordDialog(
      context: context,
      onSubmit: (email) => authNotifier.resetPassword(email),
      initialEmail: emailCtrl.text.trim(),
      accentColor: widget.primaryColor,
    );
  }
}
