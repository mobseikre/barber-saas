import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

/// Search field that picks an existing salon; what the barber types names a new one.
class SalonPicker extends ConsumerStatefulWidget {
  const SalonPicker({super.key, required this.selected, required this.onChanged, this.onNameChanged});

  final Salon? selected;
  final ValueChanged<Salon?> onChanged;
  final ValueChanged<String>? onNameChanged;

  @override
  ConsumerState<SalonPicker> createState() => _SalonPickerState();
}

class _SalonPickerState extends ConsumerState<SalonPicker> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<Salon> _results = const [];
  var _searching = false;
  String? _latest;
  String? _searched;
  var _failed = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    widget.onNameChanged?.call(text.trim());
    _debounce?.cancel();
    if (widget.selected != null) widget.onChanged(null);
    if (text.trim().length < 2) {
      setState(() {
        _latest = null;
        _searched = null;
        _failed = false;
        _searching = false;
        _results = const [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(text.trim()));
  }

  Future<void> _search(String text) async {
    _latest = text;
    setState(() {
      _searching = true;
      _failed = false;
    });
    List<Salon>? rows;
    try {
      rows = await ref.read(barberRepositoryProvider).searchSalons(text);
    } catch (_) {
      rows = null;
    }
    if (!mounted || text != _latest) return;
    setState(() {
      _searching = false;
      _searched = text;
      _failed = rows == null;
      _results = rows ?? const [];
    });
  }

  void _select(Salon salon) {
    _query.text = salon.name;
    widget.onNameChanged?.call(salon.name);
    setState(() {
      _latest = null;
      _searched = null;
      _results = const [];
    });
    widget.onChanged(salon);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('الصالون الذي تعمل فيه'),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _query,
          onChanged: _onChanged,
          inputFormatters: [LengthLimitingTextInputFormatter(AppConstants.salonNameMaxLength)],
          style: AppText.body,
          decoration: InputDecoration(
            hintText: 'ابحث عن صالونك أو أضف جديداً',
            prefixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.card),
                    child: SizedBox(
                      width: AppSizes.iconMd,
                      height: AppSizes.iconMd,
                      child: CircularProgressIndicator(strokeWidth: AppSizes.spinnerStroke),
                    ),
                  )
                : Icon(
                    widget.selected != null ? Icons.check_circle_rounded : Icons.search_rounded,
                    color: widget.selected != null ? AppColors.success : AppColors.text3,
                  ),
          ),
        ),
        if (_results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                for (final salon in _results)
                  ListTile(
                    dense: true,
                    leading: LetterAvatar(name: salon.name, size: AppSizes.avatarSmall, radius: AppRadius.badge),
                    title: Text(salon.name, style: AppText.bodyStrong),
                    onTap: () => _select(salon),
                  ),
              ],
            ),
          ),
        if (_failed)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              'تعذّر البحث، تأكد من الاتصال وحاول مرة أخرى',
              style: AppText.caption.copyWith(color: AppColors.danger),
            ),
          )
        else if (_searched != null && _results.isEmpty && widget.selected == null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              'لا يوجد صالون بهذا الاسم، سيُنشأ صالون جديد باسم «$_searched»',
              style: AppText.caption.copyWith(color: AppColors.text2),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'إذا كان صالونك مسجلاً فاختره لتظهر ضمن حلاقيه، وإلا اكتب اسمه ليُنشأ صالون جديد.',
          style: AppText.caption.copyWith(color: AppColors.text3),
        ),
      ],
    );
  }
}
