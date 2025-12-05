// File: lib/view/dashboard_screen/dashboard_screen.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:hair_sallon/view/dashboard_screen/payment_breakdown_screen.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import API Service
import '../../api/api_service.dart';
// Import Shimmer
import 'chart_placeholders.dart';
import 'dashboard_shimmer.dart';
import 'client_screen.dart';
import 'heatmap_widget.dart';
import 'staff_income_detail_screen.dart';
import 'sales_this_week_screen.dart';
import 'staff_performance_screen.dart';

enum TimeFilter { today, thisWeek, custom }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isLoading = false;
  TimeFilter _selectedFilter = TimeFilter.today;
  late AnimationController _animationController;
  String _userRole = 'OWNER';

  String toFormattedString(num number, {int decimalDigits = 2}) {
    final formatter = NumberFormat('#,##0.${'0' * decimalDigits}', 'en_US');
    return formatter.format(number);
  }

  double _lineChartScrollOffset = 0;
  double _barChartScrollOffset = 0;
  final int _maxVisibleItems = 7;

  /// Format số dạng tiền tệ
  /// Example: toCurrency(1234.56) -> "$1,234.56"
  String toCurrency(num number, {String symbol = '\$', int decimalDigits = 2}) {
    final formatter = NumberFormat.currency(
      locale: 'en_US',
      symbol: symbol,
      decimalDigits: decimalDigits,
    );
    return formatter.format(number.toDouble());
  }

  /// Format số nguyên (không có số thập phân)
  /// Example: toIntegerString(1234.56) -> "1,235"
  String toIntegerString(num number) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return formatter.format(number);
  }

  Map<String, dynamic> _dashboardData = {};

  int touchedClientsIndex = -1;
  int touchedPaymentIndex = -1;

  // Error state
  String? _errorMessage;

  // Responsive helper
  bool get _isTablet {
    final size = MediaQuery.of(context).size;
    return size.shortestSide >= 600;
  }

  double _scale(double phoneSize) {
    return _isTablet ? phoneSize * 1.4 : phoneSize;
  }

  double _scaleFont(double phoneSize) {
    return _isTablet ? phoneSize * 1.3 : phoneSize;
  }

  @override
  void initState() {
    super.initState();

    // ✅ NEW: Force portrait orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Suppress keyboard event warnings (Flutter framework bug)
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception.toString().contains('KeyUpEvent')) {
        // Ignore keyboard event errors
        return;
      }
      FlutterError.presentError(details);
    };

    // Create animation controller ONCE
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Get user role ONCE
    _getUserRole();

    // Mặc định cho OWNER: từ 1/10/2025 đến nay
    if (_userRole == 'OWNER') {
      _startDate = DateTime(2025, 10, 1);
      _endDate = DateTime.now();
      _selectedFilter = TimeFilter.custom;
    } else {
      _setDateRangeForFilter(TimeFilter.today);
    }

    _updateFilterFromDates();
    _loadDashboardData();
  }

  void _updateFilterFromDates() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    // So sánh ngày tháng năm, không so sánh thời gian chính xác
    final isToday = _startDate.year == todayStart.year &&
        _startDate.month == todayStart.month &&
        _startDate.day == todayStart.day &&
        _endDate.year == todayEnd.year &&
        _endDate.month == todayEnd.month &&
        _endDate.day == todayEnd.day;

    if (isToday) {
      _selectedFilter = TimeFilter.today;
      return;
    }

    final weekday = now.weekday;
    final weekStart = now.subtract(Duration(days: weekday - 1));
    final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final weekEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    // So sánh ngày tháng năm cho this week
    final isThisWeek = _startDate.year == weekStartDate.year &&
        _startDate.month == weekStartDate.month &&
        _startDate.day == weekStartDate.day &&
        _endDate.year == weekEnd.year &&
        _endDate.month == weekEnd.month &&
        _endDate.day == weekEnd.day;

    if (isThisWeek) {
      _selectedFilter = TimeFilter.thisWeek;
      return;
    }

    _selectedFilter = TimeFilter.custom;
  }

  Future<void> _getUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('role') ?? 'OWNER';
      setState(() {
        _userRole = role;
      });

      // Cập nhật date range dựa trên role sau khi lấy được role
      if (role == 'OWNER') {
        _startDate = DateTime(2025, 10, 1);
        _endDate = DateTime.now();
        _selectedFilter = TimeFilter.custom;
      } else {
        _setDateRangeForFilter(TimeFilter.today);
      }
    } catch (e) {
      print('Error getting user role: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();

    // ✅ NEW: Reset orientation to allow all orientations when leaving screen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    super.dispose();
  }

  void _setDateRangeForFilter(TimeFilter filter) {
    if (_userRole != 'SUPER_OWNER') return;

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
      case TimeFilter.custom:
        break;
    }

    setState(() {
      _selectedFilter = filter;
    });
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _lineChartScrollOffset = 0;
      _barChartScrollOffset = 0;
    });

    try {
      final response = await ApiService.getDashboardStats(
        startDate: _startDate,
        endDate: _endDate,
        userRole: _userRole,
      );

      if (response.isSuccess && response.data != null) {
        setState(() {
          _dashboardData = response.data!;
          _isLoading = false;

          // ============================================================================
          // ✅ ADD THIS DEBUG CODE
          // ============================================================================
          final lineData = _dashboardData['salesThisWeek'] as List<dynamic>? ?? [];

          final barData = _dashboardData['clientsPerDay'] as List<dynamic>? ?? [];

          // Set scroll offsets
          if (lineData.length > _maxVisibleItems) {
            _lineChartScrollOffset = (lineData.length - _maxVisibleItems).toDouble();
          } else {
            _lineChartScrollOffset = 0;
          }

          if (barData.length > _maxVisibleItems) {
            _barChartScrollOffset = (barData.length - _maxVisibleItems).toDouble();
          } else {
            _barChartScrollOffset = 0;
          }
        });

        _animationController.forward(from: 0.0);
      } else {
        setState(() {
          _errorMessage = response.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load dashboard data: ${e.toString()}';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage!),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }


  Future<void> _selectCustomDateRange() async {
    if (_userRole != 'SUPER_OWNER') return;

    final now = DateTime.now();
    DateTime firstDate = DateTime(2020);

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: now,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _updateFilterFromDates();
      _loadDashboardData();
    }
  }

  Future<DateTimeRange?> _navigateToStaffPerformance() async {
    final result = await Navigator.push<DateTimeRange>(
      context,
      MaterialPageRoute(
        builder: (context) => StaffPerformanceScreen(
          startDate: _startDate,
          endDate: _endDate,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _startDate = result.start;
        _endDate = result.end;
      });
      _updateFilterFromDates();
      _loadDashboardData();
    }
    return result;
  }

  Future<DateTimeRange?> _navigateToHeatmap() async {
    final result = await Navigator.push<DateTimeRange>(
      context,
      MaterialPageRoute(
        builder: (context) => ClientsPerDayScreen(
          startDate: _startDate,
          endDate: _endDate,
          role: _userRole
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _startDate = result.start;
        _endDate = result.end;
      });
      _updateFilterFromDates();
      _loadDashboardData();
    }
    return result;
  }

  Future<DateTimeRange?> _navigateToSalesThisWeek() async {
    final result = await Navigator.push<DateTimeRange>(
      context,
      MaterialPageRoute(
        builder: (context) => SalesThisWeekScreen(
          startDate: _startDate,
          endDate: _endDate,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _startDate = result.start;
        _endDate = result.end;
      });
      _updateFilterFromDates();
      _loadDashboardData();
    }
    return result;
  }

  Future<DateTimeRange?> _navigateToStaffIncome() async {
    final result = await Navigator.push<DateTimeRange>(
      context,
      MaterialPageRoute(
        builder: (context) => StaffIncomeDetailScreen(
          startDate: _startDate,
          endDate: _endDate,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _startDate = result.start;
        _endDate = result.end;
      });
      _updateFilterFromDates();
      _loadDashboardData();
    }
    return result;
  }

  Future<DateTimeRange?> _navigateToClients() async {
    final result = await Navigator.push<DateTimeRange>(
      context,
      MaterialPageRoute(
        builder: (context) => ClientsScreen(
          startDate: _startDate,
          endDate: _endDate,
          role: _userRole
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _startDate = result.start;
        _endDate = result.end;
      });
      _updateFilterFromDates();
      _loadDashboardData();
    }
    return result;
  }

  Future<DateTimeRange?> _navigateToPaymentBreakdown() async {
    final result = await Navigator.push<DateTimeRange>(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentBreakdownScreen(
          startDate: _startDate,
          endDate: _endDate,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _startDate = result.start;
        _endDate = result.end;
      });
      _updateFilterFromDates();
      _loadDashboardData();
    }
    return result;
  }

  String _getDateRangeText() {
    if (_userRole == 'OWNER') {
      return 'Oct 1, 2025 - Present';
    }
    return '${DateFormat('MMM dd').format(_startDate)} - ${DateFormat('MMM dd').format(_endDate)}';
  }

  String _getSalesChartTitle() {
    switch (_selectedFilter) {
      case TimeFilter.today:
        return 'Sales Today';
      case TimeFilter.thisWeek:
        return 'Sales This Week';
      case TimeFilter.custom:
        return 'Sales ${_getDateRangeText()}';
    }
  }

  // Helper method to safely get numeric value from dashboard data
  double _getDoubleValue(String key, {double defaultValue = 0.0}) {
    final value = _dashboardData[key];
    if (value == null) return defaultValue;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return defaultValue;
  }

  int _getIntValue(String key, {int defaultValue = 0}) {
    final value = _dashboardData[key];
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return defaultValue;
  }

  Widget _buildCompactStatCard({
    required String title,
    required String value,
    Color? valueColor,
    Color? backgroundColor,
    VoidCallback? onTap,
  }) {
    final headerRow = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: _scaleFont(11),
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (onTap != null)
          Icon(
            Icons.arrow_forward_ios,
            size: _scaleFont(12),
            color: Colors.grey.shade400,
          ),
      ],
    );

    final cardContent = Container(
      padding: EdgeInsets.all(_scale(12)),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(_scale(12)),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          onTap != null ? InkWell(onTap: onTap, child: headerRow) : headerRow,
          Expanded(
            child: Center(
              child: Align(
                alignment: Alignment.centerLeft,
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    if (value.startsWith('\$')) {
                      final numValue = double.parse(value.substring(1).replaceAll(',', ''));
                      final animatedValue = numValue * _animationController.value;
                      // ✅ SỬA: Dùng toIntegerString() thay vì toStringAsFixed(0)
                      return Text(
                        '\$${toIntegerString(animatedValue)}',
                        style: TextStyle(
                          fontSize: _scaleFont(20),
                          fontWeight: FontWeight.bold,
                          color: valueColor ?? Colors.black87,
                        ),
                      );
                    } else {
                      final numValue = int.parse(value);
                      return Text(
                        '${(numValue * _animationController.value).toInt()}',
                        style: TextStyle(
                          fontSize: _scaleFont(20),
                          fontWeight: FontWeight.bold,
                          color: valueColor ?? Colors.black87,
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
          ),
          SizedBox(height: _scale(11)),
        ],
      ),
    );

    return cardContent;
  }

  Widget _buildClientsCard(VoidCallback? onTap) {
    final newClients = _getIntValue('newClients');
    final returningClients = _getIntValue('returningClients');
    final totalClients = _getIntValue('totalClients');

    final headerRow = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Clients',
          style: TextStyle(
            fontSize: _scaleFont(11),
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (onTap != null)
          Icon(
            Icons.arrow_forward_ios,
            size: _scaleFont(12),
            color: Colors.grey.shade400,
          ),
      ],
    );

    return Container(
      padding: EdgeInsets.all(_scale(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_scale(12)),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Header (fixed height)
          onTap != null ? InkWell(onTap: onTap, child: headerRow) : headerRow,

          // ✅ Flexible content area
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: _scale(8)), // Small top padding
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left side: Number and legends
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center, // ✅ Center vertically
                      mainAxisSize: MainAxisSize.min, // ✅ Take minimum space needed
                      children: [
                        // Total clients number
                        AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            return Text(
                              '${(totalClients * _animationController.value).toInt()}',
                              style: TextStyle(
                                fontSize: _scaleFont(18), // ✅ Slightly smaller
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            );
                          },
                        ),
                        SizedBox(height: _scale(6)), // ✅ Smaller spacing
                        // Legends
                        _buildLegendItem('New', Colors.teal, _scale(8)),
                        SizedBox(height: _scale(2)), // ✅ Tiny spacing between legends
                        _buildLegendItem('Return', Colors.teal.shade200, _scale(8)),
                      ],
                    ),
                  ),

                  // Right side: Donut chart
                  SizedBox(
                    width: _scale(60), // ✅ Slightly smaller
                    height: _scale(60), // ✅ Square aspect ratio
                    child: _buildDonutChart([
                      {'value': newClients.toDouble(), 'label': 'New', 'color': Colors.teal},
                      {'value': returningClients.toDouble(), 'label': 'Returning', 'color': Colors.teal.shade200},
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, double size) {
    return Row(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: _scale(4)),
        Text(
          label,
          style: TextStyle(
            fontSize: _scaleFont(8),
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: _scaleFont(8),
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required Widget chart,
    double? height,
    VoidCallback? onTap,
  }) {
    final headerRow = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: _scaleFont(11),
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (onTap != null)
          Icon(
            Icons.arrow_forward_ios,
            size: _scaleFont(12),
            color: Colors.grey.shade400,
          ),
      ],
    );

    final cardContent = Container(
      padding: EdgeInsets.all(_scale(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_scale(12)),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          onTap != null ? InkWell(onTap: onTap, child: headerRow) : headerRow,
          SizedBox(height: _scale(8)),
          Expanded(child: chart),
        ],
      ),
    );

    return cardContent;
  }

  Widget _buildPieChart() {
    final paymentData = _dashboardData['paymentBreakdown'] as Map<String, dynamic>? ?? {};
    final cardP = (paymentData['card'] ?? 0.0) as double;
    final cashP = (paymentData['cash'] ?? 0.0) as double;
    final otherP = (paymentData['cashOther'] ?? 0.0) as double;
    final cheque = (paymentData['cheque'] ?? 0.0) as double;
    final crypto = (paymentData['crypto'] ?? 0.0) as double;
    final others = (paymentData['others'] ?? 0.0) as double;

    // Nếu tất cả đều 0, hiển thị placeholder
    if (cardP == 0.0 && cashP == 0.0 && otherP == 0.0 && cheque == 0 && crypto == 0 && others == 0) {
      return ChartPlaceholders.pieChart(scale: _scale);
    }

    // Định nghĩa màu dùng chung
    final cardColor = Colors.teal.shade700;
    final cashColor = Colors.green.shade400;
    final giftColor = Colors.orange.shade300;
    final chequeColor = Colors.indigo.shade300;
    final cryptoColor = Colors.purple.shade300;
    final othersColor = Colors.grey.shade400;

    final data = [
      {
        'value': cardP,
        'label': 'Card',
        'color': cardColor,
        'percent': cardP.toStringAsFixed(0),
      },
      {
        'value': cashP,
        'label': 'Cash',
        'color': cashColor,
        'percent': cashP.toStringAsFixed(0),
      },
      {
        'value': otherP,
        'label': 'Gift Card',
        'color': giftColor,
        'percent': otherP.toStringAsFixed(0),
      },
      {
        'value': cheque,
        'label': 'Cheque',
        'color': chequeColor,
        'percent': cheque.toStringAsFixed(0),
      },
      {
        'value': crypto,
        'label': 'Crypto',
        'color': cryptoColor,
        'percent': crypto.toStringAsFixed(0),
      },
      {
        'value': others,
        'label': 'Others',
        'color': othersColor,
        'percent': others.toStringAsFixed(0),
      },
    ];

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final sections = data.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final value = (item['value'] as double) * _animationController.value;
          final isTouched = index == touchedPaymentIndex;
          final radius = _scale(30);
          final badgeText = '${item['label']}: ${(item['value'] as double).toInt()}%';

          return PieChartSectionData(
            color: item['color'] as Color,
            value: value,
            title: '${item['percent']}%',
            radius: radius,
            titleStyle: TextStyle(
              fontSize: _scaleFont(10),
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            badgeWidget: isTouched ? _buildBadge(badgeText) : null,
          );
        }).toList();

        return Row(
          children: [
            Expanded(
              flex: 2,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 20,
                  sections: sections,
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          touchedPaymentIndex = -1;
                          return;
                        }
                        touchedPaymentIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLegendItem('Card', cardColor, 8),
                  const SizedBox(height: 4),
                  _buildLegendItem('Cash', cashColor, 8),
                  const SizedBox(height: 4),
                  _buildLegendItem('Gift Card', giftColor, 8),
                  const SizedBox(height: 4),
                  _buildLegendItem('Cheque', chequeColor, 8),
                  const SizedBox(height: 4),
                  _buildLegendItem('Crypto', cryptoColor, 8),
                  const SizedBox(height: 4),
                  _buildLegendItem('Others', othersColor, 8),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLineChart() {
    final rawData = _dashboardData['salesThisWeek'] as List<dynamic>? ?? [];

    if (rawData.isEmpty) {
      return ChartPlaceholders.lineChart(scale: _scale);
    }

    double maxY = 0;
    double totalAmount = 0;
    for (var item in rawData) {
      final amount = (item['amount'] ?? 0.0).toDouble();
      totalAmount += amount;
      if (amount > maxY) maxY = amount;
    }

    if (totalAmount == 0 || maxY == 0) {
      return ChartPlaceholders.lineChart(scale: _scale);
    }

    // ✅ If <= 7 items, show static chart
    if (rawData.length <= _maxVisibleItems) {
      return _buildStaticLineChart(rawData, maxY);
    }

    // ✅ If > 7 items, show scrollable chart
    return _buildScrollableLineChart(rawData, maxY);
  }

  Widget _buildStaticLineChart(List<dynamic> rawData, double maxY) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return SizedBox(
          height: 200,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ✅ Y-axis with fixed width and proper alignment
              Container(
                width: _scale(35), // ✅ Increased from 20 to 35 for better spacing
                alignment: Alignment.centerRight,
                padding: EdgeInsets.only(right: _scale(4)), // ✅ Right padding
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end, // ✅ Align text to right
                  children: [
                    Text('\$${maxY.toInt()}',
                      style: TextStyle(fontSize: _scaleFont(7), color: Colors.grey),
                      textAlign: TextAlign.right,
                    ),
                    Text('\$${(maxY * 0.75).toInt()}',
                      style: TextStyle(fontSize: _scaleFont(7), color: Colors.grey),
                      textAlign: TextAlign.right,
                    ),
                    Text('\$${(maxY * 0.5).toInt()}',
                      style: TextStyle(fontSize: _scaleFont(7), color: Colors.grey),
                      textAlign: TextAlign.right,
                    ),
                    Text('\$${(maxY * 0.25).toInt()}',
                      style: TextStyle(fontSize: _scaleFont(7), color: Colors.grey),
                      textAlign: TextAlign.right,
                    ),
                    Text('\$0',
                      style: TextStyle(fontSize: _scaleFont(7), color: Colors.grey),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),

              // ✅ Chart with proper clipping
              Expanded(
                child: ClipRect( // ✅ Prevent overflow
                  child: LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: maxY * 1.5,
                      minX: -0.5,
                      maxX: (rawData.length - 1).toDouble() + 0.5,
                      gridData: _buildLineGridData(maxY),
                      titlesData: _buildLineTitlesData(rawData, maxY, 0, rawData.length - 1),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [_buildLineBarData(rawData)],
                      // ✅ Add extra touch data for better UX
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          tooltipBgColor: Colors.teal.withOpacity(0.8),
                          tooltipRoundedRadius: 8,
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final index = spot.x.toInt();
                              if (index >= 0 && index < rawData.length) {
                                final day = rawData[index]['day'] ?? '';
                                final amount = rawData[index]['amount'] ?? 0.0;
                                return LineTooltipItem(
                                  '$day\n\$${amount.toInt()}',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }
                              return null;
                            }).toList();
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

// Scrollable line chart (>7 items)
  Widget _buildScrollableLineChart(List<dynamic> rawData, double maxY) {
    final maxOffset = (rawData.length - _maxVisibleItems).toDouble();
    final clampedOffset = _lineChartScrollOffset.clamp(0.0, maxOffset);
    final startIndex = clampedOffset.toInt();
    final endIndex = (startIndex + _maxVisibleItems - 1).clamp(0, rawData.length - 1);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return SizedBox(
          height: 200,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ✅ Y-axis with fixed width and proper alignment
              Container(
                width: _scale(35), // ✅ Increased from 20 to 35
                alignment: Alignment.centerRight,
                padding: EdgeInsets.only(right: _scale(4)), // ✅ Right padding
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end, // ✅ Align text to right
                  children: [
                    Text('\$${maxY.toInt()}',
                      style: TextStyle(fontSize: _scaleFont(7), color: Colors.grey),
                      textAlign: TextAlign.right,
                    ),
                    Text('\$${(maxY * 0.75).toInt()}',
                      style: TextStyle(fontSize: _scaleFont(7), color: Colors.grey),
                      textAlign: TextAlign.right,
                    ),
                    Text('\$${(maxY * 0.5).toInt()}',
                      style: TextStyle(fontSize: _scaleFont(7), color: Colors.grey),
                      textAlign: TextAlign.right,
                    ),
                    Text('\$${(maxY * 0.25).toInt()}',
                      style: TextStyle(fontSize: _scaleFont(7), color: Colors.grey),
                      textAlign: TextAlign.right,
                    ),
                    Text('\$0',
                      style: TextStyle(fontSize: _scaleFont(7), color: Colors.grey),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),

              // ✅ Scrollable chart with proper clipping
              Expanded(
                child: ClipRect( // ✅ Prevent overflow
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        final sensitivity = 0.05;
                        _lineChartScrollOffset = (_lineChartScrollOffset - details.delta.dx * sensitivity)
                            .clamp(0.0, maxOffset);
                      });
                    },
                    onHorizontalDragEnd: (details) {
                      setState(() {
                        _lineChartScrollOffset = _lineChartScrollOffset.roundToDouble();
                      });
                    },
                    child: LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: maxY * 1.5,
                        minX: startIndex.toDouble() - 0.5,
                        maxX: endIndex.toDouble() + 0.5,
                        gridData: _buildLineGridData(maxY),
                        titlesData: _buildLineTitlesData(rawData, maxY, startIndex, endIndex),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [_buildLineBarData(rawData)],
                        // ✅ Add touch data
                        lineTouchData: LineTouchData(
                          enabled: true,
                          touchTooltipData: LineTouchTooltipData(
                            tooltipBgColor: Colors.teal.withOpacity(0.8),
                            tooltipRoundedRadius: 8,
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                final index = spot.x.toInt();
                                if (index >= 0 && index < rawData.length) {
                                  final day = rawData[index]['day'] ?? '';
                                  final amount = rawData[index]['amount'] ?? 0.0;
                                  return LineTooltipItem(
                                    '$day\n\$${amount.toInt()}',
                                    const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                }
                                return null;
                              }).toList();
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  LineChartBarData _buildLineBarData(List<dynamic> rawData) {
    return LineChartBarData(
      spots: List.generate(rawData.length, (index) {
        final amount = (rawData[index]['amount'] ?? 0.0).toDouble() * _animationController.value;
        return FlSpot(index.toDouble(), amount);
      }),
      isCurved: false,
      color: Colors.teal,
      barWidth: _scale(1),
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: _scale(2),
            color: Colors.teal,
            strokeWidth: _scale(2),
            strokeColor: Colors.white,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        color: Colors.teal.withOpacity(0.1),
      ),
    );
  }

// Helper: Grid data for line chart
  FlGridData _buildLineGridData(double maxY) {
    return FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: maxY / 10,
      getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
    );
  }

// Helper: Titles data for line chart
  FlTitlesData _buildLineTitlesData(List<dynamic> rawData, double maxY, int visibleStart, int visibleEnd) {
    return FlTitlesData(
      show: true,
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 22,
          interval: 1.0,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (value != index.toDouble() || index < 0 || index >= rawData.length) {
              return const SizedBox.shrink();
            }

            final rawDay = rawData[index]['day'] ?? '';
            String displayDay = rawDay;
            try {
              final parsed = DateTime.parse(rawDay);
              displayDay = '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}';
            } catch (_) {}

            return Padding(
              padding: EdgeInsets.only(top: _scale(4)),
              child: Text(
                displayDay,
                style: TextStyle(fontSize: _scaleFont(8), color: Colors.grey),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    final rawData = _dashboardData['clientsPerDay'] as List<dynamic>? ?? [];

    if (rawData.isEmpty) {
      return ChartPlaceholders.barChart(scale: _scale);
    }

    double maxY = 0;
    double totalCount = 0;
    for (var item in rawData) {
      final count = (item['count'] ?? 0).toDouble();
      totalCount += count;
      if (count > maxY) maxY = count;
    }

    if (totalCount == 0 || maxY == 0) {
      return ChartPlaceholders.barChart(scale: _scale);
    }

    // ✅ If <= 7 items, show static chart
    if (rawData.length <= _maxVisibleItems) {
      return _buildStaticBarChart(rawData, maxY);
    }

    // ✅ If > 7 items, show scrollable chart
    return _buildScrollableBarChart(rawData, maxY);
  }

// Static bar chart (<=7 items)
  Widget _buildStaticBarChart(List<dynamic> rawData, double maxY) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return SizedBox(
          height: 200,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Y-axis
              SizedBox(
                width: _scale(30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${maxY.toInt()}', style: TextStyle(fontSize: _scaleFont(7), color: Colors.grey)),
                    Text('${(maxY * 0.75).toInt()}', style: TextStyle(fontSize: _scaleFont(7), color: Colors.grey)),
                    Text('${(maxY * 0.5).toInt()}', style: TextStyle(fontSize: _scaleFont(7), color: Colors.grey)),
                    Text('${(maxY * 0.25).toInt()}', style: TextStyle(fontSize: _scaleFont(7), color: Colors.grey)),
                    Text('0', style: TextStyle(fontSize: _scaleFont(7), color: Colors.grey)),
                  ],
                ),
              ),
              // Chart
              Expanded(
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY * 1.5,
                    barTouchData: _buildBarTouchData(rawData),
                    titlesData: _buildBarTitlesData(rawData, 0, rawData.length - 1),
                    gridData: _buildBarGridData(maxY),
                    borderData: FlBorderData(show: false),
                    barGroups: _buildBarGroups(rawData),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

// Scrollable bar chart (>7 items)
  Widget _buildScrollableBarChart(List<dynamic> rawData, double maxY) {
    final maxOffset = (rawData.length - _maxVisibleItems).toDouble();
    final clampedOffset = _barChartScrollOffset.clamp(0.0, maxOffset);
    final startIndex = clampedOffset.toInt();
    final endIndex = (startIndex + _maxVisibleItems - 1).clamp(0, rawData.length - 1);

    // Visible data slice
    final visibleData = rawData.sublist(startIndex, endIndex + 1);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return SizedBox(
          height: 200,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Y-axis
              SizedBox(
                width: _scale(30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${maxY.toInt()}', style: TextStyle(fontSize: _scaleFont(7), color: Colors.grey)),
                    Text('${(maxY * 0.75).toInt()}', style: TextStyle(fontSize: _scaleFont(7), color: Colors.grey)),
                    Text('${(maxY * 0.5).toInt()}', style: TextStyle(fontSize: _scaleFont(7), color: Colors.grey)),
                    Text('${(maxY * 0.25).toInt()}', style: TextStyle(fontSize: _scaleFont(7), color: Colors.grey)),
                    Text('0', style: TextStyle(fontSize: _scaleFont(7), color: Colors.grey)),
                  ],
                ),
              ),
              // Scrollable chart
              Expanded(
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      final sensitivity = 0.1;
                      _barChartScrollOffset = (_barChartScrollOffset - details.delta.dx * sensitivity)
                          .clamp(0.0, maxOffset);
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    setState(() {
                      _barChartScrollOffset = _barChartScrollOffset.roundToDouble();
                    });
                  },
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY * 1.5,
                      barTouchData: _buildBarTouchData(rawData, startIndex),
                      titlesData: _buildBarTitlesData(rawData, startIndex, endIndex),
                      gridData: _buildBarGridData(maxY),
                      borderData: FlBorderData(show: false),
                      barGroups: _buildBarGroupsScrollable(visibleData, startIndex),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

// Helper: Bar touch data
  BarTouchData _buildBarTouchData(List<dynamic> rawData, [int offset = 0]) {
    return BarTouchData(
      enabled: true,
      touchTooltipData: BarTouchTooltipData(
        tooltipBgColor: Colors.teal.withOpacity(0.8),
        tooltipRoundedRadius: 8,
        getTooltipItem: (group, groupIndex, rod, rodIndex) {
          final actualIndex = groupIndex + offset;
          if (actualIndex >= rawData.length) return null;

          final day = rawData[actualIndex]['day'] ?? '';
          final count = (rawData[actualIndex]['count'] ?? 0).toInt();
          return BarTooltipItem(
            '$day\n$count clients',
            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          );
        },
      ),
    );
  }

// Helper: Bar titles data
  FlTitlesData _buildBarTitlesData(List<dynamic> rawData, int visibleStart, int visibleEnd) {
    return FlTitlesData(
      show: true,
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index < 0 || index >= rawData.length) return const SizedBox.shrink();

            String label = '';
            final item = rawData[index];
            final dateValue = item['date'] ?? item['created_at'] ?? item['day'];

            if (dateValue != null) {
              DateTime date;
              if (dateValue is int) {
                date = DateTime.fromMillisecondsSinceEpoch(
                  dateValue.toString().length == 10 ? dateValue * 1000 : dateValue,
                );
              } else if (dateValue is String) {
                date = DateTime.tryParse(dateValue) ?? DateTime.now();
              } else {
                date = DateTime.now();
              }
              label = DateFormat('dd/MM').format(date);
            }

            return Padding(
              padding: EdgeInsets.only(top: _scale(4)),
              child: Text(
                label,
                style: TextStyle(fontSize: _scaleFont(8), color: Colors.grey),
              ),
            );
          },
          reservedSize: 20,
        ),
      ),
    );
  }

// Helper: Bar grid data
  FlGridData _buildBarGridData(double maxY) {
    return FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: maxY / 5,
      getDrawingHorizontalLine: (value) => FlLine(
        color: Colors.grey.shade200,
        strokeWidth: 0.5,
      ),
    );
  }

// Helper: Bar groups (static chart)
  List<BarChartGroupData> _buildBarGroups(List<dynamic> rawData) {
    return rawData.asMap().entries.map((entry) {
      final count = (entry.value['count'] ?? 0).toDouble();
      final animatedValue = count * _animationController.value;
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: animatedValue,
            color: Colors.teal,
            width: _scale(12),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(_scale(3)),
              topRight: Radius.circular(_scale(3)),
            ),
          ),
        ],
      );
    }).toList();
  }

// Helper: Bar groups (scrollable chart)
  List<BarChartGroupData> _buildBarGroupsScrollable(List<dynamic> visibleData, int startIndex) {
    return visibleData.asMap().entries.map((entry) {
      final count = (entry.value['count'] ?? 0).toDouble();
      final animatedValue = count * _animationController.value;
      return BarChartGroupData(
        x: startIndex + entry.key,  // ✅ FIX: Use actual index from full dataset
        barRods: [
          BarChartRodData(
            toY: animatedValue,
            color: Colors.teal,
            width: _scale(12),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(_scale(3)),
              topRight: Radius.circular(_scale(3)),
            ),
          ),
        ],
      );
    }).toList();
  }


  Widget _buildDonutChart(List<Map<String, dynamic>> data) {
    final labels = data.map((e) => e['label'] as String).toList();

    // Kiểm tra nếu tất cả values đều 0
    final totalValue = data.fold<double>(
      0.0,
          (sum, item) => sum + (item['value'] as double),
    );

    if (totalValue == 0) {
      return ChartPlaceholders.donutChart(scale: _scale);
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final sections = data.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final value = (item['value'] as double) * _animationController.value;
          final isTouched = index == touchedClientsIndex;
          final radius = isTouched ? 20.0 : 15.0;
          final badgeText = '${labels[index]}: ${item['value'].toInt()}';
          return PieChartSectionData(
            color: item['color'],
            value: value,
            title: '',
            radius: radius,
            badgeWidget: isTouched ? _buildBadge(badgeText) : null,
          );
        }).toList();

        return PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 20,
            sections: sections,
            pieTouchData: PieTouchData(
              touchCallback: (FlTouchEvent event, pieTouchResponse) {
                setState(() {
                  if (!event.isInterestedForInteractions ||
                      pieTouchResponse == null ||
                      pieTouchResponse.touchedSection == null) {
                    touchedClientsIndex = -1;
                    return;
                  }
                  touchedClientsIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                });
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopStaffCard(VoidCallback? onTap) {
    final topStaff = _dashboardData['topStaff'] as List<dynamic>? ?? [];

    final headerRow = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Staff Performance',
          style: TextStyle(
            fontSize: _scaleFont(11),
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (onTap != null)
          Icon(
            Icons.arrow_forward_ios,
            size: _scaleFont(12),
            color: Colors.grey.shade400,
          ),
      ],
    );

    if (topStaff.isEmpty) {
      return _buildChartCard(
        title: 'Top Staff',
        chart: const Center(child: Text('No data available')),
        onTap: onTap,
      );
    }

    return Container(
      padding: EdgeInsets.all(_scale(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_scale(12)),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          onTap != null ? InkWell(onTap: onTap, child: headerRow) : headerRow,
          SizedBox(height: _scale(8)),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: topStaff.asMap().entries.map((entry) {
                final index = entry.key;
                final staff = entry.value;
                final name = staff['name'] ?? 'Unknown';
                final sales = (staff['sales'] ?? 0.0).toDouble();

                return Row(
                  children: [
                    Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: _scaleFont(10),
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: _scale(8)),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: _scaleFont(11),
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        final value = sales * _animationController.value;
                        return Text(
                          toCurrency(value, decimalDigits: 0),
                          style: TextStyle(
                            fontSize: _scaleFont(11),
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        );
                      },
                    ),
                  ],
                );
              }).toList(),
            ),
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
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Dashboard',
          style: TextStyle(
            color: Colors.black87,
            fontSize: _scaleFont(18),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: _scale(12)),
            padding: EdgeInsets.symmetric(horizontal: _scale(10), vertical: _scale(4)),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(_scale(12)),
            ),
            child: Text(
              _userRole == 'SUPER_OWNER' ? 'Super Owner' : 'Owner',
              style: TextStyle(
                color: Colors.black87,
                fontSize: _scaleFont(11),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double sectionHeight = (constraints.maxHeight - 60) / 3;
            final double cardHeight = (sectionHeight - _scale(8)) / 2;

            // Show shimmer loading when loading
            if (_isLoading) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    children: [
                      // Date filter row - chỉ hiển thị cho SUPER_OWNER
                      if (_userRole == 'SUPER_OWNER')
                        Padding(
                          padding: EdgeInsets.fromLTRB(_scale(12), _scale(8), _scale(12), _scale(8)),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, size: _scale(14), color: Colors.grey.shade600),
                              SizedBox(width: _scale(6)),
                              Expanded(
                                child: Text(
                                  _getDateRangeText(),
                                  style: TextStyle(
                                    fontSize: _scaleFont(11),
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              _buildFilterButton('Today', TimeFilter.today),
                              SizedBox(width: _scale(6)),
                              _buildFilterButton('This Week', TimeFilter.thisWeek),
                              SizedBox(width: _scale(6)),
                              InkWell(
                                onTap: _selectCustomDateRange,
                                child: Container(
                                  padding: EdgeInsets.all(_scale(6)),
                                  decoration: BoxDecoration(
                                    color: _selectedFilter == TimeFilter.custom
                                        ? Colors.teal.withOpacity(0.1)
                                        : Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(_scale(8)),
                                  ),
                                  child: Icon(
                                    Icons.date_range,
                                    size: _scale(14),
                                    color: _selectedFilter == TimeFilter.custom
                                        ? Colors.teal
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Hiển thị thông báo cho OWNER
                      if (_userRole == 'OWNER')
                        Padding(
                          padding: EdgeInsets.fromLTRB(_scale(12), _scale(8), _scale(12), _scale(8)),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, size: _scale(14), color: Colors.grey.shade600),
                              SizedBox(width: _scale(6)),
                              Expanded(
                                child: Text(
                                  'All data from Oct 1, 2025 to present',
                                  style: TextStyle(
                                    fontSize: _scaleFont(11),
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      // SHIMMER CONTENT
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: _scale(12)),
                        child: Column(
                          children: [
                            // Top cards row - SHIMMER
                            SizedBox(
                              height: sectionHeight,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        SizedBox(
                                          height: cardHeight,
                                          child: DashboardShimmer.statCard(scale: _scale(1)),
                                        ),
                                        SizedBox(height: _scale(8)),
                                        SizedBox(
                                          height: cardHeight,
                                          child: DashboardShimmer.clientsCard(scale: _scale(1)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: _scale(8)),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        SizedBox(
                                          height: cardHeight,
                                          child: DashboardShimmer.statCard(scale: _scale(1)),
                                        ),
                                        SizedBox(height: _scale(8)),
                                        SizedBox(
                                          height: cardHeight,
                                          child: DashboardShimmer.statCard(scale: _scale(1)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: _scale(8)),
                            // Charts row - SHIMMER
                            SizedBox(
                              height: sectionHeight,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: DashboardShimmer.chartCard(scale: _scale(1)),
                                  ),
                                  SizedBox(width: _scale(8)),
                                  Expanded(
                                    child: DashboardShimmer.chartCard(scale: _scale(1)),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: _scale(8)),
                            // Bottom row - SHIMMER
                            SizedBox(
                              height: sectionHeight,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: DashboardShimmer.topStaffCard(scale: _scale(1)),
                                  ),
                                  SizedBox(width: _scale(8)),
                                  Expanded(
                                    child: DashboardShimmer.chartCard(scale: _scale(1)),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: _scale(8)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Show error state if there's an error and no data
            if (_errorMessage != null && _dashboardData.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red),
                    SizedBox(height: 16),
                    Text(
                      'Failed to load dashboard',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _loadDashboardData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            // Show actual content
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
                    // Date filter row - chỉ hiển thị cho SUPER_OWNER
                    if (_userRole == 'SUPER_OWNER')
                      Padding(
                        padding: EdgeInsets.fromLTRB(_scale(12), _scale(8), _scale(12), _scale(8)),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: _scale(14), color: Colors.grey.shade600),
                            SizedBox(width: _scale(6)),
                            Expanded(
                              child: Text(
                                _getDateRangeText(),
                                style: TextStyle(
                                  fontSize: _scaleFont(11),
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            _buildFilterButton('Today', TimeFilter.today),
                            SizedBox(width: _scale(6)),
                            _buildFilterButton('This Week', TimeFilter.thisWeek),
                            SizedBox(width: _scale(6)),
                            InkWell(
                              onTap: _selectCustomDateRange,
                              child: Container(
                                padding: EdgeInsets.all(_scale(6)),
                                decoration: BoxDecoration(
                                  color: _selectedFilter == TimeFilter.custom
                                      ? Colors.teal.withOpacity(0.1)
                                      : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(_scale(8)),
                                ),
                                child: Icon(
                                  Icons.date_range,
                                  size: _scale(14),
                                  color: _selectedFilter == TimeFilter.custom
                                      ? Colors.teal
                                      : Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Hiển thị thông báo cho OWNER
                    if (_userRole == 'OWNER')
                      Padding(
                        padding: EdgeInsets.fromLTRB(_scale(12), _scale(8), _scale(12), _scale(8)),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: _scale(14), color: Colors.grey.shade600),
                            SizedBox(width: _scale(6)),
                            Expanded(
                              child: Text(
                                'All data from Oct 1, 2025 to present',
                                style: TextStyle(
                                  fontSize: _scaleFont(11),
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Main content
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: _scale(12)),
                      child: Column(
                        children: [
                          // Top cards row
                          SizedBox(
                            height: sectionHeight,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      SizedBox(
                                        height: cardHeight,
                                        child: _buildCompactStatCard(
                                          title: 'Total Sales',
                                          value: toCurrency(_getDoubleValue('totalSales'), decimalDigits: 0),
                                          onTap: () async {
                                            final result = await _navigateToStaffIncome();
                                            if (result != null) {
                                              setState(() {
                                                _startDate = result.start;
                                                _endDate = result.end;
                                                _selectedFilter = TimeFilter.custom;
                                              });
                                              _loadDashboardData();
                                            }
                                          },
                                        ),
                                      ),
                                      SizedBox(height: _scale(8)),
                                      SizedBox(
                                        height: cardHeight,
                                        child: _buildClientsCard(() async {
                                          final result = await _navigateToClients();
                                          if (result != null) {
                                            setState(() {
                                              _startDate = result.start;
                                              _endDate = result.end;
                                              _selectedFilter = TimeFilter.custom;
                                            });
                                            _loadDashboardData();
                                          }
                                        }),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: _scale(8)),
                                Expanded(
                                  child: Column(
                                    children: [
                                      SizedBox(
                                        height: cardHeight,
                                        child: _buildCompactStatCard(
                                          title: 'Owner Share',
                                          value: toCurrency(_getDoubleValue('ownerShare'), decimalDigits: 0),
                                          valueColor: Colors.black,
                                          backgroundColor: Colors.white,
                                        ),
                                      ),
                                      SizedBox(height: _scale(8)),
                                      SizedBox(
                                        height: cardHeight,
                                        child: _buildCompactStatCard(
                                          title: 'Gift Card Usage',
                                          value: toCurrency(_getDoubleValue('giftCardSales'), decimalDigits: 0),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: _scale(8)),
                          // Charts row
                          SizedBox(
                            height: sectionHeight,
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildChartCard(
                                    title: _getSalesChartTitle(),
                                    chart: _buildLineChart(),
                                    onTap: () async {
                                      final result = await _navigateToSalesThisWeek();
                                      if (result != null) {
                                        setState(() {
                                          _startDate = result.start;
                                          _endDate = result.end;
                                          _selectedFilter = TimeFilter.custom;
                                        });
                                        _loadDashboardData();
                                      }
                                    },
                                  ),
                                ),
                                SizedBox(width: _scale(8)),
                                Expanded(
                                  child: _buildChartCard(
                                    title: 'Payment Breakdown',
                                    chart: _buildPieChart(),
                                    onTap: _navigateToPaymentBreakdown,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: _scale(8)),
                          // Bottom row
                          SizedBox(
                            height: sectionHeight,
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildTopStaffCard(() async {
                                    final result = await _navigateToStaffPerformance();
                                    if (result != null) {
                                      setState(() {
                                        _startDate = result.start;
                                        _endDate = result.end;
                                        _selectedFilter = TimeFilter.custom;
                                      });
                                      _loadDashboardData();
                                    }
                                  }),
                                ),
                                SizedBox(width: _scale(8)),
                                Expanded(
                                  child: _buildChartCard(
                                    title: 'Clients Per Day',
                                    chart: _buildBarChart(),
                                    onTap: _navigateToHeatmap,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: _scale(8)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterButton(String label, TimeFilter filter) {
    final isSelected = _selectedFilter == filter;
    return InkWell(
      onTap: () {
        _setDateRangeForFilter(filter);
        _loadDashboardData();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: _scale(10), vertical: _scale(4)),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal : Colors.grey[200],
          borderRadius: BorderRadius.circular(_scale(12)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontSize: _scaleFont(10),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}