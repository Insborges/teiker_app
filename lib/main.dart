import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:teiker_app/backend/auth_gate.dart';
import 'package:teiker_app/backend/firebase_service.dart';
import 'package:teiker_app/backend/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //Formatos de data portuguesa
  await initializeDateFormatting('pt_PT', null);
  Intl.defaultLocale = 'pt_PT';

  //Inicializar o backend(firebase)
  await FirebaseService().init();
  await NotificationService().init();

  runApp(ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().processPendingNavigation();
    });

    return MaterialApp(
      title: 'Teiker App',
      navigatorKey: NotificationService().navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 22, 40, 1),
        ),

        //Fonte da app
        fontFamily: 'RethinkSans',

        // Radius e estilo padrão para Inputs
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),

        // SnackBar padrão
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: const AuthGate(),
    );
  }
}
