import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

import '../account/account_tab.dart';
import '../bookings/my_bookings_tab.dart';
import 'home_screen.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabShell(
      variant: AppBottomNavVariant.light,
      tabs: [
        (icon: Icons.home_outlined, label: 'الرئيسية', screen: HomeScreen()),
        (icon: Icons.calendar_today_outlined, label: 'حجوزاتي', screen: MyBookingsTab()),
        (icon: Icons.person_outline_rounded, label: 'حسابي', screen: AccountTab()),
      ],
    );
  }
}
