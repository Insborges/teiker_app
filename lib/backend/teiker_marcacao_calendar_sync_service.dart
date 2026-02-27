import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:teiker_app/models/Teikers.dart';

class TeikerMarcacaoCalendarSyncService {
  TeikerMarcacaoCalendarSyncService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  String normalizeId(String? value) => (value ?? '').trim();

  Future<String?> findAdminMirrorIdForReminder(String reminderId) async {
    final normalizedReminderId = normalizeId(reminderId);
    if (normalizedReminderId.isEmpty) return null;

    final query = await _firestore
        .collection('admin_reminders')
        .where('sourceReminderId', isEqualTo: normalizedReminderId)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return query.docs.first.id;
  }

  Map<String, dynamic> buildReminderPayload({
    required TeikerMarcacao marcacao,
    required String teikerId,
    required String teikerName,
  }) {
    final tag = marcacao.tipo.label;
    return <String, dynamic>{
      'title': tag,
      'tag': tag,
      'description': marcacao.nota,
      'nota': marcacao.nota,
      'date': Timestamp.fromDate(marcacao.data),
      'start': DateFormat('HH:mm', 'pt_PT').format(marcacao.data),
      'end': '',
      'teikerId': teikerId,
      'teikerName': teikerName,
    };
  }

  Future<void> updateCalendarDocs({
    required String teikerId,
    required String teikerName,
    required TeikerMarcacao marcacao,
  }) async {
    final reminderId = normalizeId(marcacao.reminderId ?? marcacao.id);
    final payload = buildReminderPayload(
      marcacao: marcacao,
      teikerId: teikerId,
      teikerName: teikerName,
    );

    if (reminderId.isNotEmpty) {
      try {
        await _firestore
            .collection('reminders')
            .doc(teikerId)
            .collection('items')
            .doc(reminderId)
            .update(payload);
      } on FirebaseException catch (e) {
        if (e.code != 'not-found') rethrow;
      }
    }

    var adminReminderId = normalizeId(marcacao.adminReminderId);
    if (adminReminderId.isEmpty && reminderId.isNotEmpty) {
      adminReminderId = normalizeId(
        await findAdminMirrorIdForReminder(reminderId),
      );
    }

    if (adminReminderId.isNotEmpty) {
      try {
        await _firestore
            .collection('admin_reminders')
            .doc(adminReminderId)
            .update({
              ...payload,
              'sourceUserId': teikerId,
              'sourceReminderId': reminderId,
            });
      } on FirebaseException catch (e) {
        if (e.code != 'not-found') rethrow;
      }
    }
  }

  Future<void> deleteCalendarDocs({
    required String teikerId,
    required TeikerMarcacao marcacao,
  }) async {
    final reminderId = normalizeId(marcacao.reminderId ?? marcacao.id);
    var adminReminderId = normalizeId(marcacao.adminReminderId);
    if (adminReminderId.isEmpty && reminderId.isNotEmpty) {
      adminReminderId = normalizeId(
        await findAdminMirrorIdForReminder(reminderId),
      );
    }

    if (reminderId.isNotEmpty) {
      try {
        await _firestore
            .collection('reminders')
            .doc(teikerId)
            .collection('items')
            .doc(reminderId)
            .delete();
      } on FirebaseException catch (e) {
        if (e.code != 'not-found') rethrow;
      }
    }

    if (adminReminderId.isNotEmpty) {
      try {
        await _firestore
            .collection('admin_reminders')
            .doc(adminReminderId)
            .delete();
      } on FirebaseException catch (e) {
        if (e.code != 'not-found') rethrow;
      }
    }
  }
}
