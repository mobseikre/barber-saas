import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

import '../account/account_tab.dart';
import '../bookings/today_bookings_screen.dart';
import '../services/services_screen.dart';
import '../stats/stats_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  var _index = 0;
  final _visited = {0};

  static const _tabs = [
    (icon: Icons.calendar_today_outlined, label: 'الحجوزات'),
    (icon: Icons.content_cut_rounded, label: 'الخدمات'),
    (icon: Icons.bar_chart_rounded, label: 'الإحصائيات'),
    (icon: Icons.person_outline_rounded, label: 'حسابي'),
  ];

  static const _screens = [TodayBookingsScreen(), ServicesScreen(), StatsScreen(), AccountTab()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: [for (var i = 0; i < _tabs.length; i++) _visited.contains(i) ? _screens[i] : const SizedBox.shrink()],
      ),
      bottomNavigationBar: BarberBottomNav(
        index: _index,
        items: _tabs,
        onChanged: (i) => setState(() {
          _index = i;
          _visited.add(i);
        }),
      ),
    );
  }
}

/// Dark blue bottom bar with a tab per screen; the active one is red.
class BarberBottomNav extends StatelessWidget {
  const BarberBottomNav({super.key, required this.index, required this.items, required this.onChanged});

  final int index;
  final List<({IconData icon, String label})> items;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, bottomInset > 0 ? bottomInset : AppSpacing.md),
      child: Container(
        height: AppSizes.bottomNav,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(color: AppColors.blue900, borderRadius: BorderRadius.circular(AppRadius.panel)),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: () => onChanged(i),
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(items[i].icon, color: i == index ? AppColors.red400 : AppColors.onDarkInactive),
                        const SizedBox(height: AppSpacing.xs),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            items[i].label,
                            maxLines: 1,
                            style: AppText.weight(
                              AppText.label.copyWith(color: i == index ? AppColors.red400 : AppColors.onDarkInactive),
                              i == index ? FontWeight.w700 : FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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
