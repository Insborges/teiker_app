import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
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
  Uint8List? _profileImageBytes;
  String? _profileImageUrl;
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
    final photoUrl = doc.data()?['photoUrl'] as String?;
    final photoBase64 = doc.data()?['photoBase64'] as String?;
    Uint8List? bytes;
    if (photoBase64 != null && photoBase64.isNotEmpty) {
      try {
        bytes = base64Decode(photoBase64);
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      teikerName =
          doc.data()?['name'] ?? user.displayName ?? "Teiker Profissional";
      teikerEmail = email;
      _profileImageBytes = bytes;
      _profileImageUrl = photoUrl;
    });
  }

  Future<void> _saveProfileImage(File file) async {
    final user = FirebaseService().currentUser;
    if (user == null) return;

    try {
      final bytes = await file.readAsBytes();
      final base64 = base64Encode(bytes);
      await FirebaseFirestore.instance
          .collection('teikers')
          .doc(user.uid)
          .set({'photoBase64': base64}, SetOptions(merge: true));
      if (!mounted) return;
      setState(() => _profileImageBytes = bytes);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: "Erro a guardar a foto: $e",
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
    }
  }

  Future<void> _handlePick(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked == null) return;
    final file = File(picked.path);
    setState(() => _profileImage = file);
    await _saveProfileImage(file);
  }

  Future<void> _pickImage() async {
    if (Platform.isIOS) {
      showCupertinoModalPopup(
        context: context,
        builder: (context) {
          return CupertinoActionSheet(
            title: const Text('Escolher foto'),
            actions: [
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                  _handlePick(ImageSource.camera);
                },
                child: const Text('Tirar Foto'),
              ),
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                  _handlePick(ImageSource.gallery);
                },
                child: const Text('Escolher da Galeria'),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          );
        },
      );
      return;
    }

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
                onTap: () {
                  Navigator.pop(context);
                  _handlePick(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Escolher da Galeria'),
                onTap: () {
                  Navigator.pop(context);
                  _handlePick(ImageSource.gallery);
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
                            : _profileImageBytes != null
                                ? MemoryImage(_profileImageBytes!)
                                : _profileImageUrl != null
                                ? NetworkImage(_profileImageUrl!)
                            : null,
                        child: _profileImage == null
                            && _profileImageBytes == null
                            && _profileImageUrl == null
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
