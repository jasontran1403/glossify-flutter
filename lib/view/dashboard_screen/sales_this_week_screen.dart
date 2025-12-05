import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/api_service.dart'; // ✅ Import your ApiService

enum TimeFilter { today, thisWeek, custom }

class SalesThisWeekScreen extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;

  const SalesThisWeekScreen({
    super.key,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<SalesThisWeekScreen> createState() => _SalesThisWeekScreenState();
}

class _SalesThisWeekScreenState extends State<SalesThisWeekScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _animationController;

  String _selectedStaffFilter = 'All Staff';
  String _dropdownPeriod = 'This Week';
  String _titlePeriod = 'This Week';

  // Data from API
  double totalSales = 0;
  double avgPerDay = 0;
  double vsLastWeek = 0;

  List<Map<String, dynamic>> salesByDay = [];
  List<Map<String, dynamic>> topStaff = [];
  List<Map<String, dynamic>> topServices = [];

  int _touchedIndex = -1;

  // ✅ Chart pan/scroll state
  double _chartScrollOffset = 0;
  final int _maxVisibleItems = 7;

  late DateTime _localStartDate;
  late DateTime _localEndDate;
  TimeFilter _localSelectedFilter = TimeFilter.today;
  String _userRole = 'OWNER';
  bool _datesChanged = false;

  @override
  void initState() {
    super.initState();

    // ✅ Initialize dates from widget params first to avoid LateInitializationError
    _localStartDate = widget.startDate;
    _localEndDate = widget.endDate;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _datesChanged = false;

    // ✅ Load user role and data sequentially
    _initializeData();

    print('${widget.startDate} - ${widget.endDate}');
  }

  Future<void> _initializeData() async {
    await _getUserRole(); // Wait for role to be loaded
    await _loadData();    // Then load data
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

      if (role == 'OWNER') {
        _localStartDate = DateTime(2025, 10, 1);
        _localEndDate = DateTime.now();
        _localSelectedFilter = TimeFilter.custom;
        _titlePeriod = 'All Time';
        _dropdownPeriod = 'All Time';
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
      _dropdownPeriod = 'Today';
      return;
    }
    final weekday = now.weekday;
    final weekStart = now.subtract(Duration(days: weekday - 1));
    final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final weekEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    if (_localStartDate == weekStartDate && _localEndDate == weekEnd) {
      _localSelectedFilter = TimeFilter.thisWeek;
      _titlePeriod = 'This Week';
      _dropdownPeriod = 'This Week';
      return;
    }
    _localSelectedFilter = TimeFilter.custom;
    _titlePeriod = '${DateFormat('MMM dd').format(_localStartDate)} - ${DateFormat('MMM dd').format(_localEndDate)}';
    _dropdownPeriod = 'Custom Range';
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // ✅ Call ApiService.getSalesData() - token handled automatically
      final salesData = await ApiService.getSalesData(
        startDate: _localStartDate,
        endDate: _localEndDate,
        role: _userRole,
      );

      if (salesData != null && mounted) {
        // Update state with real data
        setState(() {
          totalSales = salesData.totalSales;
          avgPerDay = salesData.avgPerDay;
          vsLastWeek = salesData.vsLastWeekPercentage;

          // Convert daily sales to map format
          salesByDay = salesData.dailySales.map((day) => {
            'day': day.dayLabel,
            'amount': day.amount,
            'date': day.date,
          }).toList();

          // Convert top staff to map format
          topStaff = salesData.topStaff.map((staff) => {
            'name': staff.name,
            'sales': staff.sales,
            'avatar': staff.avatar,
          }).toList();

          // Convert top services to map format
          topServices = salesData.topServices.map((service) => {
            'name': service.name,
            'percentage': service.percentage.toInt(),
            'sales': service.sales,
          }).toList();

          // ✅ Reset chart scroll to show latest data (last 7 items)
          if (salesByDay.length > _maxVisibleItems) {
            _chartScrollOffset = (salesByDay.length - _maxVisibleItems).toDouble();
          } else {
            _chartScrollOffset = 0;
          }
        });

        _animationController.forward(from: 0.0);
      } else {
        // Handle error - use fake data as fallback
        print('⚠️ Failed to load sales data, using fake data');
        _loadFakeData();
      }
    } catch (e) {
      print('❌ Error loading sales data: $e');
      _loadFakeData();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Fallback method with fake data (for testing/error cases)
  void _loadFakeData() {
    salesByDay = [
      {'day': 'Mon', 'amount': 650.0},
      {'day': 'Tue', 'amount': 720.0},
      {'day': 'Wed', 'amount': 580.0},
      {'day': 'Thu', 'amount': 890.0},
      {'day': 'Fri', 'amount': 1250.0},
      {'day': 'Sat', 'amount': 980.0},
      {'day': 'Sun', 'amount': 1100.0},
    ];

    topStaff = [
      {'name': 'Emily', 'sales': 2900.0, 'avatar': null},
      {'name': 'John', 'sales': 2600.0, 'avatar': null},
      {'name': 'Alice', 'sales': 1850.0, 'avatar': null},
    ];

    topServices = [
      {'name': 'Dip Powder', 'percentage': 24},
      {'name': 'Gel Manicure', 'percentage': 22},
      {'name': 'Pedicure', 'percentage': 18},
    ];

    totalSales = 7850;
    avgPerDay = 1121;
    vsLastWeek = 12;

    // ✅ Reset chart scroll
    _chartScrollOffset = 0;
  }

  void _setDateRangeForFilter(TimeFilter filter) {
    if (_userRole != 'SUPER_OWNER') return;

    final now = DateTime.now();

    switch (filter) {
      case TimeFilter.today:
        _localStartDate = DateTime(now.year, now.month, now.day);
        _localEndDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        _titlePeriod = 'Today';
        _dropdownPeriod = 'Today';
        break;
      case TimeFilter.thisWeek:
        final weekday = now.weekday;
        _localStartDate = now.subtract(Duration(days: weekday - 1));
        _localStartDate = DateTime(_localStartDate.year, _localStartDate.month, _localStartDate.day);
        _localEndDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        _titlePeriod = 'This Week';
        _dropdownPeriod = 'This Week';
        break;
      case TimeFilter.custom:
        break;
    }

    setState(() {
      _localSelectedFilter = filter;
    });
  }

  Future<void> _selectCustomDateRange() async {
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
        _dropdownPeriod = 'Custom Range';
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
          'Sales $_titlePeriod',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
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
              child: Column(
                children: [
                  // Stats Section
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('Total Sales', '\$${totalSales.toInt()}'),
                        _buildStatItem('Avg Per Day', '\$${avgPerDay.toInt()}'),
                        _buildStatItem(
                          'vs Last Week',
                          '${vsLastWeek >= 0 ? '+' : ''}${vsLastWeek.toStringAsFixed(1)}%',
                          valueColor: vsLastWeek >= 0 ? Colors.green : Colors.red,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Chart Section
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      height: 250,
                      child: _buildAreaChart(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Top Staff & Top Services
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Staff
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Top Staff',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ...topStaff.map((staff) => _buildStaffItem(
                                name: staff['name'],
                                sales: staff['sales'],
                                avatar: staff['avatar'],
                              )),
                            ],
                          ),
                        ),
                        const SizedBox(width: 32),
                        // Top Services
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Top Services',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ...topServices.map((service) => _buildServiceItem(
                                name: service['name'],
                                percentage: service['percentage'],
                              )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
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
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(3, (index) => Column(
                children: [
                  Container(width: 80, height: 12, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Container(width: 60, height: 24, color: Colors.grey[300]),
                ],
              )),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Container(height: 250, color: Colors.grey[300]),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, {Color? valueColor}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            if (value.startsWith('\$')) {
              final numValue = double.parse(value.substring(1).replaceAll(',', ''));
              return Text(
                '\$${(numValue * _animationController.value).toInt()}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? Colors.black87,
                ),
              );
            } else if (value.contains('%')) {
              final numValue = double.parse(value.replaceAll('%', '').replaceAll('+', '').replaceAll('-', ''));
              final sign = value.startsWith('+') ? '+' : value.startsWith('-') ? '-' : '';
              return Text(
                '$sign${(numValue * _animationController.value).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: valueColor ?? Colors.black87,
                ),
              );
            }
            return Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: valueColor ?? Colors.black87,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAreaChart() {
    if (salesByDay.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final totalItems = salesByDay.length;

    // ✅ If data <= 7, show all without scrolling
    if (totalItems <= _maxVisibleItems) {
      return _buildStaticChart();
    }

    // ✅ For data > 7, enable scrolling
    return _buildScrollableChart();
  }

  // Static chart for <= 7 items
  Widget _buildStaticChart() {
    double maxY = salesByDay.fold(0.0, (max, item) =>
    item['amount'] > max ? item['amount'] : max
    );

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return LineChart(
          LineChartData(
            minY: 0,
            maxY: maxY * 1.2,
            // ✅ Add padding: -0.5 left, +0.5 right
            minX: -0.5,
            maxX: (salesByDay.length - 1).toDouble() + 0.5,
            gridData: _buildGridData(maxY),
            titlesData: _buildTitlesData(maxY, 0, salesByDay.length - 1),
            borderData: FlBorderData(show: false),
            lineBarsData: [_buildLineBarData()],
            lineTouchData: _buildLineTouchData(),
          ),
        );
      },
    );
  }

  // Scrollable chart for > 7 items
  Widget _buildScrollableChart() {
    final totalItems = salesByDay.length;

    double maxY = salesByDay.fold(0.0, (max, item) =>
    item['amount'] > max ? item['amount'] : max
    );

    // Calculate visible window
    final maxOffset = (totalItems - _maxVisibleItems).toDouble();
    final clampedOffset = _chartScrollOffset.clamp(0.0, maxOffset);

    final startIndex = clampedOffset.toInt();
    final endIndex = (startIndex + _maxVisibleItems - 1).clamp(0, totalItems - 1);

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          // Negative delta = swipe right (scroll left/backward)
          // Positive delta = swipe left (scroll right/forward)
          final sensitivity = 0.05;
          _chartScrollOffset = (_chartScrollOffset - details.delta.dx * sensitivity)
              .clamp(0.0, maxOffset);
        });
      },
      onHorizontalDragEnd: (details) {
        // Snap to nearest integer position
        setState(() {
          _chartScrollOffset = _chartScrollOffset.roundToDouble();
        });
      },
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY * 1.2,
              // ✅ Add padding: -0.5 left, +0.5 right
              minX: clampedOffset - 0.5,
              maxX: clampedOffset + (_maxVisibleItems - 1) + 0.5,
              gridData: _buildGridData(maxY),
              titlesData: _buildTitlesData(maxY, startIndex, endIndex),
              borderData: FlBorderData(show: false),
              lineBarsData: [_buildLineBarData()],
              lineTouchData: _buildLineTouchData(),
            ),
          );
        },
      ),
    );
  }

  // Shared grid data builder
  FlGridData _buildGridData(double maxY) {
    return FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: maxY * 0.25,
      getDrawingHorizontalLine: (value) {
        return FlLine(
          color: Colors.grey.shade200,
          strokeWidth: 1,
        );
      },
    );
  }

  // Shared titles data builder
  FlTitlesData _buildTitlesData(double maxY, int visibleStart, int visibleEnd) {
    return FlTitlesData(
      show: true,
      rightTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      topTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 45,
          interval: maxY * 0.25,
          getTitlesWidget: (value, meta) {
            return Text(
              '\$${value.toInt()}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            );
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: 1.0,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            // ✅ Only show labels for valid integer indices within data range
            // This prevents labels showing in the padding areas
            if (value != index.toDouble() || index < 0 || index >= salesByDay.length) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                salesByDay[index]['day'],
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Shared line bar data builder
  LineChartBarData _buildLineBarData() {
    return LineChartBarData(
      spots: salesByDay.asMap().entries.map((entry) {
        return FlSpot(
          entry.key.toDouble(),
          entry.value['amount'] * _animationController.value,
        );
      }).toList(),
      isCurved: false, // ✅ Straight line instead of curved
      color: Colors.blue,
      barWidth: 2,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 3,
            color: Colors.blue,
            strokeWidth: 1.5,
            strokeColor: Colors.white,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [
            Colors.blue.withOpacity(0.3),
            Colors.blue.withOpacity(0.1),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  // Shared touch data builder
  LineTouchData _buildLineTouchData() {
    return LineTouchData(
      enabled: true,
      touchTooltipData: LineTouchTooltipData(
        tooltipBgColor: Colors.black87,
        tooltipRoundedRadius: 8,
        getTooltipItems: (List<LineBarSpot> touchedSpots) {
          return touchedSpots.map((spot) {
            final index = spot.x.toInt();
            if (index >= 0 && index < salesByDay.length) {
              final dayData = salesByDay[index];
              return LineTooltipItem(
                '${dayData['day']}\n\$${dayData['amount'].toInt()}',
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
    );
  }

  Widget _buildStaffItem({
    required String name,
    required double sales,
    String? avatar,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[300],
            backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar == null || avatar.isEmpty
                ? Text(
              name.isNotEmpty ? name[0] : '?',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Text(
                '\$${(sales * _animationController.value).toInt()}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildServiceItem({
    required String name,
    required int percentage,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Text(
                    '${(percentage * _animationController.value).toInt()}%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return LinearProgressIndicator(
                value: (percentage / 100) * _animationController.value,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              );
            },
          ),
        ],
      ),
    );
  }
}