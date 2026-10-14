import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../data/directory_repository.dart';
import '../../providers.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/offline_notice.dart';
import '../salon/salon_screen.dart';
import 'barber_card.dart';
import 'ranking.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _search = TextEditingController();
  late final AppLifecycleListener _lifecycle;
  String? _cityId;
  String? _areaId;
  var _sort = HomeSort.nearest;
  var _filter = const HomeFilter();

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _recheckLocation);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _search.dispose();
    super.dispose();
  }

  void _recheckLocation() {
    final failure = ref.read(userLocationProvider).value?.failure;
    if (failure == LocationFailure.deniedForever || failure == LocationFailure.serviceDisabled) {
      ref.invalidate(userLocationProvider);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(directoryProvider);
    if (ref.read(userLocationProvider).value?.failure != null) ref.invalidate(userLocationProvider);
    await ref.read(barberTodayProvider.future).catchError((_) => const <String, BarberToday>{});
  }

  Future<void> _pickCity(List<City> cities, String? current) async {
    final picked = await showAppBottomSheet<String>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final c in cities)
            ListTile(
              title: Text(c.name, style: AppText.bodyStrong),
              trailing: c.id == current ? const Icon(Icons.check_rounded, color: AppColors.poleRed) : null,
              onTap: () => Navigator.of(ctx).pop(c.id),
            ),
        ],
      ),
    );
    if (!mounted || picked == null || picked == current) return;
    setState(() {
      _cityId = picked;
      _areaId = null;
    });
  }

  Future<void> _openFilter() async {
    FocusScope.of(context).unfocus();
    await showAppBottomSheet<void>(
      context: context,
      builder: (ctx) => _FilterSheet(value: _filter, onChanged: (f) => setState(() => _filter = f)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).value;
    final location = ref.watch(userLocationProvider);
    final directory = ref.watch(directoryProvider);
    final ranking = ref.watch(homeRankingProvider);
    final cities = ref.watch(citiesProvider).value ?? const <City>[];
    final areas = ref.watch(areasProvider).value ?? const <Area>[];
    final today = ref.watch(barberTodayProvider).value;
    final origin = location.value?.point;
    final failure = location.value?.failure;

    final hasBarbers = directory.value?.isNotEmpty ?? false;
    final cityId = _cityId ?? defaultCityId(nearest: ranking.nearest, areas: areas, cities: cities);
    final city = cities.where((c) => c.id == cityId).firstOrNull;
    final cityAreas = [
      for (final a in areas)
        if (a.cityId == cityId) a,
    ];
    final areaNames = {for (final a in areas) a.id: a.name};
    final searching = _search.text.trim().isNotEmpty;
    final shown = filterBarbers(
      _sort == HomeSort.nearest ? ranking.nearest : ranking.topRated,
      areas: areas,
      cityId: searching ? null : cityId,
      areaId: searching ? null : _areaId,
      query: _search.text,
      filter: _filter,
      today: today,
      now: AppTime.now(),
    );
    final firstName = profile == null ? null : ArabicFormat.firstName(profile.fullName);

    final header = <Widget>[
      AppHeader(
        title: 'احجز حلاقك',
        subtitle: firstName == null || firstName.isEmpty ? 'مرحباً بك' : 'مرحباً $firstName',
        trailing: city == null ? null : _CityButton(name: city.name, onTap: () => _pickCity(cities, cityId)),
        bottom: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                style: AppText.body,
                decoration: const InputDecoration(
                  hintText: 'ابحث عن صالون أو حلاق',
                  prefixIcon: Icon(Icons.search_rounded, color: AppColors.text3),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _FilterButton(active: _filter.isActive, onTap: _openFilter),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      const OfflineNotice(),
      if (!searching) _AreaChips(areas: cityAreas, selected: _areaId, onSelected: (id) => setState(() => _areaId = id)),
      if (location.isLoading)
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, 0),
          child: Row(
            children: [
              const SizedBox.square(
                dimension: AppSizes.iconSm,
                child: CircularProgressIndicator(strokeWidth: AppSizes.ring),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('جارٍ تحديد موقعك…', style: AppText.caption.copyWith(color: AppColors.text2)),
            ],
          ),
        )
      else if (failure != null)
        _LocationNotice(
          failure: failure,
          onEnable: () => failure == LocationFailure.denied || failure == LocationFailure.unavailable
              ? ref.invalidate(userLocationProvider)
              : openLocationSettingsFor(failure),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.xl, AppSpacing.screen, AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Text(
                searching
                    ? 'نتائج البحث في كل المدن'
                    : origin != null || city == null
                    ? 'حلاقون قريبون منك'
                    : 'حلاقون في ${city.name}',
                style: AppText.h2,
              ),
            ),
            _SortToggle(value: _sort, onChanged: (s) => setState(() => _sort = s)),
          ],
        ),
      ),
    ];

    final Widget? placeholder = switch (directory) {
      AsyncValue(:final error?) when !hasBarbers => Padding(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: RetryMessage(message: bookingErrorMessage(error), onRetry: () => ref.invalidate(directoryProvider)),
      ),
      AsyncValue(isLoading: true) when !hasBarbers => const Padding(
        padding: EdgeInsets.all(AppSpacing.xxxl),
        child: Center(child: CircularProgressIndicator()),
      ),
      _ when shown.isEmpty => Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Text(
          _filter.isActive || searching ? 'لا توجد نتائج لبحثك' : 'لا يوجد حلاقون متاحون للحجز هنا بعد',
          style: AppText.body.copyWith(color: AppColors.text3),
          textAlign: TextAlign.center,
        ),
      ),
      _ => null,
    };

    return StatusBarScrim(
      dark: true,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: AppBottomNav.spaceBelow(context)),
          itemCount: header.length + (placeholder == null ? shown.length : 1),
          itemBuilder: (context, i) {
            if (i < header.length) return header[i];
            if (placeholder != null) return placeholder;
            final r = shown[i - header.length];
            return Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.cardGap),
              child: BarberCard(
                ranked: r,
                areaName: areaNames[r.barber.areaId],
                today: today?[r.barber.id],
                onTap: () {
                  FocusScope.of(context).unfocus();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SalonScreen(salonId: r.barber.salonId, barberId: r.barber.id),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CityButton extends StatelessWidget {
  const _CityButton({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.blue800,
      shape: const StadiumBorder(side: BorderSide(color: AppColors.bluePressed)),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on_outlined, size: AppSizes.iconSm, color: AppColors.red400),
              const SizedBox(width: AppSpacing.xs),
              Text(name, style: AppText.weight(AppText.caption.copyWith(color: AppColors.surface), FontWeight.w700)),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.keyboard_arrow_down_rounded, size: AppSizes.iconSm, color: AppColors.onDarkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SquareIconButton(
          icon: Icons.tune_rounded,
          tooltip: 'تصفية',
          background: AppColors.poleRed,
          foreground: AppColors.surface,
          onPressed: onTap,
        ),
        if (active)
          PositionedDirectional(
            top: -AppSpacing.xs,
            end: -AppSpacing.xs,
            child: Container(
              width: AppSizes.stepDot,
              height: AppSizes.stepDot,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.poleRed, width: AppSizes.ring),
              ),
            ),
          ),
      ],
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.value, required this.onChanged});

  final HomeFilter value;
  final ValueChanged<HomeFilter> onChanged;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late var _value = widget.value;

  void _set(HomeFilter value) {
    setState(() => _value = value);
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    Widget row(String label, bool on, ValueChanged<bool> onChanged) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppText.bodyStrong)),
          AppSwitch(value: on, onChanged: onChanged, semanticLabel: label),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.screen),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('تصفية النتائج', style: AppText.h2),
          const SizedBox(height: AppSpacing.sm),
          row('مفتوح الآن فقط', _value.openNow, (v) => _set(_value.copyWith(openNow: v))),
          row('حلاقون VIP فقط', _value.vipOnly, (v) => _set(_value.copyWith(vipOnly: v))),
          if (_value.isActive) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'إعادة الضبط',
              variant: AppButtonVariant.secondary,
              onPressed: () => _set(const HomeFilter()),
            ),
          ],
        ],
      ),
    );
  }
}

class _AreaChips extends StatelessWidget {
  const _AreaChips({required this.areas, required this.selected, required this.onSelected});

  final List<Area> areas;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = [(id: null, name: 'كل المناطق'), for (final a in areas) (id: a.id, name: a.name)];
    return SizedBox(
      height: AppSizes.cardButton,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) =>
            AppChip(label: items[i].name, selected: items[i].id == selected, onTap: () => onSelected(items[i].id)),
      ),
    );
  }
}

class _SortToggle extends StatelessWidget {
  const _SortToggle({required this.value, required this.onChanged});

  final HomeSort value;
  final ValueChanged<HomeSort> onChanged;

  static const _labels = {HomeSort.nearest: 'الأقرب', HomeSort.topRated: 'الأعلى تقييماً'};

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(color: AppColors.dividerSoft, borderRadius: BorderRadius.circular(AppRadius.control)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final sort in HomeSort.values)
            GestureDetector(
              onTap: () => onChanged(sort),
              child: Semantics(
                selected: sort == value,
                button: true,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: sort == value ? AppColors.surface : null,
                    borderRadius: BorderRadius.circular(AppRadius.badge),
                  ),
                  child: Text(
                    _labels[sort]!,
                    style: AppText.weight(
                      AppText.caption.copyWith(color: sort == value ? AppColors.text : AppColors.text3),
                      FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LocationNotice extends StatelessWidget {
  const _LocationNotice({required this.failure, required this.onEnable});

  final LocationFailure failure;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final message = switch (failure) {
      LocationFailure.serviceDisabled => 'خدمة الموقع متوقفة، فعّلها لعرض الأقرب إليك',
      LocationFailure.unavailable => 'تعذّر تحديد موقعك، الترتيب حسب المنطقة',
      _ => 'اسمح بالوصول لموقعك لعرض الأقرب إليك',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.md, AppSpacing.screen, 0),
      child: Row(
        children: [
          const Icon(Icons.my_location_rounded, size: AppSizes.iconSm, color: AppColors.text3),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(message, style: AppText.caption.copyWith(color: AppColors.text2)),
          ),
          TextButton(
            onPressed: onEnable,
            child: Text(failure == LocationFailure.unavailable ? RetryMessage.retryLabel : 'تفعيل'),
          ),
        ],
      ),
    );
  }
}
