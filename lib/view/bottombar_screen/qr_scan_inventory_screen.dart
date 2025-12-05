// lib/view/bottombar_screen/qr_scan_inventory_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScanInventoryScreen extends StatefulWidget {
  const QRScanInventoryScreen({super.key});

  @override
  State<QRScanInventoryScreen> createState() => _QRScanInventoryScreenState();
}

class _QRScanInventoryScreenState extends State<QRScanInventoryScreen> {
  late MobileScannerController cameraController;
  bool _isScanned = false;
  bool _isTorchOn = false;
  bool _isDetecting = false;
  bool _isProcessing = false; // Cooldown flag

  // Animation for glow effect
  double _glowIntensity = 0.0;
  Timer? _glowTimer;

  // Last detection time for cooldown
  DateTime? _lastDetectionTime;
  static const Duration _cooldownDuration = Duration(milliseconds: 2000); // 2s cooldown

  @override
  void initState() {
    super.initState();

    cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      formats: [BarcodeFormat.qrCode, BarcodeFormat.code128, BarcodeFormat.ean13],
      returnImage: false,
    );
  }

  @override
  void dispose() {
    _glowTimer?.cancel();
    cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    // Check if already processing or scanned
    if (_isProcessing || _isDetecting || _isScanned) return;

    // Check cooldown - prevent rapid detection
    final now = DateTime.now();
    if (_lastDetectionTime != null) {
      final timeSinceLastDetection = now.difference(_lastDetectionTime!);
      if (timeSinceLastDetection < _cooldownDuration) {
        // Still in cooldown period, ignore this detection
        return;
      }
    }

    final code = capture.barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    // Mark as processing and update last detection time
    setState(() {
      _isProcessing = true;
      _isDetecting = true;
      _lastDetectionTime = now;
    });

    _startGlowAnimation();

    // Show glow for 1.5 seconds (longer for better visual feedback)
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;

      setState(() {
        _isScanned = true;
      });

      _glowTimer?.cancel();

      // Keep success message for 1 second before closing
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          Navigator.pop(context, code);
        }
      });
    });
  }

  void _startGlowAnimation() {
    _glowTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted || _isScanned) {
        timer.cancel();
        return;
      }

      setState(() {
        _glowIntensity += 0.1;
        if (_glowIntensity > 1.0) {
          _glowIntensity = 0.0;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final scanSize = screenWidth * 0.6;
    final left = (screenWidth - scanSize) / 2;
    final top = (screenHeight - scanSize) / 2;
    final scanWindow = Rect.fromLTWH(left, top, scanSize, scanSize);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera view
          MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
            fit: BoxFit.cover,
          ),

          // Scan window overlay with glow effect
          CustomPaint(
            painter: ScanWindowPainter(
              scanWindow: scanWindow,
              isDetecting: _isDetecting,
              glowIntensity: _glowIntensity,
            ),
            child: Container(),
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: _isProcessing ? null : () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Quét Mã Gift Card',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Instructions
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Torch button
                    Container(
                      decoration: BoxDecoration(
                        color: _isTorchOn
                            ? Colors.orange.withOpacity(0.9)
                            : Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isTorchOn ? Icons.flash_on : Icons.flash_off,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: _isProcessing ? null : () {
                          setState(() => _isTorchOn = !_isTorchOn);
                          cameraController.toggleTorch();
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isDetecting
                          ? 'Đang xử lý...'
                          : 'Đặt mã QR vào trong khung',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: _isDetecting ? FontWeight.bold : FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    if (!_isDetecting)
                      Text(
                        'Quét tự động khi phát hiện mã',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Success indicator
          if (_isScanned)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated check icon
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 400),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 64 * value,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Quét thành công!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Đang xử lý...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Scan window painter with glow effect on QR detection
class ScanWindowPainter extends CustomPainter {
  final Rect scanWindow;
  final bool isDetecting;
  final double glowIntensity;

  ScanWindowPainter({
    required this.scanWindow,
    required this.isDetecting,
    required this.glowIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Dark overlay
    final Paint darkPaint = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final Path path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(
        scanWindow,
        const Radius.circular(16),
      ))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, darkPaint);

    // Scan window border
    final Color borderColor = isDetecting ? Colors.greenAccent : Colors.white.withOpacity(0.5);

    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(scanWindow, const Radius.circular(16)),
      borderPaint,
    );

    // Glow effect when detecting
    if (isDetecting) {
      // Layer 1: Outer glow
      final Paint outerGlowPaint = Paint()
        ..color = Colors.greenAccent.withOpacity(0.15 * glowIntensity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 30.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          scanWindow.inflate(15),
          const Radius.circular(31),
        ),
        outerGlowPaint,
      );

      // Layer 2: Middle glow
      final Paint middleGlowPaint = Paint()
        ..color = Colors.greenAccent.withOpacity(0.3 * glowIntensity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          scanWindow.inflate(8),
          const Radius.circular(24),
        ),
        middleGlowPaint,
      );

      // Layer 3: Inner glow
      final Paint innerGlowPaint = Paint()
        ..color = Colors.greenAccent.withOpacity(0.6 * glowIntensity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          scanWindow.inflate(3),
          const Radius.circular(19),
        ),
        innerGlowPaint,
      );

      // Center bright border
      final Paint brightBorderPaint = Paint()
        ..color = Colors.greenAccent.withOpacity(0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      canvas.drawRRect(
        RRect.fromRectAndRadius(scanWindow, const Radius.circular(16)),
        brightBorderPaint,
      );
    }

    // Corner decorations
    final Paint cornerPaint = Paint()
      ..color = isDetecting ? Colors.greenAccent : Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final double cornerLength = 25.0;

    // Top-left
    canvas.drawLine(
      Offset(scanWindow.left, scanWindow.top + cornerLength),
      Offset(scanWindow.left, scanWindow.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanWindow.left, scanWindow.top),
      Offset(scanWindow.left + cornerLength, scanWindow.top),
      cornerPaint,
    );

    // Top-right
    canvas.drawLine(
      Offset(scanWindow.right - cornerLength, scanWindow.top),
      Offset(scanWindow.right, scanWindow.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanWindow.right, scanWindow.top),
      Offset(scanWindow.right, scanWindow.top + cornerLength),
      cornerPaint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(scanWindow.left, scanWindow.bottom - cornerLength),
      Offset(scanWindow.left, scanWindow.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanWindow.left, scanWindow.bottom),
      Offset(scanWindow.left + cornerLength, scanWindow.bottom),
      cornerPaint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(scanWindow.right - cornerLength, scanWindow.bottom),
      Offset(scanWindow.right, scanWindow.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanWindow.right, scanWindow.bottom - cornerLength),
      Offset(scanWindow.right, scanWindow.bottom),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(ScanWindowPainter oldDelegate) {
    return isDetecting != oldDelegate.isDetecting ||
        glowIntensity != oldDelegate.glowIntensity;
  }
}