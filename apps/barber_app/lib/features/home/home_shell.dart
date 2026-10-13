import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

import '../account/account_tab.dart';
import '../bookings/today_bookings_screen.dart';
import '../services/services_screen.dart';
import '../stats/stats_screen.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabShell(
      variant: AppBottomNavVariant.dark,
      tabs: [
        (icon: Icons.calendar_today_outlined, label: 'الحجوزات', screen: TodayBookingsScreen()),
        (icon: Icons.content_cut_rounded, label: 'الخدمات', screen: ServicesScreen()),
        (icon: Icons.bar_chart_rounded, label: 'الإحصائيات', screen: StatsScreen()),
        (icon: Icons.person_outline_rounded, label: 'حسابي', screen: AccountTab()),
      ],
    );
  }
}
