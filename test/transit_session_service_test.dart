import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teiker_app/backend/transit_session_service.dart';
import 'package:teiker_app/work_sessions/domain/work_session_repository.dart';

void main() {
  late _Firestore firestore;
  late _Auth auth;
  late _Repository repository;
  late TransitSessionService service;
  final start = DateTime(2026, 9, 19, 10); // Saturday: must not double.
  final end = DateTime(2026, 9, 19, 10, 30);

  setUp(() {
    firestore = _Firestore({
      'clienteId': 'DESLOCACAO',
      'teikerId': 'teiker-1',
      'startTime': Timestamp.fromDate(start),
      'endTime': Timestamp.fromDate(end),
      'durationHours': 0.5,
    });
    auth = _Auth(_User('admin@teiker.ch'));
    repository = _Repository();
    service = TransitSessionService(
      firestore: firestore,
      auth: auth,
      repository: repository,
    );
  });

  Future<void> update({DateTime? from, DateTime? to}) => service.update(
    sessionId: 'trip-1',
    teikerId: 'teiker-1',
    start: from ?? start,
    end: to ?? end,
  );
  Future<void> delete() =>
      service.delete(sessionId: 'trip-1', teikerId: 'teiker-1');

  test(
    'editing stores real duration, dates and admin audit, preserving trip identity',
    () async {
      await update(to: end.add(const Duration(minutes: 15)));
      final data = firestore.data!;
      expect(data['durationHours'], 0.75);
      expect(data['rawDurationHours'], 0.75);
      expect(data['durationMultiplier'], 1.0);
      expect(data['isFixedHolidayRateApplied'], false);
      expect(data['clienteId'], 'DESLOCACAO');
      expect(data['teikerId'], 'teiker-1');
      expect(
        data['endTime'],
        Timestamp.fromDate(end.add(const Duration(minutes: 15))),
      );
      expect(data['updatedById'], 'admin-id');
      expect(data['updatedByRole'], 'admin');
      expect(repository.excludedId, 'trip-1');
    },
  );

  test('supports trips crossing midnight and changing month', () async {
    await update(
      from: DateTime(2026, 8, 31, 23, 50),
      to: DateTime(2026, 9, 1, 0, 20),
    );
    expect(firestore.data!['durationHours'], 0.5);
    expect(
      firestore.data!['startTime'],
      Timestamp.fromDate(DateTime(2026, 8, 31, 23, 50)),
    );
  });

  test('admin can delete a completed trip', () async {
    await delete();
    expect(firestore.data, isNull);
  });

  test('non-admin and signed-out users cannot edit or delete', () async {
    for (final user in [
      _User('teiker@example.com'),
      _User('maryborgeshealing@gmail.com'),
      null,
    ]) {
      auth.user = user;
      await expectLater(update(), throwsException);
      await expectLater(delete(), throwsException);
    }
    expect(firestore.writes, 0);
  });

  test(
    'another teiker, normal hours, open or missing trips cannot be changed',
    () async {
      final original = Map<String, dynamic>.from(firestore.data!);
      for (final data in <Map<String, dynamic>?>[
        {...original, 'teikerId': 'another'},
        {...original, 'clienteId': 'client-1'},
        {...original, 'endTime': null},
        null,
      ]) {
        firestore.data = data;
        await expectLater(update(), throwsException);
        await expectLater(delete(), throwsException);
      }
      expect(firestore.writes, 0);
    },
  );

  test('overlapping, future and invalid intervals cannot be saved', () async {
    repository.overlap = true;
    await expectLater(update(), throwsException);
    repository.overlap = false;
    await expectLater(update(to: start), throwsException);
    await expectLater(
      update(to: start.subtract(const Duration(minutes: 1))),
      throwsException,
    );
    await expectLater(
      update(to: DateTime.now().add(const Duration(days: 1))),
      throwsException,
    );
    expect(firestore.writes, 0);
  });
}

class _User implements User {
  _User(this.email);
  @override
  final String email;
  @override
  String get uid => 'admin-id';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements FirebaseAuth {
  _Auth(this.user);
  User? user;
  @override
  User? get currentUser => user;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repository implements WorkSessionRepository {
  bool overlap = false;
  String? excludedId;
  @override
  Future<bool> hasSessionOverlap({
    required String teikerId,
    required DateTime start,
    required DateTime end,
    String? excludingSessionId,
  }) async {
    excludedId = excludingSessionId;
    return overlap;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Firestore implements FirebaseFirestore {
  _Firestore(this.data);
  Map<String, dynamic>? data;
  int writes = 0;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    expect(path, 'workSessions');
    return _Collection();
  }

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    return transactionHandler(_Transaction(this));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// In-memory Firestore test double; never used by the application.
// ignore: subtype_of_sealed_class
class _Collection implements CollectionReference<Map<String, dynamic>> {
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    expect(path, 'trip-1');
    return _Reference();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// In-memory Firestore test double; never used by the application.
// ignore: subtype_of_sealed_class
class _Reference implements DocumentReference<Map<String, dynamic>> {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// In-memory Firestore test double; never used by the application.
// ignore: subtype_of_sealed_class
class _Snapshot<T extends Object?> implements DocumentSnapshot<T> {
  _Snapshot(this.value);
  final T? value;
  @override
  T? data() => value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transaction implements Transaction {
  _Transaction(this.firestore);
  final _Firestore firestore;
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentReference,
  ) async => _Snapshot<T>(firestore.data as T?);
  @override
  Transaction update(
    DocumentReference documentReference,
    Map<String, dynamic> data,
  ) {
    firestore.data!.addAll(data);
    firestore.writes++;
    return this;
  }

  @override
  Transaction delete(DocumentReference documentReference) {
    firestore.data = null;
    firestore.writes++;
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
