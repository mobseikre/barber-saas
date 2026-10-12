import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../providers.dart';

const _vipServiceCode = 'vip';

class _ServiceRow {
  _ServiceRow(this.item, this.saved)
    : enabled = saved?.isEnabled ?? false,
      price = TextEditingController(text: saved == null ? '' : _plain(saved.price)),
      duration = TextEditingController(text: '${saved?.durationMin ?? item.defaultDurationMin}');

  final ServiceCatalogItem item;
  BarberService? saved;
  bool enabled;
  final TextEditingController price;
  final TextEditingController duration;

  static String _plain(double value) => value == value.roundToDouble() ? '${value.toInt()}' : '$value';

  double? get priceValue => double.tryParse(latinDigits(price.text.trim()));
  int? get durationValue => int.tryParse(latinDigits(duration.text.trim()));
  bool get priceValid => priceValue != null && priceValue! >= 0;
  bool get durationValid => durationValue != null && durationValue! > 0;

  void dispose() {
    price.dispose();
    duration.dispose();
  }
}

/// The barber's services: which ones they offer, at what price and for how long.
class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key, this.showBack = false});

  final bool showBack;

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  List<_ServiceRow>? _rows;
  var _submitted = false;
  var _saving = false;

  @override
  void dispose() {
    for (final row in _rows ?? const <_ServiceRow>[]) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final rows = _rows!;
    setState(() => _submitted = true);
    if (rows.any((r) => r.enabled && !(r.priceValid && r.durationValid))) return;

    setState(() => _saving = true);
    try {
      final barber = await ref.read(currentBarberProvider.future);
      final payload = [
        for (final r in rows)
          if (r.enabled || r.saved != null)
            BarberService(
              barberId: barber!.id,
              serviceId: r.item.id,
              price: r.priceValid ? r.priceValue! : (r.saved?.price ?? 0),
              durationMin: r.durationValid ? r.durationValue! : (r.saved?.durationMin ?? r.item.defaultDurationMin),
              isEnabled: r.enabled,
            ),
      ];
      await ref.read(barberRepositoryProvider).saveServices(payload);
      for (final s in payload) {
        rows.firstWhere((r) => r.item.id == s.serviceId).saved = s;
      }
      ref.invalidate(allBarberServicesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الخدمات')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(bookingErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(serviceCatalogProvider);
    final mine = ref.watch(allBarberServicesProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    if (_rows == null && catalog.hasValue && mine.hasValue) {
      final saved = {for (final s in mine.value!) s.serviceId: s};
      _rows = [for (final item in catalog.value!) _ServiceRow(item, saved[item.id])];
    }
    final rows = _rows;
    final failed = rows == null && (catalog.hasError || mine.hasError);
    final invalid = _submitted && (rows ?? const []).any((r) => r.enabled && !(r.priceValid && r.durationValid));

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageTitle(
            title: 'خدماتي',
            subtitle: 'فعّل الخدمات التي تقدمها وحدد السعر والمدة',
            leading: widget.showBack ? const AppBackButton() : null,
            trailing: rows == null ? null : AppButton(label: 'حفظ', compact: true, loading: _saving, onPressed: _save),
          ),
          if (rows == null && !failed) const Expanded(child: Center(child: CircularProgressIndicator())),
          if (failed)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.screen),
                  child: RetryMessage(
                    message: genericErrorMessage,
                    onRetry: () {
                      ref.invalidate(serviceCatalogProvider);
                      ref.invalidate(allBarberServicesProvider);
                    },
                  ),
                ),
              ),
            ),
          if (rows != null) ...[
            const _ColumnLabels(),
            if (invalid)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.sm),
                child: Text(
                  'أدخل السعر والمدة للخدمات المفعّلة',
                  style: AppText.caption.copyWith(color: AppColors.danger),
                ),
              ),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.xs,
                  AppSpacing.screen,
                  bottomInset + (widget.showBack ? AppSpacing.xxl : AppSizes.bottomNav + AppSpacing.xxxl),
                ),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.cardGap),
                itemBuilder: (_, i) =>
                    _ServiceCard(row: rows[i], submitted: _submitted, onChanged: () => setState(() {})),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ColumnLabels extends StatelessWidget {
  const _ColumnLabels();

  @override
  Widget build(BuildContext context) {
    final style = AppText.label.copyWith(color: AppColors.text3);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen + AppSpacing.card,
        0,
        AppSpacing.screen + AppSpacing.card,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          SizedBox(
            width: AppSizes.switchWidth,
            child: Text('تفعيل', style: style),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text('الخدمة', style: style)),
          SizedBox(
            width: AppSizes.numberBox,
            child: Center(child: Text('السعر', style: style)),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: AppSizes.numberBox,
            child: Center(child: Text('المدة', style: style)),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.row, required this.submitted, required this.onChanged});

  final _ServiceRow row;
  final bool submitted;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final code = row.item.code;
    final muted = AppText.cardTitle.copyWith(color: row.enabled ? AppColors.text : AppColors.text3);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.card),
      decoration: BoxDecoration(
        color: row.enabled ? AppColors.surface : AppColors.blue100,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: row.enabled ? const [AppColors.cardShadow] : null,
      ),
      child: Row(
        children: [
          AppSwitch(
            key: ValueKey('switch-$code'),
            value: row.enabled,
            semanticLabel: row.item.nameAr,
            onChanged: (v) {
              row.enabled = v;
              onChanged();
            },
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(row.item.nameAr, style: muted, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (code == _vipServiceCode) ...[const SizedBox(width: AppSpacing.sm), const VipBadge()],
                  ],
                ),
                if (row.item.descriptionAr != null)
                  Text(
                    row.item.descriptionAr!,
                    style: AppText.caption.copyWith(color: AppColors.text3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          _NumberBox(
            key: ValueKey('price-$code'),
            controller: row.price,
            unit: 'د.ل',
            enabled: row.enabled,
            error: submitted && row.enabled && !row.priceValid,
            decimal: true,
          ),
          const SizedBox(width: AppSpacing.sm),
          _NumberBox(
            key: ValueKey('duration-$code'),
            controller: row.duration,
            unit: 'دقيقة',
            enabled: row.enabled,
            error: submitted && row.enabled && !row.durationValid,
          ),
        ],
      ),
    );
  }
}

class _NumberBox extends StatelessWidget {
  const _NumberBox({
    super.key,
    required this.controller,
    required this.unit,
    required this.enabled,
    required this.error,
    this.decimal = false,
  });

  final TextEditingController controller;
  final String unit;
  final bool enabled;
  final bool error;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    final valueStyle = AppText.weight(
      AppText.bodyStrong.copyWith(color: enabled ? AppColors.text : AppColors.text3),
      FontWeight.w800,
    );
    return Container(
      width: AppSizes.numberBox,
      height: AppSizes.actionButton,
      decoration: BoxDecoration(
        color: enabled ? AppColors.surface : AppColors.blue100,
        borderRadius: BorderRadius.circular(AppRadius.smallButton),
        border: Border.all(color: error ? AppColors.danger : AppColors.border, width: AppSizes.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: AppSpacing.xl,
            child: TextField(
              controller: controller,
              enabled: enabled,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.numberWithOptions(decimal: decimal),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9٠-٩.]' : r'[0-9٠-٩]'))],
              style: valueStyle,
              decoration: const InputDecoration(
                filled: false,
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          Text(unit, style: AppText.label.copyWith(color: AppColors.text3)),
        ],
      ),
    );
  }
}
