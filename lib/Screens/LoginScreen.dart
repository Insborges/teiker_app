import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teiker_app/Screens/EcrasPrincipais/AdminScreen.dart';
import 'package:teiker_app/Screens/EcrasPrincipais/TeikersMainScreen.dart';
import 'package:teiker_app/Widgets/AppButton.dart';
import 'package:teiker_app/Widgets/AppSnackBar.dart';
import 'package:teiker_app/auth/auth_notifier.dart';
import 'package:teiker_app/auth/auth_state.dart';

class LoginScreen extends ConsumerStatefulWidget {
  LoginScreen({super.key});

  final Color primaryColor = const Color.fromARGB(255, 4, 76, 32);

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final resetCtrl = TextEditingController();
  bool obscurePassword = true;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    resetCtrl.dispose();
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
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Redefinir Palavra-passe",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Será enviado um email com instruções.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: resetCtrl,
                  decoration: InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        text: "Cancelar",
                        outline: true,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        text: "Enviar",
                        onPressed: () async {
                          await authNotifier.resetPassword(
                            resetCtrl.text.trim(),
                          );
                          Navigator.pop(context);
                          AppSnackBar.show(
                            context,
                            message: "Email enviado!",
                            icon: Icons.email,
                            background: Colors.green.shade700,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
