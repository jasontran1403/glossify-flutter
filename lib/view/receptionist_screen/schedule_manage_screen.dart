import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:hair_sallon/view/receptionist_screen/schedule_management/booking_grid.dart';
import 'package:hair_sallon/view/receptionist_screen/schedule_management/booking_header.dart';
import 'package:hair_sallon/view/receptionist_screen/schedule_management/booking_state.dart';
import 'package:hair_sallon/view/receptionist_screen/schedule_management/drag_staff_sheet.dart';
import 'package:hair_sallon/view/receptionist_screen/schedule_management/appointment_detail_panel.dart';
import '../../api/api_service.dart';
import '../../api/available_service.dart';
import '../../api/payment_websocket_service.dart';
import '../../api/staff_schedule_model.dart';
import 'task_model.dart';

class ScheduleManagementScreen extends StatefulWidget {
  final int? storeId; // ⭐ CHANGED: Make optional

  const ScheduleManagementScreen({
    super.key,
    this.storeId, // ⭐ CHANGED: Optional parameter
  });

  @override
  State<ScheduleManagementScreen> createState() => _ScheduleManagementScreenState();
}

class _ScheduleManagementScreenState extends State<ScheduleManagementScreen> with SingleTickerProviderStateMixin {
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
  static const Duration _initialReconnectDelay = Duration(seconds: 2);
  static const Duration _maxReconnectDelay = Duration(seconds: 30);
  static const Duration _statusUpdateInterval = Duration(seconds: 1);

  Map<String, dynamic>? _pendingTopup;
  bool _isProcessingTopup = false;
  bool _isTopupDialogOpen = false; // ⭐ NEW FLAG

  Timer? _autoRefreshTimer;
  static const Duration _autoRefreshInterval = Duration(seconds: 5);

  int? _storeId;
  bool _isLoadingStoreId = false;
  String? _storeIdError;

  late BookingState scheduleState; // ⚠️ Giữ late nhưng sẽ init sau
  bool _isInitialized = false; // ⭐ NEW: Track initialization status

  bool _showStaffSheet = false;
  Task? _selectedTask;

  late TabController _tabController;
  int _currentTabIndex = 0;


  @override
  void initState() {
    super.initState();

    _initializeStoreId();
  }

  Future<void> _initializeStoreId() async {
    if (widget.storeId != null) {
      // ✅ Nếu đã truyền storeId từ ngoài → dùng luôn
      setState(() {
        _storeId = widget.storeId;
      });
      _initializeAfterStoreId();
    } else {
      // ⚠️ Nếu chưa có → fetch từ API
      await _fetchWorkingStoreId();
    }
  }

  // ⭐ NEW: Fetch working store ID from API
  Future<void> _fetchWorkingStoreId() async {
    setState(() {
      _isLoadingStoreId = true;
      _storeIdError = null;
    });

    try {
      final storeId = await ApiService.getWorkingStoreId();

      if (storeId != null) {
        setState(() {
          _storeId = storeId;
          _isLoadingStoreId = false;
        });

        // ✅ Có storeId rồi → khởi tạo các thứ khác
        _initializeAfterStoreId();
      } else {
        setState(() {
          _isLoadingStoreId = false;
          _storeIdError = 'Unable to get working store. Please check your account.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingStoreId = false;
        _storeIdError = 'Error: $e';
      });
    }
  }

  // ⭐ NEW: Initialize sau khi có storeId
  void _initializeAfterStoreId() {
    if (_storeId == null || _isInitialized) return;

    // ⭐ INIT TAB CONTROLLER
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!mounted) return;
      setState(() {
        _currentTabIndex = _tabController.index;
      });

      // Pause/resume auto-refresh
      if (_currentTabIndex != 0) {
        _stopAutoRefresh();
      } else {
        _startAutoRefresh();
      }
    });

    // ⭐ INIT BOOKING STATE với storeId đã có
    scheduleState = BookingState(
      storeId: _storeId!, // ✅ Bây giờ an toàn vì đã check != null
      onStateChanged: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
    scheduleState.initialize();
    scheduleState.fetchSchedule();

    // ⭐ INIT OTHER SERVICES
    _startStatusUpdateTimer();
    _initWebSocket();
    _startAutoRefresh();

    setState(() {
      _isInitialized = true;
    });
  }



  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();

    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // ⭐ CHỈ AUTO-REFRESH KHI Ở TAB ACTIVE (0), PENDING (1), hoặc DONE (2)
      if (_currentTabIndex == 0 || _currentTabIndex == 1 || _currentTabIndex == 2) {
        // ⭐ fetchScheduleIncremental() sẽ tự động:
        // - Detect bookings mới → fade IN
        // - Detect bookings đã chuyển trạng thái → fade OUT
        scheduleState.fetchScheduleIncremental();

        // ⭐ Log current bookings for debugging
        final activeCount = scheduleState.tasks.where((t) =>
        t.status == 'BOOKED' || t.status == 'NEW_BOOKED' ||
            t.status == 'CHECKED_IN' || t.status == 'IN_PROGRESS' ||
            t.status == 'REQUEST_MORE_STAFF'
        ).length;

        final pendingCount = scheduleState.tasks.where((t) =>
        t.status == 'WAITING_PAYMENT'
        ).length;

        final doneCount = scheduleState.tasks.where((t) =>
        t.status == 'PAID'
        ).length;
      }
    });
  }


  // ⭐ THÊM METHOD MỚI: Stop auto-refresh
  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }


  void _startStatusUpdateTimer() {
    _statusUpdateTimer = Timer.periodic(_statusUpdateInterval, (timer) {
      if (mounted) {
        setState(() {
          _isWebSocketConnected = _wsService.isConnected;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _cancelStatusUpdateTimer() {
    _statusUpdateTimer?.cancel();
    _statusUpdateTimer = null;
  }

  // ===== WEBSOCKET INITIALIZATION =====
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
        print('❌ FrontDeskWelcomeScreen: WebSocket error: $error');
        _handleWebSocketDisconnection();
      }, onDone: () {
        _handleWebSocketDisconnection();
      });

      // ⭐ Send first PING immediately (no await)
      _sendPing();

      // Then start timer
      _startPingTimer();
    } catch (error) {
      print('❌ FrontDeskWelcomeScreen: Failed to connect: $error');
      _handleWebSocketDisconnection();
    }
  }

  // ===== PING/PONG HEALTH CHECK =====
  void _startPingTimer() {
    _pingTimer = Timer.periodic(_pingInterval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_wsService.isConnected && !_waitingForPong) {
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
        'fingerprint': deviceInfo['fingerprint'],  // ⭐ NEW
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
    String fingerprint = "unknown";  // ⭐ NEW

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        deviceName = "${androidInfo.manufacturer} ${androidInfo.model}";
        platform = "Android";
        version = androidInfo.version.release;

        // ⭐ Generate fingerprint from unique device identifiers
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

        // ⭐ Generate fingerprint from unique device identifiers
        fingerprint = _generateFingerprint([
          iosInfo.identifierForVendor ?? "",  // Unique ID for vendor
          iosInfo.model,                      // Device model
          iosInfo.systemVersion,              // iOS version
          iosInfo.name,                       // Device name
          iosInfo.utsname.machine,            // Hardware model (e.g., iPhone15,2)
        ]);
      }
    } catch (e) {
      print("⚠️ Failed to get device info: $e");
    }

    return {
      "deviceName": deviceName,
      "platform": platform,
      "version": version,
      "fingerprint": fingerprint,  // ⭐ NEW
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

        // ⭐ Reset reconnect counter on successful PONG
        if (_reconnectAttempts > 0) {
          _reconnectAttempts = 0;
        }
      }
    }
  }

  void _handleWebSocketDisconnection() {
    _stopPingTimer();

    if (!mounted) {
      return;
    }

    setState(() {
      _isWebSocketConnected = false;
    });

    if (_reconnectAttempts < _maxReconnectAttempts) {
      _scheduleReconnect();
    }
  }

// ===== In _scheduleReconnect() =====
  void _scheduleReconnect() {
    if (!mounted) {
      return;
    }

    _reconnectAttempts++;

    final baseDelay = _initialReconnectDelay.inSeconds * pow(2, _reconnectAttempts - 1);
    final jitter = Random().nextDouble() * 0.3;
    final delaySeconds = min(baseDelay * (1 + jitter), _maxReconnectDelay.inSeconds);


    _reconnectTimer = Timer(Duration(seconds: delaySeconds.toInt()), () {
      if (!mounted) {
        return;
      }
      _initWebSocket();
    });
  }


  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _handleWebSocketMessage(Map<String, dynamic> message) {
    if (!mounted) return;

    final type = message['type'] as String?;

    // ⭐ CRITICAL: Handle PONG FIRST, before checking data
    if (type == 'PONG') {
      _handlePong(message);
      return;
    }

    final data = message['data'] as Map<String, dynamic>?;

    // ⚠️ Chỉ ignore nếu không phải PONG và không có data
    if (data == null) {
      return;
    }

    switch (type) {
      case 'PAYMENT_COMPLETED':
        final bookingId = data['bookingId'] as int?;
        if (bookingId != null) {
          scheduleState.fetchSchedule();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Payment completed for booking #$bookingId'),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
        break;

      case 'TOPUP_REQUEST':
        if (_isTopupDialogOpen) {
          return;
        }

        final incomingCode = data['code']?.toString() ?? '';
        final pendingCode = _pendingTopup?['code']?.toString() ?? '';

        if (incomingCode.isNotEmpty && incomingCode == pendingCode) {
          return;
        }

        setState(() {
          _pendingTopup = data;
        });
        _showTopupDialog();
        break;

      case 'TOPUP_COMPLETED':
        setState(() {
          _pendingTopup = null;
          _isProcessingTopup = false;
          _isTopupDialogOpen = false;
        });
        break;

      case 'TOPUP_CANCELLED':
        setState(() {
          _pendingTopup = null;
          _isProcessingTopup = false;
          _isTopupDialogOpen = false;
        });
        break;

      case 'PAYMENT_METHOD_SELECTED':
        break;

      case 'BOOKING_TO_PAYMENT_CONFIRMED':
        break;

      case 'CANCEL_PAYMENT_CONFIRMED':
        break;

      case 'PAYMENT_CANCELLED_FROM_FRONTDESK':
        scheduleState.fetchSchedule();
        break;

      default:
        print('❓ Unknown WebSocket message type: $type');
    }
  }

  void _showTopupDialog() {
    if (_pendingTopup == null) return;

    // ⭐ CHECK IF ALREADY OPEN
    if (_isTopupDialogOpen) {
      return;
    }

    final code = _pendingTopup!['code']?.toString() ?? '';
    final amount = (_pendingTopup!['amount'] ?? 0.0).toDouble();
    final paymentMethod = _pendingTopup!['paymentMethod'] ?? 0;
    final isNewCard = _pendingTopup!['isNewCard'] ?? false;
    final currentBalance = (_pendingTopup!['currentBalance'] ?? 0.0).toDouble();

    final paymentMethodName = paymentMethod == 1 ? 'Cash' : 'Credit Card';
    final cardStatus = isNewCard ? 'New Card' : 'Existing Card';

    // ⭐ SET FLAG BEFORE SHOWING DIALOG
    setState(() {
      _isTopupDialogOpen = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ═══════════════════════════════════════════════
              // HEADER
              // ═══════════════════════════════════════════════
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.card_giftcard,
                      color: Colors.purple.shade700,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gift Card Top-up',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade900,
                          ),
                        ),
                        Text(
                          cardStatus,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.purple.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // ═══════════════════════════════════════════════
              // CARD DETAILS
              // ═══════════════════════════════════════════════
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    _buildTopupInfoRow('Card Number', code, Icons.qr_code_2),
                    const SizedBox(height: 12),
                    _buildTopupInfoRow(
                      'Current Balance',
                      '\$${currentBalance.toStringAsFixed(2)}',
                      Icons.account_balance_wallet,
                    ),
                    const SizedBox(height: 12),
                    _buildTopupInfoRow(
                      'Top-up Amount',
                      '\$${amount.toStringAsFixed(2)}',
                      Icons.add_circle,
                      valueColor: Colors.green.shade700,
                    ),
                    const SizedBox(height: 12),
                    _buildTopupInfoRow(
                      'Payment Method',
                      paymentMethodName,
                      paymentMethod == 1 ? Icons.payments : Icons.credit_card,
                    ),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),

                    // NEW BALANCE
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'New Balance',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.purple.shade900,
                            ),
                          ),
                          Text(
                            '\$${(currentBalance + amount).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ═══════════════════════════════════════════════
              // ACTION BUTTONS
              // ═══════════════════════════════════════════════
              Row(
                children: [
                  // CANCEL BUTTON
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isProcessingTopup
                          ? null
                          : () {
                        Navigator.of(context).pop();
                        // ⭐ RESET FLAG AFTER CLOSING
                        setState(() {
                          _isTopupDialogOpen = false;
                        });
                        _cancelTopup();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.red.shade300, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cancel, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // COMPLETE BUTTON
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isProcessingTopup
                          ? null
                          : () {
                        Navigator.of(context).pop();
                        // ⭐ RESET FLAG AFTER CLOSING
                        setState(() {
                          _isTopupDialogOpen = false;
                        });
                        _completeTopup();
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.purple.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isProcessingTopup
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Complete Top-up',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      // ⭐ RESET FLAG WHEN DIALOG DISMISSED BY ANY MEANS
      if (mounted) {
        setState(() {
          _isTopupDialogOpen = false;
        });
      }
    });
  }

// ⭐ HELPER: BUILD INFO ROW
  Widget _buildTopupInfoRow(
      String label,
      String value,
      IconData icon, {
        Color? valueColor,
      }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: valueColor ?? Colors.grey.shade900,
          ),
        ),
      ],
    );
  }

  void _completeTopup() async {
    if (_pendingTopup == null || _isProcessingTopup) return;

    setState(() {
      _isProcessingTopup = true;
    });

    try {
      // ⭐ EXTRACT DATA FROM PENDING TOPUP
      final String code = _pendingTopup!['code']?.toString() ?? '';
      final double amount = (_pendingTopup!['amount'] ?? 0.0).toDouble();
      final int paymentMethod = _pendingTopup!['paymentMethod'] ?? 1;
      final String phoneNumber = _pendingTopup!['phoneNumber']?.toString() ?? '';

      // ⭐ CALL API
      final result = await ApiService.createOrTopupGiftCard(
        amount: amount,
        paymentMethod: paymentMethod,
        code: code.isEmpty ? null : code,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // ✅ API SUCCESS - SEND WEBSOCKET MESSAGE
        _wsService.sendMessage({
          'type': 'TOPUP_COMPLETED',
          'data': _pendingTopup,
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Gift card top-up completed: \$${amount.toStringAsFixed(2)}',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 3),
          ),
        );

        // ⭐ CRITICAL: CLEAR ALL STATE TO ALLOW NEW TOPUP
        setState(() {
          _pendingTopup = null;
          _isProcessingTopup = false;
          _isTopupDialogOpen = false;
        });
      } else {
        // ❌ API FAILED - KEEP STATE FOR RETRY
        setState(() {
          _isProcessingTopup = false;
          // ⚠️ DO NOT clear _pendingTopup or _isTopupDialogOpen
          // User might want to retry
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result['message'] ?? 'Failed to process top-up',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print('❌ Error completing topup: $e');

      if (mounted) {
        // ❌ NETWORK ERROR - KEEP STATE FOR RETRY
        setState(() {
          _isProcessingTopup = false;
          // ⚠️ DO NOT clear state - user might want to retry
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Network error: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: () {
                _completeTopup(); // ⭐ Allow retry
              },
            ),
          ),
        );
      }
    }
  }

// ⭐ CANCEL TOPUP - WITH PROPER STATE RESET
  void _cancelTopup() async {
    if (_pendingTopup == null || _isProcessingTopup) return;

    setState(() {
      _isProcessingTopup = true;
    });

    try {
      // Send TOPUP_CANCELLED message
      _wsService.sendMessage({
        'type': 'TOPUP_CANCELLED',
        'data': _pendingTopup,
      });

      // Show cancelled message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.cancel, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Gift card top-up cancelled'),
              ],
            ),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // ⭐ CRITICAL: CLEAR ALL STATE TO ALLOW NEW TOPUP
      setState(() {
        _pendingTopup = null;
        _isProcessingTopup = false;
        _isTopupDialogOpen = false;
      });
    } catch (e) {
      print('❌ Error cancelling topup: $e');

      // ⭐ Even if WebSocket fails, still clear state
      setState(() {
        _pendingTopup = null;
        _isProcessingTopup = false;
        _isTopupDialogOpen = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cancelReconnectTimer();
    _cancelStatusUpdateTimer();
    _stopPingTimer();
    _stopAutoRefresh(); // ⭐ THÊM VÀO dispose
    _wsSubscription?.cancel();

    scheduleState.dispose();

    super.dispose();
  }

  // ⭐ PULL TO REFRESH HANDLER
  Future<void> _handleRefresh() async {
    await scheduleState.fetchSchedule();
  }

  // ⭐ CLOSE SHIFT HANDLER - ĐỂ SẴN CHO USER TRIỂN KHAI
  void _handleCloseShift() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.exit_to_app, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Close', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Text('Are you sure you want to close the current shift? This will generate a PDF report and send it to Telegram.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _closeShiftWithApi();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  // ⭐ LOADING DIALOG HELPER
  void _showLoadingDialog({String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.blue),
              const SizedBox(height: 16),
              Text(
                message ?? 'Closing shift...',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ⭐ DISMISS LOADING DIALOG
  void _dismissLoadingDialog() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _closeShiftWithApi() async {
    // ⭐ SHOW SPINNER DIALOG FOR LOADING
    _showLoadingDialog();

    try {
      // ✅ GỌI API CLOSE SHIFT (không truyền shiftData nữa)
      final response = await ApiService.closeShift();  // Trả Map<String, dynamic>

      // ⭐ Đóng loading dialog trước khi xử lý response
      _dismissLoadingDialog();

      print(response);

      // ⭐ KIỂM TRA SUCCESS - KHÔNG THROW MESSAGE NỮA, CHỈ THROW NẾU KHÔNG PHẢI SUCCESS
      if (response['status'] == 'success') {
        // ⭐ HIỂN THỊ SUCCESS TOAST VỚI ICON CHECK THAY VÌ SPINNER
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    response['message'] ?? 'Shift closed successfully. PDF report sent to Telegram!',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        // Optional: Navigate to dashboard or refresh data
        // Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        // ⭐ CHỈ THROW NẾU CÓ MESSAGE ERROR THỰC SỰ
        throw Exception(response['message'] ?? 'Unknown error (non-success response)');
      }
    } catch (e) {
      // ⭐ ĐÓNG LOADING TRƯỚC KHI HIỂN THỊ ERROR
      _dismissLoadingDialog();

      // ⭐ CHỈ HIỂN THỊ ERROR THỰC SỰ, KHÔNG PHẢI SUCCESS MESSAGE
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error closing shift: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // Helper method để filter tasks cho từng tab
  List<Task> _getFilteredTasksForTab(int tabIndex) {
    final allTasks = scheduleState.tasks;

    switch (tabIndex) {
      case 0: // Active
        return allTasks.where((task) =>
        task.status == 'BOOKED' ||
            task.status == 'NEW_BOOKED' ||
            task.status == 'CHECKED_IN' ||
            task.status == 'IN_PROGRESS' ||
            task.status == 'REQUEST_MORE_STAFF'
        ).toList();

      case 1: // Waiting payment
        return allTasks.where((task) => task.status == 'WAITING_PAYMENT').toList();

      case 2: // Paid
        return allTasks.where((task) => task.status == 'PAID').toList();

      case 3: // Canceled
        return allTasks.where((task) => task.status == 'CANCELED').toList();

      default:
        return allTasks;
    }
  }

  void _handleCardTap(Task task) {
    if (!mounted) return;

    setState(() {
      if (_showStaffSheet) {
        _showStaffSheet = false;
      }
      _selectedTask = task;
    });
  }

  void _closeDetailPanel() {
    if (!mounted) return;

    setState(() {
      _selectedTask = null;
    });
  }

  void _toggleStaffSheet() {
    if (!mounted) return;

    setState(() {
      if (_selectedTask != null) {
        _selectedTask = null;
      }
      _showStaffSheet = !_showStaffSheet;
    });
  }

  // ⭐ MAIN HANDLER: Khi drop staff vào booking card
  void _handleStaffDropOnCard(StaffSchedule droppedStaff, Task task) {
    if (!mounted) return;

    // Check xem droppedStaff đã có trong booking chưa
    bool staffAlreadyExists = task.hasStaff(droppedStaff.staffId);

    if (staffAlreadyExists) {
      _showInfoDialog('${droppedStaff.fullName} is already assigned to this booking');
      return;
    }

    // Có nhiều staff trong booking → hiển thị dialog chọn action
    if (task.hasMultipleStaffs || task.staffId != null) {
      _showReplaceOrAddDialog(droppedStaff, task);
    } else {
      // Booking chưa có staff → assign trực tiếp
      _performStaffReassignment(droppedStaff, task);
    }
  }

  // ⭐ Dialog info đơn giản
  void _showInfoDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 12),
            Text('Information', style: TextStyle(fontSize: 18)),
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

  // ⭐ Dialog chọn Replace hoặc Add - WITH markUnchange CHECK
  void _showReplaceOrAddDialog(StaffSchedule newStaff, Task task) {
    // ⭐ CHECK: Nếu markUnchange = true → chỉ cho phép Add
    final bool canReplace = task.markUnchange != true;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.people_alt, color: Colors.blue, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Staff Assignment',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          // ⭐ SHOW WARNING IF markUnchange = true
                          if (!canReplace)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.lock, size: 14, color: Colors.orange[700]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Replace locked - Add only',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Booking info
                      _buildBookingInfoCard(task),
                      const SizedBox(height: 20),

                      // New staff info
                      Text(
                        'Assign Staff:',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildStaffCard(newStaff, Colors.blue, isNew: true),

                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),

                      Text(
                        'Choose Action:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ⭐ CONDITIONAL: Replace options ONLY if canReplace
                      if (canReplace) ...[
                        Text(
                          'Replace existing staff:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildReplaceStaffOption(task, newStaff),
                        const SizedBox(height: 16),
                      ] else ...[
                        // ⭐ SHOW WARNING BOX
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[300]!, width: 2),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.lock, color: Colors.orange[700], size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'This booking cannot be replaced any staff.\nYou can only add new staff.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange[900],
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Add button (always available)
                      _buildActionButton(
                        icon: Icons.add,
                        label: 'Add ${newStaff.fullName}',
                        subtitle: 'Keep all current staff',
                        color: Colors.green,
                        onTap: () {
                          Navigator.pop(context);
                          _showSelectServicesDialog(newStaff, task);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(top: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ⭐ Build replace staff options
// ⭐ Build replace staff options - WITH LOCK CHECK
  Widget _buildReplaceStaffOption(Task task, StaffSchedule newStaff) {
    final uniqueStaffNames = task.getUniqueStaffNames();

    if (uniqueStaffNames.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'No staff currently assigned',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    // ⭐ CHECK: markUnchange
    final bool canReplace = task.markUnchange != true;

    return Column(
      children: uniqueStaffNames.map((staffName) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Opacity(
            opacity: canReplace ? 1.0 : 0.4, // ⭐ Dim if locked
            child: InkWell(
              onTap: canReplace
                  ? () {
                Navigator.pop(context);
                // Find staffId from task
                int? staffIdToReplace;
                if (task.staffName == staffName && task.staffId != null) {
                  staffIdToReplace = task.staffId!;
                } else if (task.serviceItems != null) {
                  for (var service in task.serviceItems!) {
                    if (service.staffName == staffName && service.staffId != null) {
                      staffIdToReplace = service.staffId!;
                      break;
                    }
                  }
                }

                if (staffIdToReplace != null) {
                  _handleReplaceStaff(staffIdToReplace, staffName, newStaff, task);
                }
              }
                  : null, // ⭐ Disable tap if locked
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: canReplace ? Colors.orange[50] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: canReplace ? Colors.orange[200]! : Colors.grey[400]!,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: canReplace ? Colors.orange : Colors.grey,
                      child: Text(
                        staffName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        staffName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: canReplace ? Colors.black87 : Colors.grey[600],
                        ),
                      ),
                    ),
                    if (canReplace) ...[
                      Icon(Icons.swap_horiz, color: Colors.orange[700], size: 20),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                    ] else
                      Icon(Icons.lock, color: Colors.grey[600], size: 18),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ⭐ Handle replace staff - WITH DOUBLE CHECK
  void _handleReplaceStaff(
      int oldStaffId,
      String oldStaffName,
      StaffSchedule newStaff,
      Task task,
      ) async {
    if (!mounted) return;

    // ⭐ CRITICAL CHECK: Không cho phép replace nếu markUnchange = true
    if (task.markUnchange == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.lock, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'This booking cannot be replaced any staff',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    // Show confirm dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.swap_horiz, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Confirm Replacement', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Replace services from $oldStaffName to ${newStaff.fullName}?',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('From', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        const SizedBox(height: 8),
                        _buildStaffCard(
                          StaffSchedule(
                            staffId: oldStaffId,
                            fullName: oldStaffName,
                            avatar: '',
                            slots: [],
                          ),
                          Colors.red,
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward, color: Colors.grey),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('To', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        const SizedBox(height: 8),
                        _buildStaffCard(newStaff, Colors.green),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Confirm Replace'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _performStaffReassignmentWithOldStaff(newStaff, task, oldStaffId);
    }
  }

  Future<void> _performStaffReassignmentWithOldStaff(
      StaffSchedule newStaff,
      Task task,
      int oldStaffId,
      ) async {
    if (!mounted) return;

    scheduleState.setLoading(true);

    try {
      final response = await ApiService.reassignBookingStaff(
        bookingId: task.bookingId,
        newStaffId: newStaff.staffId,
        oldStaffId: oldStaffId,
      );

      if (response.code == 900) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'Reassigned to ${newStaff.fullName}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        await scheduleState.fetchSchedule();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'Reassignment failed'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        scheduleState.setLoading(false);
      }
    }
  }

  void _showSelectServicesDialog(StaffSchedule newStaff, Task task) async {
    if (!mounted) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Fetch available services cho staff này
      final availableServices = await ApiService.getAvailableServicesForStaff(
        bookingId: task.bookingId,
        staffId: newStaff.staffId,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (availableServices.isEmpty) {
        _showInfoDialog('${newStaff.fullName} has no services available');
        return;
      }

      // Show dialog
      _showServicesSelectionDialog(newStaff, task, availableServices);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading services: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showServicesSelectionDialog(
      StaffSchedule newStaff,
      Task task,
      List<AvailableService> availableServices,
      ) {
    // Selected items
    List<int> selectedExistingIds = [];
    List<NewServiceRequest> selectedNewServices = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Separate services
          final existingServices = availableServices
              .where((s) => s.alreadyInBooking)
              .toList();

          // ⭐ Sort new services by price
          final newServices = availableServices
              .where((s) => !s.alreadyInBooking)
              .toList()
            ..sort((a, b) => a.price.compareTo(b.price)); // Sort ascending

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9, // ⭐ 90% width
              constraints: const BoxConstraints(maxWidth: 700), // ⭐ Max 700px
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Services',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Assign ${newStaff.fullName} to:',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content - WITH FLEXIBLE SCROLL
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ═══════════════════════════════════════════════
                          // EXISTING SERVICES - NO SCROLL
                          // ═══════════════════════════════════════════════
                          if (existingServices.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Services already in booking',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Existing services list - NO SCROLL
                            ...existingServices.map((service) {
                              bool isSelected = selectedExistingIds.contains(service.bookingServiceId);
                              return CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        service.serviceName,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    Text(
                                      '\$${service.price.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: service.currentStaffName != null
                                    ? Text(
                                  'Current: ${service.currentStaffName}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange[700],
                                  ),
                                )
                                    : null,
                                value: isSelected,
                                onChanged: (bool? value) {
                                  setDialogState(() {
                                    if (value == true) {
                                      selectedExistingIds.add(service.bookingServiceId!);
                                    } else {
                                      selectedExistingIds.remove(service.bookingServiceId);
                                    }
                                  });
                                },
                                activeColor: Colors.blue,
                              );
                            }).toList(),
                          ],

                          // ═══════════════════════════════════════════════
                          // NEW SERVICES - WITH SCROLL (sorted by price)
                          // ═══════════════════════════════════════════════
                          if (newServices.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.add_circle_outline, size: 16, color: Colors.green[700]),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Add new services to booking (sorted by price)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                            // ⭐ SCROLLABLE CONTAINER FOR NEW SERVICES
                            Container(
                              constraints: const BoxConstraints(
                                maxHeight: 300, // ⭐ Max height for scroll
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.green[200]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: SingleChildScrollView(
                                child: Column(
                                  children: newServices.map((service) {
                                    bool isSelected = selectedNewServices
                                        .any((s) => s.serviceId == service.serviceId);
                                    return CheckboxListTile(
                                      dense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                      title: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              service.serviceName,
                                              style: const TextStyle(fontSize: 13),
                                            ),
                                          ),
                                          Text(
                                            '\$${service.price.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: Text(
                                        '${service.duration}min • Will be added to booking',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      value: isSelected,
                                      onChanged: (bool? value) {
                                        setDialogState(() {
                                          if (value == true) {
                                            selectedNewServices.add(
                                              NewServiceRequest(
                                                serviceId: service.serviceId,
                                                price: service.price,
                                              ),
                                            );
                                          } else {
                                            selectedNewServices.removeWhere(
                                                  (s) => s.serviceId == service.serviceId,
                                            );
                                          }
                                        });
                                      },
                                      activeColor: Colors.green,
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],

                          // ═══════════════════════════════════════════════
                          // SUMMARY
                          // ═══════════════════════════════════════════════
                          if (selectedExistingIds.isNotEmpty || selectedNewServices.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.summarize, size: 16, color: Colors.grey[700]),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Summary:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (selectedExistingIds.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 24),
                                      child: Text(
                                        '• Reassign ${selectedExistingIds.length} existing service(s)',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  if (selectedNewServices.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 24),
                                      child: Text(
                                        '• Add ${selectedNewServices.length} new service(s)',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  Divider(color: Colors.grey[300]),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Total selected:',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      Text(
                                        '${selectedExistingIds.length + selectedNewServices.length} service(s)',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Actions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      border: Border(top: BorderSide(color: Colors.grey[300]!)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: (selectedExistingIds.isEmpty && selectedNewServices.isEmpty)
                              ? null
                              : () {
                            Navigator.pop(context);
                            _performAddStaffWithServices(
                              newStaff,
                              task,
                              selectedExistingIds,
                              selectedNewServices,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          child: Text(
                            'Confirm (${selectedExistingIds.length + selectedNewServices.length})',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _performAddStaffWithServices(
      StaffSchedule staff,
      Task task,
      List<int> existingServiceIds,
      List<NewServiceRequest> newServices,
      ) async {
    if (!mounted) return;

    scheduleState.setLoading(true);

    try {
      final response = await ApiService.addStaffToBooking(
        bookingId: task.bookingId,
        staffId: staff.staffId,
        existingServiceIds: existingServiceIds.isNotEmpty ? existingServiceIds : null,
        newServices: newServices.isNotEmpty ? newServices : null,
      );

      if (!mounted) return;

      // ⭐ Xử lý các error codes từ backend
      switch (response.code) {
        case 900: // Success
          final totalServices = existingServiceIds.length + newServices.length;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Added ${staff.fullName} to booking ($totalServices service${totalServices > 1 ? 's' : ''})',
              ),
              backgroundColor: Colors.green,
            ),
          );
          await scheduleState.fetchSchedule();
          break;

        case 4001: // Max services exceeded
          _showErrorSnackBar(
            'Cannot add services: Maximum 6 services per booking reached',
            icon: Icons.no_accounts,
          );
          break;

        case 4002: // Max staff exceeded
          _showErrorSnackBar(
            'Cannot add staff: Maximum 3 staff per booking reached',
            icon: Icons.group_off,
          );
          break;

        case 4003: // Staff skill missing
          _showErrorSnackBar(
            '${staff.fullName} does not have the required skills for selected services',
            icon: Icons.warning_amber,
          );
          break;

        default: // Other errors
          _showErrorSnackBar(
            response.message ?? 'Failed to add staff to booking',
          );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Network error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        scheduleState.setLoading(false);
      }
    }
  }

  void _showErrorSnackBar(String message, {IconData? icon}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              icon ?? Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ⭐ Perform staff reassignment (replace all)
  Future<void> _performStaffReassignment(StaffSchedule newStaff, Task task) async {
    if (!mounted) return;

    scheduleState.setLoading(true);

    try {
      final response = await ApiService.reassignBookingStaff(
        bookingId: task.bookingId,
        newStaffId: newStaff.staffId,
      );

      if (response.code == 900) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'Reassigned to ${newStaff.fullName}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        await scheduleState.fetchSchedule();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'Reassignment failed'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        scheduleState.setLoading(false);
      }
    }
  }

  // ========== HELPER WIDGETS ==========

  Widget _buildBookingInfoCard(Task task) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                task.fullName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                '${scheduleState.formatTime(task.startTime)} - ${scheduleState.formatTime(task.endTime)}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStaffCard(StaffSchedule staff, Color color, {bool isNew = false}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color,
            child: Text(
              staff.fullName.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              staff.fullName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (isNew)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue[700],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'NEW',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: color),
          ],
        ),
      ),
    );
  }

  // ⭐ BUILD TAB BADGE
  Widget _buildTabBadge(int count, Color color) {
    if (count == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTabContent(int tabIndex) {
    final filteredTasks = _getFilteredTasksForTab(tabIndex);

    // Tạo map filtered events theo staffId
    Map<int, List<Task>> filteredEventsByStaffId = {};

    scheduleState.eventsByStaffId.forEach((staffId, tasks) {
      final filtered = tasks.where((task) {
        switch (tabIndex) {
          case 0: // Active
            return task.status == 'BOOKED' ||
                task.status == 'NEW_BOOKED' ||
                task.status == 'CHECKED_IN' ||
                task.status == 'IN_PROGRESS' ||
                task.status == 'REQUEST_MORE_STAFF';
          case 1: // Waiting payment
            return task.status == 'WAITING_PAYMENT';
          case 2: // Paid
            return task.status == 'PAID';
          case 3: // Canceled
            return task.status == 'CANCELED';
          default:
            return true;
        }
      }).toList();

      if (filtered.isNotEmpty) {
        filteredEventsByStaffId[staffId] = filtered;
      }
    });

    // ⭐ FIX: Luôn đảm bảo có nội dung scrollable
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: Colors.blue,
      child: filteredEventsByStaffId.isEmpty
          ? _buildEmptyState(tabIndex) // ⭐ Hiển thị empty state có thể scroll
          : BookingGrid(
        scheduleState: scheduleState,
        onCardTap: _handleCardTap,
        onStaffDropOnCard: _handleStaffDropOnCard,
        showStaffSheet: _showStaffSheet,
        showDetailPanel: _selectedTask != null,
        selectedDate: scheduleState.selectedDate,
        filteredEventsByStaffId: filteredEventsByStaffId,
      ),
    );
  }

// ⭐ THÊM PHƯƠNG THỨC BUILD EMPTY STATE
  Widget _buildEmptyState(int tabIndex) {
    final tabNames = ['Active', 'Pending Payment', 'Completed', 'Canceled'];
    final tabIcons = [
      Icons.event_available,
      Icons.payment,
      Icons.check_circle,
      Icons.cancel
    ];
    final tabColors = [
      Colors.blue,
      Colors.purple,
      Colors.green,
      Colors.red
    ];

    return SingleChildScrollView( // ⭐ QUAN TRỌNG: Luôn có SingleChildScrollView
      physics: const AlwaysScrollableScrollPhysics(), // ⭐ Cho phép scroll ngay cả khi empty
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7, // ⭐ Đảm bảo đủ chiều cao
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                tabIcons[tabIndex],
                size: 64,
                color: tabColors[tabIndex].withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No ${tabNames[tabIndex].toLowerCase()} bookings',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pull down to refresh',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingStoreId) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.blue),
              const SizedBox(height: 24),
              Text(
                'Loading store information...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ⭐ NEW: Show error if cannot get storeId
    if (_storeIdError != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: Colors.red,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red[400],
                ),
                const SizedBox(height: 24),
                Text(
                  _storeIdError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    _fetchWorkingStoreId();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ⭐ ORIGINAL BUILD - Chỉ render khi đã có storeId
    if (_storeId == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final leftPadding = _showStaffSheet ? 320.0 : 0.0;
    final rightPadding = _selectedTask != null ? 440.0 : 0.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () {
              if (_selectedTask != null) {
                _closeDetailPanel();
              } else if (_showStaffSheet) {
                _toggleStaffSheet();
              }
            },
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: EdgeInsets.only(
                left: leftPadding,
                right: rightPadding,
              ),
              child: Column(
                children: [
                  // ⭐ HEADER VỚI NÚT CLOSE SHIFT
                  BookingHeader(
                    scheduleState: scheduleState,
                    showStaffSheet: _showStaffSheet,
                    onToggleStaffSheet: _toggleStaffSheet,
                    onCloseShift: _handleCloseShift, // ⭐ THÊM CALLBACK
                  ),
                  const Divider(thickness: 2, color: Colors.grey, height: 0),

                  // ⭐ TAB BAR
                  Container(
                    color: Colors.white,
                    child: TabBar(
                      controller: _tabController,
                      labelColor: Colors.blue,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.blue,
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      ),
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.event_available, size: 18),
                              const SizedBox(width: 8),
                              const Text('Active'),
                              const SizedBox(width: 4),
                              _buildTabBadge(
                                scheduleState.tasks.where((task) =>
                                task.status == 'BOOKED' ||
                                    task.status == 'NEW_BOOKED' ||
                                    task.status == 'CHECKED_IN' ||
                                    task.status == 'IN_PROGRESS' ||
                                    task.status == 'REQUEST_MORE_STAFF'
                                ).length,
                                Colors.blue,
                              ),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.payment, size: 18),
                              const SizedBox(width: 8),
                              const Text('Pending'),
                              const SizedBox(width: 4),
                              _buildTabBadge(
                                scheduleState.tasks.where((task) => task.status == 'WAITING_PAYMENT').length,
                                Colors.purple,
                              ),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle, size: 18),
                              const SizedBox(width: 8),
                              const Text('Done'),
                              const SizedBox(width: 4),
                              _buildTabBadge(
                                scheduleState.tasks.where((task) => task.status == 'PAID').length,
                                Colors.green,
                              ),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cancel, size: 18),
                              const SizedBox(width: 4),
                              const Text('Canceled'),
                              const SizedBox(width: 4),
                              _buildTabBadge(
                                scheduleState.tasks.where((task) => task.status == 'CANCELED').length,
                                Colors.red,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(thickness: 1, color: Colors.grey, height: 0),

                  // ⭐ TABBARVIEW VỚI PULL-TO-REFRESH
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Tab 1: Active
                        _buildTabContent(0),
                        // Tab 2: Payment
                        _buildTabContent(1),
                        // Tab 3: Paid
                        _buildTabContent(2),
                        // Tab 4: Canceled
                        _buildTabContent(3),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_selectedTask != null)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeDetailPanel,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  color: Colors.black.withOpacity(0.3),
                ),
              ),
            ),

          if (_showStaffSheet)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () {},
                child: DragStaffSheet(
                  staffSchedules: scheduleState.staffSchedules,
                  onClose: _toggleStaffSheet,
                ),
              ),
            ),

          if (_selectedTask != null)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () {},
                child: AppointmentDetailPanel(
                  task: _selectedTask!,
                  scheduleState: scheduleState,
                  onClose: _closeDetailPanel,
                  onPaymentSuccess: () {
                    scheduleState.fetchSchedule();
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}