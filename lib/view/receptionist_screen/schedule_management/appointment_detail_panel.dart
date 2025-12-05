import 'package:flutter/material.dart';
import 'package:hair_sallon/view/receptionist_screen/schedule_management/receipt_screen.dart';
import 'package:intl/intl.dart';
import 'package:hair_sallon/api/api_service.dart';
import 'package:hair_sallon/api/payment_websocket_service.dart';
import '../../../api/store_info_model.dart';
import '../../../utils/constant/staff_slot.dart';
import '../task_model.dart';
import 'booking_state.dart';
import 'dart:async';

class AppointmentDetailPanel extends StatefulWidget {
  final Task task;
  final VoidCallback onClose;
  final VoidCallback onPaymentSuccess;
  final BookingState scheduleState;

  const AppointmentDetailPanel({
    super.key,
    required this.task,
    required this.onClose,
    required this.onPaymentSuccess,
    required this.scheduleState,
  });

  @override
  State<AppointmentDetailPanel> createState() => _AppointmentDetailPanelState();
}

class _AppointmentDetailPanelState extends State<AppointmentDetailPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  List<Map<String, dynamic>> _availableDiscounts = [];
  bool _isLoadingDiscounts = false;

  // ===== DISCOUNT CODE STATE =====
  final TextEditingController _discountCodeController = TextEditingController();
  bool _isApplyingDiscount = false;
  Map<String, dynamic>? _appliedDiscount;
  double _discountAmount = 0.0;
  double _amountBeforeDiscount = 0.0;
  double _amountAfterDiscount = 0.0;

  // ===== WEBSOCKET SERVICE (Singleton - đã connect ở ScheduleManagementScreen) =====
  final _wsService = PaymentWebSocketService();
  StreamSubscription? _wsSubscription;

  // ===== TRẠNG THÁI "ĐÃ GỬI SANG FRONT DESK" =====
  bool _isSentToFrontDesk = false;
  int? _receivedPaymentMethod;
  double? _receivedTip;
  double? _receivedCashDiscount;
  bool _hasReceivedPaymentMethod = false;

  List<Map<String, dynamic>>? _receivedGiftCardUsages;
  double? _receivedGiftCardAmount;

  // ===== TOPUP REQUEST FROM FRONTDESK =====
  Map<String, dynamic>? _currentTopupRequest;
  bool _isProcessingTopup = false;

  StoreInfo? _storeInfo;
  bool _isLoadingStoreInfo = false;

  @override
  void initState() {
    super.initState();

    _loadStoreInfo();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
    _initializeAmounts();
    _loadAvailableDiscounts();

    // ===== CHỈ LẮNG NGHE MESSAGES - KHÔNG TẠO CONNECTION MỚI =====
    _subscribeToWebSocketMessages();
  }

  Future<void> _loadStoreInfo() async {
    setState(() => _isLoadingStoreInfo = true);

    try {
      final response = await ApiService.getStoreInfo();

      if (response.isSuccess && response.data != null) {
        setState(() {
          _storeInfo = response.data;
        });
      }
    } catch (e) {
      print('Error loading store info: $e');
    } finally {
      setState(() => _isLoadingStoreInfo = false);
    }
  }

  // ===== LẮNG NGHE WEBSOCKET MESSAGES =====
  void _subscribeToWebSocketMessages() {
    print('🔗 AppointmentDetailPanel: Subscribing to WebSocket messages for booking #${widget.task.bookingId}');

    _wsSubscription = _wsService.messages.listen((message) {
      if (message['type'] != 'PONG') print('📨 AppointmentDetailPanel received message: ${message['type']}');
      _handleWebSocketMessage(message);
    }, onError: (error) {
      print('❌ AppointmentDetailPanel WebSocket error: $error');
    }, onDone: () {
      print('⚠️ AppointmentDetailPanel WebSocket connection closed');
    });
  }


  void _handleWebSocketMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    final data = message['data'] as Map<String, dynamic>?;

    if (data == null) return;

    switch (type) {
      case 'PAYMENT_COMPLETED':
        // Front Desk đã hoàn tất thanh toán
          final bookingId = data['bookingId'] as int?;
          if (bookingId == widget.task.bookingId) {
            _handlePaymentCompleted();
          }
        break;

      case 'PAYMENT_CANCELLED_FROM_FRONTDESK':
        // Front Desk đã hủy thanh toán
        final bookingId = data['bookingId'] as int?;
        if (bookingId == widget.task.bookingId) {
          _handlePaymentCancelledFromFrontDesk();
        }
        break;

      case 'BOOKING_TO_PAYMENT_CONFIRMED':
        // Backend xác nhận đã nhận booking
        break;

      case 'PAYMENT_METHOD_SELECTED':
        final bookingId = data['bookingId'] as int?;
        if (bookingId == widget.task.bookingId) {
          setState(() {
            _receivedPaymentMethod = data['paymentMethod'] as int?;
            _receivedTip = (data['tip'] as num?)?.toDouble() ?? 0.0;
            _receivedCashDiscount = (data['cashDiscount'] as num?)?.toDouble() ?? 0.0;

            // ⭐ THÊM 2 DÒNG NÀY
            _receivedGiftCardUsages = (data['giftCardUsages'] as List?)?.cast<Map<String, dynamic>>();
            _receivedGiftCardAmount = (data['giftCardAmount'] as num?)?.toDouble() ?? 0.0;

            _hasReceivedPaymentMethod = true;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Payment method received from Front Desk'),
                  ),
                ],
              ),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }
        break;

    // ===== MỚI: NHẬN TOPUP REQUEST TỪ FRONTDESK =====
      case 'TOPUP_REQUEST':
        _handleTopupRequest(data);
        break;

      default:
      // print('📨 AppointmentDetailPanel received: $type');
    }
  }

  void _handleTopupRequest(Map<String, dynamic> data) {
    setState(() {
      _currentTopupRequest = data;
    });

    _showTopupConfirmationDialog(data);
  }

  void _showTopupConfirmationDialog(Map<String, dynamic> data) {
    final String code = data['code'];
    final double amount = data['amount'];
    final int paymentMethod = data['paymentMethod'];
    final bool isNewCard = data['isNewCard'];
    final double currentBalance = data['currentBalance'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.card_giftcard,
                    color: Colors.purple,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isNewCard ? 'New Gift Card Top-up' : 'Gift Card Top-up',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Column(
                    children: [
                      _buildTopupInfoRow('Gift Card Code', code),
                      const SizedBox(height: 8),
                      _buildTopupInfoRow(
                        'Top-up Amount',
                        _formatCurrency(amount),
                      ),
                      const SizedBox(height: 8),
                      _buildTopupInfoRow(
                        'Payment Method',
                        paymentMethod == 1 ? 'Cash' : 'Credit Card',
                      ),
                      if (!isNewCard) ...[
                        const SizedBox(height: 8),
                        _buildTopupInfoRow(
                          'Current Balance',
                          _formatCurrency(currentBalance),
                        ),
                        const SizedBox(height: 8),
                        _buildTopupInfoRow(
                          'New Balance',
                          _formatCurrency(currentBalance + amount),
                          isBold: true,
                        ),
                      ],
                      if (isNewCard) ...[
                        const SizedBox(height: 8),
                        _buildTopupInfoRow(
                          'Status',
                          'NEW CARD - Will be created',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline, size: 16, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Complete to process top-up or Cancel to reject',
                          style: TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => _cancelTopup(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 14, color: Colors.red),
                ),
              ),
              ElevatedButton(
                onPressed: () => _completeTopup(data),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Complete Top-up',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildTopupInfoRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Future<void> _completeTopup(Map<String, dynamic> data) async {
    final String code = data['code'];
    final double amount = data['amount'];
    final int paymentMethod = data['paymentMethod'];
    final bool isNewCard = data['isNewCard'];

    setState(() {
      _isProcessingTopup = true;
    });

    try {
      if (isNewCard) {
        // // Tạo gift card mới
        // final createResponse = await ApiService.createGiftCard(
        //   code: code,
        //   initialBalance: amount,
        //   paymentMethod: paymentMethod,
        // );
        //
        // if (createResponse.code != 900) {
        //   throw Exception(createResponse.message ?? 'Failed to create gift card');
        // }
        print("new");
      } else {
        // Top-up gift card hiện có
        // final topupResponse = await ApiService.topupGiftCard(
        //   code: code,
        //   amount: amount,
        //   paymentMethod: paymentMethod,
        // );
        //
        // if (topupResponse.code != 900) {
        //   throw Exception(topupResponse.message ?? 'Failed to top-up gift card');
        // }
        print("topup");
      }

      // Gửi xác nhận về FrontDesk
      _wsService.sendMessage({
        'type': 'TOPUP_COMPLETED',
        'data': {'code': code, 'amount': amount, 'success': true},
      });

      if (mounted) {
        Navigator.pop(context); // Đóng dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isNewCard
                        ? 'Gift card created and topped up successfully'
                        : 'Gift card topped up successfully',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        setState(() {
          _currentTopupRequest = null;
          _isProcessingTopup = false;
        });
      }
    } catch (e) {
      print('❌ Topup error: $e');

      // Gửi thông báo lỗi về FrontDesk
      _wsService.sendMessage({
        'type': 'TOPUP_CANCELLED',
        'data': {'code': code, 'error': e.toString()},
      });

      if (mounted) {
        Navigator.pop(context); // Đóng dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Top-up failed: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );

        setState(() {
          _currentTopupRequest = null;
          _isProcessingTopup = false;
        });
      }
    }
  }

  void _cancelTopup() {
    final code = _currentTopupRequest?['code'];

    _wsService.sendMessage({
      'type': 'TOPUP_CANCELLED',
      'data': {'code': code, 'cancelled': true},
    });

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Top-up cancelled'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );

    setState(() {
      _currentTopupRequest = null;
    });
  }

  Future<void> _handlePaymentCompleted() async {
    setState(() {
      _isSentToFrontDesk = false;
    });

    // ⚠️ KHÔNG ĐÓNG PANEL - CHỈ HIỂN THỊ THÔNG BÁO
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text('Payment completed successfully at Front Desk'),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );

    // Callback để parent refresh data (nhưng không đóng panel)
    await _handleClose();
    widget.onPaymentSuccess();

    // ===== MỚI: Hiển thị Receipt sau payment success =====
    // _showFullReceipt();
  }

  void _handlePaymentCancelledFromFrontDesk() {
    setState(() {
      _isSentToFrontDesk = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment was cancelled at Front Desk'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ===== SỬA: CHUYỂN TRỰC TIẾP QUA FULL RECEIPT =====
  void _showFullReceipt() {
    final serviceItemsList =
        widget.task.serviceItems
            ?.map((item) => {'name': item.name, 'price': item.price})
            .toList() ??
        [];

    // Lấy thông tin staff từ task
    final staffName = widget.task.staffName ?? 'Not Assigned';

    // Lấy thời gian lịch hẹn
    final appointmentDateTime = DateTime(
      widget.scheduleState.selectedDate.year,
      widget.scheduleState.selectedDate.month,
      widget.scheduleState.selectedDate.day,
      widget.task.startTime.hour,
      widget.task.startTime.minute,
    );
    final appointmentEndDateTime = DateTime(
      widget.scheduleState.selectedDate.year,
      widget.scheduleState.selectedDate.month,
      widget.scheduleState.selectedDate.day,
      widget.task.endTime.hour,
      widget.task.endTime.minute,
    );

    // ✅ SỬA: Xử lý discount dựa trên status
    String? finalDiscountCode;
    double finalDiscountAmount;
    double subtotal;

    if (widget.task.status == 'PAID') {
      // Nếu đã PAID, lấy từ task (data từ backend)
      finalDiscountCode = widget.task.discountCode;
      finalDiscountAmount =
          (widget.task.amountDiscount as num?)?.toDouble() ?? 0.0;
      // Subtotal = totalAmount + discountAmount (vì totalAmount đã trừ discount)
      subtotal = (widget.task.totalAmount ?? 0.0) + finalDiscountAmount;
    } else {
      // Nếu chưa PAID, lấy từ state (user đang apply discount)
      if (_appliedDiscount != null && _appliedDiscount!['code'] != null) {
        finalDiscountCode = _appliedDiscount!['code'] as String;
      } else if (_discountCodeController.text.trim().isNotEmpty) {
        finalDiscountCode = _discountCodeController.text.trim();
      }
      finalDiscountAmount = _discountAmount;
      subtotal = _amountBeforeDiscount;
    }

    // Navigate directly to full ReceiptScreen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ReceiptScreen(
              shopName: _storeInfo?.name ?? 'Hair Salon',
              shopAddress: _storeInfo?.location ?? 'Address not available',
              shopTel:
                  '+1 (219)-661-1636', // Có thể thêm phone vào NailStore entity
              transactionDate: DateTime.now(),
              serviceItems: serviceItemsList,
              totalAmount: subtotal,
              cashPaid: 0,
              change: 0,
              paymentMethod: widget.task.paymentMethod ?? 'Cash',
              bookingId: widget.task.bookingId,
              discountCode: finalDiscountCode,
              discountAmount: finalDiscountAmount,
              tipAmount: widget.task.tips?.toDouble(),
              customerName: widget.task.fullName,
              staffName: staffName,
              appointmentDateTime: appointmentDateTime,
              appointmentEndDateTime: appointmentEndDateTime,
              fee: _storeInfo?.fee ?? 0.0, // ⭐ Truyền fee
            ),
      ),
    );
  }

  void _viewReceipt() {
    // ⭐ Tương tự như _showFullReceipt()
    final serviceItemsList =
        widget.task.serviceItems
            ?.map((item) => {'name': item.name, 'price': item.price})
            .toList() ??
        [];

    final staffName = widget.task.staffName ?? 'Not Assigned';

    final appointmentDateTime = DateTime(
      widget.scheduleState.selectedDate.year,
      widget.scheduleState.selectedDate.month,
      widget.scheduleState.selectedDate.day,
      widget.task.startTime.hour,
      widget.task.startTime.minute,
    );

    final appointmentEndDateTime = DateTime(
      widget.scheduleState.selectedDate.year,
      widget.scheduleState.selectedDate.month,
      widget.scheduleState.selectedDate.day,
      widget.task.endTime.hour,
      widget.task.endTime.minute,
    );

    String? finalDiscountCode;
    double finalDiscountAmount;
    double subtotal;

    if (widget.task.status == 'PAID') {
      finalDiscountCode = widget.task.discountCode;
      finalDiscountAmount =
          (widget.task.amountDiscount as num?)?.toDouble() ?? 0.0;
      subtotal = (widget.task.totalAmount ?? 0.0) + finalDiscountAmount;
    } else {
      if (_appliedDiscount != null && _appliedDiscount!['code'] != null) {
        finalDiscountCode = _appliedDiscount!['code'] as String;
      } else if (_discountCodeController.text.trim().isNotEmpty) {
        finalDiscountCode = _discountCodeController.text.trim();
      }
      finalDiscountAmount = _discountAmount;
      subtotal = _amountBeforeDiscount;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ReceiptScreen(
              shopName: _storeInfo?.name ?? 'CP Nails & Spa',
              shopAddress:
                  _storeInfo?.location ??
                  '1302 North Main Street #6, Crown Point, IN 46307',
              shopTel: '+1 (219)-661-1636',
              transactionDate: DateTime.now(),
              serviceItems: serviceItemsList,
              totalAmount: subtotal,
              cashPaid: 150.00,
              change: 15.72,
              paymentMethod: widget.task.paymentMethod ?? 'Cash',
              bookingId: widget.task.bookingId,
              discountCode: finalDiscountCode,
              discountAmount: finalDiscountAmount,
              tipAmount: widget.task.tips?.toDouble(),
              customerName: widget.task.fullName,
              staffName: staffName,
              appointmentDateTime: appointmentDateTime,
              appointmentEndDateTime: appointmentEndDateTime,
              fee: _storeInfo?.fee ?? 0.0, // ⭐ Truyền fee
            ),
      ),
    );
  }

  Future<void> _loadAvailableDiscounts() async {
    setState(() => _isLoadingDiscounts = true);

    try {
      final response = await ApiService.getAvailableDiscounts(
        widget.task.bookingId,
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data as List;
        setState(() {
          _availableDiscounts =
              data.map((item) => item as Map<String, dynamic>).toList();
        });
      } else {
        setState(() {
          _availableDiscounts = [];
        });
      }
    } catch (e) {
      print('Error loading available discounts: $e');
      setState(() {
        _availableDiscounts = [];
      });
    } finally {
      setState(() => _isLoadingDiscounts = false);
    }
  }

  void _initializeAmounts() {
    final totalAmount = widget.task.totalAmount ?? 0.0;
    setState(() {
      _amountBeforeDiscount = totalAmount;
      _amountAfterDiscount = totalAmount;
    });
  }

  @override
  void didUpdateWidget(AppointmentDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.bookingId != widget.task.bookingId) {
      _initializeAmounts();
      setState(() {
        _isSentToFrontDesk = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _discountCodeController.dispose();
    _wsSubscription?.cancel();
    // NOTE: Không dispose _wsService vì nó là singleton
    super.dispose();
  }

  Future<void> _handleClose() async {
    await _animationController.reverse();
    widget.onClose();
  }

  Future<void> _processPayment() async {
    // Kiểm tra đã nhận payment method từ FrontDesk chưa
    if (!_hasReceivedPaymentMethod || _receivedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for Front Desk to select payment method'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final bookingId = widget.task.bookingId;
    final amountAfterDiscount = _amountAfterDiscount;
    final discountCode = _appliedDiscount?['code'] as String?;

    final cashDiscount = _receivedCashDiscount ?? 0.0;
    final remainingAmount = amountAfterDiscount - cashDiscount;
    final totalAmount = remainingAmount + (_receivedTip ?? 0.0);

    // ⭐ DEFENSIVE: Map lại gift card data nếu cần
    List<Map<String, dynamic>> mappedGiftCardUsages = [];
    if (_receivedGiftCardUsages != null && _receivedGiftCardUsages!.isNotEmpty) {
      mappedGiftCardUsages = _receivedGiftCardUsages!.map((card) {
        // Nếu đã đúng format thì giữ nguyên, nếu không thì map lại
        if (card.containsKey('deductedAmount') && card.containsKey('remainingBalance')) {
          return card;  // ✅ Already correct format
        } else {
          // ⚠️ Old format, need to map
          final String code = card['code'];
          final double balance = (card['balance'] as num?)?.toDouble() ?? 0.0;
          final double usedAmount = (card['usedAmount'] as num?)?.toDouble() ?? 0.0;

          return {
            'code': code,
            'deductedAmount': usedAmount,
            'remainingBalance': balance - usedAmount,
          };
        }
      }).toList();
    }

    try {
      await ApiService.completePayment(
        bookingId: bookingId,
        paymentMethod: _receivedPaymentMethod!,
        tips: _receivedTip ?? 0.0,
        giftCardUsages: mappedGiftCardUsages,  // ⭐ Use mapped data
        giftCardAmount: _receivedGiftCardAmount ?? 0.0,
        cashPaidAmount: _receivedPaymentMethod == 1 ? remainingAmount : 0.0,
        creditAmount: _receivedPaymentMethod == 2 ? remainingAmount : 0.0,
        chequeAmount: 0.0,
        discountCode: discountCode ?? '',
      );

      // Gửi xác nhận về FrontDesk
      _wsService.confirmPaymentCompleted(
        bookingId: bookingId,
        totalPaid: totalAmount,
        tips: _receivedTip ?? 0.0,
        paymentMethod: _receivedPaymentMethod!,
        cashDiscount: cashDiscount,
      );

      // Hiển thị thông báo thành công
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Payment completed successfully'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Callback để parent refresh data
        await _handleClose();
        widget.onPaymentSuccess();

        // Hiển thị Receipt
        // _showFullReceipt();

        // Reset state
        setState(() {
          _isSentToFrontDesk = false;
          _hasReceivedPaymentMethod = false;
          _receivedPaymentMethod = null;
          _receivedTip = null;
          _receivedCashDiscount = null;
        });
      }
    } catch (e) {
      print('❌ Payment error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Payment failed: $e'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _applyDiscountCode() async {
    final code = _discountCodeController.text.trim();

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a discount code'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isApplyingDiscount = true);

    try {
      final response = await ApiService.validateDiscountCode(
        code: code,
        bookingId: widget.task.bookingId,
        totalAmount: _amountBeforeDiscount,
      );

      if (response.code == 900 && response.data != null) {
        final discountData = response.data as Map<String, dynamic>;
        final bool isValid = discountData['valid'] as bool? ?? false;

        if (isValid) {
          final discountAmount =
              (discountData['discountAmount'] as num?)?.toDouble() ?? 0.0;
          final amountAfterDiscount =
              (discountData['amountAfterDiscount'] as num?)?.toDouble() ??
              _amountBeforeDiscount;

          dynamic discountValueRaw = discountData['discountValue'];
          double? discountValueNum;

          if (discountValueRaw is num) {
            discountValueNum = discountValueRaw.toDouble();
          } else if (discountValueRaw is String) {
            String cleanedValue = discountValueRaw.replaceAll(
              RegExp(r'[^\d.]'),
              '',
            );
            discountValueNum = double.tryParse(cleanedValue);
          }

          setState(() {
            _appliedDiscount = discountData;
            _discountAmount = discountAmount;
            _amountAfterDiscount = amountAfterDiscount;
            if (discountValueNum != null) {
              _appliedDiscount?['discountValueNum'] = discountValueNum;
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Discount applied: ${_formatCurrency(_discountAmount)} off!',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          final errorMessage =
              discountData['message'] as String? ?? 'Invalid discount code';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message ?? 'Invalid discount code'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isApplyingDiscount = false);
    }
  }

  void _removeDiscount() {
    setState(() {
      _appliedDiscount = null;
      _discountAmount = 0.0;
      _amountAfterDiscount = _amountBeforeDiscount;
      _discountCodeController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Discount removed'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ===== 🚀 GỬI BOOKING SANG FRONTDESK QUA WEBSOCKET =====
  void _sendToFrontDesk() {
    // Kiểm tra WebSocket có connected không
    if (!_wsService.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WebSocket not connected. Please try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Chuẩn bị danh sách service items với cả name và price
    List<Map<String, dynamic>> serviceItems = [];
    if (widget.task.serviceItems != null &&
        widget.task.serviceItems!.isNotEmpty) {
      serviceItems =
          widget.task.serviceItems!.map((item) {
            return {'name': item.name, 'price': item.price};
          }).toList();
    }

    _wsService.sendBookingToPayment(
      bookingId: widget.task.bookingId,
      customerName: widget.task.fullName,
      amountBeforeDiscount: _amountBeforeDiscount,
      amountAfterDiscount: _amountAfterDiscount,
      discountAmount: _discountAmount,
      discountCode:
          _discountCodeController.text.trim().isEmpty
              ? null
              : _discountCodeController.text.trim(),
      serviceItems: serviceItems, // Thay serviceNames bằng serviceItems
      wallet: "0xdcdfa86789a41605cc7a3b8a7ddb0c0e46aaf1a3",
      fee: _storeInfo?.fee ?? 0,
    );

    setState(() {
      _isSentToFrontDesk = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.send, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(child: Text('Booking sent to Front Desk for payment')),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );

    // ⚠️ KHÔNG ĐÓNG PANEL - giữ lại để user có thể hủy
  }

  // ===== 🚫 HỦY TỪ RECEPTIONIST SCREEN =====
  void _cancelPaymentFromReceptionist() {
    _wsService.cancelPayment(bookingId: widget.task.bookingId);

    setState(() {
      _isSentToFrontDesk = false;
      // ⭐ CLEAR PAYMENT METHOD DATA
      _hasReceivedPaymentMethod = false;
      _receivedPaymentMethod = null;
      _receivedTip = null;
      _receivedCashDiscount = null;
      // ⭐ THÊM 2 DÒNG NÀY
      _receivedGiftCardUsages = null;
      _receivedGiftCardAmount = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment cancelled - Front Desk returned to welcome screen'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }



  String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final appointmentDate = DateFormat('EEE, MMM dd, yyyy • hh:mm a').format(
      DateTime(
        widget.scheduleState.selectedDate.year,
        widget.scheduleState.selectedDate.month,
        widget.scheduleState.selectedDate.day,
        widget.task.startTime.hour,
        widget.task.startTime.minute,
      ),
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset(_slideAnimation.value, 0.0),
        end: Offset.zero,
      ).animate(_animationController),
      child: Container(
        width: 440,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
              offset: const Offset(-2, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              _isSentToFrontDesk
                                  ? Colors.purple.withOpacity(0.1)
                                  : _getStatusBackgroundColor(
                                    widget.task.status,
                                  ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isSentToFrontDesk
                                  ? Icons.payment
                                  : _getStatusIcon(widget.task.status),
                              color:
                                  _isSentToFrontDesk
                                      ? Colors.purple
                                      : _getStatusTextColor(widget.task.status),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isSentToFrontDesk
                                  ? 'SENT TO FRONT DESK'
                                  : _getStatusLabel(widget.task.status),
                              style: TextStyle(
                                color:
                                    _isSentToFrontDesk
                                        ? Colors.purple
                                        : _getStatusTextColor(
                                          widget.task.status,
                                        ),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _handleClose,
                        icon: const Icon(Icons.close, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content - CHIA THÀNH 2 PHẦN: Scrollable upper + Fixed bottom
            Expanded(
              child: Column(
                children: [
                  // ===== PHẦN TRÊN: SCROLLABLE (Info + Services) =====
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Notification khi đã gửi sang Front Desk
                          if (_isSentToFrontDesk)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.purple.withOpacity(0.1),
                                    Colors.purple.withOpacity(0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.purple.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.purple,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.payment,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Payment in Progress',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.purple,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              'This booking has been sent to Front Desk for payment processing',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          color: Colors.purple[700],
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'You can cancel the payment below if needed',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // ⭐ TẤT CẢ THÔNG TIN TRONG 1 CARD
                          _buildInfoCard(appointmentDate: appointmentDate),

                          const SizedBox(height: 12),

                          // ===== SERVICES =====
                          const Text(
                            'SERVICES',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B7280),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),

                          _buildServicesCard(),

                          const SizedBox(
                            height: 20,
                          ), // Space before bottom fixed section
                        ],
                      ),
                    ),
                  ),

                  // ===== PHẦN TOTAL AMOUNT HOẶC LÝ DO HỦY (FIXED BOTTOM) =====
                  Container(
                    padding: const EdgeInsets.only(
                      left: 12,
                      right: 12,
                      top: 18,
                      bottom: 36,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFE5E7EB),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        // 1. CANCELED → HIỂN THỊ LÝ DO HỦY
                        if (widget.task.status == 'CANCELED') ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red[300]!,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.cancel,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Booking Cancelled',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        widget.task.reason?.isNotEmpty == true
                                            ? 'Reason: ${widget.task.reason}'
                                            : 'No reason provided',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Colors.red[800],
                                          fontStyle:
                                              widget.task.reason?.isEmpty ==
                                                      true
                                                  ? FontStyle.italic
                                                  : FontStyle.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ]
                        // 2. PAID → HIỂN THỊ CHI TIẾT THANH TOÁN + NÚT RECEIPT
                        else if (widget.task.status == 'PAID') ...[
                          _buildPaidPaymentDetails(),
                        ]
                        // 3. Các trạng thái khác → HIỂN THỊ TOTAL + BUTTONS TƯƠNG ỨNG
                        else ...[
                          // Total Amount (Estimated hoặc Total)
                          // ẨN TOTAL AMOUNT KHI LÀ BOOKED / CHECKED_IN / REQUEST_MORE_STAFF
                          if (![
                            'BOOKED',
                            'CHECKED_IN',
                            'REQUEST_MORE_STAFF',
                          ].contains(widget.task.status)) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.payments_outlined,
                                        color: const Color(0xFF10B981),
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        widget.task.status == "WAITING_PAYMENT"
                                            ? 'Total Amount'
                                            : 'Estimated Amount',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    _formatCurrency(_amountBeforeDiscount),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Discount đã áp dụng (nếu có)
                          if (_discountAmount > 0) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Amount After Discount:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green[800],
                                    ),
                                  ),
                                  Text(
                                    _formatCurrency(_amountAfterDiscount),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[800],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // ===== BUTTONS THEO TRẠNG THÁI =====
                          // 3.1 WAITING_PAYMENT (Pending) → Discount + Send to Front Desk
                          if (widget.task.status == 'WAITING_PAYMENT') ...[
                            _buildDiscountCodeSection(),
                            const SizedBox(height: 16),

                            // ===== HIỂN THỊ PAYMENT METHOD ĐÃ NHẬN TỪ FRONTDESK =====
                            if (_hasReceivedPaymentMethod && _receivedPaymentMethod != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.blue.shade200,
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.blue,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.check_circle,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Expanded(
                                          child: Text(
                                            'Payment Method Received',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    _buildPaymentDetailRow(
                                      'Method',
                                      _getPaymentMethodDisplay(_receivedPaymentMethod.toString()),
                                    ),

                                    // ⭐ HIỂN THỊ GIFT CARD USAGES
                                    if (_receivedPaymentMethod == 3 &&
                                        _receivedGiftCardUsages != null &&
                                        _receivedGiftCardUsages!.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      const Divider(height: 1, color: Colors.blue),
                                      const SizedBox(height: 12),

                                      // Header
                                      Row(
                                        children: [
                                          Icon(Icons.card_giftcard, color: Colors.purple, size: 18),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Gift Cards Used:',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.purple,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      // Gift Card List
                                      ..._receivedGiftCardUsages!.map((card) {
                                        final String code = card['code'] ?? '';
                                        final double deductedAmount = (card['deductedAmount'] as num?)?.toDouble() ?? 0.0;
                                        final double remainingBalance = (card['remainingBalance'] as num?)?.toDouble() ?? 0.0;

                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.purple.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.purple.shade200),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Code
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.purple,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Icon(
                                                      Icons.card_giftcard,
                                                      color: Colors.white,
                                                      size: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      'Code: $code',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.purple.shade900,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),

                                              // Amounts
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Deducted:',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.grey[600],
                                                        ),
                                                      ),
                                                      Text(
                                                        _formatCurrency(deductedAmount),
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.red[700],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.end,
                                                    children: [
                                                      Text(
                                                        'Remaining:',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.grey[600],
                                                        ),
                                                      ),
                                                      Text(
                                                        _formatCurrency(remainingBalance),
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.green[700],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),

                                      // Total Gift Card Amount
                                      if (_receivedGiftCardAmount != null && _receivedGiftCardAmount! > 0) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.purple,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                'Total Gift Card Amount:',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              Text(
                                                _formatCurrency(_receivedGiftCardAmount!),
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],

                                    // Tip & Cash Discount
                                    if (_receivedTip != null && _receivedTip! > 0)
                                      _buildPaymentDetailRow(
                                        'Tip',
                                        _formatCurrency(_receivedTip!),
                                      ),
                                    if (_receivedCashDiscount != null && _receivedCashDiscount! > 0)
                                      _buildPaymentDetailRow(
                                        'Cash Discount',
                                        '-${_formatCurrency(_receivedCashDiscount!)}',
                                        valueColor: Colors.green,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // NÚT COMPLETE PAYMENT
                              Row(
                                children: [
                                  // CANCEL BUTTON
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _cancelPaymentFromReceptionist,
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      label: const Text(
                                        'Cancel',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                          color: Colors.red,
                                          width: 2,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  // COMPLETE PAYMENT BUTTON
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _processPayment,
                                      icon: const Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      label: const Text(
                                        'Complete',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              // NẾU CHƯA NHẬN PAYMENT METHOD
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed:
                                          _isSentToFrontDesk
                                              ? null
                                              : _sendToFrontDesk,
                                      icon: const Icon(
                                        Icons.send,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      label: const Text(
                                        'Send to Front Desk',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF3B82F6,
                                        ),
                                        disabledBackgroundColor: Colors.grey,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              if (_isSentToFrontDesk)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: _cancelPaymentFromReceptionist,
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.red,
                                      ),
                                      label: const Text(
                                        'Cancel Payment',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                          color: Colors.red,
                                          width: 2,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ]
                          // 3.2 Active (BOOKED, CHECKED_IN, IN_PROGRESS) → Chỉ Cancel
                          else ...[
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _showCancelDialog,
                                icon: const Icon(
                                  Icons.cancel_outlined,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                label: const Text(
                                  'Cancel Booking',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Colors.red,
                                    width: 2,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== WIDGET MỚI: TẤT CẢ THÔNG TIN TRONG 1 CARD =====
  Widget _buildInfoCard({required String appointmentDate}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          // Customer
          _buildInfoRow(label: 'Customer', value: widget.task.fullName),
          const SizedBox(height: 8),
          Divider(height: 1, color: Colors.grey[200]),
          const SizedBox(height: 8),

          // Phone
          _buildInfoRow(label: 'Phone', value: '+1 (970) 710-1062'),
          const SizedBox(height: 8),
          Divider(height: 1, color: Colors.grey[200]),
          const SizedBox(height: 8),

          // Detail
          _buildInfoRow(label: 'Time', value: appointmentDate),
          const SizedBox(height: 8),
          Divider(height: 1, color: Colors.grey[200]),
          const SizedBox(height: 8),

          // Booking
          _buildInfoRow(label: 'Booking', value: '#${widget.task.bookingId}'),
        ],
      ),
    );
  }

  // Helper: Build info row (label bên trái, value bên phải)
  Widget _buildInfoRow({required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  // ⭐ Widget: Tất cả services trong 1 card
  Widget _buildServicesCard() {
    if (widget.task.serviceItems == null || widget.task.serviceItems!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: const [
            Icon(Icons.info_outline, color: Color(0xFF6B7280), size: 20),
            SizedBox(width: 12),
            Text(
              'No services available',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children:
            widget.task.serviceItems!.asMap().entries.map((entry) {
              final index = entry.key;
              final serviceItem = entry.value;
              final isLast = index == widget.task.serviceItems!.length - 1;

              return Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          serviceItem.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _formatCurrency(serviceItem.price),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (!isLast) ...[
                    const SizedBox(height: 12),
                    Divider(height: 1, color: Colors.grey[200]),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            }).toList(),
      ),
    );
  }

  // ===== HELPER WIDGETS MỚI =====

  // Widget compact cho Customer, Phone
  Widget _buildCompactInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12), // GIẢM TỪ 16 XUỐNG 12
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6), // GIẢM TỪ 8 XUỐNG 6
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF3B82F6),
              size: 18,
            ), // GIẢM SIZE
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11, // GIẢM
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13, // GIẢM
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget mới: Appointment Detail (gộp cả Booking ID)
  Widget _buildCompactAppointmentDetailRow({
    required String appointmentDate,
    required int bookingId,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.access_time_outlined,
              color: Color(0xFF3B82F6),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Appointment Detail',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  appointmentDate,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Booking #$bookingId',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== HELPER WIDGETS (giữ nguyên code cũ) =====

  Widget _buildDiscountCodeSection() {
    // ⭐ WRAP WITH OPACITY + ABSORBPOINTER WHEN SENT TO FRONTDESK
    return Opacity(
      opacity: _isSentToFrontDesk ? 0.5 : 1.0, // Mờ đi khi disabled
      child: AbsorbPointer(
        absorbing: _isSentToFrontDesk, // Block touches khi disabled
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isSentToFrontDesk
                  ? Colors.grey.shade300  // Màu xám khi disabled
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(_isSentToFrontDesk ? 0.3 : 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.local_offer,
                      color: _isSentToFrontDesk ? Colors.grey : Colors.orange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Discount Code',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _isSentToFrontDesk ? Colors.grey : Colors.black87,
                    ),
                  ),
                  if (_isSentToFrontDesk) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'LOCKED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),

              if (_appliedDiscount == null) ...[
                if (_isLoadingDiscounts)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_availableDiscounts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No discount codes available for you at this time',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                    Text(
                      'Available Discounts - Tap to apply',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _isSentToFrontDesk ? Colors.grey : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildAvailableDiscountsList(),

                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(color: Colors.grey[300], thickness: 1),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(color: Colors.grey[300], thickness: 1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    _buildDiscountInputField(),
                  ],
              ] else
                _buildAppliedDiscountCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvailableDiscountsList() {
    return Column(
      children:
      _availableDiscounts.map((discount) {
        final code = discount['code'] as String? ?? '';
        final discountType =
            discount['discountType'] as String? ?? 'FIXED_AMOUNT';
        final discountValue =
            (discount['discountValue'] as num?)?.toDouble() ?? 0.0;
        final description = discount['description'] as String? ?? '';
        final minOrderAmount =
            (discount['minOrderAmount'] as num?)?.toDouble() ?? 0.0;

        final bool meetsMinimum = _amountBeforeDiscount >= minOrderAmount;
        final bool isDisabled = !meetsMinimum || _isSentToFrontDesk; // ⭐ NEW

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap:
              !isDisabled // ⭐ CHANGED
                  ? () {
                _discountCodeController.text = code;
                _applyDiscountCode();
              }
                  : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors:
                    !isDisabled // ⭐ CHANGED
                        ? [
                      Colors.orange.withOpacity(0.1),
                      Colors.orange.withOpacity(0.05),
                    ]
                        : [
                      Colors.grey.withOpacity(0.1),
                      Colors.grey.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                    !isDisabled // ⭐ CHANGED
                        ? Colors.orange.withOpacity(0.4)
                        : Colors.grey.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: !isDisabled ? Colors.orange : Colors.grey, // ⭐ CHANGED
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.local_offer,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            code,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color:
                              !isDisabled // ⭐ CHANGED
                                  ? Colors.black87
                                  : Colors.grey,
                            ),
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              description,
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                !isDisabled // ⭐ CHANGED
                                    ? Colors.grey[700]
                                    : Colors.grey[500],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDiscountInputField() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _discountCodeController,
            decoration: InputDecoration(
              hintText: 'Enter code manually',
              prefixIcon: Icon(
                Icons.discount,
                color: _isSentToFrontDesk ? Colors.grey : Colors.orange,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            textCapitalization: TextCapitalization.characters,
            enabled: !_isApplyingDiscount && !_isSentToFrontDesk, // ⭐ ADD CHECK
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _isApplyingDiscount || _isSentToFrontDesk // ⭐ ADD CHECK
              ? null
              : _applyDiscountCode,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child:
          _isApplyingDiscount
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
              : const Text(
            'Apply',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppliedDiscountCard() {
    final discountType =
        _appliedDiscount!['discountType'] as String? ?? 'FIXED';
    final code = _appliedDiscount!['code'] as String? ?? '';

    dynamic discountValueRaw = _appliedDiscount!['discountValue'];
    String discountDisplay = '';

    if (discountValueRaw is num) {
      discountDisplay =
          discountType == 'PERCENTAGE'
              ? '${discountValueRaw}% off'
              : '${_formatCurrency(discountValueRaw.toDouble())} off';
    } else if (discountValueRaw is String) {
      discountDisplay = '$discountValueRaw off';
    } else {
      discountDisplay = 'Discount applied';
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discount Applied: $code',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      discountDisplay,
                      style: TextStyle(fontSize: 12, color: Colors.green[700]),
                    ),
                  ],
                ),
              ),
              if (widget.task.status != 'PAID' &&
                  widget.task.status != 'CANCELED' &&
                  !_isSentToFrontDesk)
                IconButton(
                  onPressed: _removeDiscount,
                  icon: const Icon(Icons.close, color: Colors.red),
                  tooltip: 'Remove discount',
                ),
            ],
          ),
          const Divider(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Discount Amount:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              Text(
                '-${_formatCurrency(_discountAmount)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaidPaymentDetails() {
    // Dữ liệu từ backend
    final double totalPaid = widget.task.totalAmount ?? 0.0;
    final double discountAmount =
        (widget.task.amountDiscount as num?)?.toDouble() ?? 0.0;
    final double tipAmount = (widget.task.tips as num?)?.toDouble() ?? 0.0;
    final double cashDiscount = widget.task.cashDiscount ?? 0.0;

    // Tính lại subtotal gốc (trước mọi discount)
    final double subtotal = totalPaid + discountAmount + cashDiscount;
    final double totalAmount = totalPaid + tipAmount;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.receipt_long, color: Colors.green[800], size: 22),
              const SizedBox(width: 10),
              Text(
                'Payment Completed',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Subtotal (giá gốc)
          _buildPaymentDetailRow('Subtotal', _formatCurrency(subtotal)),

          // Cash Discount
          if (cashDiscount > 0)
            _buildPaymentDetailRow(
              'Cash Discount',
              '-${_formatCurrency(cashDiscount)}',
              valueColor: Colors.green[700],
            ),

          // Discount Code
          if (discountAmount > 0)
            _buildPaymentDetailRow(
              'Discount${widget.task.discountCode != null ? ' (${widget.task.discountCode})' : ''}',
              '-${_formatCurrency(discountAmount)}',
              valueColor: Colors.orange[700],
            ),

          // Amount after discounts
          if (cashDiscount > 0 || discountAmount > 0) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: _buildPaymentDetailRow(
                'Amount After Discount',
                _formatCurrency(subtotal - cashDiscount - discountAmount),
                isBold: true,
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Tip
          if (tipAmount > 0)
            _buildPaymentDetailRow(
              'Tip',
              '+${_formatCurrency(tipAmount)}',
              valueColor: Colors.purple[700],
            ),

          const Divider(height: 24, color: Colors.green),

          // TOTAL PAID - SỐ CUỐI CÙNG KHÁCH TRẢ
          _buildPaymentDetailRow(
            'TOTAL PAID',
            _formatCurrency(totalAmount),
            isBold: true,
            valueColor: Colors.green[800]!,
            fontSize: 20,
          ),

          const SizedBox(height: 12),

          // Payment Method
          _buildPaymentDetailRow(
            'Payment Method',
            _getPaymentMethodDisplay(widget.task.paymentMethod),
            valueColor: Colors.green[800]!,
          ),

          const SizedBox(height: 20),

          // View Receipt Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _viewReceipt,
              icon: const Icon(Icons.print, size: 20),
              label: const Text(
                'View Full Receipt',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper để hiển thị tên phương thức thanh toán đẹp hơn
  String _getPaymentMethodDisplay(String? method) {
    switch (method?.toUpperCase()) {
      case 'CASH':
      case '1':
        return 'Cash';
      case 'CREDIT':
      case '2':
        return 'Credit Card';
      case 'GIFT CARD':
      case '3':
        return 'Gift Card';
      case 'CHEQUE':
      case '6':
        return 'Cheque';
      case 'CRYPTO':
      case '4':
        return 'Crypto';
      default:
        return method ?? 'Unknown';
    }
  }

  // Cập nhật helper để hỗ trợ fontSize và bold
  Widget _buildPaymentDetailRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
    double fontSize = 14,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: Colors.green[800],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize + (isBold ? 2 : 0),
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? Colors.green[800],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusBackgroundColor(String status) {
    switch (status) {
      case 'NEW_BOOKED':
      case 'BOOKED':
        return const Color(0xFFDEF3FF);
      case 'CHECKED_IN':
        return const Color(0xFFDEFDE0);
      case 'IN_PROGRESS':
        return const Color(0xFFFFF4DE);
      case 'WAITING_PAYMENT':
        return const Color(0xFFF3E8FF);
      case 'PAID':
        return const Color(0xFFD1FAE5);
      case 'CANCELED':
        return const Color(0xFFFEE2E2);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'NEW_BOOKED':
      case 'BOOKED':
        return const Color(0xFF2196F3);
      case 'CHECKED_IN':
        return const Color(0xFF10B981);
      case 'IN_PROGRESS':
        return const Color(0xFFF59E0B);
      case 'WAITING_PAYMENT':
        return const Color(0xFF9C27B0);
      case 'PAID':
        return const Color(0xFF059669);
      case 'CANCELED':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'NEW_BOOKED':
      case 'BOOKED':
        return Icons.calendar_today;
      case 'CHECKED_IN':
        return Icons.check_circle;
      case 'IN_PROGRESS':
        return Icons.hourglass_bottom;
      case 'WAITING_PAYMENT':
        return Icons.payment;
      case 'PAID':
        return Icons.check_circle_outline;
      case 'CANCELED':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'NEW_BOOKED':
      case 'BOOKED':
        return 'BOOKING CONFIRMED';
      case 'CHECKED_IN':
        return 'CHECKED IN';
      case 'IN_PROGRESS':
        return 'IN PROGRESS';
      case 'WAITING_PAYMENT':
        return 'WAITING PAYMENT';
      case 'PAID':
        return 'PAID';
      case 'CANCELED':
        return 'CANCELED';
      default:
        return status.toUpperCase();
    }
  }

  String _getHeaderTitle(String status) {
    switch (status) {
      case 'NEW_BOOKED':
      case 'BOOKED':
        return 'Ready for Check-in';
      case 'CHECKED_IN':
        return 'Customer Checked In';
      case 'IN_PROGRESS':
        return 'Service in Progress';
      case 'WAITING_PAYMENT':
        return 'Ready for Payment';
      case 'PAID':
        return 'Payment Completed';
      case 'CANCELED':
        return 'Appointment Canceled';
      default:
        return 'Appointment Details';
    }
  }

  void _showEditDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit,
                    color: Color(0xFF3B82F6),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Edit Appointment', style: TextStyle(fontSize: 18)),
              ],
            ),
            content: const Text(
              'Edit appointment feature coming soon',
              style: TextStyle(fontSize: 14),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
    );
  }

  void _showCancelDialog() {
    final TextEditingController cancelReasonController =
        TextEditingController();
    bool isCancelling = false;

    showDialog(
      context: context,
      barrierDismissible: false, // Không cho dismiss khi đang cancel
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning,
                        color: Color(0xFFEF4444),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Cancel Appointment',
                      style: TextStyle(fontSize: 18),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Are you sure you want to cancel this appointment?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ⭐ TEXTFIELD ĐỂ NHẬP LÝ DO
                    TextField(
                      controller: cancelReasonController,
                      decoration: InputDecoration(
                        labelText: 'Reason (optional)',
                        hintText: 'Enter cancellation reason...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(
                          Icons.edit_note,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      maxLines: 3,
                      enabled: !isCancelling,
                    ),

                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: const [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Color(0xFFEF4444),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This action cannot be undone',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed:
                        isCancelling ? null : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'No, Keep It',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  ElevatedButton(
                    onPressed:
                        isCancelling
                            ? null
                            : () async {
                              setState(() {
                                isCancelling = true;
                              });

                              try {
                                // ⭐ LẤY LÝ DO - NẾU TRỐNG THÌ DÙNG MẶC ĐỊNH
                                String cancelReason =
                                    cancelReasonController.text.trim();
                                if (cancelReason.isEmpty) {
                                  cancelReason = 'Cancelled by receptionist';
                                }

                                // ⭐ GỌI API CANCEL BOOKING
                                await ApiService.cancelBooking(
                                  widget.task.bookingId,
                                  cancelReason,
                                );

                                // Đóng dialog
                                if (mounted) {
                                  Navigator.pop(context);
                                }

                                // Hiển thị thông báo thành công
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(
                                            Icons.check_circle,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Appointment for ${widget.task.fullName} cancelled successfully',
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: Colors.green,
                                      duration: const Duration(seconds: 3),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }

                                // Đóng panel và refresh
                                await _handleClose();
                                widget
                                    .onPaymentSuccess(); // Callback để refresh danh sách
                              } catch (e) {
                                setState(() {
                                  isCancelling = false;
                                });

                                // Hiển thị lỗi
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(
                                            Icons.error,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Failed to cancel booking: ${e.toString()}',
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: Colors.red,
                                      duration: const Duration(seconds: 3),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child:
                        isCancelling
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : const Text(
                              'Yes, Cancel',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                  ),
                ],
              );
            },
          ),
    );
  }
}
