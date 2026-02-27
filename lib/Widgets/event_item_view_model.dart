import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:teiker_app/agenda/agenda_event_utils.dart';

enum EventItemMetaKind { standard, status }

class EventItemMetaData {
  const EventItemMetaData.standard({required this.icon, required this.label})
    : kind = EventItemMetaKind.standard,
      isDone = false;

  const EventItemMetaData.status({required this.label, required this.isDone})
    : kind = EventItemMetaKind.status,
      icon = null;

  final EventItemMetaKind kind;
  final IconData? icon;
  final String label;
  final bool isDone;
}

class EventItemViewModel {
  EventItemViewModel({
    required this.title,
    required this.isDone,
    required this.rawTag,
    required this.tagText,
    required this.subtitle,
    required this.iconData,
    required this.surfaceColor,
    required this.borderColor,
    required this.accentColor,
    required this.titleColor,
    required this.shouldStrikeTitle,
    required this.showGenericSubtitle,
    required this.showBirthdayWishSubtitle,
    required this.showGenericTagChip,
    required this.usePillTagStyle,
    required this.isTeikerMarcacao,
    required this.isAcontecimento,
    required this.metaItems,
  });

  final String title;
  final bool isDone;
  final String? rawTag;
  final String? tagText;
  final String? subtitle;
  final IconData iconData;
  final Color surfaceColor;
  final Color borderColor;
  final Color accentColor;
  final Color titleColor;
  final bool shouldStrikeTitle;
  final bool showGenericSubtitle;
  final bool showBirthdayWishSubtitle;
  final bool showGenericTagChip;
  final bool usePillTagStyle;
  final bool isTeikerMarcacao;
  final bool isAcontecimento;
  final List<EventItemMetaData> metaItems;

  factory EventItemViewModel.fromEvent({
    required Map<String, dynamic> event,
    required Color selectedColor,
    String? displayTagOverride,
    required bool showHours,
    required bool showTeikerNameOnMarcacaoCard,
    required bool showClienteNameOnReminderCard,
  }) {
    final isDone = event['done'] ?? false;
    final sourceTag = event['tag'] as String?;
    final rawTag = sourceTag?.trim();
    final displayTag = (displayTagOverride ?? sourceTag)?.trim();
    final isAcontecimento = AgendaEventUtils.isAcontecimento(event);
    final isTeikerMarcacao = AgendaEventUtils.isTeikerMarcacaoTag(rawTag);
    final isBirthday = event['isBirthday'] == true;
    final isFerias = event['isFerias'] == true;
    final isConsulta = event['isConsulta'] == true;
    final subtitle = (event['subtitle'] as String?)?.trim();
    final start = (event['start'] ?? '').toString();
    final end = (event['end'] ?? '').toString();
    final hasHours = start.isNotEmpty || end.isNotEmpty;
    final teikerName = (event['teikerName'] as String?)?.trim() ?? '';
    final clienteName = (event['clienteName'] as String?)?.trim() ?? '';
    final createdAt = event['createdAt'] as DateTime?;
    final createdAtLabel = createdAt == null
        ? 'Data de criação indisponível'
        : DateFormat('dd/MM/yyyy • HH:mm', 'pt_PT').format(createdAt);
    final statusLabel = isDone ? 'Resolvido' : 'Por resolver';
    final hoursLabel = hasHours
        ? '$start${(start.isNotEmpty && end.isNotEmpty) ? ' — ' : ''}$end'
        : '';
    final showGenericSubtitle =
        !isAcontecimento &&
        !isTeikerMarcacao &&
        !isBirthday &&
        subtitle != null &&
        subtitle.isNotEmpty;
    final showGenericTagChip =
        !isAcontecimento &&
        !isTeikerMarcacao &&
        displayTag != null &&
        displayTag.isNotEmpty;
    final usePillTagStyle = _shouldUsePillTagStyle(displayTag);
    final showGenericHoursChip = showHours && !isTeikerMarcacao && hasHours;
    final isGenericReminderCard =
        !isAcontecimento &&
        !isTeikerMarcacao &&
        !isFerias &&
        !isConsulta &&
        !isBirthday;
    final showBirthdayWishSubtitle =
        isBirthday && subtitle != null && subtitle.isNotEmpty;

    final metaItems = <EventItemMetaData>[
      if (isAcontecimento) ...[
        EventItemMetaData.standard(
          icon: Icons.event_note_rounded,
          label: createdAtLabel,
        ),
        EventItemMetaData.status(label: statusLabel, isDone: isDone),
      ] else if (isTeikerMarcacao) ...[
        if (showTeikerNameOnMarcacaoCard && teikerName.isNotEmpty)
          EventItemMetaData.standard(
            icon: Icons.person_outline_rounded,
            label: teikerName,
          ),
        if (hoursLabel.isNotEmpty)
          EventItemMetaData.standard(
            icon: Icons.schedule_rounded,
            label: hoursLabel,
          ),
      ] else ...[
        if (showGenericHoursChip)
          EventItemMetaData.standard(
            icon: Icons.schedule_rounded,
            label: hoursLabel,
          ),
        if (showClienteNameOnReminderCard &&
            isGenericReminderCard &&
            clienteName.isNotEmpty)
          EventItemMetaData.standard(
            icon: Icons.home_work_outlined,
            label: clienteName,
          ),
      ],
    ];

    return EventItemViewModel(
      title: (event['title'] ?? '').toString(),
      isDone: isDone,
      rawTag: rawTag,
      tagText: displayTag,
      subtitle: subtitle,
      iconData: _eventIcon(
        rawTag: rawTag,
        isAcontecimento: isAcontecimento,
        isTeikerMarcacao: isTeikerMarcacao,
        isBirthday: isBirthday,
        isFerias: isFerias,
        isConsulta: isConsulta,
      ),
      surfaceColor: selectedColor.withValues(alpha: isDone ? .14 : .07),
      borderColor: selectedColor.withValues(alpha: isDone ? .28 : .18),
      accentColor: selectedColor.withValues(alpha: isDone ? .95 : .90),
      titleColor: isDone ? Colors.green.shade900 : Colors.black87,
      shouldStrikeTitle: isDone,
      showGenericSubtitle: showGenericSubtitle,
      showBirthdayWishSubtitle: showBirthdayWishSubtitle,
      showGenericTagChip: showGenericTagChip,
      usePillTagStyle: usePillTagStyle,
      isTeikerMarcacao: isTeikerMarcacao,
      isAcontecimento: isAcontecimento,
      metaItems: metaItems,
    );
  }

  static bool _shouldUsePillTagStyle(String? rawTag) {
    final normalized = (rawTag ?? '').trim().toLowerCase();
    if (normalized.isEmpty) return false;
    return normalized == 'aniversário' ||
        normalized == 'aniversario' ||
        normalized == 'consulta' ||
        normalized == 'baixa' ||
        normalized == 'férias' ||
        normalized == 'ferias';
  }

  static IconData _eventIcon({
    required String? rawTag,
    required bool isAcontecimento,
    required bool isTeikerMarcacao,
    required bool isBirthday,
    required bool isFerias,
    required bool isConsulta,
  }) {
    final normalized = (rawTag ?? '').trim().toLowerCase();
    if (isAcontecimento) return Icons.campaign_outlined;
    if (isTeikerMarcacao) {
      return normalized == 'acompanhamento'
          ? Icons.support_agent_outlined
          : Icons.groups_2_outlined;
    }
    if (isBirthday) return Icons.cake_outlined;
    if (isConsulta || normalized.contains('consulta')) {
      return Icons.medical_services_outlined;
    }
    if (normalized.contains('baixa')) return Icons.sick_outlined;
    if (isFerias ||
        normalized.contains('férias') ||
        normalized.contains('ferias')) {
      return Icons.beach_access_outlined;
    }
    if (normalized.contains('anivers')) return Icons.cake_outlined;
    return Icons.notifications_none_rounded;
  }
}
