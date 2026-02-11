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
  final rootContext = context;
  final emailCtrl = TextEditingController(text: initialEmail);

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
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
                controller: emailCtrl,
                keyboard: TextInputType.emailAddress,
                prefixIcon: Icons.email_outlined,
                focusColor: accentColor,
                fillColor: Colors.white,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: "Cancelar",
                      outline: true,
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      text: "Enviar",
                      color: accentColor,
                      onPressed: () async {
                        final email = emailCtrl.text.trim();
                        if (email.isEmpty) {
                          if (!rootContext.mounted) return;
                          AppSnackBar.show(
                            rootContext,
                            message: "Insere o email.",
                            icon: Icons.info_outline,
                            background: Colors.orange.shade700,
                          );
                          return;
                        }
                        try {
                          await onSubmit(email);
                          if (Navigator.canPop(dialogContext)) {
                            Navigator.pop(dialogContext);
                          }
                          if (!rootContext.mounted) return;
                          AppSnackBar.show(
                            rootContext,
                            message: "Email enviado!",
                            icon: Icons.email,
                            background: Colors.green.shade700,
                          );
                        } catch (e) {
                          if (!rootContext.mounted) return;
                          AppSnackBar.show(
                            rootContext,
                            message: "Erro ao enviar email: $e",
                            icon: Icons.error,
                            background: Colors.red.shade700,
                          );
                        }
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

  emailCtrl.dispose();
}
