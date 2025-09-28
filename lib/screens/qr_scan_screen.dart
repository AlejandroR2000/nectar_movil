import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerScreen extends StatefulWidget {
  final Function(String) onScan;

  const QrScannerScreen({super.key, required this.onScan});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool _scanned = false;

  @override
  void initState() {
    super.initState();
  }

  void _handleScan(String value) {
    if (_scanned) return;
    _scanned = true;
    widget.onScan(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear QR')),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              final barcode = capture.barcodes.first;
              if (barcode.rawValue != null) {
                _handleScan(barcode.rawValue!);
              }
            },
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final double width = 250;
              final double height = 250;
              final double left = (constraints.maxWidth - width) / 2;
              final double top = (constraints.maxHeight - height) / 2;
              return CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _ScannerOverlayPainter(
                  rect: Rect.fromLTWH(left, top, width, height),
                  borderRadius: 16,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final Rect rect;
  final double borderRadius;

  _ScannerOverlayPainter({required this.rect, required this.borderRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.5);
    canvas.drawRect(Offset.zero & size, paint);

    final clearPaint = Paint()..blendMode = BlendMode.clear;
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(borderRadius)),
      clearPaint,
    );
    canvas.restore();

    final borderPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(borderRadius)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
