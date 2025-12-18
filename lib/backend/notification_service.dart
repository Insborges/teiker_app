import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> init() async {
    await _fcm.requestPermission();
    FirebaseMessaging.onMessage.listen((message) {
      // Receber notificações em foreground
      print("Notificação recebida: ${message.notification?.title}");
    });
  }

  // Agendar notificação (local) para lembrete
  Future<void> scheduleNotification(
    String title,
    String body,
    DateTime scheduledDate,
  ) async {
    // Aqui podemos usar flutter_local_notifications para agendamento
  }
}
