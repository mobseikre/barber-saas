import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../providers.dart';
import '../../widgets/offline_notice.dart';
import '../booking/booking_screen.dart';
import '../home/barber_card.dart';
import '../home/ranking.dart';
import 'salon_hours.dart';

const _servicesPreview = 4;
const _nameLines = 2;

/// Salon page: photos, hours, the barbers who work there and the chosen barber's services.
class SalonScreen extends ConsumerStatefulWidget {
  const SalonScreen({super.key, required this.salonId, this.barberId});

  final String salonId;
  final String? barberId;

  @override
  ConsumerState<SalonScreen> createState() => _SalonScreenState();
}

class _SalonScreenState extends ConsumerState<SalonScreen> {
  String? _selectedId;
  var _allServices = false;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.barberId;
  }

  void _retry() {
    ref.invalidate(salonListingsProvider(widget.salonId));
    ref.invalidate(salonBarbersProvider(widget.salonId));
    ref.invalidate(salonHoursProvider(widget.salonId));
  }

  @override
  Widget build(BuildContext context) {
    final listings = ref.watch(salonListingsProvider(widget.salonId));
    final barbers = ref.watch(salonBarbersProvider(widget.salonId));
    final hours = ref.watch(salonHoursProvider(widget.salonId));
    final error = listings.error ?? barbers.error ?? hours.error;

    if (error != null) {
      return _WithBack(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: RetryMessage(title: 'تعذّر تحميل الصالون', message: bookingErrorMessage(error), onRetry: _retry),
        ),
      );
    }
    if (!listings.hasValue || !barbers.hasValue || !hours.hasValue) {
      return const _WithBack(child: CircularProgressIndicator());
    }

    final team = barbers.requireValue;
    final bookable = [
      for (final b in team)
        if (b.isBookable) b,
    ];
    final requested = team.where((b) => b.id == widget.barberId).firstOrNull;
    final unavailable = requested != null && !requested.isBookable && _selectedId == requested.id;
    final selected = unavailable
        ? null
        : bookable.where((b) => b.id == _selectedId).firstOrNull ?? (bookable.isEmpty ? null : bookable.first);
    final salonRows = listings.requireValue;
    final listing = salonRows.where((l) => l.id == selected?.id).firstOrNull;
    final salon = listing ?? salonRows.firstOrNull;
    if (salon == null) {
      return _WithBack(
        child: Text('هذا الصالون غير متاح حالياً', style: AppText.body.copyWith(color: AppColors.text3)),
      );
    }

    final services = selected == null ? null : ref.watch(barberServicesProvider(selected.id));
    final fromPrice = services?.value?.map((s) => s.price).fold<double?>(null, (m, p) => m == null || p < m ? p : m);

    return Scaffold(
      body: StatusBarScrim(
        dark: true,
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PhotoHeader(photos: salon.salonPhotos),
                  Transform.translate(
                    offset: const Offset(0, -AppRadius.panel),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.xxl, AppSpacing.screen, 0),
                      decoration: const BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.panel)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const OfflineNotice(padding: EdgeInsets.only(bottom: AppSpacing.md)),
                          _SalonInfo(salon: salon, team: team, hours: hours.requireValue),
                          const SizedBox(height: AppSpacing.xl),
                          Row(
                            children: [
                              Expanded(
                                child: AppButton(
                                  label: 'الاتجاهات',
                                  icon: Icons.near_me_outlined,
                                  variant: AppButtonVariant.secondary,
                                  onPressed: salon.hasLocation
                                      ? () => openDirections(context, salon.latitude!, salon.longitude!)
                                      : null,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              SquareIconButton(
                                icon: Icons.phone_outlined,
                                tooltip: 'اتصال',
                                outlined: true,
                                onPressed: listing?.phone == null
                                    ? null
                                    : () => launchOrExplain(
                                        context,
                                        telUri(listing!.phone!),
                                        fallback: 'رقم الحلاق: ${formatLibyanPhone(listing.phone!)}',
                                      ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xxl),
                          Row(
                            children: [
                              Expanded(child: Text('اختر حلاقك', style: AppText.h2)),
                              Text(
                                '${barbersCount(team.length)} · ${availableCount(bookable.length)}',
                                style: AppText.caption.copyWith(color: AppColors.text3),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _BarberGrid(
                            team: team,
                            selectedId: selected?.id,
                            onSelected: (id) => setState(() {
                              _selectedId = id;
                              _allServices = false;
                            }),
                          ),
                          if (bookable.length < team.length) ...[
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'الحلاقون غير المتاحين يعملون في الصالون لكنهم غير مشتركين في التطبيق، يمكنك زيارتهم مباشرة.',
                              style: AppText.caption.copyWith(color: AppColors.text3),
                            ),
                          ],
                          if (unavailable) ...[
                            const SizedBox(height: AppSpacing.xl),
                            _UnavailableNotice(name: requested.displayName, othersBookable: bookable.isNotEmpty),
                          ],
                          if (selected != null) ...[
                            const SizedBox(height: AppSpacing.xl),
                            _ServicesCard(
                              barberName: selected.displayName,
                              services: services!,
                              showAll: _allServices,
                              onShowAll: () => setState(() => _allServices = true),
                              onRetry: () => ref.invalidate(barberServicesProvider(selected.id)),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xxl),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            PositionedDirectional(
              top: MediaQuery.paddingOf(context).top + AppSpacing.lg,
              start: AppSpacing.screen,
              child: const AppBackButton(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BookBar(
        barberName: selected?.displayName,
        emptyLabel: unavailable && bookable.isNotEmpty ? 'اختر حلاقاً متاحاً' : 'لا يوجد حلاق متاح للحجز',
        fromPrice: fromPrice,
        onBook: listing == null || services?.value?.isNotEmpty != true
            ? null
            : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => BookingScreen(barber: listing))),
      ),
    );
  }
}

/// A page with [child] in the middle and only the back button, for the states before the salon shows.
class _WithBack extends StatelessWidget {
  const _WithBack({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(child: child),
          PositionedDirectional(
            top: MediaQuery.paddingOf(context).top + AppSpacing.lg,
            start: AppSpacing.screen,
            child: const AppBackButton(),
          ),
        ],
      ),
    );
  }
}

class _PhotoHeader extends StatefulWidget {
  const _PhotoHeader({required this.photos});

  final List<String> photos;

  @override
  State<_PhotoHeader> createState() => _PhotoHeaderState();
}

class _PhotoHeaderState extends State<_PhotoHeader> {
  var _page = 0;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final photos = widget.photos;
    return SizedBox(
      height: AppSizes.salonPhoto + top,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: AppColors.blue900,
            child: photos.isEmpty
                ? const Icon(Icons.storefront_outlined, size: AppSizes.heroIcon, color: AppColors.blue300)
                : PageView.builder(
                    itemCount: photos.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, i) => Image.network(
                      publicStorageUrl(photos[i])!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.storefront_outlined, size: AppSizes.heroIcon, color: AppColors.blue300),
                    ),
                  ),
          ),
          PositionedDirectional(
            top: top + AppSpacing.lg,
            start: AppSpacing.screen,
            end: AppSpacing.screen,
            child: Row(
              children: [
                const Spacer(),
                if (photos.length > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: AppColors.blue950,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      '${_page + 1} / ${photos.length} صور',
                      style: AppText.label.copyWith(color: AppColors.surface),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SalonInfo extends ConsumerWidget {
  const _SalonInfo({required this.salon, required this.team, required this.hours});

  final BarberListing salon;
  final List<SalonBarber> team;
  final List<SalonDayHours> hours;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areas = ref.watch(areasProvider).value ?? const <Area>[];
    final cities = ref.watch(citiesProvider).value ?? const <City>[];
    final origin = ref.watch(userLocationProvider).value?.point;
    final area = areas.where((a) => a.id == salon.areaId).firstOrNull;
    final city = cities.where((c) => c.id == area?.cityId).firstOrNull;
    final distance = distanceTo(origin, salon);
    final place = [area?.name, city?.name].nonNulls.join('، ');
    final meta = [if (place.isNotEmpty) place, if (distance != null) ArabicFormat.distance(distance)];

    final rated = team.where((b) => b.ratingCount > 0);
    final ratingCount = rated.fold(0, (sum, b) => sum + b.ratingCount);
    final ratingAvg = ratingCount == 0
        ? 0.0
        : rated.fold(0.0, (sum, b) => sum + b.ratingAvg * b.ratingCount) / ratingCount;

    final now = AppTime.now();
    final todayHours = hours.where((h) => h.weekday == dbWeekday(now)).firstOrNull;
    final open = openState(
      hours: todayHours == null
          ? null
          : WorkingHours(
              barberId: '',
              weekday: todayHours.weekday,
              opensAt: todayHours.opensAt,
              closesAt: todayHours.closesAt,
            ),
      now: now,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(salon.salonName, style: AppText.h1)),
            if (ratingCount > 0) RatingLabel(avg: ratingAvg, count: ratingCount),
          ],
        ),
        if (meta.isNotEmpty) Text(meta.join(' · '), style: AppText.caption.copyWith(color: AppColors.text3)),
        if (salon.address != null) Text(salon.address!, style: AppText.caption.copyWith(color: AppColors.text3)),
        const SizedBox(height: AppSpacing.sm),
        OpenStateLabel(open),
        for (final line in hours.isEmpty ? const ['لا توجد أوقات عمل'] : weeklyHours(hours))
          Text(line, style: AppText.caption.copyWith(color: AppColors.text2)),
      ],
    );
  }
}

class _BarberGrid extends StatelessWidget {
  const _BarberGrid({required this.team, required this.selectedId, required this.onSelected});

  static const _columns = 3;

  final List<SalonBarber> team;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - AppSpacing.md * (_columns - 1)) / _columns;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final b in team)
              SizedBox(
                width: width,
                child: _BarberTile(
                  barber: b,
                  selected: b.id == selectedId,
                  onTap: b.isBookable ? () => onSelected(b.id) : null,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BarberTile extends StatelessWidget {
  const _BarberTile({required this.barber, required this.selected, required this.onTap});

  final SalonBarber barber;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = barber.isBookable;
    return Semantics(
      selected: selected,
      button: enabled,
      child: Material(
        color: enabled ? AppColors.surface : AppColors.dividerSoft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: selected ? AppColors.red400 : AppColors.border, width: AppSizes.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.md),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        enabled
                            ? LetterAvatar(name: barber.displayName, imageUrl: publicStorageUrl(barber.photoUrl))
                            : Container(
                                width: AppSizes.avatar,
                                height: AppSizes.avatar,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(color: AppColors.border, shape: BoxShape.circle),
                                child: Text(
                                  barber.displayName.trim().characters.firstOrNull ?? '؟',
                                  style: AppText.cardTitle.copyWith(color: AppColors.text3),
                                ),
                              ),
                        if (barber.isVip && enabled)
                          const PositionedDirectional(
                            top: -AppSpacing.xs,
                            start: -AppSpacing.sm,
                            child: Icon(
                              Icons.workspace_premium_rounded,
                              size: AppSizes.iconSm,
                              color: AppColors.poleRed,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      height: _nameLines * AppText.buttonCompact.fontSize! * AppText.buttonCompact.height!,
                      child: Center(
                        child: Text(
                          barber.displayName,
                          style: AppText.buttonCompact.copyWith(color: enabled ? AppColors.text : AppColors.text3),
                          textAlign: TextAlign.center,
                          maxLines: _nameLines,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (!enabled)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(AppRadius.badge),
                        ),
                        child: Text('غير متاح للحجز', style: AppText.label.copyWith(color: AppColors.text3)),
                      )
                    else if (barber.ratingCount > 0)
                      RatingLabel(avg: barber.ratingAvg, count: barber.ratingCount)
                    else
                      Text('جديد', style: AppText.caption.copyWith(color: AppColors.text3)),
                    if (enabled) NextFreeLabel(barberId: barber.id),
                  ],
                ),
              ),
              if (selected)
                PositionedDirectional(
                  top: AppSpacing.sm,
                  end: AppSpacing.sm,
                  child: Container(
                    width: AppSizes.iconMd,
                    height: AppSizes.iconMd,
                    decoration: const BoxDecoration(color: AppColors.poleRed, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded, size: AppSizes.badgeIcon, color: AppColors.surface),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServicesCard extends StatelessWidget {
  const _ServicesCard({
    required this.barberName,
    required this.services,
    required this.showAll,
    required this.onShowAll,
    required this.onRetry,
  });

  final String barberName;
  final AsyncValue<List<BarberService>> services;
  final bool showAll;
  final VoidCallback onShowAll;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final firstName = ArabicFormat.firstName(barberName);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('خدمات وأسعار $firstName', style: AppText.cardTitle),
          const SizedBox(height: AppSpacing.sm),
          switch (services) {
            AsyncValue(:final error?) when !services.hasValue => RetryMessage(
              message: bookingErrorMessage(error),
              onRetry: onRetry,
              inline: true,
            ),
            AsyncValue(:final value?) => _ServiceList(services: value, showAll: showAll, onShowAll: onShowAll),
            _ => const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
          },
        ],
      ),
    );
  }
}

class _ServiceList extends StatelessWidget {
  const _ServiceList({required this.services, required this.showAll, required this.onShowAll});

  final List<BarberService> services;
  final bool showAll;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text('لم يضف الحلاق خدماته بعد', style: AppText.caption.copyWith(color: AppColors.text3)),
      );
    }
    final shown = showAll ? services : services.take(_servicesPreview).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, s) in shown.indexed) ...[
          if (i > 0) const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.nameAr ?? '', style: AppText.bodyStrong),
                      Text(
                        ArabicFormat.minutes(s.durationMin),
                        style: AppText.caption.copyWith(color: AppColors.text3),
                      ),
                    ],
                  ),
                ),
                Text(ArabicFormat.price(s.price), style: AppText.cardTitle),
              ],
            ),
          ),
        ],
        if (shown.length < services.length)
          TextButton(onPressed: onShowAll, child: Text('عرض كل الخدمات (${services.length})')),
      ],
    );
  }
}

class _UnavailableNotice extends StatelessWidget {
  const _UnavailableNotice({required this.name, required this.othersBookable});

  final String name;
  final bool othersBookable;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.event_busy_rounded, color: AppColors.danger),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$name غير متاح للحجز حالياً', style: AppText.cardTitle),
                if (othersBookable)
                  Text('اختر حلاقاً آخر من الصالون', style: AppText.caption.copyWith(color: AppColors.text3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookBar extends StatelessWidget {
  const _BookBar({required this.barberName, required this.emptyLabel, required this.fromPrice, required this.onBook});

  final String? barberName;
  final String emptyLabel;
  final double? fromPrice;
  final VoidCallback? onBook;

  @override
  Widget build(BuildContext context) {
    final firstName = barberName == null ? null : ArabicFormat.firstName(barberName!);
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.md,
        AppSpacing.screen,
        AppSpacing.md + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  firstName == null ? emptyLabel : 'مع $firstName',
                  style: AppText.caption.copyWith(color: AppColors.text3),
                ),
                if (fromPrice != null) Text('يبدأ من ${ArabicFormat.price(fromPrice!)}', style: AppText.bodyStrong),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: AppButton(label: 'احجز الآن', variant: AppButtonVariant.accent, onPressed: onBook),
          ),
        ],
      ),
    );
  }
}

/// "اليوم ٤:٠٠ م" or "غداً ١٠:٠٠ ص" for the barber's next free start.
class NextFreeLabel extends ConsumerWidget {
  const NextFreeLabel({super.key, required this.barberId});

  final String barberId;

  static String text(TimeSlot slot, DateTime now) {
    final day = dbDate(slot.startsAt) == dbDate(now) ? 'اليوم' : 'غداً';
    return '$day ${ArabicFormat.time(slot.startsAt)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slot = ref.watch(nextFreeSlotProvider(barberId));
    final label = slot.whenOrNull(data: (s) => s == null ? 'لا يوجد موعد قريب' : text(s, AppTime.now()));
    if (label == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(
        label,
        style: AppText.label.copyWith(color: AppColors.success),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
