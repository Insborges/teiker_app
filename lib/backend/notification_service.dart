import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:teiker_app/Screens/DetailsScreens.dart/ClientsDetails.dart';
import 'package:teiker_app/auth/app_user_role.dart';
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
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _userMarcacoesSubscription;
  String? _adminReminderListenerUid;
  String? _userMarcacoesListenerUid;
  bool _adminReminderBaselineLoaded = false;
  bool _userMarcacoesBaselineLoaded = false;
  final Set<String> _knownAdminReminderIds = <String>{};
  final Set<String> _knownUserMarcacaoReminderIds = <String>{};
  String? _birthdayNotificationUid;
  final StreamController<String> _managerEventOpenController =
      StreamController<String>.broadcast();
  String? _pendingManagerEventReminderId;

  Stream<String> get managerEventOpenRequests =>
      _managerEventOpenController.stream;

  String? consumePendingManagerEventReminderId() {
    final pending = _pendingManagerEventReminderId;
    _pendingManagerEventReminderId = null;
    return pending;
  }

  void _emitManagerEventOpenRequest(String reminderId) {
    final normalized = reminderId.trim();
    if (normalized.isEmpty) return;
    _pendingManagerEventReminderId = normalized;
    _managerEventOpenController.add(normalized);
  }

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
    await _requestLocalNotificationPermissions();

    await _fcm.requestPermission();
    await _saveFcmToken();
    _fcm.onTokenRefresh.listen((_) => _saveFcmToken());
    _authSubscription ??= _auth.authStateChanges().listen((_) async {
      await _saveFcmToken();
      await _syncAdminReminderNotifications();
      await _syncUserMarcacaoNotifications();
      await _syncTeikerBirthdayNotification();
    });
    await _syncAdminReminderNotifications();
    await _syncUserMarcacaoNotifications();
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
  int _userMarcacaoNotificationId(String reminderId) =>
      ('user_marcacao_$reminderId').hashCode & 0x7fffffff;
  int _marcacaoStartsSoonNotificationId({
    required String scope,
    required String reminderId,
  }) => ('marcacao_30m_${scope}_$reminderId').hashCode & 0x7fffffff;
  int _teikerBirthdayNotificationId(String uid) =>
      ('teiker_birthday_$uid').hashCode & 0x7fffffff;

  Future<void> _requestLocalNotificationPermissions() async {
    if (Platform.isAndroid) {
      final android = _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();
      return;
    }

    final ios = _local
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);

    final macOs = _local
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    await macOs?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> _syncAdminReminderNotifications() async {
    final user = _auth.currentUser;
    if (user == null) {
      await _stopAdminReminderNotifications();
      return;
    }

    final role = AppUserRoleResolver.fromEmail(user.email);
    if (!role.isPrivileged) {
      await _stopAdminReminderNotifications();
      return;
    }

    await _startAdminReminderNotifications(user.uid);
  }

  Future<void> _startAdminReminderNotifications(String managerUid) async {
    if (_adminReminderListenerUid == managerUid &&
        _adminRemindersSubscription != null) {
      return;
    }

    await _stopAdminReminderNotifications();
    _adminReminderListenerUid = managerUid;
    _adminReminderBaselineLoaded = false;
    _adminRemindersSubscription = FirebaseFirestore.instance
        .collection('admin_reminders')
        .snapshots()
        .listen((snapshot) {
          if (!_adminReminderBaselineLoaded) {
            for (final doc in snapshot.docs) {
              _knownAdminReminderIds.add(doc.id);
              final data = doc.data();
              unawaited(
                _scheduleMarcacaoStartsSoonNotification(
                  scope: 'manager',
                  reminderId: doc.id,
                  tag: data['tag'] as String?,
                  scheduledFor: _parseReminderDate(data['date']),
                ),
              );
            }
            _adminReminderBaselineLoaded = true;
            return;
          }

          for (final change in snapshot.docChanges) {
            final doc = change.doc;
            final id = doc.id;
            final data = doc.data();
            if (change.type == DocumentChangeType.removed) {
              _knownAdminReminderIds.remove(id);
              unawaited(
                _cancelMarcacaoStartsSoonNotification(
                  scope: 'manager',
                  reminderId: id,
                ),
              );
              continue;
            }
            if (data == null) continue;

            unawaited(
              _scheduleMarcacaoStartsSoonNotification(
                scope: 'manager',
                reminderId: id,
                tag: data['tag'] as String?,
                scheduledFor: _parseReminderDate(data['date']),
              ),
            );

            if (change.type != DocumentChangeType.added) continue;
            if (_knownAdminReminderIds.contains(id)) continue;
            _knownAdminReminderIds.add(id);

            final tag = (data['tag'] as String?)?.trim() ?? 'Lembrete';
            final createdById = (data['createdById'] as String?)?.trim();
            if (createdById == null || createdById.isEmpty) {
              continue;
            }

            final creatorName =
                (data['createdByName'] as String?)?.trim().isNotEmpty == true
                ? (data['createdByName'] as String).trim()
                : 'Teiker';
            if (tag == 'Lembrete') {
              if (createdById == managerUid) continue;
              final clienteName = (data['clienteName'] as String?)?.trim();
              final title = (data['title'] as String?)?.trim();
              _showAdminReminderAddedNotification(
                reminderId: id,
                teikerName: creatorName,
                clienteName: clienteName,
                reminderTitle: title,
              );
              continue;
            }

            if (tag == 'Acontecimento') {
              final creatorRole = (data['createdByRole'] as String?)
                  ?.trim()
                  .toLowerCase();
              if (creatorRole == 'admin' || creatorRole == 'hr') {
                _showManagerEventAddedNotification(
                  notificationId: id,
                  creatorName: creatorName,
                );
              }
            }
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

  bool _isTeikerMarcacaoReminderTag(String? rawTag) {
    final normalized = (rawTag ?? '').trim().toLowerCase();
    return normalized == 'reunião de trabalho' ||
        normalized == 'reuniao de trabalho' ||
        normalized == 'acompanhamento';
  }

  DateTime? _parseReminderDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String && raw.trim().isNotEmpty) {
      return DateTime.tryParse(raw.trim());
    }
    return null;
  }

  String _marcacaoStartsSoonNotificationBody(String? tag) {
    final normalized = (tag ?? '').trim().toLowerCase();
    if (normalized == 'acompanhamento') {
      return 'Tens o acompanhamento para daqui a 30 minutos! Não te esqueças.';
    }
    return 'Tens a reunião para daqui a 30 minutos! Não te esqueças.';
  }

  Future<void> _cancelMarcacaoStartsSoonNotification({
    required String scope,
    required String reminderId,
  }) async {
    await _local.cancel(
      _marcacaoStartsSoonNotificationId(scope: scope, reminderId: reminderId),
    );
  }

  Future<void> _scheduleMarcacaoStartsSoonNotification({
    required String scope,
    required String reminderId,
    required String? tag,
    required DateTime? scheduledFor,
  }) async {
    await _cancelMarcacaoStartsSoonNotification(
      scope: scope,
      reminderId: reminderId,
    );

    if (!_isTeikerMarcacaoReminderTag(tag) || scheduledFor == null) return;

    final notifyAt = scheduledFor.subtract(const Duration(minutes: 30));
    if (!notifyAt.isAfter(DateTime.now())) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'marcacao_starts_soon',
        'Marcações em breve',
        channelDescription:
            'Avisos 30 minutos antes de reuniões/acompanhamentos.',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _local.zonedSchedule(
      _marcacaoStartsSoonNotificationId(scope: scope, reminderId: reminderId),
      'Faltam 30 minutos',
      _marcacaoStartsSoonNotificationBody(tag),
      tz.TZDateTime.from(notifyAt, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({
        'tipo': 'marcacao_starts_soon',
        'reminderId': reminderId,
      }),
    );
  }

  Future<void> _syncUserMarcacaoNotifications() async {
    final user = _auth.currentUser;
    if (user == null) {
      await _stopUserMarcacaoNotifications();
      return;
    }
    await _startUserMarcacaoNotifications(user.uid);
  }

  Future<void> _startUserMarcacaoNotifications(String uid) async {
    if (_userMarcacoesListenerUid == uid &&
        _userMarcacoesSubscription != null) {
      return;
    }

    await _stopUserMarcacaoNotifications();
    _userMarcacoesListenerUid = uid;
    _userMarcacoesBaselineLoaded = false;

    _userMarcacoesSubscription = FirebaseFirestore.instance
        .collection('reminders')
        .doc(uid)
        .collection('items')
        .snapshots()
        .listen((snapshot) {
          if (!_userMarcacoesBaselineLoaded) {
            for (final doc in snapshot.docs) {
              _knownUserMarcacaoReminderIds.add(doc.id);
              final data = doc.data();
              unawaited(
                _scheduleMarcacaoStartsSoonNotification(
                  scope: 'user',
                  reminderId: doc.id,
                  tag: data['tag'] as String?,
                  scheduledFor: _parseReminderDate(data['date']),
                ),
              );
            }
            _userMarcacoesBaselineLoaded = true;
            return;
          }

          for (final change in snapshot.docChanges) {
            final doc = change.doc;
            final reminderId = doc.id;
            final data = doc.data();
            if (change.type == DocumentChangeType.removed) {
              _knownUserMarcacaoReminderIds.remove(reminderId);
              unawaited(
                _cancelMarcacaoStartsSoonNotification(
                  scope: 'user',
                  reminderId: reminderId,
                ),
              );
              continue;
            }
            if (data == null) continue;

            unawaited(
              _scheduleMarcacaoStartsSoonNotification(
                scope: 'user',
                reminderId: reminderId,
                tag: data['tag'] as String?,
                scheduledFor: _parseReminderDate(data['date']),
              ),
            );

            if (change.type != DocumentChangeType.added) continue;
            if (_knownUserMarcacaoReminderIds.contains(reminderId)) continue;
            _knownUserMarcacaoReminderIds.add(reminderId);

            final tag = (data['tag'] as String?)?.trim();
            if (!_isTeikerMarcacaoReminderTag(tag)) continue;

            final createdById = (data['createdById'] as String?)?.trim();
            if (createdById != null &&
                createdById.isNotEmpty &&
                createdById == uid) {
              continue;
            }

            _showUserMarcacaoAddedNotification(
              reminderId: reminderId,
              tag: tag,
            );
          }
        });
  }

  Future<void> _stopUserMarcacaoNotifications() async {
    _userMarcacoesListenerUid = null;
    _userMarcacoesBaselineLoaded = false;
    _knownUserMarcacaoReminderIds.clear();
    await _userMarcacoesSubscription?.cancel();
    _userMarcacoesSubscription = null;
  }

  String _userMarcacaoNotificationBody(String? tag) {
    final normalized = (tag ?? '').trim().toLowerCase();
    if (normalized == 'acompanhamento') {
      return 'Um acompanhamento foi marcado.';
    }
    if (normalized == 'reunião de trabalho' ||
        normalized == 'reuniao de trabalho') {
      return 'Uma reunião foi marcada.';
    }
    return 'Nova marcação agendada.';
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
    int hour = 0,
    int minute = 10,
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

    final role = AppUserRoleResolver.fromEmail(user.email);
    if (role.isPrivileged) {
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
    final nextBirthday = _nextBirthdayAt(birthDate: birthDate, now: now);
    final scheduleTime = tz.TZDateTime.from(nextBirthday, tz.local);

    await _local.zonedSchedule(
      _teikerBirthdayNotificationId(uid),
      'Parabéns da Teiker',
      'A Teiker deseja-te um feliz aniversário',
      scheduleTime,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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

  Future<void> _showUserMarcacaoAddedNotification({
    required String reminderId,
    required String? tag,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'teiker_marcacoes',
        'Marcações da teiker',
        channelDescription:
            'Notificações quando é marcada uma reunião/acompanhamento.',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _local.show(
      _userMarcacaoNotificationId(reminderId),
      'Nova Marcação',
      _userMarcacaoNotificationBody(tag),
      details,
    );
  }

  Future<void> _showManagerEventAddedNotification({
    required String notificationId,
    required String creatorName,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'manager_new_events',
        'Novos acontecimentos',
        channelDescription:
            'Notificações quando admin/RH adicionam acontecimentos.',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _local.show(
      _adminReminderNotificationId('evento_$notificationId'),
      'Novo acontecimento',
      'A $creatorName acabou de adicionar um acontecimento',
      details,
      payload: jsonEncode({
        'tipo': 'manager_event',
        'reminderId': notificationId,
      }),
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
      final type = (data['tipo'] as String?)?.trim();
      if (type == 'manager_event') {
        final reminderId = (data['reminderId'] as String?)?.trim();
        if (reminderId == null || reminderId.isEmpty) return;
        _emitManagerEventOpenRequest(reminderId);
        return;
      }

      if (type != 'session_reminder') return;

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
    final role = AppUserRoleResolver.fromEmail(email);

    await FirebaseFirestore.instance
        .collection('fcm_tokens')
        .doc(user.uid)
        .set({
          'token': token,
          'updatedAt': Timestamp.now(),
          'isAdmin': role.isAdmin,
          'isPrivileged': role.isPrivileged,
          'role': role.name,
          'email': email,
        }, SetOptions(merge: true));
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  NotificationService()._handleNotificationTap(response.payload);
}
