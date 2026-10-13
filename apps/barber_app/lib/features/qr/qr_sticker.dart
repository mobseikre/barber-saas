import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared/shared.dart';

PdfColor _pdf(Color c) => PdfColor.fromInt(c.toARGB32());

const _margin = 32.0;
final _contentWidth = PdfPageFormat.a5.width - 2 * _margin;

/// Pixels per PDF point for the text images: 5 × 72 = 360 dpi.
const _scale = 5.0;

/// A printable A5 sticker: the barber's name, salon and the QR code of their page in the customer app.
Future<Uint8List> buildQrSticker({required String barberName, required String salonName, required Uri link}) async {
  final (brand, title, name, salon, hint) = await (
    _text('حلّاقي', AppText.weight(AppText.h2, FontWeight.w800).copyWith(color: AppColors.red400)),
    _text('احجز موعدك', AppText.display.copyWith(color: AppColors.surface)),
    _text(barberName, AppText.h1),
    _text(salonName, AppText.h3.copyWith(color: AppColors.text2)),
    _text('امسح الرمز بكاميرا هاتفك لتحجز موعدك', AppText.body.copyWith(color: AppColors.text2)),
  ).wait;

  final doc = pw.Document(title: 'حلّاقي — $barberName');
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Column(
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.fromLTRB(_margin, 36, _margin, _margin),
            decoration: pw.BoxDecoration(
              color: _pdf(AppColors.blue900),
              borderRadius: const pw.BorderRadius.vertical(bottom: pw.Radius.circular(AppRadius.header)),
            ),
            child: pw.Column(children: [brand, title]),
          ),
          // Long names wrap inside the margins and shrink the block rather than push it off the page.
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(_margin),
              child: pw.FittedBox(
                fit: pw.BoxFit.scaleDown,
                child: pw.SizedBox(
                  width: _contentWidth,
                  child: pw.Column(
                    children: [
                      name,
                      salon,
                      pw.SizedBox(height: AppSpacing.xl),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(AppSpacing.lg),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: _pdf(AppColors.border), width: AppSizes.border),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(AppRadius.card)),
                        ),
                        child: pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: link.toString(),
                          width: 200,
                          height: 200,
                          color: _pdf(AppColors.blue900),
                        ),
                      ),
                      pw.SizedBox(height: AppSpacing.lg),
                      hint,
                    ],
                  ),
                ),
              ),
            ),
          ),
          pw.SizedBox(
            height: 24,
            width: double.infinity,
            child: pw.CustomPaint(painter: _poleStripe),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}

/// Lays [text] out with Flutter, so Arabic is shaped and kerned as in the app, and embeds it as an image.
/// The pdf package's own Arabic layout overlaps letter pairs such as ري.
Future<pw.Widget> _text(String text, TextStyle style) async {
  final bleed = style.fontSize! / 2;
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.rtl,
    textAlign: TextAlign.center,
    textWidthBasis: TextWidthBasis.longestLine,
  )..layout(maxWidth: _contentWidth - 2 * bleed);
  final width = painter.width + 2 * bleed;
  final height = painter.height;

  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder)..scale(_scale), Offset(bleed, 0));
  painter.dispose();
  final image = await recorder.endRecording().toImage((width * _scale).ceil(), (height * _scale).ceil());
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return pw.Image(pw.MemoryImage(png!.buffer.asUint8List()), width: width, height: height);
}

/// The barber pole stripe of the design: red 14, white 7, blue 14, white 7, at -45°.
void _poleStripe(PdfGraphics canvas, PdfPoint size) {
  const bands = [
    (AppColors.poleRed, 14.0),
    (AppColors.surface, 7.0),
    (AppColors.poleBlue, 14.0),
    (AppColors.surface, 7.0),
  ];
  canvas
    ..saveContext()
    ..drawRect(0, 0, size.x, size.y)
    ..clipPath();
  for (var x = -size.y; x < size.x + size.y;) {
    for (final (color, width) in bands) {
      canvas
        ..setFillColor(_pdf(color))
        ..moveTo(x, 0)
        ..lineTo(x + width, 0)
        ..lineTo(x + width + size.y, size.y)
        ..lineTo(x + size.y, size.y)
        ..closePath()
        ..fillPath();
      x += width;
    }
  }
  canvas.restoreContext();
}
