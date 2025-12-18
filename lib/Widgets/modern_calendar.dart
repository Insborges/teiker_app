import 'package:flutter/material.dart';
import 'dart:ui';

class ModernCalendar extends StatefulWidget {
  final DateTime focusedDay;
  final DateTime selectedDay;
  final void Function(DateTime selected, DateTime focusedMonth) onDaySelected;
  final Color primaryColor;
  final Color todayColor;
  final Map<DateTime, List>? events;
  final bool highlightWeek;
  final bool showHolidays;

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
    return _swissHolidays[d.month]?.contains(d.day) ?? false;
  }

  Map<int, List<int>> get _swissHolidays => {
    1: [1],
    4: [18],
    5: [1, 29],
    8: [1],
    12: [25, 26],
  };

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
    final maxHeight = screenHeight * 0.45;

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(14),
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: radius,
            border: Border.all(color: Colors.white.withOpacity(.18)),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: weekDays
                    .map(
                      (d) => Flexible(
                        fit: FlexFit.tight,
                        child: Center(
                          child: Text(
                            d,
                            style: TextStyle(
                              color: Colors.black.withOpacity(.55),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildGrid(days)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(List<DateTime> days) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cellSize = (width - 6 * 6) / 7;
        final rows = (days.length / 7).ceil();
        final gridHeight = cellSize * rows + (rows - 1) * 6;

        return SizedBox(
          height: gridHeight,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1,
            ),
            itemCount: days.length,
            itemBuilder: (_, i) {
              final d = days[i];
              final inMonth = d.month == _visibleMonth.month;
              final today = _utc(d) == _utc(DateTime.now());
              final selected = _utc(d) == _utc(_selected);
              final weekHighlight =
                  widget.highlightWeek &&
                  _utc(d).difference(_startOfWeek(DateTime.now())).inDays >=
                      0 &&
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
                  setState(() => _selected = d);
                  widget.onDaySelected(d, _visibleMonth);
                },
              );
            },
          ),
        );
      },
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
          color: Colors.white.withOpacity(.2),
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

    return InkWell(
      borderRadius: BorderRadius.circular(50),
      onTap: inMonth ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected
              ? primary
              : (today ? accent.withOpacity(.22) : Colors.transparent),
          boxShadow: selected
              ? [
                  BoxShadow(
                    blurRadius: 12,
                    color: primary.withOpacity(.28),
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
          border: weekHighlight
              ? Border.all(color: primary.withOpacity(.22), width: 1.3)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : baseColor,
              ),
            ),
            if (feriasColors.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: _FeriasIndicator(feriasColors: feriasColors),
              ),
            if (isHoliday)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color.fromARGB(255, 222, 222, 122),
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FeriasIndicator extends StatelessWidget {
  final List<Color> feriasColors;

  const _FeriasIndicator({required this.feriasColors});

  @override
  Widget build(BuildContext context) {
    if (feriasColors.isEmpty) return const SizedBox.shrink();

    if (feriasColors.length == 1) {
      // Apenas 1 Teiker de férias nesse dia → bolinha única
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: feriasColors.first,
          shape: BoxShape.circle,
        ),
      );
    } else if (feriasColors.length == 2) {
      // 2 Teikers → círculo dividido a meio
      return CustomPaint(
        size: const Size(10, 10),
        painter: _HalfCirclePainter(feriasColors[0], feriasColors[1]),
      );
    } else {
      // 3 ou mais Teikers → três bolinhas pequenas
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: feriasColors
            .take(3)
            .map(
              (c) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                width: 6,
                height: 6,
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
