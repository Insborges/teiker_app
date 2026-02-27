import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teiker_app/Widgets/AppButton.dart';
import 'package:teiker_app/Widgets/AppSnackBar.dart';
import 'package:teiker_app/Widgets/AppTextInput.dart';
import 'package:teiker_app/Widgets/ResetPasswordDialog.dart';
import 'package:teiker_app/auth/auth_notifier.dart';
import 'package:teiker_app/auth/auth_state.dart';
import 'package:teiker_app/theme/app_colors.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  final Color primaryColor = AppColors.primaryGreen;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();
  bool obscurePassword = true;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final authNotifier = ref.read(authProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(24),
                child: AutofillGroup(
                  child: Column(
                    children: [
                      const SizedBox(height: 32),

                      AppTextField(
                        label: "Email",
                        controller: emailCtrl,
                        focusNode: _emailFocus,
                        keyboard: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        onFieldSubmitted: (_) {
                          _passFocus.requestFocus();
                        },
                        prefixIcon: Icons.email_outlined,
                        focusColor: widget.primaryColor,
                        fillColor: Colors.white,
                      ),

                      const SizedBox(height: 16),

                      AppTextField(
                        label: "Password",
                        controller: passCtrl,
                        focusNode: _passFocus,
                        obscureText: obscurePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _login(context),
                        prefixIcon: Icons.lock_outline,
                        focusColor: widget.primaryColor,
                        fillColor: Colors.white,
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() => obscurePassword = !obscurePassword);
                          },
                        ),
                      ),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () =>
                              _openResetDialog(context, authNotifier),
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
            ),
          ],
        ),
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

  // --------------------
  // LÓGICA DE AÇÕES
  // --------------------

  Future<void> _login(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final email = emailCtrl.text.trim();
    final password = passCtrl.text.trim();
    final authNotifier = ref.read(authProvider.notifier);

    final ok = await authNotifier.login(email, password);
    if (!mounted) return;

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

    // A navegação é gerida pelo AuthGate quando o estado auth muda.
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
