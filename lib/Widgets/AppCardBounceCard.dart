import 'package:flutter/material.dart';

class AppCardBounceCard extends StatefulWidget {
  final IconData? icon;
  final String title;
  final Color color;
  final bool whiteText;
  final Widget? trailing;
  final VoidCallback onTap;

  const AppCardBounceCard({
    super.key,
    this.icon,
    required this.title,
    required this.color,
    this.whiteText = false,
    this.trailing,
    required this.onTap,
  });

  @override
  State<AppCardBounceCard> createState() => _AppCardBounceCardState();
}

class _AppCardBounceCardState extends State<AppCardBounceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 0.05,
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap() {
    _controller.forward().then((_) => _controller.reverse());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: Material(
        elevation: 6,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(22),
        color: widget.color,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: _onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Row(
              children: [
                if (widget.icon != null)
                  Icon(widget.icon, color: Colors.white, size: 26),
                if (widget.icon != null) const SizedBox(width: 18),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      color: widget.whiteText ? Colors.white : Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                widget.trailing ??
                    Icon(
                      Icons.chevron_right,
                      color: Colors.white.withOpacity(0.9),
                      size: 26,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
