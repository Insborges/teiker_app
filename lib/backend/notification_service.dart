import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:teiker_app/Screens/DetailsScreens.dart/ClientsDetails.dart';
import 'package:teiker_app/Screens/DetailsScreens.dart/TeikersDetais.dart';
import 'package:teiker_app/auth/app_user_role.dart';
import 'package:teiker_app/backend/firebase_service.dart';
import 'package:teiker_app/models/Clientes.dart';
import 'package:teiker_app/models/Teikers.dart';
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

  static const AndroidNotificationChannel _remoteMessagesChannel =
      AndroidNotificationChannel(
        'teiker_remote_messages',
        'Notificações Teiker',
        description: 'Canal padrão para notificações remotas da aplicação.',
        importance: Importance.max,
      );
  static const DarwinNotificationDetails _darwinNotificationDetails =
      DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  bool _initialized = false;
  bool _localNotificationsInitialized = false;
  String? _pendingPayload;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _adminRemindersSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _userMarcacoesSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _managerBirthdaysSubscription;
  String? _adminReminderListenerUid;
  String? _userMarcacoesListenerUid;
  bool _adminReminderBaselineLoaded = false;
  bool _userMarcacoesBaselineLoaded = false;
  bool _managerBirthdaysBaselineLoaded = false;
  final Set<String> _knownAdminReminderIds = <String>{};
  final Set<String> _knownUserMarcacaoReminderIds = <String>{};
  final Set<String> _knownManagerBirthdayUids = <String>{};
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

  Future<void> _cancelLocalNotificationSafely(int id) async {
    try {
      await _local.cancel(id);
    } catch (e) {
      debugPrint('Falha ao cancelar notificação local $id: $e');
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final launchDetails = await _local.getNotificationAppLaunchDetails();
    await _initializeLocalNotifications();
    await _requestLocalNotificationPermissions();
    await _requestExactAlarmPermissionIfNeeded();

    await _fcm.requestPermission(alert: true, badge: true, sound: true);
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
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
    FirebaseMessaging.onMessage.listen((message) async {
      await _handleForegroundRemoteMessage(message);
    });
    FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteMessageTap);

    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      await _handleRemoteMessageTap(initialMessage);
    }

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

    final details = _buildNotificationDetails(
      channelId: 'session_reminders',
      channelName: 'Lembretes de serviço',
      channelDescription: 'Alertas para terminar sessões em aberto.',
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
    if (sessionId.trim().isEmpty) return;
    await _cancelLocalNotificationSafely(_notificationId(sessionId));
    await _cancelLocalNotificationSafely(
      _notificationId('${sessionId}_morning'),
    );
    await _cancelLocalNotificationSafely(
      _notificationId('${sessionId}_afternoon'),
    );
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
  int _managerMarcacaoNotificationId(String reminderId) =>
      ('manager_marcacao_$reminderId').hashCode & 0x7fffffff;
  int _teikerBirthdayNotificationId(String uid) =>
      ('teiker_birthday_$uid').hashCode & 0x7fffffff;
  int _managerBirthdayNotificationId(String uid) =>
      ('manager_teiker_birthday_$uid').hashCode & 0x7fffffff;

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

  Future<void> _requestExactAlarmPermissionIfNeeded() async {
    if (!Platform.isAndroid) return;

    final android = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestExactAlarmsPermission();
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

            if (_isManualHoursReminderTag(tag)) {
              if (createdById == managerUid) continue;
              _showManualHoursAddedNotification(
                reminderId: id,
                teikerId: (data['teikerId'] as String?)?.trim(),
                teikerName: (data['teikerName'] as String?)?.trim(),
                clienteName: (data['clienteName'] as String?)?.trim(),
                startTime: _parseReminderDate(data['date']),
                manualHoursEntryId: (data['manualHoursEntryId'] as String?)
                    ?.trim(),
              );
              continue;
            }

            final creatorRole = (data['createdByRole'] as String?)?.trim();
            final isPrivilegedCreator = _isPrivilegedRoleName(creatorRole);
            if (_isTeikerMarcacaoReminderTag(tag) && isPrivilegedCreator) {
              if (createdById == managerUid) continue;
              _showManagerMarcacaoAddedNotification(
                notificationId: id,
                creatorName: creatorName,
                teikerName: (data['teikerName'] as String?)?.trim(),
                tag: tag,
              );
              continue;
            }

            if (tag == 'Acontecimento') {
              if (isPrivilegedCreator) {
                if (createdById == managerUid) continue;
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

  bool _isManualHoursReminderTag(String? rawTag) {
    final normalized = (rawTag ?? '').trim().toLowerCase();
    return normalized == 'horas adicionadas';
  }

  bool _isPrivilegedRoleName(String? rawRole) {
    final normalized = (rawRole ?? '').trim().toLowerCase();
    return normalized == AppUserRole.admin.name ||
        normalized == AppUserRole.hr.name ||
        normalized == AppUserRole.developer.name;
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
    await _cancelLocalNotificationSafely(
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

    final details = _buildNotificationDetails(
      channelId: 'marcacao_starts_soon',
      channelName: 'Marcações em breve',
      channelDescription:
          'Avisos 30 minutos antes de reuniões/acompanhamentos.',
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
    DateTime occurrence = _birthdayOccurrenceForYear(
      birthDate: birthDate,
      year: now.year,
      hour: hour,
      minute: minute,
    );
    if (!occurrence.isAfter(now)) {
      occurrence = _birthdayOccurrenceForYear(
        birthDate: birthDate,
        year: now.year + 1,
        hour: hour,
        minute: minute,
      );
    }
    return occurrence;
  }

  DateTime _birthdayOccurrenceForYear({
    required DateTime birthDate,
    required int year,
    int hour = 0,
    int minute = 10,
  }) {
    final maxDay = DateTime(year, birthDate.month + 1, 0).day;
    final safeDay = birthDate.day.clamp(1, maxDay).toInt();
    return DateTime(year, birthDate.month, safeDay, hour, minute);
  }

  Future<void> _syncTeikerBirthdayNotification() async {
    final user = _auth.currentUser;

    if (user == null) {
      await _stopSelfBirthdayNotification();
      await _stopManagerBirthdayNotifications();
      return;
    }

    final role = AppUserRoleResolver.fromEmail(user.email);
    if (role.isPrivileged) {
      await _stopSelfBirthdayNotification();
      await _startManagerBirthdayNotifications();
      return;
    }

    await _stopManagerBirthdayNotifications();
    await _startSelfBirthdayNotification(user.uid);
  }

  Future<void> _stopSelfBirthdayNotification() async {
    if (_birthdayNotificationUid != null) {
      await _cancelLocalNotificationSafely(
        _teikerBirthdayNotificationId(_birthdayNotificationUid!),
      );
    }
    _birthdayNotificationUid = null;
  }

  Future<void> _startSelfBirthdayNotification(String uid) async {
    if (_birthdayNotificationUid != null && _birthdayNotificationUid != uid) {
      await _cancelLocalNotificationSafely(
        _teikerBirthdayNotificationId(_birthdayNotificationUid!),
      );
    }
    _birthdayNotificationUid = uid;

    final doc = await FirebaseFirestore.instance
        .collection('teikers')
        .doc(uid)
        .get();
    if (!doc.exists) {
      await _cancelLocalNotificationSafely(_teikerBirthdayNotificationId(uid));
      return;
    }

    final data = doc.data();
    if (data == null) {
      await _cancelLocalNotificationSafely(_teikerBirthdayNotificationId(uid));
      return;
    }

    final birthDate =
        _parseBirthDate(data['birthDate']) ??
        _parseBirthDate(data['dataNascimento']);
    if (birthDate == null) {
      await _cancelLocalNotificationSafely(_teikerBirthdayNotificationId(uid));
      return;
    }

    final details = _buildNotificationDetails(
      channelId: 'teiker_birthday',
      channelName: 'Aniversário da teiker',
      channelDescription: 'Parabéns no aniversário da teiker.',
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

  Future<void> _startManagerBirthdayNotifications() async {
    if (_managerBirthdaysSubscription != null) return;

    _managerBirthdaysBaselineLoaded = false;
    _managerBirthdaysSubscription = FirebaseFirestore.instance
        .collection('teikers')
        .snapshots()
        .listen((snapshot) {
          if (!_managerBirthdaysBaselineLoaded) {
            for (final doc in snapshot.docs) {
              _knownManagerBirthdayUids.add(doc.id);
              final data = doc.data();
              unawaited(
                _scheduleManagerBirthdayNotification(
                  uid: doc.id,
                  teikerName:
                      (data['nameTeiker'] as String?)?.trim().isNotEmpty == true
                      ? (data['nameTeiker'] as String).trim()
                      : 'Teiker',
                  birthDate:
                      _parseBirthDate(data['birthDate']) ??
                      _parseBirthDate(data['dataNascimento']),
                ),
              );
            }
            _managerBirthdaysBaselineLoaded = true;
            return;
          }

          for (final change in snapshot.docChanges) {
            final uid = change.doc.id;
            final data = change.doc.data();
            if (change.type == DocumentChangeType.removed) {
              _knownManagerBirthdayUids.remove(uid);
              unawaited(
                _cancelLocalNotificationSafely(
                  _managerBirthdayNotificationId(uid),
                ),
              );
              continue;
            }

            _knownManagerBirthdayUids.add(uid);
            if (data == null) {
              unawaited(
                _cancelLocalNotificationSafely(
                  _managerBirthdayNotificationId(uid),
                ),
              );
              continue;
            }

            unawaited(
              _scheduleManagerBirthdayNotification(
                uid: uid,
                teikerName:
                    (data['nameTeiker'] as String?)?.trim().isNotEmpty == true
                    ? (data['nameTeiker'] as String).trim()
                    : 'Teiker',
                birthDate:
                    _parseBirthDate(data['birthDate']) ??
                    _parseBirthDate(data['dataNascimento']),
              ),
            );
          }
        });
  }

  Future<void> _stopManagerBirthdayNotifications() async {
    for (final uid in _knownManagerBirthdayUids) {
      await _cancelLocalNotificationSafely(_managerBirthdayNotificationId(uid));
    }
    _knownManagerBirthdayUids.clear();
    _managerBirthdaysBaselineLoaded = false;
    await _managerBirthdaysSubscription?.cancel();
    _managerBirthdaysSubscription = null;
  }

  Future<void> _scheduleManagerBirthdayNotification({
    required String uid,
    required String teikerName,
    required DateTime? birthDate,
  }) async {
    await _cancelLocalNotificationSafely(_managerBirthdayNotificationId(uid));
    if (birthDate == null) return;

    final details = _buildNotificationDetails(
      channelId: 'manager_teiker_birthdays',
      channelName: 'Aniversários das teikers',
      channelDescription:
          'Notificações de aniversários para admin, RH e developer.',
    );

    final nextBirthday = _nextBirthdayAt(
      birthDate: birthDate,
      now: DateTime.now(),
    );

    await _local.zonedSchedule(
      _managerBirthdayNotificationId(uid),
      'Aniversário da teiker',
      'Hoje é o aniversário de $teikerName.',
      tz.TZDateTime.from(nextBirthday, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
      payload: jsonEncode({'tipo': 'manager_birthday', 'uid': uid}),
    );
  }

  Future<void> _showAdminReminderAddedNotification({
    required String reminderId,
    required String teikerName,
    String? clienteName,
    String? reminderTitle,
  }) async {
    final details = _buildNotificationDetails(
      channelId: 'admin_new_reminders',
      channelName: 'Lembretes das teikers',
      channelDescription:
          'Notificações quando uma teiker adiciona um lembrete.',
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

  Future<void> _showManualHoursAddedNotification({
    required String reminderId,
    required String? teikerId,
    required String? teikerName,
    required String? clienteName,
    required DateTime? startTime,
    required String? manualHoursEntryId,
  }) async {
    final normalizedTeikerId = (teikerId ?? '').trim();
    final normalizedEntryId = (manualHoursEntryId ?? '').trim();
    if (normalizedTeikerId.isEmpty || normalizedEntryId.isEmpty) return;

    final details = _buildNotificationDetails(
      channelId: 'manual_hours_added',
      channelName: 'Horas adicionadas pelas teikers',
      channelDescription:
          'Notificações quando uma teiker acrescenta horas manualmente.',
    );

    final dateLabel = startTime == null
        ? ''
        : DateFormat('dd/MM/yyyy', 'pt_PT').format(startTime);
    final clientLabel = (clienteName ?? '').trim();
    final actorName = (teikerName ?? '').trim().isEmpty
        ? 'A teiker'
        : teikerName!.trim();
    final bodyParts = <String>[
      if (clientLabel.isNotEmpty) clientLabel,
      if (dateLabel.isNotEmpty) dateLabel,
    ];

    await _local.show(
      _adminReminderNotificationId('manual_$reminderId'),
      '$actorName adicionou horas',
      bodyParts.isEmpty
          ? 'Foi registada uma nova entrada manual.'
          : bodyParts.join(' • '),
      details,
      payload: jsonEncode({
        'tipo': 'manual_hours_entry',
        'teikerId': normalizedTeikerId,
        'entryId': normalizedEntryId,
      }),
    );
  }

  Future<void> _showUserMarcacaoAddedNotification({
    required String reminderId,
    required String? tag,
  }) async {
    final details = _buildNotificationDetails(
      channelId: 'teiker_marcacoes',
      channelName: 'Marcações da teiker',
      channelDescription:
          'Notificações quando é marcada uma reunião/acompanhamento.',
    );

    await _local.show(
      _userMarcacaoNotificationId(reminderId),
      'Nova Marcação',
      _userMarcacaoNotificationBody(tag),
      details,
    );
  }

  String _managerMarcacaoNotificationTitle(String? tag) {
    final normalized = (tag ?? '').trim().toLowerCase();
    if (normalized == 'acompanhamento') {
      return 'Novo acompanhamento';
    }
    return 'Nova reunião';
  }

  String _managerMarcacaoNotificationBody({
    required String creatorName,
    required String? teikerName,
    required String? tag,
  }) {
    final normalized = (tag ?? '').trim().toLowerCase();
    final label = normalized == 'acompanhamento'
        ? 'um acompanhamento'
        : 'uma reunião';
    final target = (teikerName ?? '').trim();
    if (target.isEmpty) {
      return '$creatorName marcou $label.';
    }
    return '$creatorName marcou $label para $target.';
  }

  Future<void> _showManagerMarcacaoAddedNotification({
    required String notificationId,
    required String creatorName,
    required String? teikerName,
    required String? tag,
  }) async {
    final details = _buildNotificationDetails(
      channelId: 'manager_marcacoes',
      channelName: 'Marcações da gestão',
      channelDescription:
          'Notificações quando admin, RH ou developer marcam reuniões/acompanhamentos.',
    );

    await _local.show(
      _managerMarcacaoNotificationId(notificationId),
      _managerMarcacaoNotificationTitle(tag),
      _managerMarcacaoNotificationBody(
        creatorName: creatorName,
        teikerName: teikerName,
        tag: tag,
      ),
      details,
      payload: jsonEncode({
        'tipo': 'manager_event',
        'reminderId': notificationId,
      }),
    );
  }

  Future<void> _showManagerEventAddedNotification({
    required String notificationId,
    required String creatorName,
  }) async {
    final details = _buildNotificationDetails(
      channelId: 'manager_new_events',
      channelName: 'Novos acontecimentos',
      channelDescription:
          'Notificações quando admin, RH ou developer adicionam acontecimentos.',
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

      if (type == 'manual_hours_entry') {
        final teikerId = (data['teikerId'] as String?)?.trim();
        final entryId = (data['entryId'] as String?)?.trim();
        if (teikerId == null ||
            teikerId.isEmpty ||
            entryId == null ||
            entryId.isEmpty) {
          return;
        }

        final teikerDoc = await FirebaseFirestore.instance
            .collection('teikers')
            .doc(teikerId)
            .get();
        if (!teikerDoc.exists) return;

        final teikerData = teikerDoc.data();
        if (teikerData == null) return;

        final teiker = Teiker.fromMap(teikerData, teikerDoc.id);
        final currentRole = AppUserRoleResolver.fromEmail(
          _auth.currentUser?.email,
        );
        nav.push(
          MaterialPageRoute(
            builder: (_) => TeikersDetails(
              teiker: teiker,
              canEditPersonalInfo: currentRole.isAdmin,
              specialProfileRole: null,
              initialManualHoursEntryId: entryId,
            ),
          ),
        );
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
            initialPendingSessionId: sessionId,
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

    final requiresApns = Platform.isIOS || Platform.isMacOS;
    if (requiresApns) {
      final apns = await _fcm.getAPNSToken();
      if (apns == null) {
        if (attempt < 8) {
          await Future.delayed(const Duration(seconds: 2));
          return _saveFcmToken(attempt: attempt + 1);
        }
        debugPrint(
          'APNS token ainda não está disponível. A guardar token FCM foi adiado.',
        );
        return;
      }
    }

    String? token;
    try {
      token = await _fcm.getToken();
    } on FirebaseException catch (e) {
      if (requiresApns && e.code == 'apns-token-not-set') {
        if (attempt < 8) {
          await Future.delayed(const Duration(seconds: 2));
          return _saveFcmToken(attempt: attempt + 1);
        }
        debugPrint(
          'FCM token indisponível sem APNS após várias tentativas. '
          'Nova tentativa ficará para o próximo refresh/login.',
        );
        return;
      }
      rethrow;
    }

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

  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsInitialized) return;

    tz.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationTap(response.payload);
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    await _createRemoteMessagesChannel();
    _localNotificationsInitialized = true;
  }

  Future<void> _createRemoteMessagesChannel() async {
    if (!Platform.isAndroid) return;

    final android = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(_remoteMessagesChannel);
  }

  NotificationDetails _buildNotificationDetails({
    required String channelId,
    required String channelName,
    required String channelDescription,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: _darwinNotificationDetails,
      macOS: _darwinNotificationDetails,
    );
  }

  Future<void> _handleForegroundRemoteMessage(RemoteMessage message) async {
    debugPrint(
      'Notificação remota recebida: ${message.notification?.title ?? message.data['title']}',
    );

    if ((Platform.isIOS || Platform.isMacOS) && message.notification != null) {
      return;
    }

    await _showRemoteMessageNotification(message);
  }

  Future<void> _handleRemoteMessageTap(RemoteMessage message) async {
    if (message.data.isEmpty) return;
    await _handleNotificationTap(jsonEncode(message.data));
  }

  Future<void> showRemoteMessageNotification(RemoteMessage message) async {
    await _initializeLocalNotifications();
    await _showRemoteMessageNotification(message);
  }

  Future<void> _showRemoteMessageNotification(RemoteMessage message) async {
    final title =
        message.notification?.title ??
        _trimmedDataValue(message.data, [
          'title',
          'titulo',
          'notification_title',
        ]);
    final body =
        message.notification?.body ??
        _trimmedDataValue(message.data, [
          'body',
          'message',
          'mensagem',
          'notification_body',
        ]);

    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    final payload = message.data.isEmpty ? null : jsonEncode(message.data);

    await _local.show(
      _remoteMessageNotificationId(message),
      title,
      body,
      _buildNotificationDetails(
        channelId: _remoteMessagesChannel.id,
        channelName: _remoteMessagesChannel.name,
        channelDescription:
            _remoteMessagesChannel.description ??
            'Canal padrão para notificações remotas da aplicação.',
      ),
      payload: payload,
    );
  }

  int _remoteMessageNotificationId(RemoteMessage message) {
    final key = message.messageId ?? message.sentTime?.toIso8601String();
    if (key != null && key.trim().isNotEmpty) {
      return ('remote_$key').hashCode & 0x7fffffff;
    }
    return DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
  }

  String? _trimmedDataValue(
    Map<String, dynamic> data,
    List<String> candidateKeys,
  ) {
    for (final key in candidateKeys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService().init();

  final shouldShowLocalNotification = message.notification == null;
  if (!shouldShowLocalNotification) return;

  await NotificationService().showRemoteMessageNotification(message);
}

Future<void> _handleBackgroundNotificationTap(String? payload) async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService().init();
  await NotificationService()._handleNotificationTap(payload);
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  unawaited(_handleBackgroundNotificationTap(response.payload));
}
