import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pax_sdk/pax_sdk.dart';
import 'pax_poslink_service.dart';

class PaymentDeviceScreen extends StatefulWidget {
  const PaymentDeviceScreen({super.key});

  @override
  State<PaymentDeviceScreen> createState() => _PaymentDeviceScreenState();
}

class _PaymentDeviceScreenState extends State<PaymentDeviceScreen>
    with SingleTickerProviderStateMixin {
  // PAX POSLink Service for payment
  final PaxPosLinkService _paxService = PaxPosLinkService();

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // Connection status
  bool _checking = false;
  bool _isReady = false;
  String _statusMessage = 'Chưa kiểm tra kết nối';
  String? _paxDeviceIp;
  String? _myIp;

  // Device capabilities
  bool _nfcAvailable = false;
  bool _printerAvailable = false;
  bool _paymentAvailable = false;

  // Manual IP input for payment
  final TextEditingController _manualIpController = TextEditingController();
  bool _showManualIpInput = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();

    // Auto-check on start
    Future.delayed(const Duration(milliseconds: 500), () {
      _checkDevice();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _manualIpController.dispose();
    _paxService.dispose();
    super.dispose();
  }

  /// Check all device capabilities
  Future<void> _checkDevice() async {
    setState(() {
      _checking = true;
      _statusMessage = 'Đang kiểm tra thiết bị...';
    });

    try {
      // 1. Check NFC capability
      await _checkNFC();

      // 2. Check Printer capability
      await _checkPrinter();

      // 3. Check Payment capability (scan for PAX device)
      await _checkPayment();

      // Update overall status
      setState(() {
        _isReady = _nfcAvailable || _printerAvailable || _paymentAvailable;

        if (_isReady) {
          List<String> available = [];
          if (_nfcAvailable) available.add('NFC');
          if (_printerAvailable) available.add('Printer');
          if (_paymentAvailable) available.add('Payment');

          _statusMessage = 'Thiết bị sẵn sàng: ${available.join(", ")}';
        } else {
          _statusMessage = 'Không tìm thấy tính năng nào khả dụng';
          _showManualIpInput = true;
        }
      });
    } catch (e) {
      setState(() {
        _isReady = false;
        _statusMessage = 'Lỗi kiểm tra: ${e.toString()}';
      });
    } finally {
      setState(() => _checking = false);
    }
  }

  /// Check NFC capability using PAX SDK
  Future<void> _checkNFC() async {
    try {
      final isPresent = await PaxSdk.checkCardPresence();
      setState(() {
        _nfcAvailable = true; // If method works, NFC is available
        print('✅ NFC available (card present: $isPresent)');
      });
    } catch (e) {
      setState(() {
        _nfcAvailable = false;
        print('❌ NFC not available: $e');
      });
    }
  }

  /// Check Printer capability using PAX SDK
  Future<void> _checkPrinter() async {
    try {
      final initialized = await PaxSdk.initializePrinter();
      setState(() {
        _printerAvailable = initialized == true;
        print('✅ Printer available: $initialized');
      });
    } catch (e) {
      setState(() {
        _printerAvailable = false;
        print('❌ Printer not available: $e');
      });
    }
  }

  /// Check Payment capability by scanning for PAX device
  Future<void> _checkPayment() async {
    try {
      // Get local network info
      final interfaces = await NetworkInterface.list();
      String? localSubnet;

      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            _myIp = addr.address;
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              localSubnet = '${parts[0]}.${parts[1]}.${parts[2]}';
              break;
            }
          }
        }
        if (localSubnet != null) break;
      }

      if (localSubnet != null) {
        // Quick scan for PAX device
        final deviceIp = await _quickScanForPax(localSubnet);

        if (deviceIp != null) {
          final connected = await _paxService.initialize(deviceIp);
          setState(() {
            _paymentAvailable = connected;
            _paxDeviceIp = deviceIp;
            print('✅ Payment available at $deviceIp');
          });
        } else {
          setState(() {
            _paymentAvailable = false;
            print('❌ Payment device not found');
          });
        }
      }
    } catch (e) {
      setState(() {
        _paymentAvailable = false;
        print('❌ Payment check error: $e');
      });
    }
  }

  /// Quick scan for PAX device (only check a few IPs)
  Future<String?> _quickScanForPax(String subnet) async {
    // Only check common IPs for speed
    for (int i = 100; i <= 105; i++) {
      final ip = '$subnet.$i';
      try {
        final socket = await Socket.connect(
          ip,
          10009,
          timeout: const Duration(seconds: 1),
        );
        socket.destroy();
        return ip;
      } catch (e) {
        continue;
      }
    }
    return null;
  }

  /// Test NFC card reading
  Future<void> _testNFC() async {
    try {
      _showLoadingDialog('Đợi quẹt thẻ NFC...');

      final cardResult = await PaxSdk.detectCard();

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (cardResult['success']) {
        final cardData = cardResult['cardData'];
        _showResultDialog(
          title: 'Đọc thẻ thành công',
          message: 'Card UID: ${cardData['uid']}\n'
              'Card Type: ${cardData['type'] ?? 'Unknown'}',
          isSuccess: true,
        );
      } else {
        _showResultDialog(
          title: 'Không phát hiện thẻ',
          message: 'Vui lòng đặt thẻ NFC lên máy đọc',
          isSuccess: false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showResultDialog(
        title: 'Lỗi đọc thẻ',
        message: e.toString(),
        isSuccess: false,
      );
    }
  }

  /// Test printer
  Future<void> _testPrinter() async {
    try {
      _showLoadingDialog('Đang in thử...');

      // Print test receipt
      await PaxSdk.printText(
        '================================\n',
        options: {'alignment': 1},
      );

      await PaxSdk.printText(
        'PAX A920 Pro\n',
        options: {'fontSize': 'large', 'alignment': 1},
      );

      await PaxSdk.printText(
        'TEST PRINT\n',
        options: {'fontSize': 'medium', 'alignment': 1},
      );

      await PaxSdk.printText(
        '================================\n',
        options: {'alignment': 1},
      );

      await PaxSdk.printText(
        'S/N: 1851071416\n',
        options: {'alignment': 1},
      );

      await PaxSdk.printText(
        'Date: ${DateTime.now().toString().split('.')[0]}\n',
        options: {'alignment': 0},
      );

      await PaxSdk.printText(
        '\nTest successful!\n\n',
        options: {'alignment': 1},
      );

      // Cut paper
      await PaxSdk.cutPaper(mode: 0);

      if (!mounted) return;
      Navigator.pop(context);

      _showResultDialog(
        title: 'In thử thành công',
        message: 'Hóa đơn test đã được in',
        isSuccess: true,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showResultDialog(
        title: 'Lỗi in',
        message: e.toString(),
        isSuccess: false,
      );
    }
  }

  /// Test payment
  Future<void> _testPayment() async {
    if (!_paymentAvailable) {
      _showResultDialog(
        title: 'Thanh toán không khả dụng',
        message: 'Vui lòng kết nối với thiết bị PAX trước',
        isSuccess: false,
      );
      return;
    }

    try {
      _showLoadingDialog('Đang xử lý thanh toán...\nVui lòng thực hiện trên máy PAX');

      final result = await _paxService.processSale(
        amount: 1.0, // 1.000đ
        invoiceNumber: 'TEST_${DateTime.now().millisecondsSinceEpoch}',
        timeout: 180,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (result['success'] == true) {
        _showResultDialog(
          title: 'Thanh toán thành công',
          message: 'Amount: \$${result['amount']?.toStringAsFixed(2)}\n'
              'Card: ${result['cardType'] ?? 'N/A'}\n'
              'Card Number: ${result['cardNumber'] ?? 'N/A'}\n'
              'Auth Code: ${result['authCode'] ?? 'N/A'}',
          isSuccess: true,
        );
      } else {
        _showResultDialog(
          title: 'Thanh toán thất bại',
          message: result['error'] ?? 'Unknown error',
          isSuccess: false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showResultDialog(
        title: 'Lỗi thanh toán',
        message: e.toString(),
        isSuccess: false,
      );
    }
  }

  /// Connect with manual IP
  Future<void> _connectManualIp() async {
    final ip = _manualIpController.text.trim();
    if (ip.isEmpty) {
      _showResultDialog(
        title: 'Lỗi',
        message: 'Vui lòng nhập địa chỉ IP',
        isSuccess: false,
      );
      return;
    }

    setState(() {
      _checking = true;
      _statusMessage = 'Đang kết nối $ip...';
    });

    try {
      final connected = await _paxService.initialize(ip);
      setState(() {
        _paymentAvailable = connected;
        _paxDeviceIp = ip;
        _isReady = _nfcAvailable || _printerAvailable || _paymentAvailable;
        _statusMessage = connected
            ? 'Đã kết nối payment tại $ip'
            : 'Không thể kết nối $ip';
        _showManualIpInput = !connected;
      });

      if (connected) {
        _manualIpController.clear();
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Lỗi kết nối: $e';
      });
    } finally {
      setState(() => _checking = false);
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(message, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showResultDialog({
    required String title,
    required String message,
    required bool isSuccess,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: isSuccess ? Colors.green : Colors.red,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Thiết Bị Thanh Toán'),
        centerTitle: true,
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ScaleTransition(
        scale: _scaleAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Device Info Card
              _buildDeviceInfoCard(),

              const SizedBox(height: 20),

              // Status Card
              _buildStatusCard(),

              const SizedBox(height: 20),

              // Capabilities Card
              _buildCapabilitiesCard(),

              const SizedBox(height: 20),

              // Manual IP Input (if payment not available)
              if (_showManualIpInput && !_paymentAvailable)
                _buildManualIpInput(),

              const SizedBox(height: 24),

              // Test Buttons
              _buildTestButtons(),

              const SizedBox(height: 24),

              // Info Section
              _buildInfoSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceInfoCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade700, Colors.purple.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.payment,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'PAX A920 Pro',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tag,
                  size: 16,
                  color: Colors.white.withOpacity(0.9),
                ),
                const SizedBox(width: 6),
                const Text(
                  'S/N: 1851071416',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (_paxDeviceIp != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.wifi,
                    size: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'IP: $_paxDeviceIp',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    Color statusColor = _checking
        ? Colors.orange
        : _isReady
        ? Colors.green
        : Colors.grey;

    IconData statusIcon = _checking
        ? Icons.sync
        : _isReady
        ? Icons.check_circle
        : Icons.error_outline;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _checking
                ? Padding(
              padding: const EdgeInsets.all(12),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            )
                : Icon(
              statusIcon,
              color: statusColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trạng Thái Thiết Bị',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _statusMessage,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapabilitiesCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tính Năng Khả Dụng',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          _buildCapabilityRow('NFC Card Reader', _nfcAvailable),
          const SizedBox(height: 12),
          _buildCapabilityRow('Thermal Printer', _printerAvailable),
          const SizedBox(height: 12),
          _buildCapabilityRow('Payment Processing', _paymentAvailable),
        ],
      ),
    );
  }

  Widget _buildCapabilityRow(String label, bool available) {
    return Row(
      children: [
        Icon(
          available ? Icons.check_circle : Icons.cancel,
          color: available ? Colors.green : Colors.grey,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: available ? Colors.black87 : Colors.grey,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: available
                ? Colors.green.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            available ? 'Sẵn sàng' : 'Không khả dụng',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: available ? Colors.green : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualIpInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Kết nối thủ công',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualIpController,
                  decoration: InputDecoration(
                    labelText: 'IP Address',
                    hintText: 'e.g., 192.168.1.100',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _checking ? null : _connectManualIp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                child: const Text('Kết nối'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTestButtons() {
    return Column(
      children: [
        // Check Device Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _checking ? null : _checkDevice,
            icon: _checking
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : const Icon(Icons.sync),
            label: Text(
              _checking ? 'Đang kiểm tra...' : 'Kiểm Tra Thiết Bị',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Test NFC Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _nfcAvailable && !_checking ? _testNFC : null,
            icon: const Icon(Icons.nfc),
            label: const Text(
              'Test NFC Reader',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              disabledBackgroundColor: Colors.grey[300],
              disabledForegroundColor: Colors.grey[500],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Test Printer Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _printerAvailable && !_checking ? _testPrinter : null,
            icon: const Icon(Icons.print),
            label: const Text(
              'Test Printer',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              disabledBackgroundColor: Colors.grey[300],
              disabledForegroundColor: Colors.grey[500],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Test Payment Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _paymentAvailable && !_checking ? _testPayment : null,
            icon: const Icon(Icons.credit_card),
            label: const Text(
              'Test Payment \$1.00',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              disabledBackgroundColor: Colors.grey[300],
              disabledForegroundColor: Colors.grey[500],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.blue.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Hướng Dẫn Test',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoItem('1. Nhấn "Kiểm Tra Thiết Bị" để scan tất cả tính năng'),
          _buildInfoItem('2. Test NFC: Đặt thẻ lên máy đọc khi có thông báo'),
          _buildInfoItem('3. Test Printer: In hóa đơn mẫu'),
          _buildInfoItem('4. Test Payment: Thực hiện thanh toán \$1 trên PAX'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.amber.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đảm bảo ứng dụng TSYS Sierra đang chạy trên thiết bị PAX để test payment',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 18,
            color: Colors.blue.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue.shade900,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}