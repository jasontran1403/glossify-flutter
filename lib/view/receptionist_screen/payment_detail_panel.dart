import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hair_sallon/api/api_service.dart';
import 'package:hair_sallon/view/receptionist_screen/schedule_management/booking_state.dart';
import 'package:hair_sallon/view/receptionist_screen/task_model.dart';
import 'package:intl/intl.dart';

import '../owner_screen/qr_scanner/qr_scanner_screen.dart';
import '../../../api/store_info_model.dart';

class PaymentDetailPanel extends StatefulWidget {
  final Task task;
  final VoidCallback onClose;
  final VoidCallback onPaymentSuccess;
  final BookingState scheduleState;

  const PaymentDetailPanel({
    super.key,
    required this.task,
    required this.onClose,
    required this.onPaymentSuccess,
    required this.scheduleState,
  });

  @override
  State<PaymentDetailPanel> createState() => _PaymentDetailPanelState();
}

class _PaymentDetailPanelState extends State<PaymentDetailPanel>
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

  // ===== PAYMENT METHOD STATE =====
  int _selectedPaymentMethod = 2; // Default: Credit Card
  double _tipAmount = 0.0;
  String _selectedTipOption = '';
  final TextEditingController _tipController = TextEditingController();

  // ⭐ GIFT CARD STATE
  List<Map<String, dynamic>> _scannedGiftCards = [];
  double _giftCardTotalAmount = 0.0;
  Timer? _tipDebounceTimer;

  StoreInfo? _storeInfo;
  bool _isLoadingStoreInfo = false;
  bool _isProcessingPayment = false;

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
  void dispose() {
    _animationController.dispose();
    _discountCodeController.dispose();
    _tipController.dispose();
    _tipDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleClose() async {
    await _animationController.reverse();
    widget.onClose();
  }

  //---------------------
  // ⭐ GIFT CARD FUNCTIONS
  //---------------------

  Future<void> _openGiftCardScanner() async {
    final serviceItems = widget.task.serviceItems ?? [];
    final fee = _storeInfo?.fee ?? 0.0;
    final serviceCount = serviceItems.length;
    final cashDiscount = _selectedPaymentMethod == 1 ? (fee * serviceCount) : 0.0;

    // Calculate what we still need to scan
    final totalNeeded = _amountAfterDiscount - cashDiscount + _tipAmount;
    final shortage = totalNeeded - _giftCardTotalAmount;

    final amountToScan = _giftCardTotalAmount > 0
        ? (shortage > 0 ? shortage : 0.01)
        : totalNeeded;

    if (amountToScan <= 0) {
      if (!mounted) return;
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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This gift card has no remaining balance.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      // Has remaining balance - update the card
      setState(() {
        _scannedGiftCards[existingCardIndex] = {
          'code': code,
          'balance': balance,
          'usedAmount': currentUsed + deductAmount,
        };
        _calculateGiftCardTotal();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gift card updated: +\$${deductAmount.toStringAsFixed(2)} (Total: \$${(currentUsed + deductAmount).toStringAsFixed(2)})',
          ),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // New card - add it
    setState(() {
      _scannedGiftCards.add({
        'code': code,
        'balance': balance,
        'usedAmount': deductAmount,
      });
      _calculateGiftCardTotal();
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gift card added: \$${deductAmount.toStringAsFixed(2)}'),
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

    if (!mounted) return;
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

  void _validateGiftCardCoverage() {
    final serviceItems = widget.task.serviceItems ?? [];
    final fee = _storeInfo?.fee ?? 0.0;
    final serviceCount = serviceItems.length;
    final cashDiscount = _selectedPaymentMethod == 1 ? (fee * serviceCount) : 0.0;

    final remainingAmount = _amountAfterDiscount - cashDiscount;
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
            const Expanded(
              child: Text(
                'Insufficient Gift Card Amount',
                style: TextStyle(fontSize: 16),
              ),
            ),
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
                  _buildDialogInfoRow(
                    'Gift card total:',
                    '\$${_giftCardTotalAmount.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 4),
                  _buildDialogInfoRow(
                    'Amount needed:',
                    '\$${(_giftCardTotalAmount + shortage).toStringAsFixed(2)}',
                  ),
                  const Divider(height: 16),
                  _buildDialogInfoRow(
                    'Shortage:',
                    '\$${shortage.toStringAsFixed(2)}',
                    valueColor: Colors.red.shade700,
                    boldValue: true,
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

  Widget _buildDialogInfoRow(String label, String value,
      {Color? valueColor, bool boldValue = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: boldValue ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }

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

  void _adjustGiftCardsForTipChange() {
    if (_scannedGiftCards.isEmpty) return;

    final serviceItems = widget.task.serviceItems ?? [];
    final fee = _storeInfo?.fee ?? 0.0;
    final serviceCount = serviceItems.length;
    final cashDiscount = _selectedPaymentMethod == 1 ? (fee * serviceCount) : 0.0;

    final remainingAmount = _amountAfterDiscount - cashDiscount;
    final totalNeeded = remainingAmount + _tipAmount;
    final currentTotal = _giftCardTotalAmount;

    final difference = totalNeeded - currentTotal;

    if (difference > 0.01) {
      // Tips INCREASED → Shortage
      _showGiftCardShortageDialog(difference);
    } else if (difference < -0.01) {
      // Tips DECREASED → Excess
      final excess = -difference;
      _reduceGiftCardAmount(excess);
    }
  }

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
              'Gift card ${card['code']} reduced by \$${excessAmount.toStringAsFixed(2)}',
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

  //---------------------
  // PAYMENT PROCESSING
  //---------------------

  Future<void> _processPayment() async {
    if (_isProcessingPayment) return;

    // ⭐ VALIDATE GIFT CARD COVERAGE
    if (_selectedPaymentMethod == 3) {
      if (_scannedGiftCards.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please scan at least one gift card'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final serviceItems = widget.task.serviceItems ?? [];
      final fee = _storeInfo?.fee ?? 0.0;
      final serviceCount = serviceItems.length;
      final cashDiscount = _selectedPaymentMethod == 1 ? (fee * serviceCount) : 0.0;
      final totalNeeded = _amountAfterDiscount - cashDiscount + _tipAmount;
      final shortage = totalNeeded - _giftCardTotalAmount;

      if (shortage > 0.01) {
        _validateGiftCardCoverage();
        return;
      }
    }

    setState(() => _isProcessingPayment = true);

    final bookingId = widget.task.bookingId;
    final amountAfterDiscount = _amountAfterDiscount;
    final discountCode = _appliedDiscount?['code'] as String?;

    final serviceItems = widget.task.serviceItems ?? [];
    final fee = _storeInfo?.fee ?? 0.0;
    final serviceCount = serviceItems.length;
    final cashDiscount = _selectedPaymentMethod == 1 ? (fee * serviceCount) : 0.0;
    final remainingAmount = amountAfterDiscount - cashDiscount;

    // ⭐ PREPARE GIFT CARD USAGES
    List<Map<String, dynamic>> mappedGiftCardUsages = [];
    if (_selectedPaymentMethod == 3 && _scannedGiftCards.isNotEmpty) {
      mappedGiftCardUsages = _scannedGiftCards.map((card) {
        final String code = card['code'];
        final double balance = (card['balance'] as num?)?.toDouble() ?? 0.0;
        final double usedAmount = (card['usedAmount'] as num?)?.toDouble() ?? 0.0;

        return {
          'code': code,
          'deductedAmount': usedAmount,
          'remainingBalance': balance - usedAmount,
        };
      }).toList();
    }

    try {
      await ApiService.completePayment(
        bookingId: bookingId,
        paymentMethod: _selectedPaymentMethod,
        tips: _tipAmount,
        giftCardUsages: mappedGiftCardUsages,
        giftCardAmount: _giftCardTotalAmount,
        cashPaidAmount: _selectedPaymentMethod == 1 ? remainingAmount : 0.0,
        creditAmount: _selectedPaymentMethod == 2 ? remainingAmount : 0.0,
        chequeAmount: 0.0,
        discountCode: discountCode ?? '',
      );

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

        widget.onPaymentSuccess();
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
    } finally {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
      }
    }
  }

  //---------------------
  // DISCOUNT CODE
  //---------------------

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

          setState(() {
            _appliedDiscount = discountData;
            _discountAmount = discountAmount;
            _amountAfterDiscount = amountAfterDiscount;
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

    final serviceItems = widget.task.serviceItems ?? [];
    final fee = _storeInfo?.fee ?? 0.0;
    final serviceCount = serviceItems.length;
    final cashDiscount = _selectedPaymentMethod == 1 ? (fee * serviceCount) : 0.0;
    final remainingAmount = _amountAfterDiscount - cashDiscount;
    final totalAmount = remainingAmount + _tipAmount;

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
            // ===== HEADER =====
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
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.payment,
                              color: Colors.purple,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'PENDING PAYMENT',
                              style: TextStyle(
                                color: Colors.purple,
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

            // ===== SCROLLABLE CONTENT =====
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ===== CUSTOMER INFO =====
                    _buildInfoCard(appointmentDate: appointmentDate),
                    const SizedBox(height: 16),

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

                    const SizedBox(height: 20),

                    // ===== DISCOUNT SECTION =====
                    _buildDiscountCodeSection(),

                    const SizedBox(height: 20),

                    // ===== TIP SECTION =====
                    _buildTipSection(remainingAmount),

                    const SizedBox(height: 20),

                    // ===== PAYMENT METHOD =====
                    _buildPaymentMethodSection(),

                    // ⭐ GIFT CARD DISPLAY (if payment method is Giftcard)
                    if (_selectedPaymentMethod == 3) ...[
                      const SizedBox(height: 16),
                      _buildGiftCardSection(),
                    ],

                    const SizedBox(height: 20),

                    // ===== AMOUNT SUMMARY =====
                    _buildAmountSummary(
                      amountAfterDiscount: _amountAfterDiscount,
                      cashDiscount: cashDiscount,
                      remainingAmount: remainingAmount,
                      totalAmount: totalAmount,
                    ),
                  ],
                ),
              ),
            ),

            // ===== COMPLETE PAYMENT BUTTON =====
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isProcessingPayment ? null : _processPayment,
                  icon: _isProcessingPayment
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.check_circle, color: Colors.white),
                  label: Text(
                    _isProcessingPayment ? 'Processing...' : 'Complete Payment',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== WIDGET BUILDERS =====

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
          _buildInfoRow(label: 'Customer', value: widget.task.fullName),
          const SizedBox(height: 8),
          Divider(height: 1, color: Colors.grey[200]),
          const SizedBox(height: 8),
          _buildInfoRow(label: 'Time', value: appointmentDate),
          const SizedBox(height: 8),
          Divider(height: 1, color: Colors.grey[200]),
          const SizedBox(height: 8),
          _buildInfoRow(label: 'Booking', value: '#${widget.task.bookingId}'),
        ],
      ),
    );
  }

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

  Widget _buildServicesCard() {
    if (widget.task.serviceItems == null || widget.task.serviceItems!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Row(
          children: [
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
        children: widget.task.serviceItems!.asMap().entries.map((entry) {
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

  Widget _buildDiscountCodeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.local_offer,
                  color: Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Discount Code',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_appliedDiscount == null) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _discountCodeController,
                    decoration: InputDecoration(
                      hintText: 'Enter discount code',
                      prefixIcon: const Icon(Icons.discount, color: Colors.orange),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    textCapitalization: TextCapitalization.characters,
                    enabled: !_isApplyingDiscount,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isApplyingDiscount ? null : _applyDiscountCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isApplyingDiscount
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white),
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
            ),
          ] else
            _buildAppliedDiscountCard(),
        ],
      ),
    );
  }

  Widget _buildAppliedDiscountCard() {
    final code = _appliedDiscount!['code'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
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
                      'Saved: ${_formatCurrency(_discountAmount)}',
                      style: TextStyle(fontSize: 12, color: Colors.green[700]),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _removeDiscount,
                icon: const Icon(Icons.close, color: Colors.red),
                tooltip: 'Remove discount',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTipSection(double remainingAmount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.volunteer_activism,
                  color: Colors.purple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Add Tip (Optional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildTipButton('10%', () {
                _handleTipChange(remainingAmount * 0.10);
                setState(() {
                  _selectedTipOption = '10%';
                  _tipController.clear();
                });
              }),
              const SizedBox(width: 8),
              _buildTipButton('15%', () {
                _handleTipChange(remainingAmount * 0.15);
                setState(() {
                  _selectedTipOption = '15%';
                  _tipController.clear();
                });
              }),
              const SizedBox(width: 8),
              _buildTipButton('20%', () {
                _handleTipChange(remainingAmount * 0.20);
                setState(() {
                  _selectedTipOption = '20%';
                  _tipController.clear();
                });
              }),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tipController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Custom Tip',
              prefixText: '\$ ',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: _selectedTipOption == 'custom'
                  ? Colors.purple[50]
                  : Colors.white,
            ),
            onChanged: (value) {
              setState(() {
                _selectedTipOption = 'custom';
              });
              final newTip = double.tryParse(value) ?? 0.0;
              _handleTipChange(newTip);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTipButton(String label, VoidCallback onTap) {
    final selected = _selectedTipOption == label;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.purple : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? Colors.purple : const Color(0xFFE5E7EB),
              width: selected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.payment,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Payment Method',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.5,
            children: _paymentMethods.entries.map((e) {
              final selected = _selectedPaymentMethod == e.key;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedPaymentMethod = e.key;
                  });

                  // ⭐ OPEN SCANNER IMMEDIATELY WHEN GIFTCARD IS SELECTED
                  if (e.key == 3) {
                    _openGiftCardScanner();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected ? Colors.blue : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? Colors.blue : Colors.grey[300]!,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _paymentIcons[e.key],
                        size: 24,
                        color: selected ? Colors.white : Colors.black87,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ⭐ GIFT CARD DISPLAY SECTION
  Widget _buildGiftCardSection() {
    if (_scannedGiftCards.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Click the Giftcard button to scan cards',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final serviceItems = widget.task.serviceItems ?? [];
    final fee = _storeInfo?.fee ?? 0.0;
    final serviceCount = serviceItems.length;
    final cashDiscount = _selectedPaymentMethod == 1 ? (fee * serviceCount) : 0.0;
    final totalNeeded = _amountAfterDiscount - cashDiscount + _tipAmount;
    final shortage = totalNeeded - _giftCardTotalAmount;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Scanned Gift Cards:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: _openGiftCardScanner,
                icon: const Icon(Icons.add, size: 16),
                label: const Text(
                  'Add More',
                  style: TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ⭐ GIFT CARD LIST
          ..._scannedGiftCards.map((card) {
            final code = card['code'] as String;
            final usedAmount = (card['usedAmount'] as num).toDouble();
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '****${code.substring(code.length - 4)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Text(
                    '\$${usedAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _removeGiftCard(code),
                  ),
                ],
              ),
            );
          }).toList(),

          const Divider(height: 12),

          // ⭐ TOTAL
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '\$${_giftCardTotalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
            ],
          ),

          // ⭐ SHORTAGE WARNING
          if (shortage > 0.01) ...[
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
                      'Shortage: \$${shortage.toStringAsFixed(2)} - Scan more cards',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.w600,
                      ),
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

  Widget _buildAmountSummary({
    required double amountAfterDiscount,
    required double cashDiscount,
    required double remainingAmount,
    required double totalAmount,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          _buildAmountRow('Amount After Discount', _formatCurrency(amountAfterDiscount)),
          if (cashDiscount > 0) ...[
            const SizedBox(height: 8),
            _buildAmountRow(
              'Cash Discount',
              '- ${_formatCurrency(cashDiscount)}',
              valueColor: Colors.green,
            ),
            const SizedBox(height: 8),
            _buildAmountRow('Remaining', _formatCurrency(remainingAmount)),
          ],

          // ⭐ GIFT CARD DEDUCTION
          if (_selectedPaymentMethod == 3 && _giftCardTotalAmount > 0) ...[
            const SizedBox(height: 8),
            _buildAmountRow(
              'Gift Card Amount',
              '- ${_formatCurrency(_giftCardTotalAmount)}',
              valueColor: Colors.purple,
            ),
          ],

          if (_tipAmount > 0) ...[
            const SizedBox(height: 8),
            _buildAmountRow('Tips', _formatCurrency(_tipAmount)),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _buildAmountRow(
            'TOTAL AMOUNT',
            _formatCurrency(totalAmount),
            isBold: true,
            valueColor: Colors.green,
            fontSize: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildAmountRow(
      String label,
      String value, {
        bool isBold = false,
        Color? valueColor,
        double fontSize = 14,
      }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize + (isBold ? 2 : 0),
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}