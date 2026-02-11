import 'package:flutter/material.dart';
import 'package:teiker_app/theme/app_colors.dart';

class AppColorPalettePicker extends StatelessWidget {
  const AppColorPalettePicker({
    super.key,
    required this.selectedColor,
    required this.onChanged,
    this.colors = _defaultColors,
  });

  static const List<Color> _defaultColors = <Color>[
    Color(0xFFCC7A2F), // laranja
    Color(0xFF8B72C0), // lilas
    Color(0xFFC46A93), // rosa
    Color(0xFFC24D4D), // vermelho
    Color(0xFF2D7A4B), // verde
    Color(0xFF3D74B8), // azul
    Color(0xFF7A5A3A), // castanho
    Color(0xFF2C3E6E), // azul marinho
    Color(0xFFB88A3C), // amarelo torrado
    Color(0xFF7B2E3A), // vinho vermelho
    Color(0xFF72B466), // verde claro
  ];

  final Color selectedColor;
  final ValueChanged<Color> onChanged;
  final List<Color> colors;

  bool _isSelected(Color color) => color.toARGB32() == selectedColor.toARGB32();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: colors.map((color) {
        final selected = _isSelected(color);
        return InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => onChanged(color),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.primaryGreen : Colors.grey.shade300,
                width: selected ? 2.2 : 1.2,
              ),
            ),
            child: selected
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : null,
          ),
        );
      }).toList(),
    );
  }
}
