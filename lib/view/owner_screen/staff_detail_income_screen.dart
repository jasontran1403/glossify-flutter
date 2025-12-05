import 'package:flutter/material.dart';
import 'package:hair_sallon/api/api_service.dart';
import 'package:hair_sallon/view/owner_screen/store_detail_screen.dart';
import 'package:intl/intl.dart';

// XÓA enum TimeFilter từ đây - dùng enum từ file chung

class StaffDetailIncomeScreen extends StatefulWidget {
  final dynamic staffId; // Có thể là int hoặc String
  final String staffName;
  final DateTime startDate;
  final DateTime endDate;
  final String userRole;
  final TimeFilter selectedFilter;

  const StaffDetailIncomeScreen({
    super.key,
    required this.staffId,
    required this.staffName,
    required this.startDate,
    required this.endDate,
    required this.userRole,
    required this.selectedFilter,
  });

  @override
  State<StaffDetailIncomeScreen> createState() => _StaffDetailIncomeScreenState();
}

class _StaffDetailIncomeScreenState extends State<StaffDetailIncomeScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _incomeData;
  List<Map<String, dynamic>> _bookingList = [];

  @override
  void initState() {
    super.initState();
    _fetchStaffIncome();
  }

  Future<void> _fetchStaffIncome() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.getStaffDetailIncome(
        staffId: widget.staffId,
        startDate: widget.startDate,
        endDate: widget.endDate,
        userRole: widget.userRole,
      );

      if (mounted) {
        setState(() {
          _incomeData = response.data;
          _bookingList = List<Map<String, dynamic>>.from(_incomeData?['bookings'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  String _getDateRangeText() {
    if (widget.userRole == 'OWNER') {
      return 'All Time';
    }

    switch (widget.selectedFilter) {
      case TimeFilter.today:
        return DateFormat('MMM dd, yyyy').format(widget.startDate);
      case TimeFilter.thisWeek:
        return '${DateFormat('MMM dd').format(widget.startDate)} - ${DateFormat('MMM dd, yyyy').format(widget.endDate)}';
      case TimeFilter.thisMonth:
        return DateFormat('MMMM yyyy').format(widget.startDate);
      case TimeFilter.custom:
        return '${DateFormat('MMM dd').format(widget.startDate)} - ${DateFormat('MMM dd, yyyy').format(widget.endDate)}';
    }
  }

  Widget _buildHeaderCard() {
    if (_incomeData == null) return const SizedBox();

    final totalIncome = _safeGetDouble(_incomeData!['totalIncome']);
    final supplyShare = _safeGetDouble(_incomeData!['supplyShare']);
    final commission = _safeGetDouble(_incomeData!['commission']);
    final cardCharge = _safeGetDouble(_incomeData!['cardCharge']);
    final cashDiscountCharge = _safeGetDouble(_incomeData!['cashDiscountCharge']);
    final discountCharge = _safeGetDouble(_incomeData!['discountCharge']);
    final tipByCard = _safeGetDouble(_incomeData!['tipByCard']);
    final tipChargeByCard = _safeGetDouble(_incomeData!['tipChargeByCard']);
    final tipByCash = _safeGetDouble(_incomeData!['tipByCash']);
    final totalTip = _safeGetDouble(_incomeData!['totalTip']);
    final cashIncome = _safeGetDouble(_incomeData!['cashIncome']);
    final checkIncome = _safeGetDouble(_incomeData!['checkIncome']);

    return Card(
      elevation: 4,
      color: Colors.purple[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Staff Name and Date
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.purple[100],
                  radius: 24,
                  child: Text(
                    widget.staffName[0].toUpperCase(),
                    style: TextStyle(
                      color: Colors.purple[900],
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.staffName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.date_range, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            _getDateRangeText(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'STAFF INCOME',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[900],
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            // Main stats
            _buildIncomeRow('Income', totalIncome, Colors.blue, isMain: true),
            _buildIncomeRow('Supply Share', supplyShare, Colors.red[400]!),
            _buildIncomeRow('Commission', commission, Colors.purple),
            _buildIncomeRow('Card Charge', cardCharge, Colors.orange[700]!),
            _buildIncomeRow('Cash Discount Charge', cashDiscountCharge, Colors.pink[400]!),
            _buildIncomeRow('Discount Charge', discountCharge, Colors.brown[400]!),
            const Divider(height: 16),
            // Tips
            _buildIncomeRow('Tip by card (1)', tipByCard, Colors.blue[300]!),
            _buildIncomeRow('Tip charge by card (2)', tipChargeByCard, Colors.red[300]!),
            _buildIncomeRow('Tip by cash (3)', tipByCash, Colors.green[400]!),
            _buildIncomeRow('Total tip (1-2+3)', totalTip, Colors.teal, isBold: true),
            const Divider(height: 16),
            // Final totals
            _buildIncomeRow('Cash Income:', cashIncome, Colors.green[700]!, isMain: true),
            _buildIncomeRow('Check Income:', checkIncome, Colors.blue[700]!, isMain: true),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeRow(String label, double value, Color color, {bool isMain = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isMain ? 14 : 13,
              fontWeight: (isMain || isBold) ? FontWeight.bold : FontWeight.normal,
              color: Colors.black87,
            ),
          ),
          Text(
            value >= 0 ? '\$${value.toStringAsFixed(2)}' : '-\$${(-value).toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isMain ? 16 : 14,
              fontWeight: (isMain || isBold) ? FontWeight.bold : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsSection() {
    if (_bookingList.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.receipt_long, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 8),
                Text(
                  'No bookings found',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.receipt, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Bookings (${_bookingList.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        ..._bookingList.map((booking) => _buildBookingCard(booking)),
      ],
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final orderId = booking['orderId'] ?? 'N/A';
    final services = List<Map<String, dynamic>>.from(booking['services'] ?? []);
    final totalPrice = _safeGetDouble(booking['totalPrice']);
    final tips = _safeGetDouble(booking['tips']);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order ID
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order ID',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  'Service',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  'Price',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  'Tips',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const Divider(height: 12),
            // Services
            ...services.asMap().entries.map((entry) {
              final index = entry.key;
              final service = entry.value;
              final serviceName = service['serviceName'] ?? 'Unknown';
              final servicePrice = _safeGetDouble(service['price']);
              final serviceTips = _safeGetDouble(service['tips']);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Order ID (only on first row)
                    SizedBox(
                      width: 60,
                      child: index == 0
                          ? Text(
                        orderId,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue,
                        ),
                      )
                          : const SizedBox(),
                    ),
                    // Service
                    Expanded(
                      child: Text(
                        '1x $serviceName',
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Price
                    SizedBox(
                      width: 60,
                      child: Text(
                        '\$${servicePrice.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    // Tips
                    SizedBox(
                      width: 50,
                      child: Text(
                        '\$${serviceTips.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  double _safeGetDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Income'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // Download button
          IconButton(
            onPressed: () {
              // TODO: Implement download/export functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Export feature coming soon')),
              );
            },
            icon: const Icon(Icons.download),
            tooltip: 'Download',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchStaffIncome,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 16),
              _buildBookingsSection(),
            ],
          ),
        ),
      ),
    );
  }
}