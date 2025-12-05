import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

import '../../api/api_service.dart';
import '../../api/clients_model.dart';

enum TimeFilter { today, thisWeek, custom }

class ClientsScreen extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;
  final String role;

  const ClientsScreen({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.role
  });

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _animationController;
  String _selectedPeriod = '30 Days';
  int _touchedIndex = -1;
  List<TopStaffClient> topStaffList = [];
  List<TopServiceClient> topServicesList = [];
  List<TopTimeWindow> topTimeWindowsList = [];
  double _chartScrollOffset = 0;
  final int _maxVisibleDays = 7;

  // Client statistics
  int totalClients = 0;
  int newClients = 0;
  int returningClients = 0;
  double retentionRate = 0.0;

  // Chart data for months
  List<MonthlyClientData> monthlyClientData = [];

  late DateTime _localStartDate = widget.startDate;
  late DateTime _localEndDate = widget.endDate;
  TimeFilter _localSelectedFilter = TimeFilter.today;
  String _userRole = 'OWNER';
  bool _datesChanged = false;

  @override
  void initState() {
    super.initState();
    _getUserRole();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
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

      if (role == 'OWNER') {
        _localStartDate = DateTime(2025, 10, 1);
        _localEndDate = DateTime.now();
        _localSelectedFilter = TimeFilter.custom;
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
      return;
    }
    final weekday = now.weekday;
    final weekStart = now.subtract(Duration(days: weekday - 1));
    final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final weekEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    if (_localStartDate == weekStartDate && _localEndDate == weekEnd) {
      _localSelectedFilter = TimeFilter.thisWeek;
      return;
    }
    _localSelectedFilter = TimeFilter.custom;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.getClientsStatistics(
        startDate: _localStartDate,
        endDate: _localEndDate,
        role: _userRole,
      );

      if (response.isSuccess && response.data != null) {
        final stats = ClientsStatisticsResponse.fromJson(response.data!);

        // Convert daily data to chart format
        final chartData = stats.dailyData.map((day) {
          return MonthlyClientData(
            day.formattedDate,
            day.newClientsCount.toDouble(),
            day.retentionRate,
          );
        }).toList();

        // Sort chart data by date (ascending)
        chartData.sort((a, b) {
          try {
            final dateA = DateFormat('dd/MM').parse(a.month);
            final dateB = DateFormat('dd/MM').parse(b.month);
            return dateA.compareTo(dateB);
          } catch (_) {
            return 0;
          }
        });

        // Set scroll offset to show last 7 days by default
        double scrollOffset = 0;
        if (chartData.length > _maxVisibleDays) {
          scrollOffset = (chartData.length - _maxVisibleDays).toDouble();
        }

        setState(() {
          totalClients = stats.totalClients;
          retentionRate = stats.retentionRate;
          newClients = stats.newClients;
          returningClients = stats.returningClients;
          monthlyClientData = chartData;
          topStaffList = stats.topStaff;
          topServicesList = stats.topServices;
          topTimeWindowsList = stats.topTimeWindows;
          _chartScrollOffset = scrollOffset;
          _isLoading = false;
        });

        _animationController.forward(from: 0.0);
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error loading clients data: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load clients data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _setDateRangeForFilter(TimeFilter filter) {
    if (_userRole != 'SUPER_OWNER') return;

    final now = DateTime.now();

    switch (filter) {
      case TimeFilter.today:
        _localStartDate = DateTime(now.year, now.month, now.day);
        _localEndDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case TimeFilter.thisWeek:
        final weekday = now.weekday;
        _localStartDate = now.subtract(Duration(days: weekday - 1));
        _localStartDate = DateTime(_localStartDate.year, _localStartDate.month, _localStartDate.day);
        _localEndDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
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
        title: const Text(
          'Clients',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 28,
            fontWeight: FontWeight.bold,
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildClientStatsGrid(),
                  const SizedBox(height: 20),
                  _buildClientRetentionChartSection(),
                  const SizedBox(height: 20),
                  _buildFilters(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientRetentionChartSection() {
    // Get visible data based on scroll offset
    final visibleData = _visibleChartData;

    // Nếu không có data nào, mới show message
    if (visibleData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bar_chart,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No chart data available',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Client Analytics',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              if (monthlyClientData.length > _maxVisibleDays)
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios, size: 16, color: Colors.teal),
                      onPressed: _scrollChartLeft,
                    ),
                    IconButton(
                      icon: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.teal),
                      onPressed: _scrollChartRight,
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 24),
          // Wrap chart with GestureDetector for panning
          GestureDetector(
            onHorizontalDragUpdate: _handleChartDrag,
            onHorizontalDragEnd: _handleChartDragEnd,
            child: SizedBox(
              height: 240,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  // Prepare data for line (retention rate)
                  final lineSpots = visibleData
                      .asMap()
                      .entries
                      .map((e) {
                    // Map retention rate (0-100) to chart scale (0-10)
                    final yValue = (e.value.retentionRate / 100) * 10;
                    return FlSpot(
                      e.key.toDouble(),
                      yValue * _animationController.value,
                    );
                  }).toList();

                  // Calculate maxY for chart based on data
                  final maxNewClients = visibleData
                      .map((d) => d.newClients)
                      .fold(0.0, (max, value) => value > max ? value : max);
                  final maxRetention = visibleData
                      .map((d) => d.retentionRate / 100 * 10)
                      .fold(0.0, (max, value) => value > max ? value : max);

                  // Set maxY to at least 5 for visibility (ngay cả khi data = 0)
                  double maxY = (maxNewClients > maxRetention ? maxNewClients : maxRetention) * 1.2;
                  if (maxY < 5) maxY = 5;

                  return LineChart(
                    LineChartData(
                      minX: -0.5, // Add left padding
                      maxX: (visibleData.length - 1).toDouble() + 0.5, // Add right padding
                      minY: 0,
                      maxY: maxY,
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          tooltipBgColor: Colors.black87,
                          tooltipRoundedRadius: 8,
                          getTooltipItems: (List<LineBarSpot> touchedSpots) {
                            return touchedSpots.map((spot) {
                              final index = spot.x.toInt();
                              if (index >= 0 && index < visibleData.length) {
                                final data = visibleData[index];
                                if (spot.barIndex == 0) {
                                  // Line chart tooltip (retention rate)
                                  return LineTooltipItem(
                                    '${data.month}\nRetention: ${data.retentionRate.toStringAsFixed(1)}%',
                                    const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  );
                                } else {
                                  // Bar chart tooltip (new clients)
                                  return LineTooltipItem(
                                    '${data.month}\nNew: ${data.newClients.toInt()}',
                                    const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  );
                                }
                              }
                              return null;
                            }).toList();
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1.0,
                            getTitlesWidget: (value, meta) {
                              final intValue = value.toInt();
                              if (value == intValue.toDouble() &&
                                  intValue >= 0 &&
                                  intValue < visibleData.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    visibleData[intValue].month,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }
                              return Container();
                            },
                            reservedSize: 30,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            interval: maxY > 10 ? maxY / 5 : 1,
                            getTitlesWidget: (value, meta) {
                              if (value == 0) return const Text('');
                              return Text(
                                value.toInt().toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              );
                            },
                          ),
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
                        horizontalInterval: maxY > 10 ? maxY / 5 : 1,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey[200]!,
                            strokeWidth: 1,
                          );
                        },
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      lineBarsData: [
                        // Line chart for retention rate - LUÔN hiển thị, kể cả data = 0
                        LineChartBarData(
                          spots: lineSpots,
                          isCurved: false,
                          color: Colors.teal,
                          barWidth: 2,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 3,
                                color: Colors.teal,
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(show: false),
                        ),
                        // Bars for new clients - LUÔN hiển thị, kể cả data = 0
                        ...visibleData.asMap().entries.map(
                              (e) => LineChartBarData(
                            spots: [
                              FlSpot(e.key.toDouble(), 0),
                              FlSpot(e.key.toDouble(), e.value.newClients * _animationController.value),
                            ],
                            isCurved: false,
                            color: Colors.blue.withOpacity(0.6),
                            barWidth: 20, // Bar width
                            dotData: FlDotData(show: false),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          // LUÔN hiển thị legend, kể cả data = 0
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(Colors.blue, 'New Clients'),
              const SizedBox(width: 16),
              _buildLegendItem(Colors.teal, 'Retention Rate'),
            ],
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
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 20),
          Column(
            children: [
              Container(
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClientStatsGrid() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildAnimatedStatItem('Total Clients', totalClients),
              ),
              Expanded(
                child: _buildAnimatedStatItem('Retention Rate (30D)', retentionRate, isPercentage: true),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: Colors.grey[200]),
          ),
          Row(
            children: [
              Expanded(
                child: _buildAnimatedStatItem('New Clients', newClients),
              ),
              Expanded(
                child: _buildAnimatedStatItem('Returning Clients', returningClients),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedStatItem(String label, dynamic value, {bool isPercentage = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            dynamic animatedValue;
            if (isPercentage) {
              animatedValue = (value * _animationController.value).toInt();
              return Text(
                '${animatedValue.toInt()}%',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              );
            } else {
              animatedValue = (value * _animationController.value).toInt();
              return Text(
                '$animatedValue',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              );
            }
          },
        ),
      ],
    );
  }



  // Thêm biến để theo dõi drag
  double _dragStartX = 0;
  double _dragStartOffset = 0;
  bool _isDragging = false;

  void _handleChartDrag(DragUpdateDetails details) {
    if (!_isDragging) {
      _dragStartX = details.globalPosition.dx;
      _dragStartOffset = _chartScrollOffset;
      _isDragging = true;
    }

    final deltaX = _dragStartX - details.globalPosition.dx;

    // Tính sensitivity: mỗi pixel = 0.05 unit scroll offset
    // Có thể điều chỉnh sensitivity theo ý muốn
    final sensitivity = 0.05;
    final deltaOffset = deltaX * sensitivity;

    final newOffset = _dragStartOffset + deltaOffset;
    final maxOffset = (monthlyClientData.length - _maxVisibleDays).toDouble();

    // Cập nhật state ngay lập tức để tạo hiệu ứng mượt
    setState(() {
      _chartScrollOffset = newOffset.clamp(0.0, maxOffset);
    });
  }

  void _handleChartDragEnd(DragEndDetails details) {
    _isDragging = false;

    // Snap to nearest integer
    setState(() {
      _chartScrollOffset = _chartScrollOffset.roundToDouble();
    });

    // Thêm hiệu ứng velocity nếu muốn
    final velocity = details.velocity.pixelsPerSecond.dx;
    if (velocity.abs() > 100) { // Ngưỡng velocity để tiếp tục scroll
      final direction = velocity > 0 ? -1 : 1;
      final velocityFactor = velocity.abs() / 500; // Giảm tốc độ

      _continueScrollWithVelocity(direction * velocityFactor);
    }
  }

  void _continueScrollWithVelocity(double velocityFactor) {
    final maxOffset = (monthlyClientData.length - _maxVisibleDays).toDouble();

    if (velocityFactor > 0 && _chartScrollOffset < maxOffset) {
      // Scroll sang phải (xem dữ liệu cũ hơn)
      final newOffset = _chartScrollOffset + velocityFactor;
      setState(() {
        _chartScrollOffset = newOffset.clamp(0.0, maxOffset).roundToDouble();
      });
    } else if (velocityFactor < 0 && _chartScrollOffset > 0) {
      // Scroll sang trái (xem dữ liệu mới hơn)
      final newOffset = _chartScrollOffset + velocityFactor;
      setState(() {
        _chartScrollOffset = newOffset.clamp(0.0, maxOffset).roundToDouble();
      });
    }
  }

// Thêm hiệu ứng haptic feedback khi scroll đến giới hạn
  void _scrollChartLeft() {
    if (_chartScrollOffset < (monthlyClientData.length - _maxVisibleDays)) {
      setState(() {
        _chartScrollOffset += 1;
      });
    } else {
      // Provide haptic feedback when at limit
      _showHapticFeedback();
    }
  }

  void _scrollChartRight() {
    if (_chartScrollOffset > 0) {
      setState(() {
        _chartScrollOffset -= 1;
      });
    } else {
      // Provide haptic feedback when at limit
      _showHapticFeedback();
    }
  }

  void _showHapticFeedback() {
    // Sử dụng haptic feedback nếu có
    HapticFeedback.lightImpact();
  }

  List<MonthlyClientData> get _visibleChartData {
    if (monthlyClientData.isEmpty) return [];

    final startIndex = _chartScrollOffset.toInt();
    final endIndex = startIndex + _maxVisibleDays;

    // Ensure indices are within bounds
    if (startIndex >= monthlyClientData.length) {
      return monthlyClientData.sublist(
          monthlyClientData.length - _maxVisibleDays > 0
              ? monthlyClientData.length - _maxVisibleDays
              : 0
      );
    }

    final actualEndIndex = endIndex < monthlyClientData.length
        ? endIndex
        : monthlyClientData.length;

    return monthlyClientData.sublist(startIndex, actualEndIndex);
  }

  Widget _buildFilters() {
    return Column(
      children: [
        _buildExpandableFilter(
          'By Staff',
          topStaffList.isEmpty ? 'All Staff' : '${topStaffList.length} staff',
          topStaffList.map((staff) =>
              _buildStaffItem(staff.staffName, staff.staffAvatar, staff.clientCount)
          ).toList(),
        ),
        const SizedBox(height: 12),
        _buildExpandableFilter(
          'By Service Type',
          topServicesList.isEmpty ? 'All Services' : '${topServicesList.length} services',
          topServicesList.map((service) =>
              _buildServiceItem(service.serviceName, service.categoryName, service.clientCount)
          ).toList(),
        ),
        const SizedBox(height: 12),
        _buildExpandableFilter(
          'By Time Window',
          topTimeWindowsList.isEmpty ? 'All Day' : '${topTimeWindowsList.length} windows',
          topTimeWindowsList.map((window) =>
              _buildTimeWindowItem(window.timeWindow, window.clientCount)
          ).toList(),
        ),
      ],
    );
  }

// 8️⃣ ADD EXPANDABLE FILTER WIDGET
  Widget _buildExpandableFilter(String label, String subtitle, List<Widget> children) {
    return ExpansionTile(
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[600],
        ),
      ),
      backgroundColor: Colors.white,
      collapsedBackgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      children: children,
    );
  }

// 9️⃣ ADD ITEM WIDGETS
  Widget _buildStaffItem(String name, String? avatar, int count) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: avatar != null && avatar.isNotEmpty
            ? NetworkImage(avatar)
            : null,
        child: avatar == null || avatar.isEmpty
            ? Icon(Icons.person, color: Colors.grey)
            : null,
      ),
      title: Text(name),
      trailing: Text(
        '$count clients',
        style: TextStyle(
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildServiceItem(String name, String? category, int count) {
    return ListTile(
      leading: Icon(Icons.spa, color: Colors.teal),
      title: Text(name),
      subtitle: category != null ? Text(category) : null,
      trailing: Text(
        '$count clients',
        style: TextStyle(
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTimeWindowItem(String window, int count) {
    return ListTile(
      leading: Icon(Icons.access_time, color: Colors.blue),
      title: Text(window),
      trailing: Text(
        '$count clients',
        style: TextStyle(
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black87,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class MonthlyClientData {
  final String month;
  final double newClients;
  final double retentionRate;

  MonthlyClientData(this.month, this.newClients, this.retentionRate);
}