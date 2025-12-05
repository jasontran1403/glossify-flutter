// lib/view/owner_screen/giftcard_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ Thêm import cho TextInputFormatter
import 'package:hair_sallon/api/api_service.dart';
import 'package:hair_sallon/view/owner_screen/shimmer_loading.dart';
import 'package:intl/intl.dart';

import '../../api/giftcard_transaction_history.dart';
import '../bottombar_screen/qr_scan_inventory_screen.dart';

/// ✅ Custom Formatter cho US Phone: Format thành (XXX) XXX-XXXX, data gửi chỉ số thuần
class USPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final newText = newValue.text;

    // Chỉ cho phép số
    if (!RegExp(r'^\d+$').hasMatch(newText)) {
      return oldValue;
    }

    // Format: (XXX) XXX-XXXX (tối đa 10 chữ số)
    if (newText.length <= 10) {
      final buffer = StringBuffer();
      if (newText.length >= 3) {
        buffer.write('(');
        buffer.write(newText.substring(0, 3));
        buffer.write(') ');
      } else {
        buffer.write(newText);
      }
      if (newText.length > 3) {
        if (newText.length >= 6) {
          buffer.write(newText.substring(3, 6));
        } else {
          buffer.write(newText.substring(3));
        }
        buffer.write('-');
      }
      if (newText.length > 6) {
        // ✅ Fix: Cap end at newText.length to avoid RangeError when length < 10
        final endIndex = min(10, newText.length);
        buffer.write(newText.substring(6, endIndex));
      }

      return TextEditingValue(
        text: buffer.toString(),
        selection: TextSelection.collapsed(offset: buffer.length),
      );
    }

    return oldValue;
  }
}

class GiftcardScreen extends StatefulWidget {
  const GiftcardScreen({super.key});

  @override
  State<GiftcardScreen> createState() => _GiftcardScreenState();
}

class _GiftcardScreenState extends State<GiftcardScreen> {
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  List<GiftCardTransactionHistory> _historyData = [];
  List<GiftCardTransactionHistory> _filteredHistoryData = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  int _page = 0;
  final int _pageSize = 10;
  final double _loadThreshold = 200.0;
  ScaffoldMessengerState? _scaffoldMessenger; // ✅ Thêm reference để tránh ancestor lookup error

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger ??= ScaffoldMessenger.of(context); // ✅ Capture messenger state
  }

  @override
  void initState() {
    super.initState();
    _fetchHistoryData(isRefresh: true);
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      _page = 0;
      _hasMore = true;
    });
    _fetchHistoryData(isRefresh: true);
  }

  void _closeLoader() {
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();  // Use local navigator (default, no rootNavigator: true)
    }
  }

  /// ✅ Helper để show SnackBar an toàn
  void _showSnackBar({
    required String message,
    required Color backgroundColor,
  }) {
    if (mounted && _scaffoldMessenger != null) {
      _scaffoldMessenger!.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
        ),
      );
    }
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (maxScroll - currentScroll <= _loadThreshold) {
      _fetchHistoryData(isRefresh: false);
    }
  }

  Future<void> _fetchHistoryData({required bool isRefresh}) async {
    if (isRefresh) {
      setState(() {
        _isLoading = true;
        _historyData.clear();
        _filteredHistoryData.clear();
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
      final result = await ApiService.getGiftcardHistory(
        page: _page,
        size: _pageSize,
        search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      );

      if (!mounted) return;

      final List<GiftCardTransactionHistory> newData = result['content'];
      final bool hasNextPage = result['hasNextPage'];

      setState(() {
        if (isRefresh) {
          _historyData = newData;
          _filteredHistoryData = List.from(_historyData);
        } else {
          _historyData.addAll(newData);
          _filteredHistoryData = List.from(_historyData);
        }

        _hasMore = hasNextPage;
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

      _showSnackBar(
        message: 'Error loading history: $e',
        backgroundColor: Colors.red,
      );
    }
  }

  Future<void> _refreshData() async {
    await _fetchHistoryData(isRefresh: true);
  }

  /// Scan QR Code và kiểm tra gift card
  void _scanQRCode() async {
    final scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const QRScanInventoryScreen(),
      ),
    );

    if (scannedCode == null || !mounted) return;

    // Show loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Check if gift card exists
      final exists = await ApiService.checkGiftCardExists(scannedCode);

      if (!mounted) return;
      if (mounted) _closeLoader(); // Close loading

      if (exists) {
        // Gift card đã tồn tại → Show TOPUP dialog
        _showTopupDialog(scannedCode);
      } else {
        // Gift card chưa tồn tại → Show ACTIVATE dialog
        _showActivateDialog(scannedCode);
      }
    } catch (e) {
      if (!mounted) return;
      if (mounted) _closeLoader(); // Close loading

      _showSnackBar(
        message: 'Error checking gift card: $e',
        backgroundColor: Colors.red,
      );
    }
  }

  /// Extract chỉ số thuần từ formatted phone (e.g., "(970) 710-1066" → "9707101066")
  String _extractPhoneDigits(String formattedPhone) {
    return formattedPhone.replaceAll(RegExp(r'[^\d]'), '');
  }

  /// Dialog để ACTIVATE gift card mới (card chưa tồn tại trong DB)
  void _showActivateDialog(String scannedCode) {
    final amountController = TextEditingController();
    final phoneController = TextEditingController();

    // 1 = Owner (hiện input phone), 2 = No Owner (ẩn input, gửi số cố định)
    int ownerOption = 1; // mặc định là có chủ
    int selectedPaymentMethod = 1; // 1: Credit, 2: Cash

    // Số điện thoại hardcode khi chọn "No Owner"
    const String noOwnerPhone = '9707101060'; // 6839589712 → backend sẽ tự thêm +1

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.card_giftcard, color: Colors.green, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Activate Gift Card', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Scanned Code
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.qr_code_2, color: Colors.purple),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Scanned Code', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text(scannedCode, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Radio: Owner / No Owner
                const Text('Owner', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<int>(
                        title: const Text('Owner'),
                        value: 1,
                        groupValue: ownerOption,
                        onChanged: (val) => setDialogState(() => ownerOption = val!),
                        dense: true,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<int>(
                        title: const Text('No Owner'),
                        value: 2,
                        groupValue: ownerOption,
                        onChanged: (val) => setDialogState(() => ownerOption = val!),
                        dense: true,
                      ),
                    ),
                  ],
                ),

                // Input Phone + Nút Default – chỉ hiện khi chọn Owner
                if (ownerOption == 1) ...[
                  TextField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: 'Owner Phone Number *',
                      hintText: '(970) 710-1066',
                      prefixText: '+1 ',
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      USPhoneFormatter(),
                    ],
                  ),
                  const SizedBox(height: 8),
                ] else ...[
                ],

                // Amount
                TextField(
                  controller: amountController,
                  decoration: InputDecoration(
                    labelText: 'Initial Amount *',
                    hintText: '0.00',
                    prefixIcon: const Icon(Icons.attach_money),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),

                // Payment Method
                const Text('Payment Method', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<int>(
                        title: const Text('Credit'),
                        value: 1,
                        groupValue: selectedPaymentMethod,
                        onChanged: (value) => setDialogState(() => selectedPaymentMethod = value!),
                        dense: true,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<int>(
                        title: const Text('Cash'),
                        value: 2,
                        groupValue: selectedPaymentMethod,
                        onChanged: (value) => setDialogState(() => selectedPaymentMethod = value!),
                        dense: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amountText = amountController.text.trim();
                final amount = double.tryParse(amountText);

                if (amount == null || amount <= 0) {
                  _showSnackBar(message: 'Please enter a valid amount', backgroundColor: Colors.orange);
                  return;
                }

                String? phoneDigits;
                if (ownerOption == 1) {
                  final formatted = phoneController.text.trim();
                  phoneDigits = _extractPhoneDigits(formatted);
                  if (phoneDigits.length != 10) {
                    _showSnackBar(message: 'Phone must be 10 digits', backgroundColor: Colors.orange);
                    return;
                  }
                } else {
                  // No Owner → hardcode số điện thoại
                  phoneDigits = noOwnerPhone; // 6839589712
                }

                Navigator.pop(context); // đóng dialog

                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const Center(child: CircularProgressIndicator()),
                );

                try {
                  final result = await ApiService.activateGiftCard(
                    code: scannedCode,
                    phoneNumber: phoneDigits, // luôn có giá trị (10 số)
                    amount: amount,
                    paymentMethod: selectedPaymentMethod,
                  );

                  _closeLoader();

                  if (mounted) {
                    _showSnackBar(
                      message: result['success'] == true ? 'Gift card activated!' : (result['message'] ?? 'Failed'),
                      backgroundColor: result['success'] == true ? Colors.green : Colors.red,
                    );
                    _refreshData();
                  }
                } catch (e) {
                  _closeLoader();
                  if (mounted) {
                    _showSnackBar(message: 'Error: $e', backgroundColor: Colors.red);
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              child: const Text('Activate'),
            ),
          ],
        ),
      ),
    );
  }

  /// Dialog để TOPUP gift card đã tồn tại
  void _showTopupDialog(String code) {
    final amountController = TextEditingController();
    int selectedPaymentMethod = 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Top-up Gift Card',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.card_giftcard, color: Colors.purple),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Gift Card Code',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              code,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  decoration: InputDecoration(
                    labelText: 'Top-up Amount *',
                    hintText: '0.00',
                    prefixIcon: const Icon(Icons.attach_money),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Payment Method',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<int>(
                        title: const Text('Credit'),
                        value: 1,
                        groupValue: selectedPaymentMethod,
                        onChanged: (value) {
                          setDialogState(() {
                            selectedPaymentMethod = value!;
                          });
                        },
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<int>(
                        title: const Text('Cash'),
                        value: 2,
                        groupValue: selectedPaymentMethod,
                        onChanged: (value) {
                          setDialogState(() {
                            selectedPaymentMethod = value!;
                          });
                        },
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amountText = amountController.text.trim();

                final amount = double.tryParse(amountText);
                if (amount == null || amount <= 0) {
                  _showSnackBar(
                    message: 'Please enter a valid amount',
                    backgroundColor: Colors.orange,
                  );
                  return;
                }

                // ✅ Pop AlertDialog explicit (KHÔNG dùng _closeLoader() ở đây)
                if (Navigator.canPop(context)) {
                  Navigator.of(context).pop();  // Pop AlertDialog chính
                }

                // Show loading spinner
                if (!mounted) return;
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );

                try {
                  final result = await ApiService.topupGiftCard(
                    code: code,
                    amount: amount,
                    paymentMethod: selectedPaymentMethod,
                  );

                  // ✅ Đóng loading spinner
                  _closeLoader();

                  // ✅ Show feedback & refresh CHỈ nếu mounted (an toàn sau pop/async)
                  if (mounted) {
                    if (result['success']) {
                      _showSnackBar(
                        message: result['message'] ?? 'Gift card topped up successfully',
                        backgroundColor: Colors.green,
                      );
                    } else {
                      _showSnackBar(
                        message: result['message'] ?? 'Failed to top-up gift card',
                        backgroundColor: Colors.red,
                      );
                    }
                    _refreshData();  // Gọi 1 lần ở đây
                  }
                } catch (e) {
                  // ✅ Đóng loading spinner
                  _closeLoader();

                  // ✅ Show error nếu mounted
                  if (mounted) {
                    _showSnackBar(
                      message: 'Error: $e',
                      backgroundColor: Colors.red,
                    );
                    _refreshData();  // Gọi ngay cả error (để refresh nếu cần)
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Top-up'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gift Card History'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        // ❌ XÓA nút "+" - Không còn tạo gift card thủ công
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: _isLoading
            ? const ShimmerListLoading(itemCount: 10)
            : CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          controller: _scrollController,
          slivers: [
            // Sticky Search Bar with Scan Button
            SliverAppBar(
              pinned: true,
              floating: true,
              automaticallyImplyLeading: false,
              backgroundColor: Colors.white,
              elevation: 2,
              toolbarHeight: 80,
              title: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by code or owner...',
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: const BorderSide(color: Colors.purple),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // ✅ NÚT SCAN QR - Duy nhất cách để tạo/topup gift card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.purple,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                        onPressed: _scanQRCode,
                        tooltip: 'Scan Gift Card QR',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // History List
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: _filteredHistoryData.isEmpty && _searchController.text.isNotEmpty
                  ? SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(
                      'No history found for "${_searchController.text}"',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              )
                  : SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final history = _filteredHistoryData[index];
                    return _buildHistoryCard(history);
                  },
                  childCount: _filteredHistoryData.length,
                ),
              ),
            ),
            // Loading More Indicator
            if (_isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
            // No More Data Indicator
            if (!_hasMore && _searchController.text.isEmpty && _filteredHistoryData.isNotEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'No more history',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(GiftCardTransactionHistory history) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: history.typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    history.typeIcon,
                    color: history.typeColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        history.transactionType,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: history.typeColor,
                        ),
                      ),
                      Text(
                        DateFormat('MMM dd, yyyy • hh:mm a').format(history.updateDate),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    history.paymentMethodText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.purple,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            // Gift Card Info
            _buildInfoRow('Gift Card Code', history.code, Icons.card_giftcard),
            const SizedBox(height: 8),
            _buildInfoRow('Owner', history.ownerName, Icons.person),
            const Divider(height: 24),
            // Balance Info
            Row(
              children: [
                Expanded(
                  child: _buildBalanceColumn(
                    'Old Balance',
                    history.oldBalance,
                    Colors.grey,
                  ),
                ),
                const Icon(Icons.arrow_forward, color: Colors.grey),
                Expanded(
                  child: _buildBalanceColumn(
                    'Change',
                    history.changeAmount,
                    Colors.green,
                  ),
                ),
                const Icon(Icons.arrow_forward, color: Colors.grey),
                Expanded(
                  child: _buildBalanceColumn(
                    'New Balance',
                    history.newBalance,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceColumn(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}