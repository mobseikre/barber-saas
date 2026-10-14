import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

import 'time_chip.dart';

typedef BreakResult = ({Break? save, bool delete});

const _defaultStart = TimeOfDay(hour: 13, minute: 30);
const _defaultEnd = TimeOfDay(hour: 14, minute: 30);

/// Adds, edits or deletes a break. Returns null when dismissed.
Future<BreakResult?> showBreakSheet(BuildContext context, {required String barberId, Break? existing}) {
  return showAppBottomSheet<BreakResult>(
    context: context,
    builder: (_) => _BreakSheet(barberId: barberId, existing: existing),
  );
}

class _BreakSheet extends StatefulWidget {
  const _BreakSheet({required this.barberId, this.existing});

  final String barberId;
  final Break? existing;

  @override
  State<_BreakSheet> createState() => _BreakSheetState();
}

class _BreakSheetState extends State<_BreakSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late var _start = widget.existing?.startsAt ?? _defaultStart;
  late var _end = widget.existing?.endsAt ?? _defaultEnd;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'أدخل اسم الاستراحة');
      return;
    }
    if (!isAfter(_end, _start)) {
      setState(() => _error = 'وقت نهاية الاستراحة يجب أن يكون بعد بدايتها');
      return;
    }
    Navigator.of(context).pop((
      save: Break(
        id: widget.existing?.id,
        barberId: widget.barberId,
        weekday: widget.existing?.weekday,
        name: _name.text.trim(),
        startsAt: _start,
        endsAt: _end,
      ),
      delete: false,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.screen),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(editing ? 'تعديل الاستراحة' : 'إضافة استراحة', style: AppText.h2),
          Text('تُطبّق على كل أيام العمل', style: AppText.caption.copyWith(color: AppColors.text3)),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(label: 'الاسم', required: true, controller: _name, hint: 'مثال: غداء وصلاة'),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Text('من', style: AppText.caption.copyWith(color: AppColors.text3)),
              const SizedBox(width: AppSpacing.sm),
              TimeChip(time: _start, onChanged: (t) => setState(() => _start = t)),
              const SizedBox(width: AppSpacing.lg),
              Text('إلى', style: AppText.caption.copyWith(color: AppColors.text3)),
              const SizedBox(width: AppSpacing.sm),
              TimeChip(time: _end, onChanged: (t) => setState(() => _end = t)),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: AppText.caption.copyWith(color: AppColors.danger)),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppButton(label: editing ? 'حفظ' : 'إضافة', onPressed: _save),
          if (editing) ...[
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop((save: null, delete: true)),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('حذف الاستراحة'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
