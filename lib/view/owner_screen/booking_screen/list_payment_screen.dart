// view/owner_screen/payment_tab.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hair_sallon/api/api_service.dart';
import 'package:hair_sallon/api/payment_model.dart';

import '../qr_scanner/qr_scanner_screen.dart';

class _PaymentDetailState {
  List<Map<String, dynamic>> usedGiftCards = [];
  double totalGiftAmount = 0.0;
  double cashPaid = 0.0;
  double change = 0.0;
  final TextEditingController cashController = TextEditingController();
}

class PaymentTab extends StatefulWidget {
  const PaymentTab({super.key});

  @override
  State<PaymentTab> createState() => _PaymentTabState();
}

class _PaymentTabState extends State<PaymentTab> {
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  List<PaymentHistoryDTO> _paymentData = [];
  List<PaymentHistoryDTO> _filteredPaymentData = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  int _page = 0;
  final int _pageSize = 10;
  final double _loadThreshold = 200.0;
  Timer? _searchDebounce;
  String _lastSearchQuery = '';
  PaymentHistoryDTO? _selectedPayment;

  final Map<int, _PaymentDetailState> _paymentDetailStates = {};


  @override
  void initState() {
    super.initState();
    _fetchPaymentData(isRefresh: true);
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final currentQuery = _searchController.text.trim();
    if (currentQuery == _lastSearchQuery) return;

    if (_searchDebounce?.isActive ?? false) {
      _searchDebounce?.cancel();
    }

    _searchDebounce = Timer(const Duration(seconds: 2), () {
      _lastSearchQuery = currentQuery;
      _fetchPaymentData(isRefresh: true);
    });
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (maxScroll - currentScroll <= _loadThreshold) {
      _fetchPaymentData(isRefresh: false);
    }
  }

  Future<void> _fetchPaymentData({required bool isRefresh}) async {
    if (isRefresh) {
      setState(() {
        _isLoading = true;
        _paymentData.clear();
        _filteredPaymentData.clear();
        _page = 0;
        _hasMore = true;
      });
    } else if (_isLoadingMore || !_hasMore) {
      return;
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final response = await ApiService.getPaymentHistory(
        searchQuery: _lastSearchQuery,
        page: _page,
        size: _pageSize,
      );

      if (!mounted) return;

      setState(() {
        if (isRefresh) {
          _paymentData = response.payments;
          _filteredPaymentData = response.payments;
        } else {
          _paymentData.addAll(response.payments);
          _filteredPaymentData.addAll(response.payments);
        }

        if (response.payments.length < _pageSize) {
          _hasMore = false;
        }

        _page++;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });

      if (!isRefresh) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _refreshData() async {
    if (_searchDebounce?.isActive ?? false) {
      _searchDebounce?.cancel();
    }
    await _fetchPaymentData(isRefresh: true);
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

  String _formatPhoneNumber(String phone) {
    if (phone.length == 10) {
      return '(${phone.substring(0, 3)}) ${phone.substring(3, 6)}-${phone.substring(6)}';
    } else if (phone.length == 11 && phone.startsWith('1')) {
      return '+1 (${phone.substring(1, 4)}) ${phone.substring(4, 7)}-${phone.substring(7)}';
    }
    return phone;
  }

  void _showPaymentDetail(PaymentHistoryDTO payment) {
    setState(() {
      _selectedPayment = payment;
    });

    // KHỞI TẠO STATE NẾU CHƯA CÓ
    if (!_paymentDetailStates.containsKey(payment.id)) {
      _paymentDetailStates[payment.id] = _PaymentDetailState();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => _buildPaymentDetailSheet(payment),
    ).then((_) async {
      // Revert all gift cards if user closes without confirming
      final detailState = _paymentDetailStates[payment.id];
      if (detailState != null && detailState.usedGiftCards.isNotEmpty) {
        for (var gc in detailState.usedGiftCards) {
          try {
            await ApiService.revertGiftCardUsage(gc['usageId'] as String);
          } catch (e) {
            print('Failed to revert gift card usage ${gc['usageId']}: $e');
          }
        }
      }

      setState(() {
        _selectedPayment = null;
      });
      // CLEAR STATE KHI ĐÓNG BOTTOM SHEET
      _paymentDetailStates.remove(payment.id);
    });
  }


  Widget _buildPaymentDetailSheet(PaymentHistoryDTO payment) {
    // LẤY STATE TỪ MAP
    final detailState = _paymentDetailStates[payment.id]!;

    // LOGIC: Remaining dựa trên Credit Total (sau khi trừ gift)
    double getRemainingCreditAmount() {
      return payment.totalCreditAmount - detailState.totalGiftAmount;
    }

    // Cash Total không bị ảnh hưởng bởi gift card
    double getCashAmount() {
      return payment.totalCashAmount;
    }

    Future<void> addGiftCard(Function(void Function()) setSheetState) async {
      double remainingCredit = getRemainingCreditAmount();

      if (remainingCredit <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No remaining credit to pay'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QRScannerScreen(
            maxAmount: remainingCredit,
          ),
        ),
      );

      if (result != null && result is Map<String, dynamic>) {
        // SỬ DỤNG setSheetState để update UI ngay lập tức
        setSheetState(() {
          detailState.usedGiftCards.add(result);
          detailState.totalGiftAmount += result['deductAmount'] as double;
        });

        // Hiển thị snackbar thông báo thành công
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added ${_formatCurrency(result['deductAmount'] as double)} from ${result['code']}',
            ),
            backgroundColor: Colors.purple,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }

    Future<void> confirmPayment(Function(void Function()) setSheetState) async {
      double remainingCredit = getRemainingCreditAmount();
      double cashAmount = getCashAmount();


      // ✅ FIX: Kiểm tra cash paid có đủ cash total không
      if (detailState.cashPaid > 0 && detailState.cashPaid + detailState.totalGiftAmount < cashAmount) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cash payment insufficient'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      int method;
      double creditAmount = 0;
      double finalCashAmount = 0;

      // ✅ Chuẩn hoá giftCardUsages theo format backend
      List<Map<String, dynamic>> giftCardUsages = detailState.usedGiftCards
          .where((gc) => gc['code'] != null)
          .map((gc) => {
        'code': gc['code'] as String,
        'deductedAmount': gc['deductAmount'] as double,
        'remainingBalance': gc['balance'] as double,
      })
          .toList();

      bool hasGiftCard = detailState.totalGiftAmount > 0;
      bool hasCash = detailState.cashPaid > 0;

      // ✅ Xác định payment method mới - FIX LOGIC ĐƠN GIẢN
      if (hasGiftCard && hasCash) {
        method = 5; // Gift + Cash
        finalCashAmount = detailState.cashPaid;
        creditAmount = 0;
      } else if (hasGiftCard && !hasCash) {
        method = 3; // Chỉ Gift
        finalCashAmount = 0;
        creditAmount = 0;
      } else if (hasCash && !hasGiftCard) {
        method = 1; // Chỉ Cash
        finalCashAmount = detailState.cashPaid;
        creditAmount = 0;
      } else {
        // Nếu không có cả gift card lẫn cash, mặc định là credit
        method = 2; // Chỉ Credit
        finalCashAmount = 0;
        creditAmount = remainingCredit;
      }

      // ✅ Nếu đã dùng gift card và chọn credit
      if (detailState.totalGiftAmount > 0 && method == 3) {
        method = 4; // Gift + Credit
        // Credit amount = remaining sau khi trừ gift
        creditAmount = remainingCredit;
      }

      try {
        await ApiService.completePayment(
          bookingId: payment.id,
          paymentMethod: method,
          giftCardUsages: giftCardUsages,
          giftCardAmount: detailState.totalGiftAmount,
          cashPaidAmount: finalCashAmount,
          creditAmount: creditAmount,
          discountCode: "", tips: 0
        );

        if (mounted) {
          // XÓA STATE SAU KHI THANH TOÁN THÀNH CÔNG
          _paymentDetailStates.remove(payment.id);
          Navigator.of(context).pop();

          String message = 'Payment completed: ';
          if (detailState.totalGiftAmount > 0) {
            message += 'Gift \$${detailState.totalGiftAmount.toStringAsFixed(2)}, ';
          }
          if (finalCashAmount > 0) {
            message +=
            'Cash \$${finalCashAmount.toStringAsFixed(2)} (Change: \$${detailState.change.toStringAsFixed(2)}), ';
          }
          if (creditAmount > 0) {
            message += 'Credit \$${creditAmount.toStringAsFixed(2)}';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
          _fetchPaymentData(isRefresh: true);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }

    void showCashInput(Function(void Function()) setSheetState) {
      // ✅ FIX: Cash amount phải là phần còn lại sau khi trừ gift card
      double cashRequired = payment.totalCashAmount - detailState.totalGiftAmount;

      detailState.cashController.text = cashRequired.toStringAsFixed(2);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Enter Cash Amount'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ FIX: Hiển thị số tiền cần trả (sau khi trừ gift)
              Text('Cash Required: ${_formatCurrency(cashRequired)}'),
              const SizedBox(height: 8),
              TextField(
                controller: detailState.cashController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'Enter amount (>= ${cashRequired.toStringAsFixed(2)})',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                double? cash = double.tryParse(detailState.cashController.text);
                // ✅ FIX: Validate theo cashRequired chứ không phải cashAmount
                if (cash != null && cash >= cashRequired && cash > 0) {
                  setSheetState(() {
                    detailState.cashPaid = cash;
                    // ✅ FIX: Change = tiền nhập - tiền cần trả
                    detailState.change = cash - cashRequired;
                  });
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Amount must be at least ${_formatCurrency(cashRequired)}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
    }

    // Kiểm tra xem tất cả dịch vụ có cùng một nhân viên không
    final allStaffSame = _areAllStaffSame(payment.bookingServices);
    final String? commonStaffName = allStaffSame && payment.bookingServices.isNotEmpty
        ? payment.bookingServices.first.staff?.fullName
        : null;

    return StatefulBuilder(
      builder: (context, setSheetState) {
        double remainingCredit = getRemainingCreditAmount();
        double cashAmount = getCashAmount();

        // ✅ FIX 2: Kiểm tra xem remaining đã hết chưa
        bool isRemainingZero = remainingCredit <= 0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Payment Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Customer Info
              Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundImage: NetworkImage(payment.customerAvt),
                    backgroundColor: Colors.grey.shade200,
                    child: payment.customerAvt.isEmpty
                        ? Text(
                      payment.customerName.isNotEmpty
                          ? payment.customerName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(color: Colors.grey),
                    )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payment.customerName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatPhoneNumber(payment.customerPhone),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Services List
              const Text(
                'Services:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              if (allStaffSame && commonStaffName != null)
                _buildServicesTable(payment.bookingServices, commonStaffName)
              else
                ...payment.bookingServices
                    .map((service) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.service?.name ?? 'Unknown Service',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (service.staff != null) ...[
                        Text(
                          'Staff: ${service.staff!.fullName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Credit: ${_formatCurrency(service.displayPrice)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Cash: ${_formatCurrency(service.displayCashPrice)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (service.priceNote != null &&
                          service.priceNote!.isNotEmpty)
                        Text(
                          'Note: ${service.priceNote!}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                    ],
                  ),
                ))
                    .toList(),

              const SizedBox(height: 16),

              // Totals Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (payment.tip > 0) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Tip:',
                            style: TextStyle(fontSize: 14),
                          ),
                          Text(
                            _formatCurrency(payment.tip),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Credit Total:',
                          style: TextStyle(fontSize: 14),
                        ),
                        Text(
                          _formatCurrency(payment.totalCreditAmount),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Cash Total:',
                          style: TextStyle(fontSize: 14),
                        ),
                        Text(
                          _formatCurrency(payment.totalCashAmount),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Remaining Amount
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isRemainingZero ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isRemainingZero ? Colors.green.shade200 : Colors.red.shade200,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isRemainingZero ? 'Paid in Full' : 'Remaining:',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _formatCurrency(remainingCredit),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isRemainingZero ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),

              // Gift Cards Used
              if (detailState.usedGiftCards.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
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
                        children: [
                          Icon(Icons.card_giftcard, color: Colors.purple.shade700, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Gift Cards Used:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...detailState.usedGiftCards.map((gc) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                gc['code'].toString(),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              '-${_formatCurrency(gc['deductAmount'] as double)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple,
                              ),
                            ),
                          ],
                        ),
                      )),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Gift:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _formatCurrency(detailState.totalGiftAmount),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // ✅ FIX 1 & 2: Payment Buttons với logic mới
              Row(
                children: [
                  // Gift Card Button - Disable khi remaining = 0
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: !isRemainingZero
                          ? () => addGiftCard(setSheetState)
                          : null,
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      label: const Text('Gift Card'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purpleAccent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Cash Button - Disable khi remaining = 0 HOẶC không có cash amount
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (cashAmount > 0 && !isRemainingZero)
                          ? () => showCashInput(setSheetState)
                          : null,
                      icon: const Icon(Icons.money, size: 18),
                      label: const Text('Cash'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Credit Button - Enable khi:
                  // - Remaining > 0
                  // - Cash amount = 0 (không có cash total)
                  // - Chưa dùng gift card
                  // - Disable khi remaining = 0
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (!isRemainingZero)
                          ? () => _completePayment(payment.id, 2)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                      child: const Text('Credit'),
                    ),
                  ),
                ],
              ),

              // Confirm Button - Hiển thị khi:
              // - Đã dùng gift card HOẶC đã nhập cash
              // - Bao gồm cả trường hợp remaining = 0 (gift card trả hết)
              if (detailState.totalGiftAmount > 0 || detailState.cashPaid > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Center(
                    child: ElevatedButton(
                      onPressed: () => confirmPayment(setSheetState),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text(
                        'Confirm Payment',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // Widget hiển thị services theo dạng bảng
  Widget _buildServicesTable(List<PaymentServiceDTO> services, String staffName) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Staff:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    staffName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: services.asMap().entries.map((entry) {
                  final index = entry.key;
                  final service = entry.value;
                  return Container(
                    margin: EdgeInsets.only(bottom: index == services.length - 1 ? 0 : 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.service?.name ?? 'Unknown Service',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Credit: ${_formatCurrency(service.displayPrice)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Cash: ${_formatCurrency(service.displayCashPrice)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (service.priceNote != null && service.priceNote!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Note: ${service.priceNote!}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade700,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
      ],
    );
  }

  // Hàm kiểm tra xem tất cả dịch vụ có cùng một nhân viên không
  bool _areAllStaffSame(List<PaymentServiceDTO> services) {
    if (services.isEmpty) return true;

    final firstStaffId = services.first.staff?.id;
    if (firstStaffId == null) return false;

    for (final service in services) {
      if (service.staff?.id != firstStaffId) {
        return false;
      }
    }

    return true;
  }

  Future<void> _completePayment(int bookingId, int paymentMethod) async {
    try {
      await ApiService.completePayment(
        bookingId: bookingId,
        paymentMethod: paymentMethod,
        discountCode: "",
        tips: 0
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment completed successfully')),
        );

        // Refresh data
        _fetchPaymentData(isRefresh: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    // DISPOSE ALL DETAIL STATES
    for (final state in _paymentDetailStates.values) {
      state.cashController.dispose();
    }
    _paymentDetailStates.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Stack(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by customer name or phone...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: const BorderSide(color: Colors.green),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
              ),
              if (_searchDebounce?.isActive ?? false)
                Positioned(
                  right: 8,
                  top: 8,
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshData,
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) => false,
              child: _isLoading
                  ? const Center(
                child: CircularProgressIndicator(),
              )
                  : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                controller: _scrollController,
                slivers: [
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final payment = _filteredPaymentData[index];
                        final startTime = payment.parsedStartTime;

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: InkWell(
                            // onTap: () => _showPaymentDetail(payment),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Customer Avatar
                                  CircleAvatar(
                                    radius: 25,
                                    backgroundImage: NetworkImage(payment.customerAvt),
                                    backgroundColor: Colors.grey.shade200,
                                    child: payment.customerAvt.isEmpty
                                        ? Text(
                                      payment.customerName.isNotEmpty
                                          ? payment.customerName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                      ),
                                    )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),

                                  // Customer Information
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          payment.customerName,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatPhoneNumber(payment.customerPhone),
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Total: ${_formatCurrency(payment.totalCreditAmount)}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Booking Time
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        _formatTime(startTime),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                        ),
                                      ),
                                      Text(
                                        _formatDate(startTime),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: _filteredPaymentData.length,
                    ),
                  ),

                  if (_isLoadingMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),

                  if (_filteredPaymentData.isEmpty && (_searchController.text.isNotEmpty || _lastSearchQuery.isNotEmpty))
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(
                          child: Text(
                            'No payments found',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}