class AgendaMarcacaoIds {
  const AgendaMarcacaoIds({
    required this.teikerId,
    required this.reminderId,
    required this.adminReminderId,
  });

  final String teikerId;
  final String reminderId;
  final String adminReminderId;
}

class AgendaEventUtils {
  const AgendaEventUtils._();

  static bool isAcontecimento(Map<String, dynamic> event) {
    return event['isAcontecimento'] == true || event['tag'] == 'Acontecimento';
  }

  static bool isReminder(Map<String, dynamic> event) {
    if (isAcontecimento(event)) return false;
    if (event['isFerias'] == true) return false;
    if (event['isConsulta'] == true) return false;
    if (event['isBirthday'] == true) return false;
    return true;
  }

  static bool isTeikerMarcacaoTag(String? rawTag) {
    final normalized = (rawTag ?? '').trim().toLowerCase();
    return normalized == 'reunião de trabalho' ||
        normalized == 'reuniao de trabalho' ||
        normalized == 'acompanhamento';
  }

  static bool isHrVisibleAgendaTag(String? rawTag) {
    final normalized = (rawTag ?? '').trim();
    if (normalized == 'Acontecimento') return true;
    return isTeikerMarcacaoTag(normalized);
  }

  static bool isTeikerMarcacaoAgendaEvent(Map<String, dynamic> event) {
    return isTeikerMarcacaoTag(event['tag'] as String?);
  }

  static int eventOrderWeight(Map<String, dynamic> event) {
    if (isAcontecimento(event)) return 4;
    if (isTeikerMarcacaoAgendaEvent(event)) return 3;
    if (event['isConsulta'] == true) return 2;
    if (event['isBirthday'] == true) return 0;
    if (event['isFerias'] == true) return 1;
    return 2;
  }

  static int eventMinutesOfDay(Map<String, dynamic> event) {
    final start = event['start'];
    if (start is DateTime) {
      return (start.hour * 60) + start.minute;
    }

    final raw = (start ?? '').toString().trim();
    if (raw.isEmpty) return -1;
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw);
    if (match == null) return -1;
    final h = int.tryParse(match.group(1) ?? '');
    final m = int.tryParse(match.group(2) ?? '');
    if (h == null || m == null) return -1;
    return (h * 60) + m;
  }

  static List<Map<String, dynamic>> sortedEventsForList(
    List<Map<String, dynamic>> events,
  ) {
    final sorted = List<Map<String, dynamic>>.from(events);
    sorted.sort((a, b) {
      final byWeight = eventOrderWeight(a).compareTo(eventOrderWeight(b));
      if (byWeight != 0) return byWeight;

      final aMinutes = eventMinutesOfDay(a);
      final bMinutes = eventMinutesOfDay(b);
      final byTime = aMinutes.compareTo(bMinutes);
      if (byTime != 0) return byTime;

      final aTitle = (a['title'] ?? '').toString().toLowerCase();
      final bTitle = (b['title'] ?? '').toString().toLowerCase();
      return aTitle.compareTo(bTitle);
    });
    return sorted;
  }

  static AgendaMarcacaoIds agendaMarcacaoIds(Map<String, dynamic> event) {
    final isAdminSource = event['adminSource'] == true;
    final teikerId = (event['teikerId'] as String?)?.trim() ?? '';
    final reminderId = isAdminSource
        ? ((event['sourceReminderId'] as String?)?.trim() ?? '')
        : ((event['id'] as String?)?.trim() ?? '');
    final adminReminderId = isAdminSource
        ? ((event['id'] as String?)?.trim() ?? '')
        : ((event['adminReminderId'] as String?)?.trim() ?? '');
    return AgendaMarcacaoIds(
      teikerId: teikerId,
      reminderId: reminderId,
      adminReminderId: adminReminderId,
    );
  }

  static bool marcacaoItemMatchesIds({
    required Map<String, dynamic> item,
    required AgendaMarcacaoIds ids,
  }) {
    final itemId = (item['id'] as String?)?.trim() ?? '';
    final itemReminderId = (item['reminderId'] as String?)?.trim() ?? '';
    final itemAdminReminderId =
        (item['adminReminderId'] as String?)?.trim() ?? '';

    final matchesReminder =
        ids.reminderId.isNotEmpty &&
        (itemId == ids.reminderId || itemReminderId == ids.reminderId);
    final matchesAdmin =
        ids.adminReminderId.isNotEmpty &&
        itemAdminReminderId == ids.adminReminderId;
    return matchesReminder || matchesAdmin;
  }
}
