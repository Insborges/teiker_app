import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:teiker_app/utils/swiss_holiday_calendar.dart';

class ModernCalendar extends StatefulWidget {
  final DateTime focusedDay;
  final DateTime selectedDay;
  final void Function(DateTime selected, DateTime focusedMonth) onDaySelected;
  final Color primaryColor;
  final Color todayColor;
  final Map<DateTime, List>? events;
  final bool highlightWeek;
  final bool showHolidays;
  final double? maxHeight;

  final List<Map<String, dynamic>> teikersFerias;

  const ModernCalendar({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.onDaySelected,
    required this.primaryColor,
    required this.todayColor,
    this.events,
    this.highlightWeek = true,
    this.showHolidays = true,
    this.maxHeight,
    this.teikersFerias = const [],
  });

  @override
  State<ModernCalendar> createState() => _ModernCalendarState();
}

class _ModernCalendarState extends State<ModernCalendar> {
  late DateTime _visibleMonth;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(
      widget.focusedDay.year,
      widget.focusedDay.month,
      1,
    );
    _selected = widget.selectedDay;
  }

  @override
  void didUpdateWidget(covariant ModernCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _visibleMonth = DateTime(
      widget.focusedDay.year,
      widget.focusedDay.month,
      1,
    );
    _selected = widget.selectedDay;
  }

  DateTime _utc(DateTime d) => DateTime.utc(d.year, d.month, d.day);
  bool _hasEvents(DateTime d) => widget.events?.containsKey(_utc(d)) ?? false;

  bool _isHoliday(DateTime d) {
    if (!widget.showHolidays) return false;
    return SwissHolidayCalendar.isBernDayOff(d);
  }

  void _goMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + delta,
        1,
      );
    });
  }

  List<DateTime> _daysForMonth() {
    final first = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final weekdayOfFirst = first.weekday % 7;
    final daysBefore = weekdayOfFirst;
    final totalDays = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final totalCells = ((daysBefore + totalDays) / 7).ceil() * 7;

    return List.generate(totalCells, (i) {
      final dayIndex = i - daysBefore + 1;
      return DateTime(_visibleMonth.year, _visibleMonth.month, dayIndex);
    });
  }

  DateTime _startOfWeek(DateTime dt) {
    final weekday = dt.weekday % 7;
    return DateTime(dt.year, dt.month, dt.day - weekday);
  }

  List<Color> _feriasCoresParaDia(DateTime dia) {
    final cores = <Color>[];
    for (var teiker in widget.teikersFerias) {
      final diasFerias = teiker['dias'] as List<DateTime>;
      if (diasFerias.any((d) => _utc(d) == _utc(dia))) {
        // Adiciona a cor específica desse Teiker
        cores.add(teiker['cor'] as Color);
      }
    }
    return cores;
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22.0);
    final theme = Theme.of(context).textTheme;
    final days = _daysForMonth();
    final weekDays = ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"];
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = widget.maxHeight ?? (screenHeight * 0.45);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: maxHeight,
          padding: const EdgeInsets.all(14),
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: radius,
            border: Border.all(color: Colors.white.withValues(alpha: .18)),
            boxShadow: [
              BoxShadow(
                blurRadius: 20,
                color: Colors.black12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _glassButton(Icons.chevron_left, () => _goMonth(-1)),
                  Text(
                    "${_monthName(_visibleMonth.month)} ${_visibleMonth.year}",
                    style: theme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  _glassButton(Icons.chevron_right, () => _goMonth(1)),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 5.0;
                    const weekLabelHeight = 22.0;
                    final rows = (days.length / 7).ceil();
                    final widthCellSize =
                        (constraints.maxWidth - spacing * 6) / 7;
                    final availableGridHeight = math.max(
                      0.0,
                      constraints.maxHeight - weekLabelHeight - 8,
                    );
                    final heightCellSize =
                        (availableGridHeight - spacing * (rows - 1)) / rows;
                    if (heightCellSize <= 0 || widthCellSize <= 0) {
                      return const SizedBox.shrink();
                    }

                    final gridWidth = constraints.maxWidth;
                    final gridHeight = availableGridHeight;
                    final childAspectRatio = widthCellSize / heightCellSize;

                    return Column(
                      children: [
                        Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: gridWidth,
                            height: weekLabelHeight,
                            child: Row(
                              children: weekDays
                                  .map(
                                    (d) => Expanded(
                                      child: Center(
                                        child: Text(
                                          d,
                                          style: TextStyle(
                                            color: Colors.black.withValues(
                                              alpha: .55,
                                            ),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _buildGrid(
                            days,
                            gridWidth: gridWidth,
                            gridHeight: gridHeight,
                            spacing: spacing,
                            childAspectRatio: childAspectRatio,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(
    List<DateTime> days, {
    required double gridWidth,
    required double gridHeight,
    required double spacing,
    required double childAspectRatio,
  }) {
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: gridWidth,
        height: gridHeight,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: days.length,
          itemBuilder: (_, i) {
            final d = days[i];
            final inMonth = d.month == _visibleMonth.month;
            final today = _utc(d) == _utc(DateTime.now());
            final selected = _utc(d) == _utc(_selected);
            final weekHighlight =
                widget.highlightWeek &&
                _utc(d).difference(_startOfWeek(DateTime.now())).inDays >= 0 &&
                _utc(d).difference(_startOfWeek(DateTime.now())).inDays < 7;

            final coresFerias = _feriasCoresParaDia(d);

            return _Tile(
              date: d,
              selected: selected,
              today: today,
              inMonth: inMonth,
              weekHighlight: weekHighlight,
              hasEvents: _hasEvents(d),
              isHoliday: _isHoliday(d),
              feriasColors: coresFerias,
              primary: widget.primaryColor,
              accent: widget.todayColor,
              onTap: () {
                setState(() {
                  _selected = d;
                  _visibleMonth = DateTime(d.year, d.month, 1);
                });
                widget.onDaySelected(d, _visibleMonth);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _glassButton(IconData icon, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: .2),
          border: Border.all(color: Colors.white54),
        ),
        child: Icon(icon, color: widget.primaryColor),
      ),
    );
  }

  String _monthName(int m) {
    const months = [
      "Janeiro",
      "Fevereiro",
      "Março",
      "Abril",
      "Maio",
      "Junho",
      "Julho",
      "Agosto",
      "Setembro",
      "Outubro",
      "Novembro",
      "Dezembro",
    ];
    return months[m - 1];
  }
}

class _Tile extends StatelessWidget {
  final DateTime date;
  final bool selected, today, inMonth, weekHighlight, hasEvents, isHoliday;
  final Color primary, accent;
  final List<Color> feriasColors;
  final VoidCallback onTap;

  const _Tile({
    required this.date,
    required this.selected,
    required this.today,
    required this.inMonth,
    required this.weekHighlight,
    required this.hasEvents,
    required this.isHoliday,
    required this.feriasColors,
    required this.primary,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = "${date.day}";
    final baseColor = inMonth ? Colors.black87 : Colors.black26;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileSide = math.min(constraints.maxWidth, constraints.maxHeight);
        final bubbleSide = math.min(tileSide * .9, 64.0);
        final dayFontSize = (bubbleSide * 0.34).clamp(10.0, 20.0);
        final markerSize = (bubbleSide * 0.12).clamp(4.0, 7.0);
        final markerSpacing = bubbleSide < 30 ? 2.0 : 4.0;
        final markerTopPadding = bubbleSide < 30 ? 2.0 : 4.0;
        final showMarkers =
            (feriasColors.isNotEmpty || hasEvents || isHoliday) &&
            bubbleSide >= 26;

        return Center(
          child: SizedBox(
            width: bubbleSide,
            height: bubbleSide,
            child: InkWell(
              borderRadius: BorderRadius.circular(50),
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? primary
                      : (today
                            ? accent.withValues(alpha: .22)
                            : Colors.transparent),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            blurRadius: 12,
                            color: primary.withValues(alpha: .28),
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                  border: weekHighlight
                      ? Border.all(
                          color: primary.withValues(alpha: .22),
                          width: 1.3,
                        )
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      fit: FlexFit.loose,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          text,
                          style: TextStyle(
                            fontSize: dayFontSize,
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : baseColor,
                          ),
                        ),
                      ),
                    ),
                    if (showMarkers)
                      Padding(
                        padding: EdgeInsets.only(top: markerTopPadding),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (feriasColors.isNotEmpty)
                              _FeriasIndicator(
                                feriasColors: feriasColors,
                                markerSize: markerSize,
                              ),
                            if (hasEvents)
                              Container(
                                margin: EdgeInsets.only(left: markerSpacing),
                                width: markerSize,
                                height: markerSize,
                                decoration: BoxDecoration(
                                  color: selected ? Colors.white : primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            if (isHoliday)
                              Container(
                                margin: EdgeInsets.only(left: markerSpacing),
                                width: markerSize,
                                height: markerSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color.fromARGB(
                                      255,
                                      222,
                                      222,
                                      122,
                                    ),
                                    width: markerSize <= 4.5 ? 1.3 : 2,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FeriasIndicator extends StatelessWidget {
  final List<Color> feriasColors;
  final double markerSize;

  const _FeriasIndicator({required this.feriasColors, this.markerSize = 6});

  @override
  Widget build(BuildContext context) {
    if (feriasColors.isEmpty) return const SizedBox.shrink();

    if (feriasColors.length == 1) {
      // Apenas 1 Teiker de férias nesse dia -> bolinha única.
      return Container(
        width: markerSize,
        height: markerSize,
        decoration: BoxDecoration(
          color: feriasColors.first,
          shape: BoxShape.circle,
        ),
      );
    } else if (feriasColors.length == 2) {
      // 2 Teikers -> círculo dividido a meio.
      final splitSize = markerSize + 2;
      return CustomPaint(
        size: Size(splitSize, splitSize),
        painter: _HalfCirclePainter(feriasColors[0], feriasColors[1]),
      );
    } else {
      // 3 ou mais Teikers -> três bolinhas pequenas.
      final compactSize = math.max(3.0, markerSize - 1.5);
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: feriasColors
            .take(3)
            .map(
              (c) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                width: compactSize,
                height: compactSize,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle),
              ),
            )
            .toList(),
      );
    }
  }
}

class _HalfCirclePainter extends CustomPainter {
  final Color leftColor;
  final Color rightColor;

  _HalfCirclePainter(this.leftColor, this.rightColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    paint.color = leftColor;
    canvas.drawArc(rect, 0, 3.14159, true, paint);

    paint.color = rightColor;
    canvas.drawArc(rect, 3.14159, 3.14159, true, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
