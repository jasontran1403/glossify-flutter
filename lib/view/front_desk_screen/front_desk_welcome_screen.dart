import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:decimal/decimal.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hair_sallon/view/front_desk_screen/phone_verification_dialog.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';

import '../../api/api_service.dart';
import '../../api/payment_websocket_service.dart';
import '../get_started/get_started.dart';
import '../owner_screen/qr_scanner/qr_scanner_screen.dart';
import '../receptionist_screen/checkin_screen.dart';
import '../receptionist_screen/schedule_calendar_screen.dart';
import 'topup_qr_scanner_screen.dart';

class FrontDeskWelcomeScreen extends StatefulWidget {
  const FrontDeskWelcomeScreen({super.key});

  @override
  State<FrontDeskWelcomeScreen> createState() => _FrontDeskWelcomeScreenState();
}

class _FrontDeskWelcomeScreenState extends State<FrontDeskWelcomeScreen> with TickerProviderStateMixin {
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;

  // ===== WEBSOCKET =====
  final _wsService = PaymentWebSocketService();
  StreamSubscription? _wsSubscription;
  bool _isWebSocketConnected = false;
  String _lastMessageReceived = 'None';
  DateTime? _lastMessageTime;

  // ===== WEBSOCKET HEALTH CHECK (PING/PONG) =====
  Timer? _pingTimer;
  Timer? _pongTimer;
  bool _waitingForPong = false;
  int _pingSequence = 0;
  static const Duration _pingInterval = Duration(seconds: 1);
  static const Duration _pongTimeout = Duration(seconds: 3);

  // ===== WEBSOCKET RECONNECTION =====
  Timer? _reconnectTimer;
  Timer? _statusUpdateTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectInterval = Duration(seconds: 15);
  static const Duration _statusUpdateInterval = Duration(seconds: 1);

  // ===== BOOKING DATA =====
  Map<String, dynamic>? _currentBooking;

  // ===== PAYMENT STATE =====
  bool _isInPaymentMode = false;
  late AnimationController _paymentAnimationController;
  late Animation<double> _paymentAnimation;
  double _tipAmount = 0.0;
  final TextEditingController _tipController = TextEditingController();
  String _selectedTipOption = '';
  int _selectedPaymentMethod = 2;
  bool _showCryptoQR = false;
  String _cryptoWalletAddress = '';

  // GIFT CARD STATE
  List<Map<String, dynamic>> _scannedGiftCards = [];
  double _giftCardTotalAmount = 0.0;

  // TIP DEBOUNCE TIMER (FIX #1)
  Timer? _tipDebounceTimer;

  // ===== TOPUP STATE =====
  bool _isInTopupMode = false;
  late AnimationController _topupAnimationController;
  late Animation<double> _topupAnimation;

  final Map<int, String> _paymentMethods = {
    2: 'Credit Card',
    1: 'Cash',
    3: 'Giftcard',
    4: 'Crypto',
    5: 'Others'
  };

  final Map<int, IconData> _paymentIcons = {
    2: Icons.credit_card,
    1: Icons.money,
    3: Icons.wallet_giftcard,
    4: Icons.currency_bitcoin,
    5: Icons.devices_other
  };

  int? _storeId; // NEW: Store storeId

  @override
  void initState() {
    super.initState();

    if (Platform.isAndroid) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else if (Platform.isIOS) {
      try {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } catch (e) {
        print('iOS Orientation error (ignored): $e');
      }
    }

    _paymentAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _paymentAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _paymentAnimationController,
      curve: Curves.easeInOut,
    ));

    _topupAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _topupAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _topupAnimationController,
      curve: Curves.easeInOut,
    ));

    _initVideo();
    _initWebSocket();
    _startStatusUpdateTimer();
    _fetchStoreId(); // NEW: Fetch storeId once
  }

  Future<void> _fetchStoreId() async {
    try {
      _storeId = await ApiService.getStoreId();
      print('Store ID fetched: $_storeId'); // Optional log
    } catch (e) {
      print('Error fetching storeId: $e');
      // Optionally set default or handle error
    }
  }

  void _startStatusUpdateTimer() {
    _statusUpdateTimer = Timer.periodic(_statusUpdateInterval, (timer) {
      if (mounted) {
        setState(() {
          _isWebSocketConnected = _wsService.isConnected;
        });
      }
    });
  }

  Future<void> _initVideo() async {
    _videoController = VideoPlayerController.asset("assets/videos/introducing.mp4");
    await _videoController.initialize();
    _videoController.setLooping(true);
    _videoController.play();
    if (mounted) {
      setState(() => _isVideoInitialized = true);
    }
  }

  void _initWebSocket() async {
    _cancelReconnectTimer();
    _stopPingTimer();
    const wsUrl = 'wss://api.glossify.salon/ws/payment';

    try {
      await _wsService.connect(wsUrl);

      _reconnectAttempts = 0;
      setState(() {
        _isWebSocketConnected = true;
      });

      _wsSubscription = _wsService.messages.listen((message) {
        if (mounted) {
          setState(() {
            _lastMessageReceived = message['type']?.toString() ?? 'Unknown';
            _lastMessageTime = DateTime.now();
          });
        }
        _handleWebSocketMessage(message);
      }, onError: (error) {
        print('FrontDeskWelcomeScreen: WebSocket error: $error');
        _handleWebSocketDisconnection();
      }, onDone: () {
        _handleWebSocketDisconnection();
      });

      // Send first PING immediately (no await)
      _sendPing();

      // Then start timer
      _startPingTimer();
    } catch (error) {
      print('FrontDeskWelcomeScreen: Failed to connect: $error');
      _handleWebSocketDisconnection();
    }
  }

  void _startPingTimer() {
    _pingTimer = Timer.periodic(_pingInterval, (timer) {
      if (mounted && _wsService.isConnected && !_waitingForPong) {
        _sendPing();
      }
    });
  }

  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _pongTimer?.cancel();
    _pongTimer = null;
    _waitingForPong = false;
    _pingSequence = 0;
  }

  void _sendPing() async {
    _pingSequence++;

    final deviceInfo = await getDeviceInfo();

    final pingMessage = {
      'type': 'PING',
      'sequence': _pingSequence,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'deviceInfo': {
        'deviceName': deviceInfo['deviceName'],
        'platform': deviceInfo['platform'],
        'version': deviceInfo['version'],
        'fingerprint': deviceInfo['fingerprint'],  // NEW
      },
    };

    _wsService.sendMessage(pingMessage);

    _waitingForPong = true;

    _pongTimer = Timer(_pongTimeout, () {
      if (_waitingForPong) {
        _handleWebSocketDisconnection();
      }
    });
  }


  Future<Map<String, String>> getDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();

    String deviceName = "Unknown Device";
    String platform = Platform.operatingSystem;
    String version = "Unknown";
    String fingerprint = "unknown";  // NEW

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        deviceName = "${androidInfo.manufacturer} ${androidInfo.model}";
        platform = "Android";
        version = androidInfo.version.release;

        // Generate fingerprint from unique device identifiers
        fingerprint = _generateFingerprint([
          androidInfo.id,                    // Android ID (unique per device)
          androidInfo.model,                 // Device model
          androidInfo.manufacturer,          // Manufacturer
          androidInfo.device,                // Device codename
          androidInfo.fingerprint,           // Android build fingerprint
        ]);

      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        deviceName = iosInfo.name ?? iosInfo.model ?? "iOS Device";
        platform = "iOS";
        version = iosInfo.systemVersion;

        // Generate fingerprint from unique device identifiers
        fingerprint = _generateFingerprint([
          iosInfo.identifierForVendor ?? "",  // Unique ID for vendor
          iosInfo.model,                      // Device model
          iosInfo.systemVersion,              // iOS version
          iosInfo.name,                       // Device name
          iosInfo.utsname.machine,            // Hardware model (e.g., iPhone15,2)
        ]);
      }
    } catch (e) {
      print("Failed to get device info: $e");
    }

    return {
      "deviceName": deviceName,
      "platform": platform,
      "version": version,
      "fingerprint": fingerprint,  // NEW
    };
  }

  /// Generate unique fingerprint from device identifiers
  String _generateFingerprint(List<String?> identifiers) {
    // Filter out null values and join
    final validIdentifiers = identifiers
        .where((id) => id != null && id.isNotEmpty)
        .join('|');

    // Generate MD5 hash
    final bytes = utf8.encode(validIdentifiers);
    final digest = md5.convert(bytes);

    return digest.toString();
  }



  void _handlePong(Map<String, dynamic> message) {
    if (message['type'] == 'PONG') {
      final receivedSeq = message['sequence'] as int?;

      if (receivedSeq == _pingSequence) {
        _waitingForPong = false;
        _pongTimer?.cancel();

        // Reset reconnect counter
        if (_reconnectAttempts > 0) {
          _reconnectAttempts = 0;
        }
      }
    }
  }

  void _handleWebSocketDisconnection() {
    _stopPingTimer();
    setState(() {
      _isWebSocketConnected = false;
    });
    if (_reconnectAttempts < _maxReconnectAttempts) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectAttempts++;
    _reconnectTimer = Timer(_reconnectInterval, () {
      _initWebSocket();
    });
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _cancelStatusUpdateTimer() {
    _statusUpdateTimer?.cancel();
    _statusUpdateTimer = null;
  }

  void _handleWebSocketMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;

    // CRITICAL: Handle PONG FIRST
    if (type == 'PONG') {
      _handlePong(message);
      return;
    }

    final data = message['data'] as Map<String, dynamic>?;

    if (data == null) {
      return;
    }

    switch (type) {
      case 'BOOKING_TO_PAYMENT':
        if (!_isInPaymentMode && !_isInTopupMode && !_isNavigating) {
          if (mounted) {
            setState(() {
              _currentBooking = data;
              _isInPaymentMode = true;
              _tipAmount = 0.0;
              _tipController.clear();
              _selectedTipOption = '';
              _selectedPaymentMethod = 2;
              _showCryptoQR = false;
              _cryptoWalletAddress = data['wallet'] as String? ?? '';
              _scannedGiftCards.clear();
              _giftCardTotalAmount = 0.0;
            });
          }
          _paymentAnimationController.forward();
        }
        break;

      case 'PAYMENT_COMPLETED':
        final incomingBookingId = data['bookingId'] as int?;
        final currentBookingId = _currentBooking?['bookingId'] as int?;
        if (incomingBookingId == currentBookingId) {
          _returnToWelcomeScreen();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 20),
                    SizedBox(width: 12),
                    Expanded(child: Text('Payment completed successfully!')),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
        break;

      case 'CANCEL_PAYMENT':
        final incomingBookingId = data['bookingId'] as int?;
        final currentBookingId = _currentBooking?['bookingId'] as int?;
        if (incomingBookingId == currentBookingId) {
          _returnToWelcomeScreen();
        }
        break;

      case 'TOPUP_COMPLETED':
      case 'TOPUP_CANCELLED':
        _returnToWelcomeScreen();
        break;

      default:
        print('Unknown WebSocket message type: $type');
    }
  }

  void _returnToWelcomeScreen() {
    if (_isInPaymentMode) {
      _paymentAnimationController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _currentBooking = null;
            _isInPaymentMode = false;
            _tipAmount = 0.0;
            _tipController.clear();
            _selectedTipOption = '';
            _showCryptoQR = false;
            _scannedGiftCards.clear();
            _giftCardTotalAmount = 0.0;
          });
        }
      });
    }

    if (_isInTopupMode) {
      _topupAnimationController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _isInTopupMode = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _cancelReconnectTimer();
    _cancelStatusUpdateTimer();
    _stopPingTimer();
    _wsSubscription?.cancel();
    _videoController.dispose();
    _tipController.dispose();
    _paymentAnimationController.dispose();
    _topupAnimationController.dispose();
    _tipDebounceTimer?.cancel(); // FIX #1: Cancel debounce timer
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  //---------------------
  // NAVIGATION
  //---------------------
  bool _isNavigating = false;

  void _navigateToCheckIn() {
    if (_isInPaymentMode || _isInTopupMode) return;
    setState(() => _isNavigating = true);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CheckInScreen()),
    ).then((_) {
      setState(() => _isNavigating = false);
    });
  }

  Future<void> _navigateToBooking() async {
    if (_isInPaymentMode || _isInTopupMode) return;
    if (mounted) {
      setState(() => _isNavigating = true);
    }

    // NEW: No need for loading dialog since storeId is pre-fetched

    try {
      // Use pre-fetched storeId
      final storeId = _storeId;
      if (storeId == null) {
        // Fallback fetch if not available (unlikely)
        await _fetchStoreId();
        if (_storeId == null) {
          throw Exception('Failed to get store ID');
        }
      }

      // Show phone verification dialog
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const PhoneVerificationDialog(),
      );

      if (!mounted) return;

      if (result == null || result['success'] != true) {
        if (mounted) {
          setState(() => _isNavigating = false);
        }
        return;
      }

      final int userId = result['userId'];

      // Navigate with dynamic storeId
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScheduleCalendarScreen(
            serviceIds: [1, 2, 3],
            serviceNames: ['Test1', 'Test2', 'Test3'],
            storeId: storeId!, // Dynamic
            userId: userId,
          ),
        ),
      );
    } catch (e) {
      print('Error in _navigateToBooking: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Error: $e'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() => _isNavigating = false);
      }
    } finally {
      if (mounted) {
        setState(() => _isNavigating = false);
      }
    }
  }

  //---------------------
  // GIFT CARD FUNCTIONS
  //---------------------

  Future<void> _openGiftCardScanner() async {
    if (_currentBooking == null) return;

    final amountAfterDiscount = (_currentBooking!['amountAfterDiscount'] as num).toDouble();
    final serviceItems = _currentBooking!['serviceItems'] as List<dynamic>?;
    final fee = (_currentBooking!['fee'] as num?)?.toDouble() ?? 0.0;
    final serviceCount = serviceItems?.length ?? 0;
    final cashDiscount = _selectedPaymentMethod == 1 ? (fee * serviceCount) : 0.0;

    // FIX: Calculate what we still need to scan
    final totalNeeded = amountAfterDiscount - cashDiscount + _tipAmount;
    final shortage = totalNeeded - _giftCardTotalAmount;

    // If we have cards already, only scan the shortage. Otherwise scan the full amount.
    final amountToScan = _giftCardTotalAmount > 0
        ? (shortage > 0 ? shortage : 0.01) // Minimum 0.01 to prevent 0 scan
        : totalNeeded;

    if (amountToScan <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gift cards already cover the full amount!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QRScannerScreen(
          maxAmount: amountToScan,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      _handleGiftCardScanResult(result);
    }
  }

  // FIX #2: Allow scanning same card multiple times if balance remains
  void _handleGiftCardScanResult(Map<String, dynamic> result) {
    final String code = result['code'];
    final double deductAmount = result['deductAmount'];
    final double balance = result['balance'];

    // Find if this card already exists
    final existingCardIndex = _scannedGiftCards.indexWhere(
          (card) => card['code'] == code,
    );

    if (existingCardIndex != -1) {
      // Card already scanned - check if it has remaining balance
      final existingCard = _scannedGiftCards[existingCardIndex];
      final currentUsed = (existingCard['usedAmount'] as num).toDouble();
      final currentBalance = (existingCard['balance'] as num).toDouble();
      final remainingBalance = currentBalance - currentUsed;

      if (remainingBalance <= 0.01) {
        // No balance left
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This gift card has no remaining balance.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      // Has remaining balance - update the card by adding more deduction
      setState(() {
        _scannedGiftCards[existingCardIndex] = {
          'code': code,
          'balance': balance,
          'usedAmount': currentUsed + deductAmount,
        };
        _calculateGiftCardTotal();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gift card updated: +${_formatCurrency(deductAmount)} (Total used: ${_formatCurrency(currentUsed + deductAmount)})',
          ),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // New card - add it normally
    setState(() {
      _scannedGiftCards.add({
        'code': code,
        'balance': balance,
        'usedAmount': deductAmount,
      });
      _calculateGiftCardTotal();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gift card added: ${_formatCurrency(deductAmount)}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _removeGiftCard(String code) {
    setState(() {
      _scannedGiftCards.removeWhere((card) => card['code'] == code);
      _calculateGiftCardTotal();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gift card removed'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _calculateGiftCardTotal() {
    double total = 0.0;
    for (var card in _scannedGiftCards) {
      total += (card['usedAmount'] as num).toDouble();
    }
    _giftCardTotalAmount = total;
  }

  // FIX #1: Add debounce to prevent popup spam
  void _handleTipChange(double newTipAmount) {
    setState(() {
      _tipAmount = newTipAmount;
    });

    // Cancel previous timer
    _tipDebounceTimer?.cancel();

    if (_selectedPaymentMethod == 3 && _scannedGiftCards.isNotEmpty) {
      _tipDebounceTimer = Timer(const Duration(seconds: 1), () {
        _adjustGiftCardsForTipChange();
      });
    }
  }

// NEW: Automatically adjust gift cards when tips change
  void _adjustGiftCardsForTipChange() {
    if (_currentBooking == null || _scannedGiftCards.isEmpty) return;

    final amountAfterDiscount = (_currentBooking!['amountAfterDiscount'] as num).toDouble();
    final serviceItems = _currentBooking!['serviceItems'] as List<dynamic>?;
    final fee = (_currentBooking!['fee'] as num?)?.toDouble() ?? 0.0;
    final serviceCount = serviceItems?.length ?? 0;
    final cashDiscount = _selectedPaymentMethod == 1 ? (fee * serviceCount) : 0.0;

    final remainingAmount = amountAfterDiscount - cashDiscount;
    final totalNeeded = remainingAmount + _tipAmount;
    final currentTotal = _giftCardTotalAmount;

    final difference = totalNeeded - currentTotal;

    if (difference > 0.01) {
      // CASE 1: Tips INCREASED → Shortage
      _showGiftCardShortageDialog(difference);
    } else if (difference < -0.01) {
      // CASE 2: Tips DECREASED → Excess, need to reduce scanned cards
      final excess = -difference;
      _reduceGiftCardAmount(excess);
    }
    // If difference is ~0, do nothing
  }

// NEW: Reduce gift card amount by removing from the last cards
  void _reduceGiftCardAmount(double excessAmount) {
    double toReduce = excessAmount;

    // Start from the LAST card and work backwards
    for (int i = _scannedGiftCards.length - 1; i >= 0 && toReduce > 0.01; i--) {
      final card = _scannedGiftCards[i];
      final currentUsed = (card['usedAmount'] as num).toDouble();

      if (currentUsed > toReduce) {
        // Reduce this card partially
        setState(() {
          _scannedGiftCards[i]['usedAmount'] = currentUsed - toReduce;
        });
        toReduce = 0;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gift card ${card['code']} reduced by ${_formatCurrency(excessAmount)}',
            ),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // Remove this card completely
        toReduce -= currentUsed;
        final removedCode = card['code'] as String;

        setState(() {
          _scannedGiftCards.removeAt(i);
        });

        if (toReduce <= 0.01) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gift card $removedCode removed (tips reduced)'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }

    _calculateGiftCardTotal();
  }

  void _validateGiftCardCoverage() {
    if (_currentBooking == null) return;

    final amountAfterDiscount = (_currentBooking!['amountAfterDiscount'] as num).toDouble();
    final serviceItems = _currentBooking!['serviceItems'] as List<dynamic>?;
    final fee = (_currentBooking!['fee'] as num?)?.toDouble() ?? 0.0;
    final serviceCount = serviceItems?.length ?? 0;
    final cashDiscount = _selectedPaymentMethod == 1 ? (fee * serviceCount) : 0.0;

    final remainingAmount = amountAfterDiscount - cashDiscount;
    final totalNeeded = remainingAmount + _tipAmount;
    final shortage = totalNeeded - _giftCardTotalAmount;

    if (shortage > 0.01) {
      _showGiftCardShortageDialog(shortage);
    }
  }

  void _showGiftCardShortageDialog(double shortage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 28),
            const SizedBox(width: 12),
            const Text('Insufficient Gift Card Amount', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your gift cards don\'t cover the full amount including tips.',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Gift card total:', style: TextStyle(fontSize: 13)),
                      Text(
                        _formatCurrency(_giftCardTotalAmount),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Amount needed:', style: TextStyle(fontSize: 13)),
                      Text(
                        _formatCurrency(_giftCardTotalAmount + shortage),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Shortage:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      Text(
                        _formatCurrency(shortage),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _scannedGiftCards.clear();
                _giftCardTotalAmount = 0.0;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All gift cards cleared. Please scan again.'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Clear & Rescan'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _openGiftCardScanner();
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan More'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  //---------------------
  // TOPUP FUNCTIONS
  //---------------------

  void _openTopupScanner() async {
    if (_isInPaymentMode || _isInTopupMode) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TopupQRScannerScreen(),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      _handleTopupScanResult(result);
    }
  }

  void _handleTopupScanResult(Map<String, dynamic> result) {
    final String code = result['code'];
    final double amount = result['amount'];
    final int paymentMethod = result['paymentMethod'];
    final bool isNewCard = result['isNewCard'];
    final double currentBalance = result['currentBalance'];

    final topupRequest = {
      'type': 'TOPUP_REQUEST',
      'data': {
        'code': code,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'isNewCard': isNewCard,
        'currentBalance': currentBalance,
      },
    };

    _wsService.sendMessage(topupRequest);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.send, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(child: Text('Top-up request sent to Receptionist')),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );
  }

  //---------------------
  // PAYMENT PROCESSING
  //---------------------

  void _confirmPaymentMethod() {
    if (_currentBooking == null) return;

    final bookingId = _currentBooking!['bookingId'] as int;
    final serviceItems = _currentBooking!['serviceItems'] as List<dynamic>?;
    final fee = (_currentBooking!['fee'] as num?)?.toDouble() ?? 0.0;
    final serviceCount = serviceItems?.length ?? 0;
    final cashDiscount = _selectedPaymentMethod == 1 ? (fee * serviceCount) : 0.0;

    List<Map<String, dynamic>> giftCardUsages = [];
    if (_selectedPaymentMethod == 3 && _scannedGiftCards.isNotEmpty) {
      giftCardUsages = _scannedGiftCards.map((card) {
        final String code = card['code'];
        final double balance = (card['balance'] as num).toDouble();
        final double usedAmount = (card['usedAmount'] as num).toDouble();

        return {
          'code': code,
          'deductedAmount': usedAmount,
          'remainingBalance': balance - usedAmount,
        };
      }).toList();
    }

    final paymentMethodMessage = {
      'type': 'PAYMENT_METHOD_SELECTED',
      'data': {
        'bookingId': bookingId,
        'paymentMethod': _selectedPaymentMethod,
        'tip': _tipAmount,
        'cashDiscount': cashDiscount,
        'giftCardUsages': giftCardUsages,
        'giftCardAmount': _giftCardTotalAmount,
      },
    };

    _wsService.sendMessage(paymentMethodMessage);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(child: Text('Payment method sent to Receptionist')),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isInPaymentMode || _isInTopupMode) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please complete or cancel the operation first'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // VIDEO
            if (_isVideoInitialized)
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoController.value.size.width,
                    height: _videoController.value.size.height,
                    child: VideoPlayer(_videoController),
                  ),
                ),
              )
            else
              const Center(child: CircularProgressIndicator(color: Colors.white)),

            // GRADIENT
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.5),
                      Colors.black.withOpacity(0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // PAYMENT PANEL
            if (_isInPaymentMode && _currentBooking != null)
              Positioned.fill(
                child: FadeTransition(
                  opacity: _paymentAnimation,
                  child: _buildPaymentPanel(),
                ),
              ),

            // CRYPTO OVERLAY
            if (_showCryptoQR)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.8),
                  child: Center(child: _buildCryptoOverlay()),
                ),
              ),

            // BUTTONS
            if (!_isInPaymentMode && !_isInTopupMode && !_isNavigating)
              Positioned(
                bottom: 40,
                left: 40,
                right: 40,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildMainButton(
                      label: "BOOKING",
                      icon: Icons.calendar_today,
                      onTap: _navigateToBooking,
                      bg: Colors.transparent,
                      fg: Colors.white,
                    ),
                    const SizedBox(width: 30),
                    _buildMainButton(
                      label: "CHECK-IN",
                      icon: Icons.login,
                      onTap: _navigateToCheckIn,
                      bg: Colors.transparent,
                      fg: Colors.white,
                    ),
                    const SizedBox(width: 30),
                    _buildMainButton(
                      label: "TOP-UP",
                      icon: Icons.card_giftcard,
                      onTap: _openTopupScanner,
                      bg: Colors.transparent,
                      fg: Colors.white,
                    ),
                  ],
                ),
              ),

            // SIGN OUT
            if (!_isInPaymentMode && !_isInTopupMode)
              Positioned(
                top: 20,
                right: 20,
                child: Opacity(
                  opacity: 0.1,
                  child: IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white, size: 26),
                    onPressed: () async {
                      await ApiService.clearSession();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const GetStarted(initialPage: 0)),
                            (route) => false,
                      );
                    },
                  ),
                ),
              ),

            // DEBUG PANEL
            Positioned(
              bottom: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _isWebSocketConnected ? Colors.green : Colors.red,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isWebSocketConnected ? Icons.wifi : Icons.wifi_off,
                          color: _isWebSocketConnected ? Colors.green : Colors.red,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'WS: ${_isWebSocketConnected ? 'Connected' : 'Disconnected'}',
                          style: TextStyle(
                            color: _isWebSocketConnected ? Colors.green : Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Last: $_lastMessageReceived',
                      style: const TextStyle(color: Colors.white, fontSize: 9),
                    ),
                    if (_lastMessageTime != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Time: ${_lastMessageTime!.hour.toString().padLeft(2, '0')}:${_lastMessageTime!.minute.toString().padLeft(2, '0')}:${_lastMessageTime!.second.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: Colors.white70, fontSize: 8),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Payment: ${_isInPaymentMode ? 'ACTIVE' : 'IDLE'}',
                      style: TextStyle(
                        color: _isInPaymentMode ? Colors.yellow : Colors.white70,
                        fontSize: 9,
                        fontWeight: _isInPaymentMode ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Topup: ${_isInTopupMode ? 'ACTIVE' : 'IDLE'}',
                      style: TextStyle(
                        color: _isInTopupMode ? Colors.purple : Colors.white70,
                        fontSize: 9,
                        fontWeight: _isInTopupMode ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required Color bg,
    required Color fg,
    bool border = false,
  }) {
    return SizedBox(
      width: 200,
      height: 70,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          side: border ? const BorderSide(color: Colors.white, width: 3) : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  //------------------------------
  // PAYMENT PANEL UI
  //------------------------------
  Widget _buildPaymentPanel() {
    final bookingId = _currentBooking!['bookingId'] as int;
    final customerName = _currentBooking!['customerName'] as String;
    final amountAfterDiscount = (_currentBooking!['amountAfterDiscount'] as num).toDouble();
    final serviceItems = _currentBooking!['serviceItems'] as List<dynamic>?;
    final fee = (_currentBooking!['fee'] as num?)?.toDouble() ?? 0.0;
    final serviceCount = serviceItems?.length ?? 0;
    final cashDiscount = _selectedPaymentMethod == 1 ? (fee * serviceCount) : 0.0;
    final remainingAmount = amountAfterDiscount - cashDiscount;
    final totalAmount = remainingAmount + _tipAmount;

    return Center(
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 650),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.payment, color: Color(0xFF3B82F6), size: 28),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Select Payment Method",
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Booking #$bookingId | $customerName",
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // CONTENT
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TIP + PAYMENT METHOD
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // TIP SECTION
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Add Tip (Optional)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _buildCompactTipButton('10%', () {
                                    _handleTipChange(remainingAmount * 0.10);
                                    setState(() {
                                      _selectedTipOption = '10%';
                                      _tipController.clear();
                                    });
                                  }),
                                  const SizedBox(width: 4),
                                  _buildCompactTipButton('15%', () {
                                    _handleTipChange(remainingAmount * 0.15);
                                    setState(() {
                                      _selectedTipOption = '15%';
                                      _tipController.clear();
                                    });
                                  }),
                                  const SizedBox(width: 4),
                                  _buildCompactTipButton('20%', () {
                                    _handleTipChange(remainingAmount * 0.20);
                                    setState(() {
                                      _selectedTipOption = '20%';
                                      _tipController.clear();
                                    });
                                  }),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: TextField(
                                  controller: _tipController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: 'Custom Tip',
                                    prefixText: '\$ ',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                    filled: true,
                                    fillColor: _selectedTipOption == 'custom' ? Colors.blue[50] : Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    labelStyle: const TextStyle(fontSize: 12),
                                  ),
                                  style: const TextStyle(fontSize: 12),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedTipOption = 'custom';
                                    });
                                    final newTip = double.tryParse(value) ?? 0.0;
                                    _handleTipChange(newTip);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // PAYMENT METHOD SECTION
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Payment Method',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Container(
                                constraints: const BoxConstraints(maxHeight: 100),
                                child: GridView.count(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisCount: 5,
                                  crossAxisSpacing: 3,
                                  mainAxisSpacing: 3,
                                  childAspectRatio: 1.1,
                                  children: _paymentMethods.entries.map((e) {
                                    final selected = _selectedPaymentMethod == e.key;
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedPaymentMethod = e.key;
                                          if (e.key == 4) {
                                            _showCryptoQR = true;
                                          } else {
                                            _showCryptoQR = false;
                                          }
                                        });
                                        if (e.key == 3) {
                                          _openGiftCardScanner();
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: selected ? const Color(0xFF3B82F6) : Colors.grey[200],
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: selected ? const Color(0xFF3B82F6) : Colors.grey[300]!,
                                            width: selected ? 2 : 1,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              _paymentIcons[e.key],
                                              size: 16,
                                              color: selected ? Colors.white : Colors.black87,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _getPaymentMethodShortName(e.key),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                                color: selected ? Colors.white : Colors.black87,
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // AMOUNT SUMMARY
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF3B82F6).withOpacity(0.1),
                            const Color(0xFF3B82F6).withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF3B82F6).withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          _amountRow("Amount After Discount:", _formatCurrency(amountAfterDiscount)),

                          if (cashDiscount > 0) ...[
                            _amountRow(
                              "Cash Discount:",
                              "- ${_formatCurrency(cashDiscount)}",
                              valueColor: Colors.green,
                            ),
                            _amountRow("Remaining:", _formatCurrency(remainingAmount)),
                          ],

                          // GIFT CARD SECTION
                          if (_selectedPaymentMethod == 3) ...[
                            if (_giftCardTotalAmount > 0) ...[
                              _amountRow(
                                "Gift Card Amount:",
                                "- ${_formatCurrency(_giftCardTotalAmount)}",
                                valueColor: Colors.purple,
                              ),

                              Builder(
                                builder: (context) {
                                  final totalNeeded = remainingAmount + _tipAmount;
                                  final shortage = totalNeeded - _giftCardTotalAmount;

                                  if (shortage > 0.01) {
                                    return Column(
                                      children: [
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.red.shade200),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.warning_amber, color: Colors.red.shade700, size: 16),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Shortage: ${_formatCurrency(shortage)} - Scan more or adjust tips',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.red.shade900,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: Icon(Icons.delete_outline, color: Colors.red.shade700, size: 18),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: () {
                                                  setState(() {
                                                    _scannedGiftCards.clear();
                                                    _giftCardTotalAmount = 0.0;
                                                  });
                                                },
                                                tooltip: 'Clear all cards',
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }

                                  return _amountRow(
                                    "Remaining After Gift Card:",
                                    _formatCurrency((totalNeeded - _giftCardTotalAmount).clamp(0, double.infinity)),
                                  );
                                },
                              ),
                            ] else ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Click the Giftcard button above to scan',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.blue.shade900,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],

                          if (_tipAmount > 0)
                            _amountRow("Tips:", _formatCurrency(_tipAmount)),

                          const SizedBox(height: 8),

                          _amountRow(
                            "Total Amount:",
                            _formatCurrency(totalAmount),
                            isBold: true,
                            valueColor: const Color(0xFF3B82F6),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ACTION BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _confirmPaymentMethod,
                icon: const Icon(Icons.send, color: Colors.white),
                label: const Text(
                  'Send to Receptionist',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCryptoOverlay() {
    final amountAfterDiscount = (_currentBooking!['amountAfterDiscount'] as num).toDouble();
    final totalAmount = amountAfterDiscount + _tipAmount;

    if (_cryptoWalletAddress.isEmpty) {
      return Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Crypto Wallet Not Available', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            Icon(Icons.error, color: Colors.red, size: 60),
            SizedBox(height: 20),
            Text('Wallet address not received'),
          ],
        ),
      );
    }

    const usdtContract = "0x55d398326f99059fF775485246999027B3197955";
    final receiver = _cryptoWalletAddress.trim();
    final totalAmountDecimal = Decimal.parse(totalAmount.toString());
    final decimals = Decimal.parse('1000000000000000000');
    final amountWei = (totalAmountDecimal * decimals).toBigInt();
    final qrData = "ethereum:$usdtContract@56/transfer?address=$receiver&uint256=$amountWei";

    return Container(
      width: 420,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Crypto Payment', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _showCryptoQR = false),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 220,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.H,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _formatCurrency(totalAmount),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() => _showCryptoQR = false),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _amountRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  String _getPaymentMethodShortName(int methodId) {
    switch (methodId) {
      case 2:
        return 'Credit';
      case 4:
        return 'Crypto';
      default:
        return _paymentMethods[methodId] ?? '';
    }
  }

  Widget _buildCompactTipButton(String label, VoidCallback onTap) {
    final selected = _selectedTipOption == label;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF3B82F6) : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? const Color(0xFF3B82F6) : const Color(0xFFE5E7EB),
              width: selected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }
}