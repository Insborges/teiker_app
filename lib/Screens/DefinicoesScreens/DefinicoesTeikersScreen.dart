import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:teiker_app/Screens/DefinicoesScreens/TeikerHorasScreen.dart';
import 'package:teiker_app/Screens/LoginScreen.dart';
import 'package:teiker_app/Widgets/AppCardBounceCard.dart';
import 'package:teiker_app/Widgets/AppSnackBar.dart';
import 'package:teiker_app/Widgets/CurveAppBarClipper.dart';
import 'package:teiker_app/Widgets/ResetPasswordDialog.dart';
import 'package:teiker_app/backend/auth_service.dart';
import 'package:teiker_app/backend/firebase_service.dart';

class DefinicoesTeikersScreen extends StatefulWidget {
  const DefinicoesTeikersScreen({super.key});

  @override
  State<DefinicoesTeikersScreen> createState() =>
      _DefinicoesTeikersScreenState();
}

class _DefinicoesTeikersScreenState extends State<DefinicoesTeikersScreen> {
  File? _profileImage;
  final Color mainColor = const Color.fromARGB(255, 4, 76, 32);
  final AuthService _authService = AuthService();

  String teikerName = "";
  String teikerEmail = "";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseService().currentUser;
    if (user == null) return;

    final uid = user.uid;

    // Vai à procura no Firestore
    final doc = await FirebaseFirestore.instance
        .collection('teikers')
        .doc(uid)
        .get();

    final email = doc.data()?['email'] ?? user.email ?? "";

    if (!mounted) return;
    setState(() {
      teikerName =
          doc.data()?['name'] ?? user.displayName ?? "Teiker Profissional";
      teikerEmail = email;
    });
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
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
            clipper: CurveAppBarClipper(),
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
                    Text(
                      teikerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      teikerEmail,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
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
                  icon: Icons.timer_outlined,
                  label: "Ver horas totais",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TeikerHorasScreen(),
                      ),
                    );
                  },
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
    showResetPasswordDialog(
      context: context,
      onSubmit: (email) => _authService.resetPassword(email),
      initialEmail: teikerEmail,
      accentColor: mainColor,
    );
  }
}
