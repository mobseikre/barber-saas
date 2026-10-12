import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import 'today_bookings_provider.dart';

Future<void> showManualBookingSheet(BuildContext context) {
  return showAppBottomSheet<void>(context: context, builder: (_) => const _ManualBookingSheet());
}

class _ManualBookingSheet extends ConsumerStatefulWidget {
  const _ManualBookingSheet();

  @override
  ConsumerState<_ManualBookingSheet> createState() => _ManualBookingSheetState();
}

class _ManualBookingSheetState extends ConsumerState<_ManualBookingSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  BarberService? _service;
  DateTime _startsAt = AppTime.nextQuarterHour(AppTime.now());
  var _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _startsAt.hour, minute: _startsAt.minute),
    );
    if (picked != null) setState(() => _startsAt = AppTime.at(_startsAt, picked.hour, picked.minute));
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate() || _service == null) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(todayBookingsProvider.notifier)
          .addManual(serviceId: _service!.serviceId, startsAt: _startsAt, customerName: _name.text.trim());
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = bookingErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(barberServicesProvider);
    final noServices = services.value?.isEmpty ?? false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.screen),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('إضافة حجز يدوي', style: AppText.h2),
            Text('لزبون حضر بدون التطبيق أو اتصل بك', style: AppText.caption.copyWith(color: AppColors.text3)),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'اسم الزبون',
              required: true,
              controller: _name,
              hint: 'مثال: يوسف المصراتي',
              maxLength: AppConstants.customerNameMaxLength,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'أدخل اسم الزبون' : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            const FieldLabel('الخدمة', required: true),
            const SizedBox(height: AppSpacing.sm),
            services.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => RetryMessage(
                inline: true,
                message: bookingErrorMessage(e),
                onRetry: () => ref.invalidate(barberServicesProvider),
              ),
              data: (list) => list.isEmpty
                  ? Text(
                      'فعّل خدماتك أولاً من تبويب الخدمات لتتمكن من إضافة حجز',
                      style: AppText.caption.copyWith(color: AppColors.text3),
                    )
                  : DropdownButtonFormField<BarberService>(
                      initialValue: _service,
                      isExpanded: true,
                      hint: const Text('اختر الخدمة'),
                      items: [
                        for (final s in list)
                          DropdownMenuItem(
                            value: s,
                            child: Text(
                              '${s.nameAr ?? ''} · ${ArabicFormat.price(s.price)} · ${ArabicFormat.minutes(s.durationMin)}',
                              style: AppText.body,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (s) => setState(() => _service = s),
                      validator: (s) => s == null ? 'اختر الخدمة' : null,
                    ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const FieldLabel('الوقت', required: true),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: _pickTime,
              icon: const Icon(Icons.schedule_rounded),
              label: Text(ArabicFormat.time(_startsAt)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border, width: AppSizes.border),
                alignment: AlignmentDirectional.centerStart,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!, style: AppText.caption.copyWith(color: AppColors.danger)),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'إضافة الحجز',
              variant: AppButtonVariant.accent,
              onPressed: noServices || services.hasError ? null : _submit,
              loading: _loading,
            ),
          ],
        ),
      ),
    );
  }
}
