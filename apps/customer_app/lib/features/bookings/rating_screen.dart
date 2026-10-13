import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

import '../../data/my_bookings_repository.dart';
import '../../providers.dart';
import '../../widgets/app_chip.dart';

const ratingLabels = ['سيئ', 'مقبول', 'جيد', 'جيد جداً', 'ممتاز'];
const ratingTags = AppConstants.reviewTags;

/// Rates a completed booking and refreshes the list once the review is sent.
Future<void> rateBooking(BuildContext context, WidgetRef ref, MyBooking item) async {
  final messenger = ScaffoldMessenger.of(context);
  final sent = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => RatingScreen(item: item)));
  if (sent != true || !context.mounted) return;
  ref.invalidate(myBookingsProvider);
  messenger.showSnackBar(const SnackBar(content: Text('شكراً لتقييمك')));
}

class RatingScreen extends ConsumerStatefulWidget {
  const RatingScreen({super.key, required this.item});

  final MyBooking item;

  @override
  ConsumerState<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends ConsumerState<RatingScreen> {
  final _comment = TextEditingController();
  final _tags = <String>{};
  var _rating = 0;
  var _sending = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || _rating == 0) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(myBookingsRepositoryProvider)
          .submitReview(
            customerId: userId,
            bookingId: widget.item.booking.id,
            rating: _rating,
            tags: [
              for (final t in ratingTags)
                if (_tags.contains(t)) t,
            ],
            comment: _comment.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = reviewErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final subtitle = [
      item.salonName,
      if (item.booking.serviceName != null) item.booking.serviceName!,
      ArabicFormat.dayDate(item.booking.startsAt),
    ].join(' · ');
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screen),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: SquareIconButton(
                        icon: Icons.close_rounded,
                        tooltip: 'إغلاق',
                        outlined: true,
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.red400, width: AppSizes.ring),
                        ),
                        child: LetterAvatar(name: item.salonName, size: AppSizes.avatarTile),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text('كيف كانت زيارتك؟', style: AppText.h1, textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: AppText.caption.copyWith(color: AppColors.text3),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var star = 1; star <= ratingLabels.length; star++)
                          IconButton(
                            onPressed: _sending ? null : () => setState(() => _rating = star),
                            tooltip: ratingLabels[star - 1],
                            iconSize: AppSizes.avatar,
                            icon: Icon(
                              Icons.star_rounded,
                              color: star <= _rating ? AppColors.red400 : AppColors.switchOff,
                              semanticLabel: ratingLabels[star - 1],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _rating == 0 ? 'اختر تقييمك' : ratingLabels[_rating - 1],
                      style: AppText.cardTitle.copyWith(color: _rating == 0 ? AppColors.text3 : AppColors.red700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Text('ما الذي أعجبك؟', style: AppText.cardTitle),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final tag in ratingTags)
                          SizedBox(
                            height: AppSizes.cardButton,
                            child: AppChip(
                              label: tag,
                              selected: _tags.contains(tag),
                              onTap: () => setState(() => _tags.contains(tag) ? _tags.remove(tag) : _tags.add(tag)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Text.rich(
                      TextSpan(
                        text: 'تعليقك ',
                        style: AppText.inputLabel,
                        children: [
                          TextSpan(
                            text: '(اختياري)',
                            style: AppText.caption.copyWith(color: AppColors.text3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _comment,
                      minLines: 4,
                      maxLines: 6,
                      style: AppText.body,
                      inputFormatters: [LengthLimitingTextInputFormatter(AppConstants.reviewCommentMaxLength)],
                      decoration: const InputDecoration(hintText: 'اكتب رأيك في الخدمة ليستفيد منه غيرك'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(_error!, style: AppText.caption.copyWith(color: AppColors.danger)),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, AppSpacing.sm, AppSpacing.screen, AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppButton(label: 'إرسال التقييم', loading: _sending, onPressed: _rating == 0 ? null : _submit),
                  AppButton(
                    label: 'لاحقاً',
                    variant: AppButtonVariant.text,
                    onPressed: _sending ? null : () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
