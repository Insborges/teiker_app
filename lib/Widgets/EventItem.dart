import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:teiker_app/Widgets/event_item_view_model.dart';

class EventItem extends StatelessWidget {
  static const Color _appDarkGreen = Color(0xFF0B4B35);

  final Map<String, dynamic> event;
  final Color selectedColor;
  final VoidCallback onDelete;
  final VoidCallback onToggleDone;
  final VoidCallback? onTap;
  final Widget? trailingWidget;
  final bool showHours; // NOVO: controla se mostra horas
  final bool readOnly;
  final String? tag;
  final bool showTeikerNameOnMarcacaoCard;
  final bool showClienteNameOnReminderCard;

  const EventItem({
    super.key,
    required this.event,
    required this.selectedColor,
    required this.onDelete,
    required this.onToggleDone,
    this.onTap,
    this.trailingWidget,
    this.showHours = true, // padrão true para compatibilidade
    this.readOnly = false,
    this.tag,
    this.showTeikerNameOnMarcacaoCard = true,
    this.showClienteNameOnReminderCard = false,
  });

  @override
  Widget build(BuildContext context) {
    final vm = EventItemViewModel.fromEvent(
      event: event,
      selectedColor: selectedColor,
      displayTagOverride: tag,
      showHours: showHours,
      showTeikerNameOnMarcacaoCard: showTeikerNameOnMarcacaoCard,
      showClienteNameOnReminderCard: showClienteNameOnReminderCard,
    );
    final metaChips = vm.metaItems.map(_buildMetaItem).toList();

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: vm.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: vm.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 5,
            height: 36,
            decoration: BoxDecoration(
              color: vm.accentColor,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: selectedColor.withValues(alpha: .14),
              shape: BoxShape.circle,
            ),
            child: Icon(vm.iconData, size: 17, color: selectedColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        vm.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: vm.titleColor,
                          decoration: vm.shouldStrikeTitle
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    if (vm.showGenericTagChip && vm.tagText != null)
                      _tagChip(vm.tagText!, usePillStyle: vm.usePillTagStyle),
                  ],
                ),
                if (vm.showGenericSubtitle && vm.subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    vm.subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: _appDarkGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (vm.showBirthdayWishSubtitle && vm.subtitle != null) ...[
                  const SizedBox(height: 5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.favorite_border_rounded,
                        size: 14,
                        color: _appDarkGreen,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          vm.subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _appDarkGreen,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (metaChips.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: metaChips),
                ],
              ],
            ),
          ),
          if (trailingWidget != null) ...[
            const SizedBox(width: 8),
            trailingWidget!,
          ],
          if (!readOnly)
            GestureDetector(
              onTap: onToggleDone,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: vm.isDone
                    ? Icon(
                        Icons.check_circle,
                        color: selectedColor,
                        size: 24,
                        key: const ValueKey('done'),
                      )
                    : Icon(
                        Icons.check_circle_outline,
                        color: selectedColor,
                        size: 22,
                        key: const ValueKey('todo'),
                      ),
              ),
            ),
        ],
      ),
    );

    final tappableChild = onTap == null
        ? card
        : Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: card,
            ),
          );

    if (readOnly) {
      return Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 8),
        child: tappableChild,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Slidable(
        key: ValueKey(event),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => onDelete(),
              icon: Icons.delete,
              label: 'Eliminar',
              backgroundColor: Colors.red.shade600,
              borderRadius: BorderRadius.circular(12),
            ),
          ],
        ),
        child: tappableChild,
      ),
    );
  }

  Widget _buildMetaItem(EventItemMetaData meta) {
    if (meta.kind == EventItemMetaKind.status) {
      return _statusChip(label: meta.label, isDone: meta.isDone);
    }
    return _metaChip(icon: meta.icon!, label: meta.label);
  }

  Widget _tagChip(String text, {required bool usePillStyle}) {
    if (usePillStyle) {
      return Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .92),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selectedColor.withValues(alpha: .22)),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selectedColor,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: _appDarkGreen,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _statusChip({required String label, required bool isDone}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isDone ? Icons.check_circle_outline : Icons.pending_outlined,
          size: 13,
          color: _appDarkGreen,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: _appDarkGreen,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _metaChip({required IconData icon, required String label}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 1),
          Icon(icon, size: 13, color: _appDarkGreen),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: _appDarkGreen,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
