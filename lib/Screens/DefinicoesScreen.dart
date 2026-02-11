import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:teiker_app/Screens/AdminInvoicesScreen.dart';
import 'package:teiker_app/Screens/TeikerHorasScreen.dart';
import 'package:teiker_app/Widgets/AppSnackBar.dart';
import 'package:teiker_app/Widgets/CurveAppBarClipper.dart';
import 'package:teiker_app/Widgets/ResetPasswordDialog.dart';
import 'package:teiker_app/Widgets/profile_image_picker_sheet.dart';
import 'package:teiker_app/Widgets/settings_option_card.dart';
import 'package:teiker_app/backend/auth_service.dart';
import 'package:teiker_app/backend/firebase_service.dart';
import 'package:teiker_app/theme/app_colors.dart';

enum SettingsRole { admin, teiker }

class DefinicoesScreen extends StatefulWidget {
  const DefinicoesScreen({super.key, required this.role});

  final SettingsRole role;

  bool get isAdmin => role == SettingsRole.admin;

  @override
  State<DefinicoesScreen> createState() => _DefinicoesScreenState();
}

class _DefinicoesScreenState extends State<DefinicoesScreen> {
  final AuthService _authService = AuthService();

  File? _profileImage;
  Uint8List? _profileImageBytes;
  String? _profileImageUrl;

  String _displayName = '';
  String _displaySubtitle = '';

  String get _collection => widget.isAdmin ? 'admins' : 'teikers';
  Color get _mainColor => AppColors.primaryGreen;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseService().currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection(_collection)
        .doc(user.uid)
        .get();

    final data = doc.data() ?? const <String, dynamic>{};
    final photoUrl = data['photoUrl'] as String?;
    final photoBase64 = data['photoBase64'] as String?;

    Uint8List? bytes;
    if (photoBase64 != null && photoBase64.isNotEmpty) {
      try {
        bytes = base64Decode(photoBase64);
      } catch (_) {
        bytes = null;
      }
    }

    if (!mounted) return;
    setState(() {
      _profileImageUrl = photoUrl;
      _profileImageBytes = bytes;

      if (widget.isAdmin) {
        _displayName = 'Sónia Pereira';
        _displaySubtitle = 'Gestora da Teiker';
      } else {
        _displayName =
            data['name'] as String? ??
            user.displayName ??
            'Teiker Profissional';
        _displaySubtitle =
            data['email'] as String? ?? user.email ?? 'teiker@teiker.ch';
      }
    });
  }

  Future<void> _saveProfileImage(File file) async {
    final user = FirebaseService().currentUser;
    if (user == null) return;

    try {
      final bytes = await file.readAsBytes();
      final base64 = base64Encode(bytes);

      await FirebaseFirestore.instance
          .collection(_collection)
          .doc(user.uid)
          .set({'photoBase64': base64}, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => _profileImageBytes = bytes);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        message: 'Erro a guardar a foto: $e',
        icon: Icons.error_outline,
        background: Colors.red.shade700,
      );
    }
  }

  Future<void> _handlePick(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
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
    await showProfileImagePickerSheet(context, onSourceSelected: _handlePick);
  }

  Future<void> _logout() async {
    await _authService.logout();
    // A navegação é gerida automaticamente pelo AuthGate.
  }

  void _openResetDialog() {
    showResetPasswordDialog(
      context: context,
      onSubmit: (email) => _authService.resetPassword(email),
      initialEmail: widget.isAdmin ? null : _displaySubtitle,
      accentColor: _mainColor,
    );
  }

  List<Widget> _buildActionButtons() {
    final buttons = <Widget>[
      SettingsOptionCard(
        icon: Icons.lock_outline,
        label: 'Recompor palavra-passe',
        onTap: _openResetDialog,
        color: _mainColor,
      ),
    ];

    if (widget.isAdmin) {
      buttons.add(
        SettingsOptionCard(
          icon: Icons.receipt_long_outlined,
          label: 'Ver as minhas faturas',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminInvoicesScreen()),
            );
          },
          color: _mainColor,
        ),
      );
    } else {
      buttons.add(
        SettingsOptionCard(
          icon: Icons.timer_outlined,
          label: 'Ver horas totais',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TeikerHorasScreen()),
            );
          },
          color: _mainColor,
        ),
      );
    }

    buttons.add(
      SettingsOptionCard(
        icon: Icons.logout,
        label: 'Terminar Sessão',
        onTap: _logout,
        color: _mainColor,
      ),
    );

    return buttons;
  }

  @override
  Widget build(BuildContext context) {
    final appBarHeight = MediaQuery.of(context).size.height * 0.45;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          ClipPath(
            clipper: CurveAppBarClipper(),
            child: Container(
              width: double.infinity,
              height: appBarHeight,
              color: _mainColor,
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
                        child:
                            _profileImage == null &&
                                _profileImageBytes == null &&
                                _profileImageUrl == null
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
                      _displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _displaySubtitle,
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
          const SizedBox(height: 18),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(children: _buildActionButtons()),
            ),
          ),
        ],
      ),
    );
  }
}
