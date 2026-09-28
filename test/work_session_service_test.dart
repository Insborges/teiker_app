import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teiker_app/backend/work_session_service.dart';
import 'package:teiker_app/work_sessions/domain/work_session.dart';
import 'package:teiker_app/work_sessions/domain/work_session_repository.dart';

void main() {
  late _Repository repository;
  late _Auth auth;
  late WorkSessionService service;
  final start = DateTime(2025, 1, 7, 10);
  final end = start.add(const Duration(hours: 2));

  setUp(() {
    repository = _Repository();
    auth = _Auth(_User('admin@teiker.ch'));
    service = WorkSessionService(
      firestore: _Firestore(),
      auth: auth,
      repository: repository,
    );
  });

  Future<MonthlyTotals> add(String client, {bool extra = false}) =>
      service.addManualSession(
        clienteId: client,
        start: start,
        end: end,
        isExtra: extra,
      );

  for (final extra in [false, true]) {
    test(
      'admin can register overlapping client entries, extra=$extra',
      () async {
        await add('client-a', extra: extra);
        await add('client-b', extra: extra);
        expect(repository.clients, ['client-a', 'client-b']);
        expect(repository.extras, [extra, extra]);
        expect(repository.overlapChecks, 0);
        expect(repository.creatorRole, 'admin');
        expect(repository.creatorId, 'actor-id');
        expect(repository.totalClients, ['client-a', 'client-b']);
      },
    );
  }

  test('teiker client entries still reject overlapping work', () async {
    auth.user = _User('worker@example.com');
    await expectLater(add('client-a'), throwsException);
    expect(repository.clients, isEmpty);
    expect(repository.overlapChecks, 1);
  });

  test('admin adding work to a specific teiker still checks overlap', () async {
    await expectLater(
      service.addManualSessionForTeikerByAdmin(
        clienteId: 'client-a',
        teikerId: 'worker-id',
        start: start,
        end: end,
      ),
      throwsException,
    );
    expect(repository.clients, isEmpty);
    expect(repository.overlapChecks, 1);
  });

  test(
    'signed-out users and invalid intervals cannot create entries',
    () async {
      await expectLater(
        service.addManualSession(clienteId: 'client-a', start: end, end: start),
        throwsException,
      );
      await expectLater(
        service.addManualSession(
          clienteId: 'client-a',
          start: DateTime.now().add(const Duration(days: 1)),
          end: DateTime.now().add(const Duration(days: 2)),
        ),
        throwsException,
      );
      auth.user = null;
      await expectLater(add('client-a'), throwsException);
      expect(repository.clients, isEmpty);
    },
  );
}

class _User implements User {
  _User(this.email);
  @override
  final String email;
  @override
  String get uid => 'actor-id';
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

class _Firestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repository implements WorkSessionRepository {
  final clients = <String>[];
  final extras = <bool>[];
  final totalClients = <String>[];
  int overlapChecks = 0;
  String? creatorId;
  String? creatorRole;

  @override
  Future<bool> hasSessionOverlap({
    required String teikerId,
    required DateTime start,
    required DateTime end,
    String? excludingSessionId,
  }) async {
    overlapChecks++;
    return true;
  }

  @override
  Future<WorkSession> addManualSession({
    required String clienteId,
    required String teikerId,
    required DateTime start,
    required DateTime end,
    bool isExtra = false,
    String? createdById,
    String? createdByRole,
  }) async {
    clients.add(clienteId);
    extras.add(isExtra);
    creatorId = createdById;
    creatorRole = createdByRole;
    return WorkSession(
      id: 'session-${clients.length}',
      clienteId: clienteId,
      teikerId: teikerId,
      startTime: start,
      endTime: end,
      isExtra: isExtra,
    );
  }

  @override
  Future<MonthlyTotals> calculateMonthlyTotal({
    required String clienteId,
    required DateTime referenceDate,
  }) async {
    totalClients.add(clienteId);
    return MonthlyTotals(normal: 2, extra: 2);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
