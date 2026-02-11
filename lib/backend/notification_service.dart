import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:teiker_app/Screens/DetailsScreens.dart/ClientsDetails.dart';
import 'package:teiker_app/models/Clientes.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  bool _initialized = false;
  String? _pendingPayload;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    tz.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    final launchDetails = await _local.getNotificationAppLaunchDetails();

    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationTap(response.payload);
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    await _fcm.requestPermission();
    await _saveFcmToken();
    _fcm.onTokenRefresh.listen((_) => _saveFcmToken());
    FirebaseMessaging.onMessage.listen((message) {
      // Receber notificações em foreground
      debugPrint("Notificação recebida: ${message.notification?.title}");
    });

    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final payload = launchDetails?.notificationResponse?.payload;
      if (payload != null) {
        _handleNotificationTap(payload);
      }
    }
  }

  // Agendar notificação (local) para lembrete
  Future<void> schedulePendingSessionReminder({
    required String sessionId,
    required String clienteId,
    required String clienteName,
    required DateTime startTime,
  }) async {
    final scheduledDate = startTime.add(const Duration(hours: 5));
    if (scheduledDate.isBefore(DateTime.now())) return;

    final payload = jsonEncode({
      'tipo': 'session_reminder',
      'sessionId': sessionId,
      'clienteId': clienteId,
      'clienteName': clienteName,
      'startTime': startTime.toIso8601String(),
    });

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'session_reminders',
        'Lembretes de serviço',
        channelDescription: 'Alertas para terminar sessões em aberto.',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(),
    );

    final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

    await _local.zonedSchedule(
      _notificationId(sessionId),
      'Esqueceste-te de terminar o serviço',
      'Esqueceste-te de terminar o serviço na casa $clienteName',
      tzScheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null,
      payload: payload,
    );
  }

  Future<void> cancelPendingSessionReminder(String sessionId) async {
    await _local.cancel(_notificationId(sessionId));
  }

  int _notificationId(String sessionId) => sessionId.hashCode & 0x7fffffff;

  Future<void> _handleNotificationTap(String? payload) async {
    if (payload == null) return;

    final nav = navigatorKey.currentState;
    if (nav == null) {
      _pendingPayload = payload;
      return;
    }

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      if (data['tipo'] != 'session_reminder') return;

      final clienteId = data['clienteId'] as String?;
      if (clienteId == null) return;

      final sessionId = data['sessionId'] as String?;

      final doc = await FirebaseFirestore.instance
          .collection('clientes')
          .doc(clienteId)
          .get();

      if (!doc.exists) return;

      final Map<String, dynamic>? clienteData = doc.data();
      if (clienteData == null) return;

      final cliente = Clientes.fromMap({...clienteData, 'uid': doc.id});

      nav.push(
        MaterialPageRoute(
          builder: (_) => Clientsdetails(
            cliente: cliente,
            onSessionClosed: () {
              cancelPendingSessionReminder(sessionId ?? '');
            },
          ),
        ),
      );
    } catch (_) {
      // Silenciar erros para não crashar fluxo de navegação.
    }
  }

  void processPendingNavigation() {
    final payload = _pendingPayload;
    if (payload == null) return;
    if (navigatorKey.currentState == null) return;

    _pendingPayload = null;
    _handleNotificationTap(payload);
  }

  Future<void> _saveFcmToken({int attempt = 0}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (Platform.isIOS) {
      final apns = await _fcm.getAPNSToken();
      if (apns == null) {
        if (attempt < 5) {
          await Future.delayed(const Duration(seconds: 2));
          return _saveFcmToken(attempt: attempt + 1);
        }
        return;
      }
    }

    final token = await _fcm.getToken();
    if (token == null) return;

    final email = user.email ?? '';
    final isAdmin = email.trim().endsWith("@teiker.ch");

    await FirebaseFirestore.instance.collection('fcm_tokens').doc(user.uid).set(
      {
        'token': token,
        'updatedAt': Timestamp.now(),
        'isAdmin': isAdmin,
        'email': email,
      },
      SetOptions(merge: true),
    );
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  NotificationService()._handleNotificationTap(response.payload);
}
