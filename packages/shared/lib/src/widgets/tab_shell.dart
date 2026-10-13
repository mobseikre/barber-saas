import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text.dart';

typedef AppTab = ({IconData icon, String label, Widget screen});

/// The barber app's dark bar or the customer app's white bar with a pill behind the active icon.
enum AppBottomNavVariant { dark, light }

/// Bottom-nav screen that builds each tab the first time it is opened and keeps it alive afterwards.
class TabShell extends StatefulWidget {
  const TabShell({super.key, required this.tabs, required this.variant});

  final List<AppTab> tabs;
  final AppBottomNavVariant variant;

  @override
  State<TabShell> createState() => _TabShellState();
}

class _TabShellState extends State<TabShell> {
  var _index = 0;
  final _visited = {0};

  @override
  Widget build(BuildContext context) {
    final tabs = widget.tabs;
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < tabs.length; i++) _visited.contains(i) ? tabs[i].screen : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        variant: widget.variant,
        index: _index,
        items: [for (final t in tabs) (icon: t.icon, label: t.label)],
        onChanged: (i) => setState(() {
          _index = i;
          _visited.add(i);
        }),
      ),
    );
  }
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.variant,
    required this.index,
    required this.items,
    required this.onChanged,
  });

  final AppBottomNavVariant variant;
  final int index;
  final List<({IconData icon, String label})> items;
  final ValueChanged<int> onChanged;

  /// Space the bar takes at the bottom of a tab, so lists can scroll clear of it.
  static double spaceBelow(BuildContext context) =>
      AppSizes.bottomNav + AppSpacing.md * 2 + MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final dark = variant == AppBottomNavVariant.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, bottomInset > 0 ? bottomInset : AppSpacing.md),
      child: Container(
        height: AppSizes.bottomNav,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: dark ? AppColors.blue900 : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.panel),
          border: dark ? null : Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _NavItem(
                  icon: items[i].icon,
                  label: items[i].label,
                  selected: i == index,
                  dark: dark,
                  onTap: () => onChanged(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.dark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = dark
        ? (selected ? AppColors.red400 : AppColors.onDarkInactive)
        : (selected ? AppColors.blue900 : AppColors.text3);
    final weight = selected ? (dark ? FontWeight.w700 : FontWeight.w800) : FontWeight.w600;
    final iconWidget = Icon(icon, size: AppSizes.iconMd, color: color);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: Semantics(
          selected: selected,
          button: true,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (dark)
                SizedBox(height: AppSizes.navPillHeight, child: iconWidget)
              else
                Container(
                  width: AppSizes.navPillWidth,
                  height: AppSizes.navPillHeight,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.red100 : null,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: iconWidget,
                ),
              const SizedBox(height: AppSpacing.xs),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, maxLines: 1, style: AppText.weight(AppText.label.copyWith(color: color), weight)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
