import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared/shared.dart';

import '../../providers.dart';
import 'qr_sticker.dart';

/// The barber's QR code: customers scan it to open the barber's page in the customer app.
class QrScreen extends ConsumerStatefulWidget {
  const QrScreen({super.key});

  @override
  ConsumerState<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends ConsumerState<QrScreen> {
  var _sharing = false;

  Future<void> _share(Barber barber, Salon salon) async {
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final pdf = await buildQrSticker(
        barberName: barber.displayName,
        salonName: salon.name,
        link: barberLink(barber.id),
      );
      await ref.read(stickerSharerProvider).share(pdf, 'hallaqi-qr.pdf');
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('تعذّر تجهيز الملصق، حاول مرة أخرى')));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final barber = ref.watch(currentBarberProvider);
    final salon = ref.watch(currentSalonProvider);
    final error = barber.error ?? salon.error;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xxxl),
        children: [
          const PageTitle(
            title: 'رمز QR',
            subtitle: 'يمسحه زبائنك ليفتحوا صفحتك ويحجزوا مباشرة',
            leading: AppBackButton(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            child: switch ((barber.value, salon.value)) {
              _ when error != null => RetryMessage(
                message: authErrorMessage(error),
                onRetry: () {
                  ref.invalidate(currentBarberProvider);
                  ref.invalidate(currentSalonProvider);
                },
              ),
              (final Barber b, final Salon s) => _Content(
                barber: b,
                salon: s,
                sharing: _sharing,
                onShare: () => _share(b, s),
              ),
              _ => const Padding(
                padding: EdgeInsets.only(top: AppSpacing.xxxl * 3),
                child: Center(child: CircularProgressIndicator()),
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.barber, required this.salon, required this.sharing, required this.onShare});

  final Barber barber;
  final Salon salon;
  final bool sharing;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final link = barberLink(barber.id).toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            children: [
              QrImageView(
                key: ValueKey(link),
                data: link,
                size: 220,
                padding: EdgeInsets.zero,
                semanticsLabel: 'رمز QR لصفحة ${barber.displayName}',
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.blue900),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppColors.blue900,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(barber.displayName, style: AppText.h2, textAlign: TextAlign.center),
              Text(
                salon.name,
                style: AppText.caption.copyWith(color: AppColors.text3),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'اطبع الملصق بحجم A5 وضعه عند المرآة أو على باب الصالون.',
          style: AppText.caption.copyWith(color: AppColors.text2),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(label: 'مشاركة الملصق PDF', icon: Icons.ios_share_rounded, loading: sharing, onPressed: onShare),
      ],
    );
  }
}
