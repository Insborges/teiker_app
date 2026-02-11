import 'dart:async';
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
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _adminRemindersSubscription;
  String? _adminReminderListenerUid;
  bool _adminReminderBaselineLoaded = false;
  final Set<String> _knownAdminReminderIds = <String>{};
  String? _birthdayNotificationUid;
  String? _lastBirthdayShownKey;

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
    _authSubscription ??= _auth.authStateChanges().listen((_) async {
      await _saveFcmToken();
      await _syncAdminReminderNotifications();
      await _syncTeikerBirthdayNotification();
    });
    await _syncAdminReminderNotifications();
    await _syncTeikerBirthdayNotification();
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
    final sessionDay = DateTime(startTime.year, startTime.month, startTime.day);
    final now = DateTime.now();

    final reminders = <({String slot, DateTime when, String title, String body})>[
      (
        slot: 'morning',
        when: DateTime(sessionDay.year, sessionDay.month, sessionDay.day, 15),
        title: 'Esqueceste de terminar a manhã',
        body: 'Esqueceste de terminar o serviço da manhã na casa $clienteName',
      ),
      (
        slot: 'afternoon',
        when: DateTime(sessionDay.year, sessionDay.month, sessionDay.day, 19),
        title: 'Esqueceste de terminar a tarde',
        body: 'Esqueceste de terminar o serviço da tarde na casa $clienteName',
      ),
    ];

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

    for (final reminder in reminders) {
      if (!reminder.when.isAfter(now)) continue;
      if (startTime.isAfter(reminder.when)) continue;

      final payload = jsonEncode({
        'tipo': 'session_reminder',
        'sessionId': sessionId,
        'clienteId': clienteId,
        'clienteName': clienteName,
        'startTime': startTime.toIso8601String(),
        'slot': reminder.slot,
      });

      final tzScheduledDate = tz.TZDateTime.from(reminder.when, tz.local);

      await _local.zonedSchedule(
        _notificationId('${sessionId}_${reminder.slot}'),
        reminder.title,
        reminder.body,
        tzScheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: null,
        payload: payload,
      );
    }
  }

  Future<void> cancelPendingSessionReminder(String sessionId) async {
    await _local.cancel(_notificationId(sessionId));
    await _local.cancel(_notificationId('${sessionId}_morning'));
    await _local.cancel(_notificationId('${sessionId}_afternoon'));
  }

  int _notificationId(String sessionId) => sessionId.hashCode & 0x7fffffff;
  int _adminReminderNotificationId(String reminderId) =>
      ('admin_reminder_$reminderId').hashCode & 0x7fffffff;
  int _teikerBirthdayNotificationId(String uid) =>
      ('teiker_birthday_$uid').hashCode & 0x7fffffff;

  Future<void> _syncAdminReminderNotifications() async {
    final user = _auth.currentUser;
    if (user == null) {
      await _stopAdminReminderNotifications();
      return;
    }

    final email = (user.email ?? '').trim().toLowerCase();
    final isAdmin = email.endsWith('@teiker.ch');
    if (!isAdmin) {
      await _stopAdminReminderNotifications();
      return;
    }

    await _startAdminReminderNotifications(user.uid);
  }

  Future<void> _startAdminReminderNotifications(String adminUid) async {
    if (_adminReminderListenerUid == adminUid &&
        _adminRemindersSubscription != null) {
      return;
    }

    await _stopAdminReminderNotifications();
    _adminReminderListenerUid = adminUid;
    _adminReminderBaselineLoaded = false;
    _adminRemindersSubscription = FirebaseFirestore.instance
        .collection('admin_reminders')
        .snapshots()
        .listen((snapshot) {
          if (!_adminReminderBaselineLoaded) {
            for (final doc in snapshot.docs) {
              _knownAdminReminderIds.add(doc.id);
            }
            _adminReminderBaselineLoaded = true;
            return;
          }

          for (final change in snapshot.docChanges) {
            if (change.type != DocumentChangeType.added) continue;

            final doc = change.doc;
            final id = doc.id;
            if (_knownAdminReminderIds.contains(id)) continue;
            _knownAdminReminderIds.add(id);

            final data = doc.data();
            if (data == null) continue;

            final tag = (data['tag'] as String?)?.trim() ?? 'Lembrete';
            if (tag != 'Lembrete') continue;

            final createdById = (data['createdById'] as String?)?.trim();
            if (createdById == null ||
                createdById.isEmpty ||
                createdById == adminUid) {
              continue;
            }

            final teikerName =
                (data['createdByName'] as String?)?.trim().isNotEmpty == true
                ? (data['createdByName'] as String).trim()
                : 'Teiker';
            final clienteName = (data['clienteName'] as String?)?.trim();
            final title = (data['title'] as String?)?.trim();

            _showAdminReminderAddedNotification(
              reminderId: id,
              teikerName: teikerName,
              clienteName: clienteName,
              reminderTitle: title,
            );
          }
        });
  }

  Future<void> _stopAdminReminderNotifications() async {
    _adminReminderListenerUid = null;
    _adminReminderBaselineLoaded = false;
    _knownAdminReminderIds.clear();
    await _adminRemindersSubscription?.cancel();
    _adminRemindersSubscription = null;
  }

  DateTime? _parseBirthDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String && raw.trim().isNotEmpty) {
      return DateTime.tryParse(raw.trim());
    }
    return null;
  }

  DateTime _nextBirthdayAt({
    required DateTime birthDate,
    required DateTime now,
    int hour = 9,
    int minute = 0,
  }) {
    DateTime occurrence = DateTime(
      now.year,
      birthDate.month,
      birthDate.day,
      hour,
      minute,
    );
    if (!occurrence.isAfter(now)) {
      occurrence = DateTime(
        now.year + 1,
        birthDate.month,
        birthDate.day,
        hour,
        minute,
      );
    }
    return occurrence;
  }

  Future<void> _syncTeikerBirthdayNotification() async {
    final user = _auth.currentUser;

    if (user == null) {
      if (_birthdayNotificationUid != null) {
        await _local.cancel(
          _teikerBirthdayNotificationId(_birthdayNotificationUid!),
        );
      }
      _birthdayNotificationUid = null;
      return;
    }

    final email = (user.email ?? '').trim().toLowerCase();
    final isAdmin = email.endsWith('@teiker.ch');
    if (isAdmin) {
      if (_birthdayNotificationUid != null) {
        await _local.cancel(
          _teikerBirthdayNotificationId(_birthdayNotificationUid!),
        );
      }
      _birthdayNotificationUid = null;
      return;
    }

    final uid = user.uid;
    if (_birthdayNotificationUid != null && _birthdayNotificationUid != uid) {
      await _local.cancel(
        _teikerBirthdayNotificationId(_birthdayNotificationUid!),
      );
    }
    _birthdayNotificationUid = uid;

    final doc = await FirebaseFirestore.instance
        .collection('teikers')
        .doc(uid)
        .get();
    if (!doc.exists) {
      await _local.cancel(_teikerBirthdayNotificationId(uid));
      return;
    }

    final data = doc.data();
    if (data == null) {
      await _local.cancel(_teikerBirthdayNotificationId(uid));
      return;
    }

    final birthDate =
        _parseBirthDate(data['birthDate']) ??
        _parseBirthDate(data['dataNascimento']);
    if (birthDate == null) {
      await _local.cancel(_teikerBirthdayNotificationId(uid));
      return;
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'teiker_birthday',
        'Aniversário da teiker',
        channelDescription: 'Parabéns no aniversário da teiker.',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(),
    );

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayBirthday = DateTime(now.year, birthDate.month, birthDate.day);
    if (today == todayBirthday) {
      final shownKey = '${uid}_${today.toIso8601String()}';
      if (_lastBirthdayShownKey != shownKey) {
        _lastBirthdayShownKey = shownKey;
        await _local.show(
          _teikerBirthdayNotificationId(uid),
          'Parabens da Teiker',
          'A Teiker deseja-te um feliz aniversário',
          details,
          payload: jsonEncode({'tipo': 'teiker_birthday', 'uid': uid}),
        );
      }
    }

    final nextBirthday = _nextBirthdayAt(birthDate: birthDate, now: now);
    final scheduleTime = tz.TZDateTime.from(nextBirthday, tz.local);

    await _local.zonedSchedule(
      _teikerBirthdayNotificationId(uid),
      'Parabens da Teiker',
      'A Teiker deseja-te um feliz aniversário',
      scheduleTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
      payload: jsonEncode({'tipo': 'teiker_birthday', 'uid': uid}),
    );
  }

  Future<void> _showAdminReminderAddedNotification({
    required String reminderId,
    required String teikerName,
    String? clienteName,
    String? reminderTitle,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'admin_new_reminders',
        'Lembretes das teikers',
        channelDescription:
            'Notificações quando uma teiker adiciona um lembrete.',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(),
    );

    final bodyParts = <String>[
      'Lembrete:',
      if (clienteName != null && clienteName.isNotEmpty) ' $clienteName',
      if (reminderTitle != null && reminderTitle.isNotEmpty) '• $reminderTitle',
    ];

    await _local.show(
      _adminReminderNotificationId(reminderId),
      '$teikerName adicionou um lembrete',
      bodyParts.join(' '),
      details,
      payload: jsonEncode({'tipo': 'admin_reminder', 'reminderId': reminderId}),
    );
  }

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
