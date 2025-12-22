import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:teiker_app/firebase_options.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  FirebaseApp? app;
  late FirebaseAuth auth;
  late FirebaseFirestore firestore;
  FirebaseApp? _secondaryApp;
  FirebaseAuth? _secondaryAuth;

  Future<void> init() async {
    app = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    auth = FirebaseAuth.instance;
    firestore = FirebaseFirestore.instance;
  }

  User? get currentUser => auth.currentUser;

  Future<FirebaseApp> _ensureSecondaryApp() async {
    if (_secondaryApp != null) return _secondaryApp!;

    try {
      _secondaryApp = await Firebase.initializeApp(
        name: 'secondary',
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (e) {
      if (e.code == 'duplicate-app') {
        _secondaryApp = Firebase.app('secondary');
      } else {
        rethrow;
      }
    }

    return _secondaryApp!;
  }

  Future<FirebaseAuth> get secondaryAuth async {
    if (_secondaryAuth != null) return _secondaryAuth!;

    final secondaryApp = await _ensureSecondaryApp();
    _secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
    return _secondaryAuth!;
  }
}
