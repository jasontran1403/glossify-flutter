import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hair_sallon/api/api_service.dart';
import 'package:hair_sallon/view/dashboard_screen/dashboard_screen.dart';
import 'package:hair_sallon/view/owner_screen/staff_statistics_screen.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TimeFilter { today, thisWeek, thisMonth, custom }

class OwnerStoreDetailScreen extends StatefulWidget {
  const OwnerStoreDetailScreen({super.key});

  @override
  State<OwnerStoreDetailScreen> createState() => _OwnerStoreDetailScreenState();
}

class _OwnerStoreDetailScreenState extends State<OwnerStoreDetailScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isLoading = true;
  Map<String, dynamic>? _statsData;
  TimeFilter _selectedFilter = TimeFilter.today;
  late AnimationController _animationController;
  double _animationValue = 0.0;
  int _touchedIndex = -1;
  double _pieRotation = 0.0;
  String _userRole = 'OWNER';

  @override
  void initState() {
    super.initState();
    _getUserRole();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..addListener(() {
      setState(() {
        _animationValue = _animationController.value;
        _pieRotation = _animationController.value * 2 * 3.14159;
      });
    });

    _setDateRangeForFilter(TimeFilter.today);
    _fetchStoreStats();
  }

  Future<void> _getUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userRole = prefs.getString('role') ?? 'OWNER';
      });
    } catch (e) {
      print('Error getting user role: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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

  Future<void> _fetchStoreStats() async {
    setState(() {
      _isLoading = true;
      _animationValue = 0.0;
      _pieRotation = 0.0;
    });

    try {
      final response = await ApiService.getMyStoreStats(
        startDate: _startDate,
        endDate: _endDate,
        userRole: _userRole,
      );

      if (mounted) {
        setState(() {
          _statsData = response.data;
          _isLoading = false;
        });
        _animationController.forward(from: 0.0);
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
      _fetchStoreStats();
    }
  }

  String _getDateRangeText() {
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
    if (_userRole == "OWNER") {
      return const SizedBox.shrink();
    }

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
        _fetchStoreStats();
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

  Widget _buildStatsCard(BuildContext context) {
    if (_statsData == null) return const SizedBox();

    final stats = _statsData!;

    return InkWell(
      onTap: () {
        // Navigate to Staff Statistics Screen
        Navigator.push(
          context,
          MaterialPageRoute(
            // builder: (context) => const StaffStatisticsScreen(),
            builder: (context) => const DashboardScreen(),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Store Statistics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 2,
                    children: [
                      _buildStatItem('Daily Customers', stats['dailyCustomers'], Icons.people, isCurrency: false),
                      _buildStatItem(
                        'Total Shares',
                        (stats['totalShares'] ?? 0) + (stats['dailyRevenue'] ?? 0),
                        Icons.trending_up,
                        isCurrency: true,
                      ),
                      _buildStatItem('Total Tips', stats['totalTips'], Icons.emoji_events, isCurrency: true),
                      _buildStatItem('Credit Revenue', stats['creditRevenue'], Icons.credit_card, isCurrency: true),
                      _buildStatItem('Cash Revenue', stats['cashRevenue'], Icons.money, isCurrency: true),
                      _buildStatItem('Gift Card', stats['giftCardRevenue'], Icons.card_giftcard, isCurrency: true),
                      _buildStatItem('Cheque', stats['chequeRevenue'], Icons.receipt_long, isCurrency: true),
                      _buildStatItem('Others', stats['othersRevenue'], Icons.payments, isCurrency: true),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String title, dynamic value, IconData icon, {bool isCurrency = false}) {
    double numericValue = _safeGetDouble(value);
    final animatedValue = isCurrency
        ? '\$${(numericValue * _animationValue).toStringAsFixed(2)}'
        : '${(numericValue * _animationValue).toInt()}';

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.blue),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            animatedValue,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    if (_statsData == null) return const SizedBox();

    final statusData = _statsData!['bookingStatus'] as Map<String, dynamic>?;
    if (statusData == null) return const SizedBox();

    final bookedCount = _safeGetInt(statusData['BOOKED']);
    final checkedInCount = _safeGetInt(statusData['CHECKED_IN']);
    final waitingPaymentCount = _safeGetInt(statusData['WAITING_PAYMENT']);
    final paidCount = _safeGetInt(statusData['PAID']);

    final totalBookings = bookedCount + checkedInCount + waitingPaymentCount + paidCount;

    if (totalBookings == 0) return const SizedBox();

    final sections = [
      _buildPieSection('BOOKED', bookedCount.toDouble() * _animationValue, Colors.blue),
      _buildPieSection('CHECKED_IN', checkedInCount.toDouble() * _animationValue, Colors.orange),
      _buildPieSection('WAITING_PAYMENT', waitingPaymentCount.toDouble() * _animationValue, Colors.yellow),
      _buildPieSection('PAID', paidCount.toDouble() * _animationValue, Colors.green),
    ];

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Booking Status Distribution', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        startDegreeOffset: _pieRotation,
                        pieTouchData: PieTouchData(
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                _touchedIndex = -1;
                                return;
                              }
                              _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                            });
                          },
                        ),
                        sections: _touchedIndex == -1
                            ? sections
                            : sections.asMap().entries.map((entry) {
                          return entry.key == _touchedIndex
                              ? entry.value.copyWith(radius: 55)
                              : entry.value.copyWith(radius: 45);
                        }).toList(),
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLegendItem('BOOKED', bookedCount, totalBookings, Colors.blue),
                        _buildLegendItem('CHECKED_IN', checkedInCount, totalBookings, Colors.orange),
                        _buildLegendItem('WAITING_PAYMENT', waitingPaymentCount, totalBookings, Colors.yellow),
                        _buildLegendItem('PAID', paidCount, totalBookings, Colors.green),
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

  PieChartSectionData _buildPieSection(String title, double value, Color color) {
    return PieChartSectionData(
      color: color,
      value: value,
      title: value > 0 ? '${value.toInt()}' : '',
      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      radius: 50,
      titlePositionPercentageOffset: 0.6,
    );
  }

  Widget _buildLegendItem(String status, int count, int total, Color color) {
    final percentage = total > 0 ? (count / total * 100).toStringAsFixed(1) : '0.0';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                Text('$count ($percentage%)', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    if (_statsData == null) return const SizedBox();

    final revenueData = _statsData!['dailyRevenueData'] as List<dynamic>?;
    if (revenueData == null || revenueData.isEmpty) return const SizedBox();

    double maxY = 0;
    for (var data in revenueData) {
      final totalRevenue = _safeGetDouble(data['totalRevenue']);
      if (totalRevenue > maxY) maxY = totalRevenue;
    }

    if (maxY == 0) maxY = 100;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Daily Revenue Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY * 1.2,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        if (groupIndex >= revenueData.length) return null;

                        final data = revenueData[groupIndex] as Map<String, dynamic>;
                        final date = DateFormat('dd/MM').format(DateTime.parse(_safeGetString(data['date'])));
                        final totalRevenue = _safeGetDouble(data['totalRevenue']);
                        final share = _safeGetDouble(data['share']);
                        final tip = _safeGetDouble(data['tip']);
                        final remaining = _safeGetDouble(data['remaining']);

                        return BarTooltipItem(
                          '$date\nTotal: \$${totalRevenue.toStringAsFixed(2)}\n'
                              'Share: \$${share.toStringAsFixed(2)}\n'
                              'Tip: \$${tip.toStringAsFixed(2)}\n'
                              'Net: \$${remaining.toStringAsFixed(2)}',
                          const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: revenueData.asMap().entries.map((entry) {
                    final index = entry.key;
                    final data = entry.value as Map<String, dynamic>;

                    final totalRevenue = _safeGetDouble(data['totalRevenue']) * _animationValue;
                    final share = _safeGetDouble(data['share']) * _animationValue;
                    final tip = _safeGetDouble(data['tip']) * _animationValue;

                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: totalRevenue,
                          width: 20,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                          rodStackItems: [
                            BarChartRodStackItem(0, share, Colors.red[400]!),
                            BarChartRodStackItem(share, share + tip, Colors.orange[400]!),
                            BarChartRodStackItem(share + tip, totalRevenue, Colors.green[400]!),
                          ],
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: const FlTitlesData(
                    show: false,
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildChartLegend('Share', Colors.red[400]!),
                const SizedBox(width: 16),
                _buildChartLegend('Tip', Colors.orange[400]!),
                const SizedBox(width: 16),
                _buildChartLegend('Net Revenue', Colors.green[400]!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartLegend(String text, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
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

  String _safeGetString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Store Dashboard'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _fetchStoreStats,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(
                  _userRole == 'SUPER_OWNER' ? Icons.admin_panel_settings : Icons.person,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _userRole,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchStoreStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildTimeFilterButtons(),
              const SizedBox(height: 16),
              _buildStatsCard(context),
              const SizedBox(height: 16),
              _buildPieChart(),
              const SizedBox(height: 16),
              _buildBarChart(),
            ],
          ),
        ),
      ),
    );
  }
}