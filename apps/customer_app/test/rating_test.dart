import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';
import 'package:test_support/test_support.dart';

import 'package:customer_app/features/bookings/my_bookings_tab.dart';
import 'package:customer_app/features/bookings/rating_screen.dart';

import 'support/fakes.dart';

void main() {
  useTestClock(testNow);

  late TestDeps deps;

  Future<void> openRating(WidgetTester tester) async {
    deps = TestDeps(auth: FakeAuthRepo(userId: 'customer-1'));
    deps.myBookings.items = [
      myBooking(id: 'done', startsIn: const Duration(days: -11), status: BookingStatus.completed),
    ];
    await pumpPhone(tester, deps.app(const Scaffold(body: MyBookingsTab())));
    await tapVisible(tester, find.text('السابقة'));
    await tapVisible(tester, find.text('قيّم'));
  }

  Finder star(String label) => find.byTooltip(label);

  Future<void> send(WidgetTester tester) => tapVisible(tester, find.widgetWithText(FilledButton, 'إرسال التقييم'));

  testWidgets('the screen shows the visit and cannot be sent before choosing stars', (tester) async {
    await openRating(tester);

    expect(find.text('كيف كانت زيارتك؟'), findsOneWidget);
    expect(find.text('صالون الأناقة · قص شعر · الخميس، 1 أكتوبر'), findsOneWidget);
    expect(find.text('اختر تقييمك'), findsOneWidget);
    for (final tag in ratingTags) {
      expect(find.text(tag), findsOneWidget);
    }
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'إرسال التقييم')).onPressed, isNull);
  });

  testWidgets('each star names its rating and the last tap wins', (tester) async {
    await openRating(tester);

    for (var i = 0; i < ratingLabels.length; i++) {
      await tapVisible(tester, star(ratingLabels[i]));
      expect(find.text(ratingLabels[i]), findsOneWidget);
    }
    await tapVisible(tester, star('جيد'));

    expect(find.text('جيد'), findsOneWidget);
    expect(find.text('ممتاز'), findsNothing);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'إرسال التقييم')).onPressed, isNotNull);
  });

  testWidgets('sending stores the stars, the chosen tags in order and the trimmed comment, then the list shows it', (
    tester,
  ) async {
    await openRating(tester);

    await tapVisible(tester, star('جيد جداً'));
    await tapVisible(tester, find.text('النظافة'));
    await tapVisible(tester, find.text('جودة القص'));
    await tapVisible(tester, find.text('السعر مناسب'));
    await tapVisible(tester, find.text('السعر مناسب'));
    await tester.enterText(find.byType(TextField), '  قص ممتاز  ');
    await send(tester);

    final review = deps.myBookings.reviews.single;
    expect(review.bookingId, 'done');
    expect(review.rating, 4);
    expect(review.tags, ['جودة القص', 'النظافة']);
    expect(review.comment, 'قص ممتاز');
    expect(find.text('شكراً لتقييمك'), findsOneWidget);
    expect(find.text('كيف كانت زيارتك؟'), findsNothing);
    expect(find.text('قيّم'), findsNothing, reason: 'a booking is rated once');
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('tags and comment are optional', (tester) async {
    await openRating(tester);

    await tapVisible(tester, star('ممتاز'));
    await send(tester);

    final review = deps.myBookings.reviews.single;
    expect(review.rating, 5);
    expect(review.tags, isEmpty);
    expect(review.comment, isNull);
  });

  testWidgets('the comment stops at the limit', (tester) async {
    await openRating(tester);

    await tester.enterText(find.byType(TextField), 'ا' * (AppConstants.reviewCommentMaxLength + 20));

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text.length,
      AppConstants.reviewCommentMaxLength,
    );
  });

  testWidgets('a review that already exists is explained and the screen stays open', (tester) async {
    await openRating(tester);
    deps.myBookings.reviewError = const PostgrestException(message: 'duplicate', code: '23505');

    await tapVisible(tester, star('جيد'));
    await send(tester);

    expect(find.text('قيّمت هذا الحجز مسبقاً'), findsOneWidget);
    expect(find.text('كيف كانت زيارتك؟'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'إرسال التقييم')).onPressed, isNotNull);
  });

  testWidgets('a network failure keeps the input and allows another try', (tester) async {
    await openRating(tester);
    deps.myBookings.reviewError = Exception('offline');

    await tapVisible(tester, star('جيد'));
    await tester.enterText(find.byType(TextField), 'رأيي');
    await send(tester);
    expect(find.text(genericErrorMessage), findsOneWidget);

    deps.myBookings.reviewError = null;
    await send(tester);

    expect(deps.myBookings.reviews.single.comment, 'رأيي');
    expect(find.text('كيف كانت زيارتك؟'), findsNothing);
  });

  testWidgets('لاحقاً and the close button leave without sending', (tester) async {
    await openRating(tester);
    await tapVisible(tester, find.text('لاحقاً'));
    expect(find.text('كيف كانت زيارتك؟'), findsNothing);
    expect(find.text('قيّم'), findsOneWidget);

    await tapVisible(tester, find.text('قيّم'));
    await tapVisible(tester, find.byTooltip('إغلاق'));

    expect(find.text('كيف كانت زيارتك؟'), findsNothing);
    expect(deps.myBookings.reviews, isEmpty);
  });

  testWidgets('with the keyboard open the send button stays pinned and the comment stays in view', (tester) async {
    await openRating(tester);
    await tapVisible(tester, star('ممتاز'));
    const keyboard = 300.0;

    await tester.showKeyboard(find.byType(TextField));
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
    await tester.pumpAndSettle();

    final visibleBottom = tester.view.physicalSize.height / tester.view.devicePixelRatio - keyboard;
    final send = tester.getRect(find.widgetWithText(FilledButton, 'إرسال التقييم'));
    final comment = tester.getRect(find.byType(TextField));
    expect(send.bottom, lessThanOrEqualTo(visibleBottom));
    final firstLine = AppText.body.fontSize! * AppText.body.height!;
    expect(comment.top, greaterThanOrEqualTo(0));
    expect(comment.top + firstLine, lessThanOrEqualTo(send.top), reason: 'the line being typed stays above the button');
  });

  testWidgets('a check the server refuses is explained by its constraint', (tester) async {
    await openRating(tester);
    deps.myBookings.reviewError = const PostgrestException(
      message: 'new row for relation "reviews" violates check constraint "reviews_tags_allowed"',
      code: '23514',
    );

    await tapVisible(tester, star('جيد'));
    await send(tester);

    expect(find.text('أحد الوسوم المختارة غير متاح، حدّث الصفحة وحاول مرة أخرى'), findsOneWidget);
  });
}
