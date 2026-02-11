import 'package:flutter/material.dart';
import 'package:teiker_app/Widgets/AppButton.dart';
import 'package:teiker_app/Widgets/AppSnackBar.dart';
import 'package:teiker_app/Widgets/AppTextInput.dart';

Future<void> showResetPasswordDialog({
  required BuildContext context,
  required Future<void> Function(String email) onSubmit,
  String? initialEmail,
  Color accentColor = const Color.fromARGB(255, 4, 76, 32),
}) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ResetPasswordDialogContent(
      onSubmit: onSubmit,
      initialEmail: initialEmail,
      accentColor: accentColor,
      rootContext: context,
    ),
  );
}

class _ResetPasswordDialogContent extends StatefulWidget {
  const _ResetPasswordDialogContent({
    required this.onSubmit,
    required this.initialEmail,
    required this.accentColor,
    required this.rootContext,
  });

  final Future<void> Function(String email) onSubmit;
  final String? initialEmail;
  final Color accentColor;
  final BuildContext rootContext;

  @override
  State<_ResetPasswordDialogContent> createState() =>
      _ResetPasswordDialogContentState();
}

class _ResetPasswordDialogContentState
    extends State<_ResetPasswordDialogContent> {
  late final TextEditingController _emailCtrl;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      if (!widget.rootContext.mounted) return;
      AppSnackBar.show(
        widget.rootContext,
        message: "Insere o email.",
        icon: Icons.info_outline,
        background: Colors.orange.shade700,
      );
      return;
    }

    try {
      await widget.onSubmit(email);
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      if (!widget.rootContext.mounted) return;
      AppSnackBar.show(
        widget.rootContext,
        message: "Email enviado!",
        icon: Icons.email,
        background: Colors.green.shade700,
      );
    } catch (e) {
      if (!widget.rootContext.mounted) return;
      AppSnackBar.show(
        widget.rootContext,
        message: "Erro ao enviar email: $e",
        icon: Icons.error,
        background: Colors.red.shade700,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            AppTextField(
              label: "Email",
              controller: _emailCtrl,
              keyboard: TextInputType.emailAddress,
              prefixIcon: Icons.email_outlined,
              focusColor: widget.accentColor,
              fillColor: Colors.white,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: "Cancelar",
                    outline: true,
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    text: "Enviar",
                    color: widget.accentColor,
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
