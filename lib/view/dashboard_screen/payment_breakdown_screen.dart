import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/api_service.dart';

enum TimeFilter { today, thisWeek, custom }

class PaymentBreakdownScreen extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;

  const PaymentBreakdownScreen({
    super.key,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<PaymentBreakdownScreen> createState() => _PaymentBreakdownScreenState();
}

class _PaymentBreakdownScreenState extends State<PaymentBreakdownScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _animationController;
  late ScrollController _scrollController;
  int _touchedIndex = -1;

  // Payment data
  double cashAmount = 0;
  double cardAmount = 0;
  double giftCardAmount = 0;
  double chequeAmount = 0;
  double cryptoAmount = 0;
  double otherAmount = 0;

  // Daily payment data (Mon - Sun)
  List<DailyPayment> dailyPayments = [];

  late DateTime _localStartDate = widget.startDate;
  late DateTime _localEndDate = widget.endDate;
  TimeFilter _localSelectedFilter = TimeFilter.today;
  String _userRole = 'OWNER';
  bool _datesChanged = false;
  String _titlePeriod = 'This Week';

  @override
  void initState() {
    super.initState();
    _getUserRole();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _scrollController = ScrollController();
    _datesChanged = false;
    _loadData();
  }

  Future<void> _getUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('role') ?? 'OWNER';
      if (mounted) {
        setState(() {
          _userRole = role;
        });
      }

      // Cập nhật date range dựa trên role
      if (role == 'OWNER') {
        _localStartDate = DateTime(2025, 10, 1);
        _localEndDate = DateTime.now();
        _localSelectedFilter = TimeFilter.custom;
        _titlePeriod = 'All Time';
      } else {
        _localStartDate = widget.startDate;
        _localEndDate = widget.endDate;
        _setFilterFromDates();
      }
    } catch (e) {
      print('Error getting user role: $e');
    }
  }

  void _setFilterFromDates() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    if (_localStartDate == todayStart && _localEndDate == todayEnd) {
      _localSelectedFilter = TimeFilter.today;
      _titlePeriod = 'Today';
      return;
    }
    final weekday = now.weekday;
    final weekStart = now.subtract(Duration(days: weekday - 1));
    final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final weekEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    if (_localStartDate == weekStartDate && _localEndDate == weekEnd) {
      _localSelectedFilter = TimeFilter.thisWeek;
      _titlePeriod = 'This Week';
      return;
    }
    _localSelectedFilter = TimeFilter.custom;
    _titlePeriod = '${DateFormat('MMM dd').format(_localStartDate)} - ${DateFormat('MMM dd').format(_localEndDate)}';
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  double _calculateChartContentWidth() {
    final numBars = dailyPayments.length;
    if (numBars == 0) return 350.0;
    const barWidth = 20.0;
    const groupsSpace = 28.0;
    const extraPadding = 40.0;
    return numBars * barWidth + (numBars - 1) * groupsSpace + extraPadding;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.getPaymentBreakdown(
          startDate: _localStartDate,
          endDate: _localEndDate,
          role: _userRole
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data as Map<String, dynamic>;

        // Parse totals
        final totals = data['totals'] as Map<String, dynamic>;
        cashAmount = (totals['cash'] ?? 0.0).toDouble();
        cardAmount = (totals['card'] ?? 0.0).toDouble();
        giftCardAmount = (totals['giftCard'] ?? 0.0).toDouble();
        chequeAmount = (totals['cheque'] ?? 0.0).toDouble();
        cryptoAmount = (totals['crypto'] ?? 0.0).toDouble();
        otherAmount = (totals['other'] ?? 0.0).toDouble();

        // Parse daily breakdown
        final dailyData = data['dailyBreakdown'] as List;
        dailyPayments = dailyData.map((item) {
          return DailyPayment(
            item['day'],
            (item['cash'] ?? 0.0).toDouble(),
            (item['card'] ?? 0.0).toDouble(),
            (item['giftCard'] ?? 0.0).toDouble(),
            (item['cheque'] ?? 0.0).toDouble(),
            (item['crypto'] ?? 0.0).toDouble(),
            (item['other'] ?? 0.0).toDouble(),
          );
        }).toList();

        setState(() {
          _isLoading = false;
        });

        _animationController.forward(from: 0.0);

        // Scroll to show the latest 7 bars if there are more than 7
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (dailyPayments.length > 7 && _scrollController.hasClients) {
            final contentWidth = _calculateChartContentWidth();
            final approxVisibleWidth = 350.0;
            final targetOffset = (contentWidth - approxVisibleWidth).clamp(0.0, contentWidth);
            _scrollController.jumpTo(targetOffset);
          }
        });
      } else {
        setState(() {
          _isLoading = false;
        });

        _showErrorSnackBar(response.message);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      _showErrorSnackBar('Error loading payment breakdown: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  List<PieChartSectionData> _buildPieSections(double animationValue) {
    final data = [
      {'amount': cashAmount, 'color': const Color(0xFF1D4ED8), 'label': 'Cash'},
      {'amount': cardAmount, 'color': const Color(0xFF3B82F6), 'label': 'Card'},
      {'amount': giftCardAmount, 'color': const Color(0xFF93C5FD), 'label': 'Gift Card'},
      {'amount': chequeAmount, 'color': const Color(0xFF10B981), 'label': 'Cheque'},
      {'amount': cryptoAmount, 'color': const Color(0xFF8B5CF6), 'label': 'Crypto'},
      {'amount': otherAmount, 'color': const Color(0xFFD1D5DB), 'label': 'Other'},
    ];

    // ✅ ép kiểu rõ ràng để tránh lỗi "Object > int"
    final nonZeroData = data
        .where((d) => (d['amount'] as double) > 0)
        .toList();

    return List.generate(nonZeroData.length, (index) {
      final item = nonZeroData[index];
      return _buildPieSection(
        index,
        (item['amount'] as double) * animationValue,
        item['color'] as Color,
        item['label'] as String,
      );
    });
  }

  void _setDateRangeForFilter(TimeFilter filter) {
    // Chỉ cho phép SUPER_OWNER thay đổi date range
    if (_userRole != 'SUPER_OWNER') return;

    final now = DateTime.now();

    switch (filter) {
      case TimeFilter.today:
        _localStartDate = DateTime(now.year, now.month, now.day);
        _localEndDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        _titlePeriod = 'Today';
        break;
      case TimeFilter.thisWeek:
        final weekday = now.weekday;
        _localStartDate = now.subtract(Duration(days: weekday - 1));
        _localStartDate = DateTime(_localStartDate.year, _localStartDate.month, _localStartDate.day);
        _localEndDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        _titlePeriod = 'This Week';
        break;
      case TimeFilter.custom:
        break;
    }

    setState(() {
      _localSelectedFilter = filter;
    });
  }

  Future<void> _selectCustomDateRange() async {
    // Chỉ cho phép SUPER_OWNER chọn custom date range
    if (_userRole != 'SUPER_OWNER') return;

    final now = DateTime.now();
    DateTime firstDate = DateTime(2020);

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: now,
      initialDateRange: DateTimeRange(start: _localStartDate, end: _localEndDate),
    );

    if (picked != null) {
      final oldStart = _localStartDate;
      final oldEnd = _localEndDate;
      setState(() {
        _localStartDate = picked.start;
        _localEndDate = picked.end;
        _localSelectedFilter = TimeFilter.custom;
        _titlePeriod = '${DateFormat('MMM dd').format(_localStartDate)} - ${DateFormat('MMM dd').format(_localEndDate)}';
      });

      if (_localStartDate != oldStart || _localEndDate != oldEnd) {
        _datesChanged = true;
      }
      _loadData();
    }
  }

  String _getDateRangeText() {
    if (_userRole == 'OWNER') {
      return 'Oct 1, 2025 - Present';
    }
    return '${DateFormat('MMM dd').format(_localStartDate)} - ${DateFormat('MMM dd').format(_localEndDate)}';
  }

  Widget _buildFilterButton(String label, TimeFilter filter) {
    final isSelected = _localSelectedFilter == filter;
    return InkWell(
      onTap: () {
        // Chỉ cho phép SUPER_OWNER sử dụng filter buttons
        if (_userRole != 'SUPER_OWNER') return;

        final oldStart = _localStartDate;
        final oldEnd = _localEndDate;
        _setDateRangeForFilter(filter);
        if (_localStartDate != oldStart || _localEndDate != oldEnd) {
          _datesChanged = true;
        }
        _loadData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  double get totalPayments => cashAmount + cardAmount + giftCardAmount + chequeAmount + cryptoAmount + otherAmount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
          onPressed: () {
            if (_datesChanged) {
              Navigator.pop(context, DateTimeRange(start: _localStartDate, end: _localEndDate));
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          'Payment Breakdown $_titlePeriod',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Date filter row - HIỂN THỊ CHO CẢ HAI ROLE NHƯNG KHÁC NHAU
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Color(0xFF9E9E9E)),
                const SizedBox(width: 6),
                Expanded(
                  child: GestureDetector(
                    onTap: _userRole == 'SUPER_OWNER' ? _selectCustomDateRange : null,
                    child: Text(
                      _getDateRangeText(),
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9E9E9E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                // Chỉ hiển thị filter buttons cho SUPER_OWNER
                if (_userRole == 'SUPER_OWNER') ...[
                  _buildFilterButton('Today', TimeFilter.today),
                  const SizedBox(width: 6),
                  _buildFilterButton('This Week', TimeFilter.thisWeek),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: _selectCustomDateRange,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _localSelectedFilter == TimeFilter.custom
                            ? Colors.teal.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.date_range,
                        size: 14,
                        color: _localSelectedFilter == TimeFilter.custom
                            ? Colors.teal
                            : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? _buildShimmerLoading()
                : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Payment method cards - 2 rows of 3 cards
                  _buildPaymentCards(),
                  const SizedBox(height: 24),

                  // Total Payments Pie Chart
                  _buildTotalPaymentsSection(),
                  const SizedBox(height: 24),

                  // Payments by Day Chart
                  _buildPaymentsByDaySection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Payment cards shimmer - 2 rows of 3
          Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildPaymentShimmer()),
                  const SizedBox(width: 6),
                  Expanded(child: _buildPaymentShimmer()),
                  const SizedBox(width: 6),
                  Expanded(child: _buildPaymentShimmer()),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: _buildPaymentShimmer()),
                  const SizedBox(width: 6),
                  Expanded(child: _buildPaymentShimmer()),
                  const SizedBox(width: 6),
                  Expanded(child: _buildPaymentShimmer()),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Total payments section shimmer
          Container(
            height: 250,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 24),
          // Payments by day section shimmer
          Container(
            height: 350,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentShimmer() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _buildPaymentCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildPaymentCard('Cash', cashAmount, const Color(0xFF1D4ED8))),
            const SizedBox(width: 6),
            Expanded(child: _buildPaymentCard('Card', cardAmount, const Color(0xFF3B82F6))),
            const SizedBox(width: 6),
            Expanded(child: _buildPaymentCard('Gift Card', giftCardAmount, const Color(0xFF93C5FD))),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _buildPaymentCard('Cheque', chequeAmount, const Color(0xFF10B981))),
            const SizedBox(width: 6),
            Expanded(child: _buildPaymentCard('Crypto', cryptoAmount, const Color(0xFF8B5CF6))),
            const SizedBox(width: 6),
            Expanded(child: _buildPaymentCard('Other', otherAmount, const Color(0xFFD1D5DB))),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentCard(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Text(
                  '\$${(amount * _animationController.value).toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalPaymentsSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Payments',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Pie Chart on the left
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 200,
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 1200),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return
                              PieChart(
                                PieChartData(
                                  sectionsSpace: 0,
                                  centerSpaceRadius: 40,
                                  pieTouchData: PieTouchData(
                                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                      setState(() {
                                        if (!event.isInterestedForInteractions ||
                                            pieTouchResponse == null ||
                                            pieTouchResponse.touchedSection == null) {
                                          _touchedIndex = -1;
                                          return;
                                        }
                                        _touchedIndex =
                                            pieTouchResponse.touchedSection!.touchedSectionIndex;
                                      });
                                    },
                                  ),
                                  sections: _buildPieSections(value),
                                ),
                              );
                          },
                        );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Legend on the right
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center, // ✅ canh giữa 2 khối
                  children: [
                    _buildLegendItemWithPercentage(const Color(0xFF1D4ED8), 'Cash', cashAmount),
                    const SizedBox(height: 8),
                    _buildLegendItemWithPercentage(const Color(0xFF3B82F6), 'Card', cardAmount),
                    const SizedBox(height: 8),
                    _buildLegendItemWithPercentage(const Color(0xFF93C5FD), 'Gift Card', giftCardAmount),
                    const SizedBox(height: 8),
                    _buildLegendItemWithPercentage(const Color(0xFF10B981), 'Cheque', chequeAmount),
                    const SizedBox(height: 8),
                    _buildLegendItemWithPercentage(const Color(0xFF8B5CF6), 'Crypto', cryptoAmount),
                    const SizedBox(height: 8),
                    _buildLegendItemWithPercentage(const Color(0xFFD1D5DB), 'Other', otherAmount),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  PieChartSectionData _buildPieSection(int index, double amount, Color color, String label) {
    if (totalPayments == 0) {
      return PieChartSectionData(
        color: color,
        value: 0,
        title: '',
      );
    }

    final isTouched = index == _touchedIndex;
    final percentage = (amount / totalPayments * 100);

    return PieChartSectionData(
      color: color,
      value: amount, // chỉ nhân 1 lần animation bên ngoài
      radius: isTouched ? 38 : 30,
      title: isTouched ? '${percentage.toStringAsFixed(1)}%' : '',
      titleStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildLegendItemWithPercentage(Color color, String label, double amount) {
    // ✅ Fix: Kiểm tra totalPayments == 0 → hiển thị 0%
    final percentage = totalPayments == 0 ? 0 : (amount / totalPayments * 100).toInt();

    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            // ✅ Fix: Dùng percentage đã tính sẵn, tránh tính lại khi animation
            return Text(
              '${(percentage * _animationController.value).toInt()}%',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFixedLeft(double maxY, double interval, double height) {
    final tickValues = <double>[];
    double current = 0;
    while (current <= maxY) {
      tickValues.add(current);
      current += interval;
    }

    return Container(
      width: 50.0,
      height: height,
      clipBehavior: Clip.none,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey[300]!, width: 1)),
      ),
      child: Stack(
        children: tickValues.map((value) {
          final yFromTop = height * (1 - value / maxY) - 6;
          final clampedTop = yFromTop.clamp(0.0, height);
          String text;
          if (maxY <= 1000) {
            text = '\$${value.toInt()}';
          } else {
            text = '\$${(value / 1000).toStringAsFixed(0)}k';
          }
          return Positioned(
            top: clampedTop,
            left: 0,
            right: 8.0,
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
              textAlign: TextAlign.right,
            ),
          );
        }).toList(),
      ),
    );
  }

  double roundToNiceStep(double value) {
    if (value <= 10) return 10;
    if (value <= 100) return (value / 10).ceil() * 10;
    if (value <= 1000) return (value / 50).ceil() * 50;
    if (value <= 10000) return (value / 500).ceil() * 500;
    return (value / 1000).ceil() * 1000;
  }

  Widget _buildPaymentsByDaySection() {
    final showScrollView = dailyPayments.length > 7;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payments by Day',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 300,
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                final maxDayTotal = dailyPayments.isNotEmpty
                    ? dailyPayments.map((d) => d.total).reduce((a, b) => a > b ? a : b)
                    : 0.0;

                double rawMax = maxDayTotal * 1.2;
                final chartMaxY = roundToNiceStep(rawMax);
                final interval = chartMaxY <= 1000
                    ? 50.0
                    : chartMaxY <= 5000
                    ? 500.0
                    : 1000.0;
                final animValue = _animationController.value;
                final contentWidth = _calculateChartContentWidth();

                final chart = BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.start,
                    groupsSpace: 28.0,
                    maxY: chartMaxY,
                    minY: 0,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        tooltipBgColor: Colors.black87,
                        tooltipRoundedRadius: 8,
                        tooltipPadding: const EdgeInsets.all(8),
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          if (groupIndex < 0 || groupIndex >= dailyPayments.length) {
                            return null;
                          }
                          final data = dailyPayments[groupIndex];
                          return BarTooltipItem(
                            '${data.day}\n',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            children: [
                              TextSpan(
                                text: 'Total: \$${data.total.toInt()}\n',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                              TextSpan(
                                text: 'Cash: \$${data.cash.toInt()}\n',
                                style: const TextStyle(
                                  color: Color(0xFF1D4ED8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                              TextSpan(
                                text: 'Card: \$${data.card.toInt()}\n',
                                style: const TextStyle(
                                  color: Color(0xFF3B82F6),
                                  fontSize: 11,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                              TextSpan(
                                text: 'Gift Card: \$${data.giftCard.toInt()}\n',
                                style: const TextStyle(
                                  color: Color(0xFF93C5FD),
                                  fontSize: 11,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                              TextSpan(
                                text: 'Cheque: \$${data.cheque.toInt()}\n',
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 11,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                              TextSpan(
                                text: 'Crypto: \$${data.crypto.toInt()}\n',
                                style: const TextStyle(
                                  color: Color(0xFF8B5CF6),
                                  fontSize: 11,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                              TextSpan(
                                text: 'Other: \$${data.other.toInt()}',
                                style: const TextStyle(
                                  color: Color(0xFFD1D5DB),
                                  fontSize: 11,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      touchCallback: (FlTouchEvent event, barTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              barTouchResponse == null ||
                              barTouchResponse.spot == null) {
                            _touchedIndex = -1;
                            return;
                          }
                          _touchedIndex = barTouchResponse.spot!.touchedBarGroupIndex;
                        });
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= 0 &&
                                value.toInt() < dailyPayments.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  dailyPayments[value.toInt()].day,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }
                            return const Text('');
                          },
                          reservedSize: 30,
                        ),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false, reservedSize: 0),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: interval,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey[200]!,
                          strokeWidth: 1,
                        );
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: dailyPayments.asMap().entries.map((entry) {
                      final index = entry.key;
                      final data = entry.value;
                      return BarChartGroupData(
                        x: index,
                        groupVertically: true,
                        barRods: [
                          // Cash (bottom)
                          BarChartRodData(
                            toY: data.cash * animValue,
                            color: const Color(0xFF1D4ED8),
                            width: 20,
                            borderRadius: BorderRadius.zero,
                          ),
                          // Card (on top of cash)
                          BarChartRodData(
                            fromY: data.cash * animValue,
                            toY: (data.cash + data.card) * animValue,
                            color: const Color(0xFF3B82F6),
                            width: 20,
                            borderRadius: BorderRadius.zero,
                          ),
                          // Gift Card (on top of card)
                          BarChartRodData(
                            fromY: (data.cash + data.card) * animValue,
                            toY: (data.cash + data.card + data.giftCard) * animValue,
                            color: const Color(0xFF93C5FD),
                            width: 20,
                            borderRadius: BorderRadius.zero,
                          ),
                          // Cheque (on top of gift card)
                          BarChartRodData(
                            fromY: (data.cash + data.card + data.giftCard) * animValue,
                            toY: (data.cash + data.card + data.giftCard + data.cheque) * animValue,
                            color: const Color(0xFF10B981),
                            width: 20,
                            borderRadius: BorderRadius.zero,
                          ),
                          // Crypto (on top of cheque)
                          BarChartRodData(
                            fromY: (data.cash + data.card + data.giftCard + data.cheque) * animValue,
                            toY: (data.cash + data.card + data.giftCard + data.cheque + data.crypto) * animValue,
                            color: const Color(0xFF8B5CF6),
                            width: 20,
                            borderRadius: BorderRadius.zero,
                          ),
                          // Other (on top of crypto)
                          BarChartRodData(
                            fromY: (data.cash + data.card + data.giftCard + data.cheque + data.crypto) * animValue,
                            toY: data.total * animValue,
                            color: const Color(0xFFD1D5DB),
                            width: 20,
                            borderRadius: BorderRadius.zero,
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                );

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFixedLeft(chartMaxY, interval, 300.0),
                    Expanded(
                      child: showScrollView
                          ? SingleChildScrollView(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: contentWidth,
                          child: chart,
                        ),
                      )
                          : Center(
                        child: SizedBox(
                          width: contentWidth,
                          child: chart,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DailyPayment {
  final String day;
  final double cash;
  final double card;
  final double giftCard;
  final double cheque;
  final double crypto;
  final double other;

  DailyPayment(this.day, this.cash, this.card, this.giftCard, this.cheque, this.crypto, this.other);

  double get total => cash + card + giftCard + cheque + crypto + other;
}