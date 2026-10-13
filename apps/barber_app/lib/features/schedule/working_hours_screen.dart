import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../providers.dart';
import 'break_sheet.dart';
import 'time_chip.dart';

const _weekOrder = [6, 0, 1, 2, 3, 4, 5];
const _friday = 5;
const _defaultOpen = TimeOfDay(hour: 10, minute: 0);
const _defaultClose = TimeOfDay(hour: 22, minute: 0);

class _Day {
  _Day(this.weekday, WorkingHours? saved)
    : open = saved == null ? weekday != _friday : !saved.isClosed,
      opens = saved?.opensAt ?? _defaultOpen,
      closes = saved?.closesAt ?? _defaultClose;

  final int weekday;
  bool open;
  TimeOfDay opens;
  TimeOfDay closes;

  bool get valid => !open || isAfter(closes, opens);
}

/// Opening hours for each day of the week, days off and breaks.
class WorkingHoursScreen extends ConsumerStatefulWidget {
  const WorkingHoursScreen({super.key});

  @override
  ConsumerState<WorkingHoursScreen> createState() => _WorkingHoursScreenState();
}

class _WorkingHoursScreenState extends ConsumerState<WorkingHoursScreen> {
  List<_Day>? _days;
  List<Break>? _breaks;
  var _submitted = false;
  var _saving = false;

  Future<void> _editBreak({Break? existing}) async {
    final barber = await ref.read(currentBarberProvider.future);
    if (!mounted || barber == null) return;
    final result = await showBreakSheet(context, barberId: barber.id, existing: existing);
    if (result == null) return;
    setState(() {
      final list = _breaks!;
      if (result.delete) {
        list.remove(existing);
      } else if (existing == null) {
        list.add(result.save!);
      } else {
        list[list.indexOf(existing)] = result.save!;
      }
    });
  }

  Future<void> _save() async {
    final days = _days!;
    setState(() => _submitted = true);
    if (days.any((d) => !d.valid)) return;

    setState(() => _saving = true);
    try {
      final barber = await ref.read(currentBarberProvider.future);
      final repo = ref.read(barberRepositoryProvider);
      await repo.saveSchedule(
        barberId: barber!.id,
        hours: [
          for (final d in days)
            WorkingHours(
              barberId: barber.id,
              weekday: d.weekday,
              opensAt: d.valid ? d.opens : _defaultOpen,
              closesAt: d.valid ? d.closes : _defaultClose,
              isClosed: !d.open,
            ),
        ],
        breaks: _breaks!,
      );
      final saved = await repo.breaksOf(barber.id);
      ref.invalidate(workingHoursProvider);
      ref.invalidate(breaksProvider);
      if (mounted) {
        setState(() => _breaks = saved);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ أوقات العمل')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(bookingErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hours = ref.watch(workingHoursProvider);
    final breaks = ref.watch(breaksProvider);
    if (_days == null && hours.hasValue && breaks.hasValue) {
      final saved = {for (final h in hours.value!) h.weekday: h};
      _days = [for (final w in _weekOrder) _Day(w, saved[w])];
      _breaks = List.of(breaks.value!);
    }
    final days = _days;
    final failed = days == null && (hours.hasError || breaks.hasError);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: Column(
        children: [
          const PageTitle(title: 'أوقات العمل', subtitle: 'حدد ساعات كل يوم وأيام العطلة', leading: AppBackButton()),
          if (days == null && !failed) const Expanded(child: Center(child: CircularProgressIndicator())),
          if (failed)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.screen),
                  child: RetryMessage(
                    message: genericErrorMessage,
                    onRetry: () {
                      ref.invalidate(workingHoursProvider);
                      ref.invalidate(breaksProvider);
                    },
                  ),
                ),
              ),
            ),
          if (days != null) ...[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
                children: [
                  for (final day in days) ...[
                    _DayCard(day: day, submitted: _submitted, onChanged: () => setState(() {})),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  _BreaksCard(
                    breaks: _breaks!,
                    onAdd: _editBreak,
                    onEdit: (b) => _editBreak(existing: b),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.sm,
                AppSpacing.screen,
                bottomInset + AppSpacing.lg,
              ),
              child: AppButton(label: 'حفظ أوقات العمل', loading: _saving, onPressed: _save),
            ),
          ],
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.submitted, required this.onChanged});

  final _Day day;
  final bool submitted;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final showError = submitted && !day.valid;
    final muted = AppText.cardTitle.copyWith(color: day.open ? AppColors.text : AppColors.text3);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.card, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: day.open ? AppColors.surface : AppColors.blue100,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: showError ? Border.all(color: AppColors.danger, width: AppSizes.border) : null,
        boxShadow: day.open ? const [AppColors.cardShadow] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppSwitch(
                key: ValueKey('open-${day.weekday}'),
                value: day.open,
                semanticLabel: ArabicFormat.weekdays[day.weekday],
                onChanged: (v) {
                  day.open = v;
                  onChanged();
                },
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(ArabicFormat.weekdays[day.weekday]!, style: muted)),
              if (day.open) ...[
                TimeChip(
                  key: ValueKey('opens-${day.weekday}'),
                  time: day.opens,
                  onChanged: (t) {
                    day.opens = t;
                    onChanged();
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Text('إلى', style: AppText.caption.copyWith(color: AppColors.text3)),
                ),
                TimeChip(
                  key: ValueKey('closes-${day.weekday}'),
                  time: day.closes,
                  onChanged: (t) {
                    day.closes = t;
                    onChanged();
                  },
                ),
              ] else
                Text('يوم عطلة', style: AppText.caption.copyWith(color: AppColors.text3)),
            ],
          ),
          if (showError)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'وقت الإغلاق يجب أن يكون بعد وقت الفتح',
                style: AppText.caption.copyWith(color: AppColors.danger),
              ),
            ),
        ],
      ),
    );
  }
}

class _BreaksCard extends StatelessWidget {
  const _BreaksCard({required this.breaks, required this.onAdd, required this.onEdit});

  final List<Break> breaks;
  final VoidCallback onAdd;
  final ValueChanged<Break> onEdit;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.coffee_outlined, color: AppColors.red700),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('الاستراحات', style: AppText.cardTitle)),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: AppSizes.iconMd),
                label: const Text('إضافة'),
              ),
            ],
          ),
          if (breaks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text('لا توجد استراحات', style: AppText.caption.copyWith(color: AppColors.text3)),
            ),
          for (final b in breaks)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: InkWell(
                onTap: () => onEdit(b),
                borderRadius: BorderRadius.circular(AppRadius.control),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.red50,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(b.name, style: AppText.body.copyWith(color: AppColors.text2)),
                      ),
                      Text(
                        '${ArabicFormat.clock(b.startsAt.hour, b.startsAt.minute)} — ${ArabicFormat.clock(b.endsAt.hour, b.endsAt.minute)}',
                        style: AppText.weight(AppText.caption.copyWith(color: AppColors.text), FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
