import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../providers.dart';
import '../account/account_tab.dart';
import '../bookings/my_bookings_tab.dart';
import '../salon/salon_screen.dart';
import 'home_screen.dart';

/// The tabs, plus what lives as long as the app: push registration, notices while open and barber links.
/// حجوزاتي reloads whenever it is opened and whenever the app comes back to the foreground.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  StreamSubscription<Uri>? _links;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _links = ref.read(appLinksProvider).listen(_openLink);
    _lifecycle = AppLifecycleListener(onResume: () => ref.invalidate(myBookingsProvider));
  }

  @override
  void dispose() {
    _links?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (index == HomeTab.bookings) ref.invalidate(myBookingsProvider);
    ref.read(homeTabProvider.notifier).select(index);
  }

  /// Opens the salon page on the barber of a QR code link.
  Future<void> _openLink(Uri uri) async {
    final barberId = barberIdFromLink(uri);
    if (barberId == null) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final salonId = await ref.read(directoryRepositoryProvider).salonOfBarber(barberId);
      if (salonId == null) {
        messenger.showSnackBar(const SnackBar(content: Text('هذا الحلاق غير متاح حالياً')));
        return;
      }
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => SalonScreen(salonId: salonId, barberId: barberId),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(bookingErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentProfileProvider, (_, next) {
      if (next case AsyncData(value: Profile(:final id, role: UserRole.customer))) {
        ref.read(pushTokensProvider).register(id);
      }
    });
    ref.listen(pushNoticesProvider, (_, next) {
      final notice = next.value;
      if (notice == null) return;
      ref.invalidate(myBookingsProvider);
      final text = [notice.title, notice.body].nonNulls.join('\n');
      if (text.isNotEmpty) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    });

    return TabShell(
      variant: AppBottomNavVariant.light,
      index: ref.watch(homeTabProvider),
      onChanged: _selectTab,
      tabs: const [
        (icon: Icons.home_outlined, label: 'الرئيسية', screen: HomeScreen()),
        (icon: Icons.calendar_today_outlined, label: 'حجوزاتي', screen: MyBookingsTab()),
        (icon: Icons.person_outline_rounded, label: 'حسابي', screen: AccountTab()),
      ],
    );
  }
}
