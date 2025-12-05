import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hair_sallon/api/api_service.dart';
import 'package:hair_sallon/view/owner_screen/store_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'staff_detail_income_screen.dart';

// XÓA enum TimeFilter từ đây - dùng enum từ file chung

class StaffStatisticsScreen extends StatefulWidget {
  const StaffStatisticsScreen({super.key});

  @override
  State<StaffStatisticsScreen> createState() => _StaffStatisticsScreenState();
}

class _StaffStatisticsScreenState extends State<StaffStatisticsScreen> {
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isLoading = true;
  List<Map<String, dynamic>> _staffList = [];
  TimeFilter _selectedFilter = TimeFilter.today;
  String _userRole = 'OWNER';

  @override
  void initState() {
    super.initState();
    _getUserRole();
    _setDateRangeForFilter(TimeFilter.today);
  }

  Future<void> _getUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userRole = prefs.getString('role') ?? 'OWNER';
      });
      _fetchStaffStats();
    } catch (e) {
      print('Error getting user role: $e');
    }
  }

  void _setDateRangeForFilter(TimeFilter filter) {
    final now = DateTime.now();

    switch (filter) {
      case TimeFilter.today:
        _startDate = DateTime(now.year, now.month, now.day);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case TimeFilter.thisWeek:
        final weekday = now.weekday;
        _startDate = now.subtract(Duration(days: weekday - 1));
        _startDate = DateTime(_startDate.year, _startDate.month, _startDate.day);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case TimeFilter.thisMonth:
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case TimeFilter.custom:
        break;
    }

    setState(() {
      _selectedFilter = filter;
    });
  }

  Future<void> _fetchStaffStats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.getStaffStatistics(
        startDate: _startDate,
        endDate: _endDate,
        userRole: _userRole,
      );

      if (mounted) {
        setState(() {
          _staffList = List<Map<String, dynamic>>.from(response.data ?? []);
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

  Future<void> _selectCustomDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _selectedFilter = TimeFilter.custom;
      });
      _fetchStaffStats();
    }
  }

  String _getDateRangeText() {
    if (_userRole == 'OWNER') {
      return 'All Time Data';
    }

    switch (_selectedFilter) {
      case TimeFilter.today:
        return 'Today: ${DateFormat('MMM dd, yyyy').format(_startDate)}';
      case TimeFilter.thisWeek:
        return 'This Week: ${DateFormat('MMM dd').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}';
      case TimeFilter.thisMonth:
        return 'This Month: ${DateFormat('MMMM yyyy').format(_startDate)}';
      case TimeFilter.custom:
        return 'Custom: ${DateFormat('MMM dd').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}';
    }
  }

  Widget _buildTimeFilterButtons() {
    // OWNER không thấy date filter
    if (_userRole == 'OWNER') {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getDateRangeText(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // SUPER_OWNER thấy date filter
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.date_range, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getDateRangeText(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildFilterButton('Today', TimeFilter.today, Icons.today),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFilterButton('This Week', TimeFilter.thisWeek, Icons.date_range),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFilterButton('This Month', TimeFilter.thisMonth, Icons.calendar_month),
                ),
                const SizedBox(width: 8),
                _buildCustomDateButton(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton(String label, TimeFilter filter, IconData icon) {
    final isSelected = _selectedFilter == filter;

    return ElevatedButton.icon(
      onPressed: () {
        _setDateRangeForFilter(filter);
        _fetchStaffStats();
      },
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue : Colors.grey[200],
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildCustomDateButton() {
    final isSelected = _selectedFilter == TimeFilter.custom;

    return IconButton(
      onPressed: _selectCustomDateRange,
      icon: Icon(Icons.calendar_today, color: isSelected ? Colors.blue : Colors.grey[700]),
      style: IconButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue[50] : Colors.grey[200],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      tooltip: 'Custom Date Range',
    );
  }

  Widget _buildStaffCard(Map<String, dynamic> staff) {
    final staffName = staff['staffName'] ?? 'Unknown';
    final staffId = staff['staffId']; // Lấy staffId
    final totalIncome = _safeGetDouble(staff['totalIncome']);
    final commission = _safeGetDouble(staff['commission']);
    final totalTips = _safeGetDouble(staff['totalTips']);
    final bookingCount = _safeGetInt(staff['bookingCount']);
    final cashIncome = _safeGetDouble(staff['cashIncome']);
    final checkIncome = _safeGetDouble(staff['checkIncome']);

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StaffDetailIncomeScreen(
                staffId: staffId,
                staffName: staffName,
                startDate: _startDate,
                endDate: _endDate,
                userRole: _userRole,
                selectedFilter: _selectedFilter,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with staff name and arrow
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue[100],
                    child: Text(
                      staffName[0].toUpperCase(),
                      style: TextStyle(
                        color: Colors.blue[900],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          staffName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$bookingCount bookings',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
              const Divider(height: 24),
              // Income stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatItem('Income', totalIncome, Colors.blue),
                  _buildStatItem('Commission', commission, Colors.purple),
                  _buildStatItem('Tips', totalTips, Colors.orange),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatItem('Cash', cashIncome, Colors.green),
                  _buildStatItem('Check', checkIncome, Colors.teal),
                  const SizedBox(width: 60), // Spacing
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, double value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '\$${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    if (_staffList.isEmpty) return const SizedBox();

    double totalIncome = 0;
    double totalCommission = 0;
    double totalTips = 0;
    int totalBookings = 0;

    for (var staff in _staffList) {
      totalIncome += _safeGetDouble(staff['totalIncome']);
      totalCommission += _safeGetDouble(staff['commission']);
      totalTips += _safeGetDouble(staff['totalTips']);
      totalBookings += _safeGetInt(staff['bookingCount']);
    }

    return Card(
      elevation: 4,
      color: Colors.blue[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.summarize, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Text(
                  'Overall Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem('Total Income', totalIncome, Icons.attach_money),
                ),
                Expanded(
                  child: _buildSummaryItem('Commission', totalCommission, Icons.money_off),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem('Total Tips', totalTips, Icons.volunteer_activism),
                ),
                Expanded(
                  child: _buildSummaryItem('Bookings', totalBookings.toDouble(), Icons.receipt, isInt: true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, double value, IconData icon, {bool isInt = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.blue),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isInt ? value.toInt().toString() : '\$${value.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  double _safeGetDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _safeGetInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Statistics'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _fetchStaffStats,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchStaffStats,
        child: _staffList.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No staff data available',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],
          ),
        )
            : SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildTimeFilterButtons(),
              const SizedBox(height: 16),
              _buildSummaryCard(),
              const SizedBox(height: 16),
              ..._staffList.map((staff) => _buildStaffCard(staff)),
            ],
          ),
        ),
      ),
    );
  }
}