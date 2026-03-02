import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:teiker_app/theme/app_colors.dart';

class AppBottomNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback? onFabTap;
  final bool fabOpen;
  final bool showFab;
  final List<NavItemConfig> items;

  const AppBottomNavBar({
    super.key,
    required this.index,
    required this.onTap,
    required this.items,
    this.onFabTap,
    this.fabOpen = false,
    this.showFab = true,
  });

  static const Color barColor = AppColors.primaryGreen;
  static const Color appBackground = AppColors.creamBackground;
  static const double barHeight = 90;
  static const double fabSize = 60;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isDesktop = mediaQuery.size.width >= 980;
    if (isDesktop) {
      return _buildDesktopBar(context, mediaQuery);
    }

    return _buildMobileBar();
  }

  Widget _buildMobileBar() {
    return SizedBox(
      height: barHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // BAR VERDE
          Positioned.fill(child: Container(color: barColor)),

          if (showFab)
            Positioned(
              right: 10,
              top: -20,
              child: Container(
                width: fabSize + 12,
                height: fabSize + 12,
                decoration: BoxDecoration(
                  color: appBackground,
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            ),

          // NAV ITEMS
          Positioned(
            left: 20,
            right: showFab ? 100 : 20,
            top: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (int i = 0; i < items.length; i++)
                  _NavItem(
                    active: index == i,
                    icon: items[i].icon,
                    activeIcon: items[i].activeIcon ?? items[i].icon,
                    label: items[i].label,
                    onTap: () => onTap(i),
                  ),
              ],
            ),
          ),

          // FAB
          if (showFab)
            Positioned(
              right: 16,
              top: -14,
              child: GestureDetector(
                onTap: onFabTap,
                child: Stack(
                  children: [
                    // BOTÃO PRINCIPAL
                    Container(
                      width: fabSize,
                      height: fabSize,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.28),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        fabOpen ? CupertinoIcons.xmark : Icons.add,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopBar(BuildContext context, MediaQueryData mediaQuery) {
    final safeBottom = mediaQuery.padding.bottom;
    final maxWidth = showFab ? 980.0 : 920.0;
    final navWidth = (mediaQuery.size.width * 0.62).clamp(560.0, maxWidth);

    return SizedBox(
      height: 112 + safeBottom,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + safeBottom),
        child: Center(
          child: SizedBox(
            width: navWidth,
            child: Container(
              height: 84,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: .14)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .16),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        for (int i = 0; i < items.length; i++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: _DesktopNavItem(
                                active: index == i,
                                icon: items[i].icon,
                                activeIcon:
                                    items[i].activeIcon ?? items[i].icon,
                                label: items[i].label,
                                onTap: () => onTap(i),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (showFab) ...[
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: onFabTap,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .24),
                          ),
                        ),
                        child: Icon(
                          fabOpen ? CupertinoIcons.xmark : Icons.add,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final bool active;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback onTap;

  const _NavItem({
    required this.active,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 56,
        child: Column(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Icon(
                active ? activeIcon : icon,
                key: ValueKey(active),
                size: 30,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: active ? 1 : 0,
              child: active
                  ? Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopNavItem extends StatelessWidget {
  final bool active;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback onTap;

  const _DesktopNavItem({
    required this.active,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? Colors.white.withValues(alpha: .16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? Colors.white.withValues(alpha: .28)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                active ? activeIcon : icon,
                size: 24,
                color: active
                    ? Colors.white
                    : Colors.white.withValues(alpha: .86),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: .90),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NavItemConfig {
  final IconData icon;
  final IconData? activeIcon;
  final String label;

  const NavItemConfig({
    required this.icon,
    this.activeIcon,
    required this.label,
  });
}
