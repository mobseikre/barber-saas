import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../providers.dart';
import '../auth/sign_in.dart';
import '../home/ranking.dart';
import '../../widgets/app_chip.dart';
import 'booking_attempt.dart';
import 'booking_confirmed_screen.dart';

const _slotColumns = 3;

/// Choose a service, a day and a free time with the chosen barber, then confirm.
class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key, required this.barber});

  final BarberListing barber;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  final _attempt = BookingAttempt();
  late final List<DateTime> _days;
  String? _serviceId;
  int? _dayIndex;
  TimeSlot? _slot;
  var _submitting = false;
  String? _error;
  var _blocked = false;

  @override
  void initState() {
    super.initState();
    final now = AppTime.now();
    _days = [for (var i = 0; i < bookingDays; i++) AppTime.at(now.add(Duration(days: i)), 12, 0)];
  }

  String get _barberId => widget.barber.id;

  bool _isOpen(DateTime day, List<WorkingHours> hours, List<DayClosure> closures) {
    final h = hours.where((h) => h.weekday == dbWeekday(day)).firstOrNull;
    if (h == null || h.isClosed) return false;
    return !closures.any((c) => c.isWholeDay && dbDate(c.date) == dbDate(day));
  }

  SlotQuery? _slotQuery(BarberService? service, int? dayIndex) => service == null || dayIndex == null
      ? null
      : (barberId: _barberId, date: dbDate(_days[dayIndex]), durationMin: service.durationMin);

  Future<void> _confirm(BarberService service, TimeSlot slot, SlotQuery query) async {
    if (_submitting) return;
    setState(() {
      _error = null;
      _blocked = false;
    });
    if (!await ensureSignedIn(context, ref) || !mounted) return;
    setState(() => _submitting = true);
    final choice = (barberId: _barberId, serviceId: service.serviceId, startsAt: slot.startsAt);
    try {
      final booking = await ref
          .read(bookingRepositoryProvider)
          .createBooking(
            barberId: _barberId,
            serviceId: service.serviceId,
            startsAt: slot.startsAt,
            idempotencyKey: _attempt.keyFor(choice),
          );
      _attempt.reset();
      if (!mounted) return;
      ref.invalidate(myBookingsProvider);
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) =>
              BookingConfirmedScreen(booking: booking, barber: widget.barber, serviceName: service.nameAr ?? ''),
        ),
        (r) => r.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      final taken = e is PostgrestException && e.message == 'slot_not_available';
      setState(() {
        _error = bookingErrorMessage(e);
        _blocked = e is PostgrestException && e.message == 'customer_blocked';
        if (taken) _slot = null;
      });
      if (taken) ref.invalidate(availableSlotsProvider(query));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(barberServicesProvider(_barberId));
    final hours = ref.watch(workingHoursProvider(_barberId));
    final closures = ref.watch(upcomingClosuresProvider(_barberId));
    final error = services.error ?? hours.error ?? closures.error;

    Widget body;
    if (error != null && !(services.hasValue && hours.hasValue && closures.hasValue)) {
      body = Padding(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: RetryMessage(
          message: bookingErrorMessage(error),
          onRetry: () {
            ref.invalidate(barberServicesProvider(_barberId));
            ref.invalidate(workingHoursProvider(_barberId));
            ref.invalidate(upcomingClosuresProvider(_barberId));
          },
        ),
      );
    } else if (!services.hasValue || !hours.hasValue || !closures.hasValue) {
      body = const Padding(
        padding: EdgeInsets.all(AppSpacing.xxxl),
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      body = _buildForm(services.requireValue, hours.requireValue, closures.requireValue);
    }

    final service = services.value?.where((s) => s.serviceId == _serviceId).firstOrNull;
    final dayIndex = _dayIndexFor(hours.value, closures.value);
    final query = _slotQuery(service, dayIndex);
    final slot = _slot;
    return Scaffold(
      body: StatusBarScrim(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageTitle(
                title: 'حجز موعد',
                subtitle: '${widget.barber.salonName} · مع ${widget.barber.displayName}',
                leading: const AppBackButton(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                child: _Steps(
                  done: 1 + (service != null ? 1 : 0) + (dayIndex != null ? 1 : 0) + (slot != null ? 1 : 0),
                ),
              ),
              body,
            ],
          ),
        ),
      ),
      bottomNavigationBar: _ConfirmBar(
        summary: service == null || slot == null
            ? null
            : [
                ArabicFormat.firstName(widget.barber.displayName),
                service.nameAr ?? '',
                ArabicFormat.dayDate(slot.startsAt),
                ArabicFormat.time(slot.startsAt),
              ].join(' · '),
        price: service?.price,
        error: _error,
        onContactSupport: _blocked ? () => contactSupport(context) : null,
        loading: _submitting,
        onConfirm: service == null || slot == null || query == null ? null : () => _confirm(service, slot, query),
      ),
    );
  }

  /// The chosen day, or the first open one; today only while the barber is still working.
  int? _dayIndexFor(List<WorkingHours>? hours, List<DayClosure>? closures) {
    if (_dayIndex != null) return _dayIndex;
    if (hours == null || closures == null) return null;
    bool stillOpenToday() {
      final now = AppTime.now();
      final today = hours.where((h) => h.weekday == dbWeekday(now)).firstOrNull;
      final closure = closures.where((c) => dbDate(c.date) == dbDate(now)).firstOrNull;
      return openState(hours: today, closure: closure, now: now) is! ClosedToday;
    }

    for (var i = 0; i < _days.length; i++) {
      if (_isOpen(_days[i], hours, closures) && (i > 0 || stillOpenToday())) return i;
    }
    return null;
  }

  Widget _buildForm(List<BarberService> services, List<WorkingHours> hours, List<DayClosure> closures) {
    final open = [for (final d in _days) _isOpen(d, hours, closures)];
    final dayIndex = _dayIndexFor(hours, closures);
    final service = services.where((s) => s.serviceId == _serviceId).firstOrNull;
    final query = _slotQuery(service, dayIndex);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.xl, AppSpacing.screen, AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BarberRow(barber: widget.barber),
          const SizedBox(height: AppSpacing.xl),
          Text('2. اختر الخدمة', style: AppText.h3),
          const SizedBox(height: AppSpacing.md),
          if (services.isEmpty)
            Text('لم يضف الحلاق خدماته بعد', style: AppText.caption.copyWith(color: AppColors.text3))
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final s in services)
                  SizedBox(
                    height: AppSizes.actionButton,
                    child: AppChip(
                      label: s.nameAr ?? '',
                      detail: ArabicFormat.price(s.price),
                      selected: s.serviceId == _serviceId,
                      onTap: () => setState(() {
                        _serviceId = s.serviceId;
                        _slot = null;
                        _error = null;
                      }),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: AppSpacing.xl),
          Text('3. اختر اليوم', style: AppText.h3),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: AppSizes.numberBox,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _days.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (_, i) => _DayTile(
                label: switch (i) {
                  0 => 'اليوم',
                  1 => 'غداً',
                  _ => ArabicFormat.weekday(_days[i]),
                },
                day: _days[i].day,
                selected: i == dayIndex,
                onTap: open[i]
                    ? () => setState(() {
                        _dayIndex = i;
                        _slot = null;
                        _error = null;
                      })
                    : null,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(child: Text('4. اختر الوقت', style: AppText.h3)),
              Text(
                'مواعيد ${ArabicFormat.firstName(widget.barber.displayName)} فقط',
                style: AppText.caption.copyWith(color: AppColors.text3),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (dayIndex == null)
            _Hint('لا توجد أيام عمل في الأسبوعين القادمين')
          else if (query == null)
            _Hint('اختر الخدمة لعرض المواعيد المتاحة')
          else
            _SlotGrid(
              slots: ref.watch(availableSlotsProvider(query)),
              selected: _slot,
              onSelected: (s) => setState(() {
                _slot = s;
                _error = null;
              }),
              onRetry: () => ref.invalidate(availableSlotsProvider(query)),
            ),
        ],
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.done});

  static const _labels = ['الحلاق', 'الخدمة', 'اليوم', 'الوقت', 'تأكيد'];

  final int done;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: AppSpacing.xs,
                  decoration: BoxDecoration(
                    color: i < done ? AppColors.blue900 : (i == done ? AppColors.red400 : AppColors.border),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _labels[i],
                  style: AppText.weight(
                    AppText.label.copyWith(color: i <= done ? AppColors.text : AppColors.text3),
                    i == done ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _BarberRow extends StatelessWidget {
  const _BarberRow({required this.barber});

  final BarberListing barber;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          LetterAvatar(name: barber.displayName, imageUrl: publicStorageUrl(barber.photoUrl)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('1. الحلاق', style: AppText.caption.copyWith(color: AppColors.text3)),
                Text(barber.displayName, style: AppText.cardTitle),
              ],
            ),
          ),
          AppButton(
            label: 'تغيير',
            variant: AppButtonVariant.text,
            compact: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.label, required this.day, required this.selected, required this.onTap});

  final String label;
  final int day;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = selected ? AppColors.surface : (enabled ? AppColors.text : AppColors.text3);
    return Semantics(
      selected: selected,
      enabled: enabled,
      button: true,
      child: Material(
        color: selected ? AppColors.blue900 : (enabled ? AppColors.surface : AppColors.dividerSoft),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          side: BorderSide(color: selected ? AppColors.blue900 : AppColors.border, width: AppSizes.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: SizedBox(
            width: AppSizes.numberBox,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: AppText.label.copyWith(color: selected ? AppColors.red300 : AppColors.text3)),
                Text(
                  '$day',
                  style: AppText.time.copyWith(
                    color: fg,
                    decoration: enabled ? null : TextDecoration.lineThrough,
                    decorationColor: AppColors.text3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SlotGrid extends StatelessWidget {
  const _SlotGrid({required this.slots, required this.selected, required this.onSelected, required this.onRetry});

  final AsyncValue<List<TimeSlot>> slots;
  final TimeSlot? selected;
  final ValueChanged<TimeSlot> onSelected;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return switch (slots) {
      AsyncValue(:final value?) when !slots.isLoading || value.isNotEmpty =>
        value.isEmpty
            ? const _Hint('لا توجد مواعيد متاحة في هذا اليوم، جرّب يوماً آخر')
            : LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - AppSpacing.sm * (_slotColumns - 1)) / _slotColumns;
                  return Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final s in value)
                        SizedBox(
                          width: width,
                          child: _SlotChip(
                            label: ArabicFormat.time(s.startsAt),
                            selected: selected?.startsAt.isAtSameMomentAs(s.startsAt) ?? false,
                            onTap: () => onSelected(s),
                          ),
                        ),
                    ],
                  );
                },
              ),
      AsyncValue(:final error?) => RetryMessage(message: bookingErrorMessage(error), onRetry: onRetry, inline: true),
      _ => const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.red400 : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          side: BorderSide(color: selected ? AppColors.red400 : AppColors.border, width: AppSizes.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: SizedBox(
            height: AppSizes.actionButton,
            child: Center(
              child: Text(label, style: AppText.buttonSmall.copyWith(color: AppColors.text)),
            ),
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: AppText.caption.copyWith(color: AppColors.text3));
}

class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({
    required this.summary,
    required this.price,
    required this.error,
    this.onContactSupport,
    required this.loading,
    required this.onConfirm,
  });

  final String? summary;
  final double? price;
  final String? error;
  final VoidCallback? onContactSupport;
  final bool loading;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.lg,
        AppSpacing.screen,
        AppSpacing.md + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('5. تأكيد', style: AppText.caption.copyWith(color: AppColors.text3)),
                    Text(summary ?? 'اختر الخدمة والوقت', style: AppText.bodyStrong),
                  ],
                ),
              ),
              if (price != null) Text(ArabicFormat.price(price!), style: AppText.h2),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(error!, style: AppText.caption.copyWith(color: AppColors.danger)),
            if (onContactSupport != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: AppButton(
                  label: 'تواصل مع الدعم',
                  variant: AppButtonVariant.text,
                  compact: true,
                  onPressed: onContactSupport,
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.md),
          AppButton(label: 'تأكيد الحجز', onPressed: onConfirm, loading: loading),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'الدفع نقداً في الصالون · الإلغاء متاح حتى ${ArabicFormat.hours(AppConstants.cancellationWindow.inHours)} قبل الموعد',
            style: AppText.caption.copyWith(color: AppColors.text3),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
