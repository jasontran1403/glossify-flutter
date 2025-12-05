// clients_per_day_screen.dart (hoặc heatmap_screen.dart)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import '../../api/api_service.dart';
import '../../api/clients_per_day.dart'; // Đảm bảo đã có method mới bên dưới

class ClientsPerDayScreen extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;
  final String role;

  const ClientsPerDayScreen({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.role
  });

  @override
  State<ClientsPerDayScreen> createState() => _ClientsPerDayScreenState();
}

class _ClientsPerDayScreenState extends State<ClientsPerDayScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _localStartDate;
  late DateTime _localEndDate;
  String _userRole = 'OWNER';
  late AnimationController _animationController;
  bool _isLoading = true;

  // Dữ liệu từ API
  ClientsPerDayData? _data;

  @override
  void initState() {
    super.initState();
    _localStartDate = widget.startDate;
    _localEndDate = widget.endDate;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );

    _getUserRoleAndLoad();
  }

  Future<void> _getUserRoleAndLoad() async {
    final prefs = await SharedPreferences.getInstance();
    _userRole = prefs.getString('role') ?? 'OWNER';

    if (_userRole == 'OWNER') {
      _localStartDate = DateTime(2025, 10, 1);
      _localEndDate = DateTime.now();
    }

    setState(() {});
    _loadHeatmapData();
  }

  Future<void> _loadHeatmapData() async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.getClientsHeatmap(
        start: _localStartDate,
        end: _localEndDate,
        role: _userRole
      );

      if (response.isSuccess && response.data != null) {
        setState(() {
          _data = ClientsPerDayData.fromJson(response.data!);
          _isLoading = false;
        });
        _animationController.forward(from: 0.0);
      } else {
        final errorMsg = response.message.isNotEmpty ? response.message : "Unknown error";
        throw Exception(errorMsg);
      }
    } catch (e, stackTrace) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Load failed: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _handleBack() {
    Navigator.pop(context, DateTimeRange(start: _localStartDate, end: _localEndDate));
  }

  Future<void> _selectCustomDateRange() async {
    if (_userRole != 'SUPER_OWNER') return;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _localStartDate, end: _localEndDate),
    );

    if (picked != null &&
        (picked.start != _localStartDate || picked.end != _localEndDate)) {
      setState(() {
        _localStartDate = picked.start;
        _localEndDate = picked.end;
      });
      _loadHeatmapData();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Clients Per Day Heatmap'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _handleBack),
      ),
      body: Column(
        children: [
          // Header: Date Range + Filter (chỉ SUPER_OWNER thấy nút filter)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: _userRole == 'SUPER_OWNER' ? _selectCustomDateRange : null,
                    child: Text(
                      _userRole == 'OWNER'
                          ? 'Oct 1, 2025 - Present'
                          : '${DateFormat('MMM dd').format(_localStartDate)} - ${DateFormat('MMM dd').format(_localEndDate)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ),
                if (_userRole == 'SUPER_OWNER') ...[
                  _buildFilterButton('Today'),
                  const SizedBox(width: 6),
                  _buildFilterButton('This Week'),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: _selectCustomDateRange,
                    child: const Icon(Icons.date_range, size: 20, color: Colors.teal),
                  ),
                ],
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.teal))
                : _data == null
                ? const Center(child: Text("No data available"))
                : ClientsHeatmapWidget(data: _data!, animationController: _animationController),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label) {
    final now = DateTime.now();
    bool isActive = false;

    if (label == 'Today') {
      final today = DateTime(now.year, now.month, now.day);
      isActive = _localStartDate.isAtSameMomentAs(today);
    } else if (label == 'This Week') {
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
      isActive = _localStartDate.isAtSameMomentAs(start);
    }

    return InkWell(
      onTap: () {
        if (label == 'Today') {
          _localStartDate = DateTime(now.year, now.month, now.day);
          _localEndDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        } else if (label == 'This Week') {
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          _localStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
          _localEndDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        }
        setState(() {});
        _loadHeatmapData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.teal : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ==================== CLIENTS HEATMAP WIDGET (dùng dữ liệu thật) ====================
class ClientsHeatmapWidget extends StatefulWidget {
  final ClientsPerDayData data;
  final AnimationController animationController;

  const ClientsHeatmapWidget({
    super.key,
    required this.data,
    required this.animationController,
  });

  @override
  State<ClientsHeatmapWidget> createState() => _ClientsHeatmapWidgetState();
}

class _ClientsHeatmapWidgetState extends State<ClientsHeatmapWidget> {
  int? _selectedDay;
  int? _selectedHour;

  final List<String> hours = ['9AM', '10AM', '11AM', '12PM', '1PM', '2PM', '3PM', '4PM', '5PM', '6PM'];
  final List<String> weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animationController,
      builder: (context, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatsCards(),
              const SizedBox(height: 24),
              _buildBarChart(),
              const SizedBox(height: 12),
              Text(
                'This week is ${widget.data.weekComparisonPercent >= 0 ? '+' : ''}${widget.data.weekComparisonPercent}% compared to last week.',
                style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
              ),
              const SizedBox(height: 24),
              _buildHeatmap(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsCards() {
    final animatedTotal = widget.data.totalClients * widget.animationController.value;
    final animatedAvg = widget.data.avgPerDay * widget.animationController.value;

    return Row(
      children: [
        _buildStatCard('Total Clients', animatedTotal.toInt().toString(), Colors.black87),
        const SizedBox(width: 12),
        _buildStatCard(
          '${widget.data.weekComparisonPercent >= 0 ? '+' : ''}${widget.data.weekComparisonPercent}%',
          'vs Last Week',
          widget.data.weekComparisonPercent >= 0 ? const Color(0xFF6B8E7A) : Colors.red,
          subtitleFontSize: 12,
        ),
        const SizedBox(width: 12),
        _buildStatCard('Avg per Day', animatedAvg.toInt().toString(), Colors.black87),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color valueColor, {double? subtitleFontSize}) {
    return Expanded(
      child: Container(
        height: 90,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (subtitleFontSize != null)
              Text(title, style: TextStyle(fontSize: subtitleFontSize, color: Colors.grey))
            else
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: subtitleFontSize != null ? 16 : 24,
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    final List<Map<String, dynamic>> barData = widget.data.barChart;

    // Tính maxY động từ peak lớn nhất
    double maxPeak = 0;
    for (var item in barData) {
      final peak = (item['peak'] as num?)?.toDouble() ?? 0.0;
      if (peak > maxPeak) maxPeak = peak;
    }
    if (maxPeak == 0) maxPeak = 60; // fallback
    final double maxHeight = 130.0; // chiều cao tối đa của cột

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Peak vs Slow Hours This Week', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Y Axis động
              SizedBox(
                width: 40,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${(maxPeak * 1.0).toInt()}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('${(maxPeak * 0.75).toInt()}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('${(maxPeak * 0.5).toInt()}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    Text('${(maxPeak * 0.25).toInt()}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    const Text('0', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: barData.map((item) {
                    final double peakRaw = (item['peak'] as num?)?.toDouble() ?? 0.0;
                    final double slowRaw = (item['slow'] as num?)?.toDouble() ?? 0.0;

                    final double peak = peakRaw * widget.animationController.value;
                    final double slow = slowRaw * widget.animationController.value;

                    return _buildDualBar(
                      day: item['day'] as String,
                      peak: peak,
                      slow: slow,
                      maxPeak: maxPeak,
                      maxHeight: maxHeight,
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDualBar({
    required String day,
    required double peak,
    required double slow,
    required double maxPeak,
    required double maxHeight,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          height: maxHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Peak bar (đậm)
              Container(
                width: 18,
                height: (peak / maxPeak) * maxHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    colors: [Colors.teal.shade700, Colors.teal.shade400],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 6),
              // Slow bar (nhạt)
              Container(
                width: 18,
                height: (slow / maxPeak) * maxHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    colors: [Colors.teal.shade300, Colors.teal.shade100],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildHeatmap() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Hourly Distribution', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        Row(
          children: [
            const SizedBox(width: 40),
            ...hours.map((h) => Expanded(child: Center(child: Text(h, style: const TextStyle(fontSize: 14, color: Colors.grey))))),
          ],
        ),
        const SizedBox(height: 8),
        ...weekdays.asMap().entries.map((entry) {
          final dayIdx = entry.key;
          final day = entry.value;
          final hourValues = widget.data.heatmap[day.toUpperCase()] ?? List.filled(11, 0.0);

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(width: 40, child: Text(day, style: const TextStyle(fontWeight: FontWeight.w500))),
                Expanded(
                  child: Row(
                    children: List.generate(10, (hourIdx) {
                      final value = (hourValues[hourIdx] ?? 0.0) * widget.animationController.value;
                      final color = _getHeatmapColor(value);
                      final selected = _selectedDay == dayIdx && _selectedHour == hourIdx;

                      return Expanded(
                        child:
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (selected) {
                                _selectedDay = null;
                                _selectedHour = null;
                              } else {
                                _selectedDay = dayIdx;
                                _selectedHour = hourIdx;
                              }
                            });
                          },
                          child: Tooltip(
                            message: selected
                                ? '${day} ${hours[hourIdx]}: ${(hourValues[hourIdx] ?? 0).toInt()} clients'
                                : '',
                            preferBelow: false,
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(color: Colors.white, fontSize: 12),
                            child: Container(
                              height: 60,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(4),
                                border: selected ? Border.all(color: Colors.black, width: 2.5) : null,
                              ),
                              alignment: Alignment.center,
                              child: selected
                                  ? Text(
                                (hourValues[hourIdx] ?? 0).toInt().toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  shadows: [
                                    Shadow(color: Colors.black, blurRadius: 4),
                                  ],
                                ),
                              )
                                  : null,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Color _getHeatmapColor(double value) {
    final ratio = (value / 100).clamp(0.0, 1.0);
    if (ratio < 0.15) return Colors.grey.shade100;
    if (ratio < 0.30) return Colors.teal.shade50;
    if (ratio < 0.45) return Colors.teal.shade100;
    if (ratio < 0.60) return Colors.teal.shade200;
    if (ratio < 0.75) return Colors.teal.shade400;
    if (ratio < 0.90) return Colors.teal.shade600;
    return Colors.teal.shade800;
  }
}