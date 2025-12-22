import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:teiker_app/Screens/LoginScreen.dart';
import 'package:teiker_app/Widgets/AppButton.dart';
import 'package:teiker_app/Widgets/AppCardBounceCard.dart';
import 'package:teiker_app/Widgets/AppSnackBar.dart';
import 'package:teiker_app/backend/auth_service.dart';

class DefinicoesAdminScreen extends StatefulWidget {
  const DefinicoesAdminScreen({super.key});

  @override
  State<DefinicoesAdminScreen> createState() => _DefinicoesAdminScreenState();
}

class _DefinicoesAdminScreenState extends State<DefinicoesAdminScreen> {
  File? _profileImage;
  final Color mainColor = const Color.fromARGB(255, 4, 76, 32);
  final AuthService _authService = AuthService();
  final TextEditingController _resetCtrl = TextEditingController();

  @override
  void dispose() {
    _resetCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Tirar Foto'),
                onTap: () async {
                  Navigator.pop(context);
                  final picked = await picker.pickImage(
                    source: ImageSource.camera,
                  );
                  if (picked != null) {
                    setState(() => _profileImage = File(picked.path));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Escolher da Galeria'),
                onTap: () async {
                  Navigator.pop(context);
                  final picked = await picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (picked != null) {
                    setState(() => _profileImage = File(picked.path));
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double appBarHeight = MediaQuery.of(context).size.height * 0.45;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          // --- AppBar Curva ---
          ClipPath(
            clipper: _CurveAppBarClipper(),
            child: Container(
              width: double.infinity,
              height: appBarHeight,
              color: mainColor,
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 55,
                        backgroundColor: Colors.white,
                        backgroundImage: _profileImage != null
                            ? FileImage(_profileImage!)
                            : null,
                        child: _profileImage == null
                            ? const Icon(
                                Icons.camera_alt,
                                size: 40,
                                color: Colors.grey,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Sónia Pereira",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Gestora da Teiker",
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // --- Botões de Ação ---
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildOption(
                  icon: Icons.lock_outline,
                  label: "Recompor palavra-passe",
                  onTap: _openResetDialog,
                ),
                _buildOption(
                  icon: Icons.receipt_long_outlined,
                  label: "Ver as minhas faturas",
                  onTap: () {},
                ),
                _buildOption(
                  icon: Icons.logout,
                  label: "Terminar Sessão",
                  onTap: () async {
                    await _authService.logout();

                    AppSnackBar.show(
                      context,
                      message: "Terminaste a sessão com sucesso!",
                      icon: Icons.logout_outlined,
                      background: Colors.green.shade700,
                    );

                    Future.delayed(const Duration(milliseconds: 400), () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => LoginScreen()),
                      );
                    });
                  },
                  forceWhiteText: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool forceWhiteText = true,
  }) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: AppCardBounceCard(
        icon: icon,
        title: label,
        color: mainColor,
        whiteText: true,
        onTap: onTap,
      ),
    );
  }

  void _openResetDialog() {
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
                  controller: _resetCtrl,
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
                          await _authService.resetPassword(
                            _resetCtrl.text.trim(),
                          );
                          if (mounted) Navigator.pop(context);
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

// --- CLIPPER da AppBar Curva ---
class _CurveAppBarClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 60);
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 60,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
