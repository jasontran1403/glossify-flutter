import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'pax_poslink_service.dart';

class PaxTransaction {
  final String bookingId;
  final double amount;
  final double tip;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String status;
  final String? cardHolder;
  final String? cardType;
  final String? cardNumber;
  final String? authCode;
  final String transactionId;

  PaxTransaction({
    required this.bookingId,
    required this.amount,
    this.tip = 0.0,
    required this.createdAt,
    this.updatedAt,
    required this.status,
    this.cardHolder,
    this.cardType,
    this.cardNumber,
    this.authCode,
    required this.transactionId,
  });
}

class PaxPaymentManagementScreen extends StatefulWidget {
  const PaxPaymentManagementScreen({super.key});

  @override
  State<PaxPaymentManagementScreen> createState() =>
      _PaxPaymentManagementScreenState();
}

class _PaxPaymentManagementScreenState
    extends State<PaxPaymentManagementScreen> {
  final PaxPosLinkService _paxService = PaxPosLinkService();

  bool _isScanning = false;
  bool _isDeviceConnected = false;
  String _deviceStatus = 'Not connected';
  String? _paxDeviceIp;
  String? _myIp;

  final TextEditingController _manualIpController = TextEditingController();
  bool _showManualIpInput = false;

  final List<PaxTransaction> _transactions = [];
  final TextEditingController _bookingIdController = TextEditingController();
  final TextEditingController _amountController = TextEditingController(text: '1.00');

  bool _isCreatingPayment = false;
  Timer? _paymentTimeoutTimer;
  String? _currentTransactionId;

  bool _cancelScan = false;
  int _scannedCount = 0;
  int _totalToScan = 0;

  @override
  void initState() {
    super.initState();
    _scanForPaxDevice();
  }

  @override
  void dispose() {
    _paymentTimeoutTimer?.cancel();
    _bookingIdController.dispose();
    _amountController.dispose();
    _manualIpController.dispose();
    _paxService.dispose();
    super.dispose();
  }

  void _stopScan() {
    setState(() {
      _cancelScan = true;
      _isScanning = false;
      _deviceStatus = 'Scan cancelled';
      _showManualIpInput = true;
    });
  }

  /// AUTO-SCAN với FULL SUBNET (1-254)
  Future<void> _scanForPaxDevice() async {
    _cancelScan = false;
    _scannedCount = 0;

    setState(() {
      _isScanning = true;
      _deviceStatus = 'Scanning for PAX device...';
      _showManualIpInput = false;
    });

    try {
      // Get local IP
      final interfaces = await NetworkInterface.list();
      String? localSubnet;

      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            _myIp = addr.address;
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              localSubnet = '${parts[0]}.${parts[1]}.${parts[2]}';
              print('\n╔════════════════════════════════════════╗');
              print('║   STARTING DEVICE SCAN                 ║');
              print('╚════════════════════════════════════════╝');
              print('My IP: $_myIp');
              print('Subnet: $localSubnet.x');
              break;
            }
          }
        }
        if (localSubnet != null) break;
      }

      if (localSubnet == null) {
        throw Exception('Cannot detect local network');
      }

      // Scan subnet
      final deviceIp = await _scanSubnetFull(localSubnet);

      if (_cancelScan) return;

      if (deviceIp != null) {
        print('\n✅ Device found at: $deviceIp');
        print('Attempting POSLink connection...');

        final connected = await _paxService.initialize(deviceIp);

        if (connected) {
          setState(() {
            _isDeviceConnected = true;
            _paxDeviceIp = deviceIp;
            _deviceStatus = 'Connected to PAX A920 Pro at $deviceIp';
            _isScanning = false;
          });
          print('✅ POSLink connection successful\n');
        } else {
          throw Exception('Socket connected but POSLink initialize failed');
        }
      } else {
        setState(() {
          _isDeviceConnected = false;
          _deviceStatus = 'No PAX device found in $localSubnet.x';
          _isScanning = false;
          _showManualIpInput = true;
        });
        print('❌ No device found on subnet\n');
      }
    } catch (e) {
      if (!_cancelScan) {
        setState(() {
          _isDeviceConnected = false;
          _deviceStatus = 'Error: $e';
          _isScanning = false;
          _showManualIpInput = true;
        });
        print('❌ Scan error: $e\n');
      }
    }
  }

  /// FULL SUBNET SCAN (optimized with priority ranges)
  Future<String?> _scanSubnetFull(String subnet) async {
    // Priority ranges (scan these first for speed)
    final priorityRanges = [
      [180, 190],  // Your device is at .186
      [100, 110],
      [1, 20],
      [200, 220],
    ];

    // Remaining IPs
    final remaining = <int>[];
    final scanned = <int>{};

    // Calculate total
    for (var range in priorityRanges) {
      _totalToScan += (range[1] - range[0] + 1);
      for (int i = range[0]; i <= range[1]; i++) {
        scanned.add(i);
      }
    }

    for (int i = 1; i <= 254; i++) {
      if (!scanned.contains(i)) {
        remaining.add(i);
      }
    }
    _totalToScan += remaining.length;

    setState(() {});

    print('\nScanning strategy:');
    print('Priority ranges: $priorityRanges');
    print('Total IPs to scan: $_totalToScan');
    print('Starting scan...\n');

    // Scan priority ranges first
    for (var range in priorityRanges) {
      for (int i = range[0]; i <= range[1]; i++) {
        if (_cancelScan) {
          print('🛑 Scan cancelled by user');
          return null;
        }

        final ip = '$subnet.$i';
        _scannedCount++;

        if (_scannedCount % 10 == 0) {
          setState(() {
            _deviceStatus = 'Scanning... ($_scannedCount/$_totalToScan)';
          });
        }

        final found = await _tryConnectToIP(ip);
        if (found) return ip;
      }
    }

    // Scan remaining IPs
    print('Priority ranges complete. Scanning remaining IPs...');
    for (int i in remaining) {
      if (_cancelScan) return null;

      final ip = '$subnet.$i';
      _scannedCount++;

      if (_scannedCount % 20 == 0) {
        setState(() {
          _deviceStatus = 'Scanning... ($_scannedCount/$_totalToScan)';
        });
      }

      final found = await _tryConnectToIP(ip);
      if (found) return ip;
    }

    return null;
  }

  /// Try to connect to specific IP
  Future<bool> _tryConnectToIP(String ip) async {
    try {
      final socket = await Socket.connect(
        ip,
        10009,
        timeout: const Duration(milliseconds: 500), // Fast timeout
      );
      socket.destroy();
      print('✅ FOUND: $ip responds on port 10009');
      return true;
    } catch (e) {
      // Silent fail, continue scanning
      return false;
    }
  }

  /// Manual IP connection
  Future<void> _connectWithManualIp() async {
    final manualIp = _manualIpController.text.trim();

    if (manualIp.isEmpty) {
      _showErrorDialog('Please enter IP address');
      return;
    }

    final ipPattern = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (!ipPattern.hasMatch(manualIp)) {
      _showErrorDialog('Invalid IP format');
      return;
    }

    setState(() {
      _isScanning = true;
      _deviceStatus = 'Connecting to $manualIp...';
    });

    print('\n╔════════════════════════════════════════╗');
    print('║   MANUAL CONNECTION                    ║');
    print('╚════════════════════════════════════════╝');
    print('Target IP: $manualIp');

    try {
      // Test port 10009
      print('Testing port 10009...');
      final socket = await Socket.connect(
        manualIp,
        10009,
        timeout: const Duration(seconds: 10),
      );
      print('✅ Port 10009 is open');
      socket.destroy();

      // Initialize POSLink
      print('Initializing POSLink...');
      final connected = await _paxService.initialize(manualIp);

      if (connected) {
        setState(() {
          _isDeviceConnected = true;
          _paxDeviceIp = manualIp;
          _deviceStatus = 'Connected to $manualIp';
          _isScanning = false;
          _showManualIpInput = false;
        });
        _manualIpController.clear();
        print('✅ Manual connection successful\n');
      } else {
        throw Exception('POSLink initialization failed');
      }
    } catch (e) {
      setState(() {
        _isDeviceConnected = false;
        _deviceStatus = 'Connection failed';
        _isScanning = false;
      });
      print('❌ Manual connection failed: $e\n');
      _showErrorDialog(
          'Cannot connect to $manualIp\n\n'
              'Please check:\n'
              '• Device is powered on\n'
              '• TSYS Sierra app is running\n'
              '• Same WiFi network\n'
              '• IP address is correct\n'
              '• Port 10009 is not blocked'
      );
    }
  }

  /// Create payment
  Future<void> _createPayment() async {
    if (_bookingIdController.text.isEmpty) {
      _showErrorDialog('Please enter Booking ID');
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showErrorDialog('Invalid amount');
      return;
    }

    if (!_isDeviceConnected) {
      _showErrorDialog('PAX device not connected');
      return;
    }

    final transactionId = DateTime.now().millisecondsSinceEpoch.toString();
    final transaction = PaxTransaction(
      bookingId: _bookingIdController.text,
      amount: amount,
      createdAt: DateTime.now(),
      status: 'PENDING',
      transactionId: transactionId,
    );

    setState(() {
      _transactions.insert(0, transaction);
      _isCreatingPayment = true;
      _currentTransactionId = transactionId;
    });

    _bookingIdController.clear();
    _showWaitingDialog();

    _paymentTimeoutTimer = Timer(const Duration(minutes: 3), () {
      if (_isCreatingPayment) {
        _handleTimeout();
      }
    });

    try {
      print('\n╔════════════════════════════════════════╗');
      print('║   CREATING PAYMENT                     ║');
      print('╚════════════════════════════════════════╝');
      print('Amount: \$${amount.toStringAsFixed(2)}');
      print('Booking ID: ${transaction.bookingId}');
      print('Device IP: $_paxDeviceIp');

      final result = await _paxService.processSale(
        amount: amount,
        invoiceNumber: transaction.bookingId,
        timeout: 180,
      );

      _paymentTimeoutTimer?.cancel();

      print('\n╔════════════════════════════════════════╗');
      print('║   PAYMENT RESULT                       ║');
      print('╚════════════════════════════════════════╝');
      print('Success: ${result['success']}');
      print('Status: ${result['statusText']}');
      print('Full result: $result\n');

      if (result['success'] == true) {
        _handlePaymentSuccess(result);
      } else {
        if (result['status'] == 'CANCEL' || result['statusText'] == 'CANCELLED') {
          _handlePaymentCancelled();
        } else {
          _handlePaymentError(result['error'] ?? 'Payment failed');
        }
      }
    } catch (e, stackTrace) {
      _paymentTimeoutTimer?.cancel();
      print('\n❌ Payment exception: $e');
      print('Stack: ${stackTrace.toString().split('\n').take(5).join('\n')}\n');
      _handlePaymentError('Payment error: $e');
    }
  }

  void _handlePaymentSuccess(Map<String, dynamic> data) {
    if (!mounted) return;

    setState(() {
      final index = _transactions
          .indexWhere((t) => t.transactionId == _currentTransactionId);
      if (index != -1) {
        _transactions[index] = PaxTransaction(
          bookingId: _transactions[index].bookingId,
          amount: data['amount'] ?? _transactions[index].amount,
          tip: data['tip'] ?? 0.0,
          createdAt: _transactions[index].createdAt,
          updatedAt: DateTime.now(),
          status: 'SUCCESS',
          cardHolder: data['cardHolder'],
          cardType: data['cardType'],
          cardNumber: data['cardNumber'],
          authCode: data['authCode'],
          transactionId: _transactions[index].transactionId,
        );
      }
      _isCreatingPayment = false;
      _currentTransactionId = null;
    });

    Navigator.pop(context);
    _showSuccessDialog(data);
  }

  void _handlePaymentCancelled() {
    if (!mounted) return;

    setState(() {
      final index = _transactions
          .indexWhere((t) => t.transactionId == _currentTransactionId);
      if (index != -1) {
        _transactions[index] = PaxTransaction(
          bookingId: _transactions[index].bookingId,
          amount: _transactions[index].amount,
          createdAt: _transactions[index].createdAt,
          updatedAt: DateTime.now(),
          status: 'CANCELLED',
          transactionId: _transactions[index].transactionId,
        );
      }
      _isCreatingPayment = false;
      _currentTransactionId = null;
    });

    Navigator.pop(context);
    _showErrorDialog('Payment cancelled by user');
  }

  void _handleTimeout() {
    if (!mounted) return;

    setState(() {
      final index = _transactions
          .indexWhere((t) => t.transactionId == _currentTransactionId);
      if (index != -1) {
        _transactions[index] = PaxTransaction(
          bookingId: _transactions[index].bookingId,
          amount: _transactions[index].amount,
          createdAt: _transactions[index].createdAt,
          updatedAt: DateTime.now(),
          status: 'TIMEOUT',
          transactionId: _transactions[index].transactionId,
        );
      }
      _isCreatingPayment = false;
      _currentTransactionId = null;
    });

    Navigator.pop(context);
    _showErrorDialog('Payment timeout (3 minutes)');
  }

  void _handlePaymentError(String message) {
    if (!mounted) return;

    setState(() {
      final index = _transactions
          .indexWhere((t) => t.transactionId == _currentTransactionId);
      if (index != -1) {
        _transactions[index] = PaxTransaction(
          bookingId: _transactions[index].bookingId,
          amount: _transactions[index].amount,
          createdAt: _transactions[index].createdAt,
          updatedAt: DateTime.now(),
          status: 'FAILED',
          transactionId: _transactions[index].transactionId,
        );
      }
      _isCreatingPayment = false;
      _currentTransactionId = null;
    });

    Navigator.pop(context);
    _showErrorDialog(message);
  }

  void _showWaitingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: const Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Expanded(child: Text('Processing Payment')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Payment request sent to PAX device.'),
              const SizedBox(height: 8),
              const Text('Please complete transaction on terminal.'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Timeout in 3 minutes',
                        style: TextStyle(color: Colors.grey[700], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _handlePaymentCancelled,
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(Map<String, dynamic> data) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600], size: 32),
            const SizedBox(width: 12),
            const Text('Payment Successful'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Payment processed successfully!', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              _buildDetailRow('Amount', '\$${data['amount']?.toStringAsFixed(2) ?? '0.00'}'),
              if (data['tip'] != null && data['tip'] > 0)
                _buildDetailRow('Tip', '\$${data['tip']?.toStringAsFixed(2)}'),
              if (data['cardType'] != null)
                _buildDetailRow('Card Type', data['cardType']),
              if (data['cardNumber'] != null)
                _buildDetailRow('Card', data['cardNumber']),
              if (data['authCode'] != null)
                _buildDetailRow('Auth Code', data['authCode']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showTransactionDetails(PaxTransaction transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Transaction - ${transaction.bookingId}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Booking ID', transaction.bookingId),
              _buildDetailRow('Amount', '\$${transaction.amount.toStringAsFixed(2)}'),
              _buildDetailRow('Tip', '\$${transaction.tip.toStringAsFixed(2)}'),
              _buildDetailRow('Total', '\$${(transaction.amount + transaction.tip).toStringAsFixed(2)}', bold: true),
              const Divider(),
              _buildDetailRow('Status', transaction.status),
              _buildDetailRow('Created', _formatDateTime(transaction.createdAt)),
              if (transaction.updatedAt != null)
                _buildDetailRow('Updated', _formatDateTime(transaction.updatedAt!)),
              if (transaction.cardHolder != null) ...[
                const Divider(),
                _buildDetailRow('Card Holder', transaction.cardHolder!),
              ],
              if (transaction.cardType != null)
                _buildDetailRow('Card Type', transaction.cardType!),
              if (transaction.cardNumber != null)
                _buildDetailRow('Card Number', transaction.cardNumber!),
              if (transaction.authCode != null)
                _buildDetailRow('Auth Code', transaction.authCode!),
              const Divider(),
              _buildDetailRow('Transaction ID', transaction.transactionId, small: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool bold = false, bool small = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: small ? 11 : 14,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: small ? 11 : 14,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'SUCCESS': return Colors.green;
      case 'PENDING': return Colors.orange;
      case 'CANCELLED': return Colors.blue;
      case 'TIMEOUT':
      case 'FAILED': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('PAX Payment Management'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          if (_isScanning)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stopScan,
              tooltip: 'Stop scanning',
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _scanForPaxDevice,
              tooltip: 'Rescan',
            ),
        ],
      ),
      body: Column(
        children: [
          // Device Status
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isDeviceConnected ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isDeviceConnected ? Colors.green : Colors.orange,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isDeviceConnected ? Icons.check_circle : Icons.error_outline,
                  color: _isDeviceConnected ? Colors.green : Colors.orange,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _deviceStatus,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isDeviceConnected ? Colors.green[700] : Colors.orange[700],
                        ),
                      ),
                      if (_paxDeviceIp != null) ...[
                        const SizedBox(height: 4),
                        Text('IP: $_paxDeviceIp', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                      if (_myIp != null)
                        Text('My IP: $_myIp', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ),
                if (_isScanning)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),

          // Manual IP
          if (_showManualIpInput && !_isDeviceConnected)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text('Device not found? Enter IP manually', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blue)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manualIpController,
                          decoration: InputDecoration(
                            labelText: 'PAX IP',
                            hintText: '192.168.0.186',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.router, color: Colors.blue),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          enabled: !_isScanning,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _isScanning ? null : _connectWithManualIp,
                        icon: const Icon(Icons.link, size: 18),
                        label: const Text('Connect'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Payment Form
          if (_isDeviceConnected)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Create Payment Request', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _bookingIdController,
                          decoration: InputDecoration(
                            labelText: 'Booking ID',
                            hintText: '0001',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.receipt, color: Colors.purple),
                            isDense: true,
                          ),
                          enabled: !_isCreatingPayment,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: _amountController,
                          decoration: InputDecoration(
                            labelText: 'Amount',
                            hintText: '0.00',
                            prefixText: '\$ ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.attach_money, color: Colors.green),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          enabled: !_isCreatingPayment,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _isCreatingPayment ? null : _createPayment,
                    icon: const Icon(Icons.payment),
                    label: const Text('Create Payment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Transactions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${_transactions.length} total', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: _transactions.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No transactions yet', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _transactions.length,
              itemBuilder: (context, index) {
                final transaction = _transactions[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: _getStatusColor(transaction.status).withOpacity(0.3), width: 2),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _getStatusColor(transaction.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        transaction.status == 'SUCCESS'
                            ? Icons.check_circle
                            : transaction.status == 'PENDING'
                            ? Icons.hourglass_empty
                            : transaction.status == 'CANCELLED'
                            ? Icons.cancel
                            : Icons.error_outline,
                        color: _getStatusColor(transaction.status),
                        size: 28,
                      ),
                    ),
                    title: Text('Booking #${transaction.bookingId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('\$${(transaction.amount + transaction.tip).toStringAsFixed(2)} USD', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(_formatDateTime(transaction.updatedAt ?? transaction.createdAt), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(transaction.status),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(transaction.status, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    onTap: () => _showTransactionDetails(transaction),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}