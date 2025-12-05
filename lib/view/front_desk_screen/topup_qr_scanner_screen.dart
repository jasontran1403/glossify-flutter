import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:hair_sallon/api/api_service.dart';
import 'package:hair_sallon/api/giftcard_model.dart';

class TopupQRScannerScreen extends StatefulWidget {
  const TopupQRScannerScreen({super.key});

  @override
  State<TopupQRScannerScreen> createState() => _TopupQRScannerScreenState();
}

class _TopupQRScannerScreenState extends State<TopupQRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.front,
    formats: [BarcodeFormat.qrCode],
    returnImage: false,
  );

  bool _isScanned = false;
  String? _scannedCode;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    // Force portrait mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  void dispose() {
    // Restore landscape mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isScanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    final String? code = barcode.rawValue;

    if (code != null && code.isNotEmpty) {
      setState(() {
        _isScanned = true;
        _scannedCode = code;
      });

      Future.delayed(const Duration(milliseconds: 300), () {
        _handleScannedCode(code);
      });
    }
  }

  bool _isValidGiftCardCode(String code) {
    const expectedLength = 12;
    if (code.length != expectedLength) return false;
    final digitRegex = RegExp(r'^\d{12}$');
    return digitRegex.hasMatch(code);
  }

  Future<void> _handleScannedCode(String code) async {
    final isValid = _isValidGiftCardCode(code);

    if (!isValid) {
      _showErrorSheet('Gift card code must be exactly 12 digits');
      return;
    }

    // Show loading
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildLoadingSheet(),
    );

    try {
      // Check if gift card exists
      final response = await ApiService.getGiftCard(code);

      if (!mounted) return;

      // Close loading
      Navigator.pop(context);

      GiftCardDTO? existingCard;
      bool isNewCard = false;

      if (response.code == 900 && response.data != null) {
        existingCard = response.data!;
        isNewCard = false;
      } else {
        // Gift card doesn't exist - will create new
        isNewCard = true;
      }

      // Show topup form
      _showTopupForm(code, existingCard, isNewCard);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading

      // Assume new card if error
      _showTopupForm(code, null, true);
    }
  }

  void _showTopupForm(String code, GiftCardDTO? existingCard, bool isNewCard) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TopupFormSheet(
        code: code,
        existingCard: existingCard,
        isNewCard: isNewCard,
      ),
    ).then((result) {
      if (result != null) {
        // Return result to FrontDesk
        Navigator.pop(context, result);
      } else {
        // Reset scanner for another scan
        _resetScanner();
      }
    });
  }

  Widget _buildLoadingSheet() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.purple),
            const SizedBox(height: 24),
            Text(
              'Checking gift card...',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorSheet(String message) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline,
                    color: Colors.red.shade600,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Invalid Code',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _resetScanner();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                            color: Colors.grey.shade400,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Scan Again',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Close Scanner',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _resetScanner() {
    setState(() {
      _isScanned = false;
      _scannedCode = null;
    });
  }

  void _toggleTorch() {
    setState(() {
      _isTorchOn = !_isTorchOn;
    });
    cameraController.toggleTorch();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final scanAreaSize = screenSize.width * 0.45;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera full screen
          Positioned.fill(
            child: Transform.rotate(
              angle: -math.pi / 2,
              child: OverflowBox(
                alignment: Alignment.center,
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: screenSize.height,
                    height: screenSize.width,
                    child: MobileScanner(
                      controller: cameraController,
                      onDetect: _onDetect,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Top gradient overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 200,
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
            ),
          ),

          // Bottom gradient overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 250,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Scanner overlay
          CustomPaint(
            painter: ModernScannerOverlay(scanAreaSize: scanAreaSize),
            child: Container(),
          ),

          // Close button
          Positioned(
            top: 16,
            left: 16,
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),

          // Title
          Positioned(
            top: 24,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Center(
                child: const Text(
                  'Scan Gift Card for Top-up',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(color: Colors.black45, blurRadius: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Torch button
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: _isTorchOn
                      ? Colors.purple.withOpacity(0.9)
                      : Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                  boxShadow: _isTorchOn
                      ? [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                      : [],
                ),
                child: IconButton(
                  icon: Icon(
                    _isTorchOn ? Icons.flash_on : Icons.flash_off,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: _toggleTorch,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Topup Form Sheet
class TopupFormSheet extends StatefulWidget {
  final String code;
  final GiftCardDTO? existingCard;
  final bool isNewCard;

  const TopupFormSheet({
    super.key,
    required this.code,
    required this.existingCard,
    required this.isNewCard,
  });

  @override
  State<TopupFormSheet> createState() => _TopupFormSheetState();
}

class _TopupFormSheetState extends State<TopupFormSheet> {
  final TextEditingController _amountController = TextEditingController();
  int _selectedPaymentMethod = 1; // 1: Cash, 2: Credit
  double _topupAmount = 0.0;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _handleConfirm() {
    if (_topupAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Return data to parent
    Navigator.pop(context, {
      'code': widget.code,
      'amount': _topupAmount,
      'paymentMethod': _selectedPaymentMethod,
      'isNewCard': widget.isNewCard,
      'currentBalance': widget.existingCard?.remainingBalance ?? 0.0,
    });
  }

  String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // Icon
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.card_giftcard,
                    color: Colors.purple.shade600,
                    size: 40,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Title
              Center(
                child: Text(
                  widget.isNewCard ? 'New Gift Card' : 'Top-up Gift Card',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Card info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('Code', widget.code),
                    if (!widget.isNewCard && widget.existingCard != null) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Current Balance',
                        _formatCurrency(widget.existingCard!.remainingBalance),
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow('Status', widget.existingCard!.status),
                    ],
                    if (widget.isNewCard) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow('Status', 'NEW - Will be created'),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Amount input
              const Text(
                'Top-up Amount',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Enter amount',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                onChanged: (value) {
                  setState(() {
                    _topupAmount = double.tryParse(value) ?? 0.0;
                  });
                },
              ),

              const SizedBox(height: 24),

              // Payment method
              const Text(
                'Payment Method',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildPaymentMethodButton(
                      icon: Icons.money,
                      label: 'Cash',
                      methodId: 1,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPaymentMethodButton(
                      icon: Icons.credit_card,
                      label: 'Credit Card',
                      methodId: 2,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(
                          color: Colors.grey.shade400,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _handleConfirm,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.purple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Confirm',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodButton({
    required IconData icon,
    required String label,
    required int methodId,
  }) {
    final selected = _selectedPaymentMethod == methodId;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = methodId;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? Colors.purple : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.purple : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : Colors.black87,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ModernScannerOverlay extends CustomPainter {
  final double scanAreaSize;

  ModernScannerOverlay({required this.scanAreaSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final left = (size.width - scanAreaSize) / 2;
    final top = (size.height - scanAreaSize) / 2;
    final scanRect = Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize);

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(24)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(
      RRect.fromRectAndRadius(scanRect, const Radius.circular(24)),
      borderPaint,
    );

    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const cornerLength = 30.0;

    // Top-left corner
    canvas.drawLine(
        Offset(left, top + 24), Offset(left, top + cornerLength), cornerPaint);
    canvas.drawLine(Offset(left + 24, top), Offset(left + cornerLength, top),
        cornerPaint);

    // Top-right corner
    canvas.drawLine(Offset(left + scanAreaSize, top + 24),
        Offset(left + scanAreaSize, top + cornerLength), cornerPaint);
    canvas.drawLine(Offset(left + scanAreaSize - 24, top),
        Offset(left + scanAreaSize - cornerLength, top), cornerPaint);

    // Bottom-left corner
    canvas.drawLine(Offset(left, top + scanAreaSize - 24),
        Offset(left, top + scanAreaSize - cornerLength), cornerPaint);
    canvas.drawLine(Offset(left + 24, top + scanAreaSize),
        Offset(left + cornerLength, top + scanAreaSize), cornerPaint);

    // Bottom-right corner
    canvas.drawLine(Offset(left + scanAreaSize, top + scanAreaSize - 24),
        Offset(left + scanAreaSize, top + scanAreaSize - cornerLength), cornerPaint);
    canvas.drawLine(Offset(left + scanAreaSize - 24, top + scanAreaSize),
        Offset(left + scanAreaSize - cornerLength, top + scanAreaSize), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}