import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/api_service.dart';

enum SortMode { income, bookings }

enum StaffTab { sales, income, bookings, retention }

enum TimeFilter { today, thisWeek, custom }

enum SortOrder { none, ascending, descending }

class StaffPerformanceScreen extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;

  const StaffPerformanceScreen({
    super.key,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<StaffPerformanceScreen> createState() => _StaffPerformanceScreenState();
}

class _StaffPerformanceScreenState extends State<StaffPerformanceScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _animationController;

  SortMode _sortMode = SortMode.income;
  StaffTab _selectedTab = StaffTab.income;

  // Sorting states for headers
  SortOrder _incomeSortOrder = SortOrder.descending;
  SortOrder _bookingsSortOrder = SortOrder.none;
  SortOrder _retentionSortOrder = SortOrder.none;

  late DateTime _localStartDate = widget.startDate;
  late DateTime _localEndDate = widget.endDate;
  TimeFilter _localSelectedFilter = TimeFilter.today;
  String _userRole = 'OWNER';
  bool _datesChanged = false;
  String _titlePeriod = 'This Week';

  List<Map<String, dynamic>> staffList = [];

  // Format number with commas (US standard)
  String _formatCurrency(double amount) {
    final formatter = amount.toStringAsFixed(0);
    final parts = <String>[];
    var value = formatter;

    while (value.length > 3) {
      parts.insert(0, value.substring(value.length - 3));
      value = value.substring(0, value.length - 3);
    }
    parts.insert(0, value);

    return '\$${parts.join(',')}';
  }

  String _formatNumber(int number) {
    final formatter = number.toString();
    final parts = <String>[];
    var value = formatter;

    while (value.length > 3) {
      parts.insert(0, value.substring(value.length - 3));
      value = value.substring(0, value.length - 3);
    }
    parts.insert(0, value);

    return parts.join(',');
  }

  @override
  void initState() {
    super.initState();
    _getUserRole();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
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
    super.dispose();
  }

  // File: lib/view/dashboard_screen/staff_performance_screen.dart
// Update _loadData method

  // Update _loadData method
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.getStaffPerformance(
        startDate: _localStartDate,
        endDate: _localEndDate,
        role: _userRole
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data as List;

        staffList = data.map((item) {
          // Xử lý kiểu dữ liệu an toàn
          double parseDouble(dynamic value) {
            if (value == null) return 0.0;
            if (value is double) return value;
            if (value is int) return value.toDouble();
            if (value is String) return double.tryParse(value) ?? 0.0;
            return 0.0;
          }

          int parseInt(dynamic value) {
            if (value == null) return 0;
            if (value is int) return value;
            if (value is double) return value.toInt();
            if (value is String) return int.tryParse(value) ?? 0;
            return 0;
          }

          return {
            'id': parseInt(item['staffId']),
            'name': item['staffName']?.toString() ?? '',
            'avatar': item['avatar']?.toString(),
            'sales': parseDouble(item['sales']),
            'income': parseDouble(item['totalIncome']),
            'bookings': parseInt(item['totalBookings']),
            'retention': parseDouble(item['retentionRate']),
          };
        }).toList();

        setState(() {
          _isLoading = false;
        });

        _animationController.forward(from: 0.0);
      } else {
        setState(() {
          _isLoading = false;
          staffList = [];
        });

        _showErrorSnackBar(response.message);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        staffList = [];
      });

      _showErrorSnackBar('Error loading staff performance: $e');
    }
  }

// Update sortedStaffList getter với xử lý kiểu an toàn
  List<Map<String, dynamic>> get sortedStaffList {
    List<Map<String, dynamic>> sorted = List.from(staffList);

    // Helper functions để đảm bảo kiểu dữ liệu đúng
    double getIncome(Map<String, dynamic> staff) {
      final value = staff['income'];
      if (value is double) return value;
      if (value is int) return value.toDouble();
      return 0.0;
    }

    int getBookings(Map<String, dynamic> staff) {
      final value = staff['bookings'];
      if (value is int) return value;
      if (value is double) return value.toInt();
      return 0;
    }

    double getRetention(Map<String, dynamic> staff) {
      final value = staff['retention'];
      if (value is double) return value;
      if (value is int) return value.toDouble();
      return 0.0;
    }

    if (_incomeSortOrder != SortOrder.none) {
      sorted.sort((a, b) {
        final aValue = getIncome(a);
        final bValue = getIncome(b);
        return _incomeSortOrder == SortOrder.ascending
            ? aValue.compareTo(bValue)
            : bValue.compareTo(aValue);
      });
    } else if (_bookingsSortOrder != SortOrder.none) {
      sorted.sort((a, b) {
        final aValue = getBookings(a);
        final bValue = getBookings(b);
        return _bookingsSortOrder == SortOrder.ascending
            ? aValue.compareTo(bValue)
            : bValue.compareTo(aValue);
      });
    } else if (_retentionSortOrder != SortOrder.none) {
      sorted.sort((a, b) {
        final aValue = getRetention(a);
        final bValue = getRetention(b);
        return _retentionSortOrder == SortOrder.ascending
            ? aValue.compareTo(bValue)
            : bValue.compareTo(aValue);
      });
    } else {
      // Default sort by income descending
      sorted.sort((a, b) => getIncome(b).compareTo(getIncome(a)));
    }

    return sorted;
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

// Update _buildStaffItem để hiển thị income thay vì sales khi ở income mode
  Widget _buildStaffItem(Map<String, dynamic> staff) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey[300],
            backgroundImage: staff['avatar'] != null && staff['avatar'].isNotEmpty
                ? NetworkImage(staff['avatar'])
                : null,
            child: staff['avatar'] == null || staff['avatar'].isEmpty
                ? Text(
              staff['name'].isNotEmpty ? staff['name'][0] : '?',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            )
                : null,
          ),
          const SizedBox(width: 12),

          // Name
          Expanded(
            flex: 4,
            child: Text(
              staff['name'],
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),

          // Values based on sort mode
          if (_sortMode == SortMode.income) ...[
            // Show Income amount (staff's share)
            Expanded(
              flex: 2,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  final income = staff['income'] * _animationController.value;
                  return Text(
                    _formatCurrency(income),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.teal,
                    ),
                    textAlign: TextAlign.left,
                  );
                },
              ),
            ),
            // Show Retention percentage
            Expanded(
              flex: 2,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  final retention = (staff['retention'] * _animationController.value);
                  return Text(
                    '${retention.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.right,
                  );
                },
              ),
            ),
          ] else ...[
            // Show Bookings count
            Expanded(
              flex: 2,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  final bookings = (staff['bookings'] * _animationController.value).toInt();
                  return Text(
                    _formatNumber(bookings),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.teal,
                    ),
                    textAlign: TextAlign.left,
                  );
                },
              ),
            ),
            // Show Retention percentage
            Expanded(
              flex: 2,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  final retention = (staff['retention'] * _animationController.value);
                  return Text(
                    '${retention.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.right,
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
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

  void _handleHeaderSort(String headerType) {
    setState(() {
      switch (headerType) {
        case 'income':
          if (_incomeSortOrder == SortOrder.none) {
            _incomeSortOrder = SortOrder.descending;
          } else if (_incomeSortOrder == SortOrder.descending) {
            _incomeSortOrder = SortOrder.ascending;
          } else {
            _incomeSortOrder = SortOrder.descending;
          }
          // Reset other sort orders
          _bookingsSortOrder = SortOrder.none;
          _retentionSortOrder = SortOrder.none;
          break;
        case 'bookings':
          if (_bookingsSortOrder == SortOrder.none) {
            _bookingsSortOrder = SortOrder.descending;
          } else if (_bookingsSortOrder == SortOrder.descending) {
            _bookingsSortOrder = SortOrder.ascending;
          } else {
            _bookingsSortOrder = SortOrder.descending;
          }
          // Reset other sort orders
          _incomeSortOrder = SortOrder.none;
          _retentionSortOrder = SortOrder.none;
          break;
        case 'retention':
          if (_retentionSortOrder == SortOrder.none) {
            _retentionSortOrder = SortOrder.descending;
          } else if (_retentionSortOrder == SortOrder.descending) {
            _retentionSortOrder = SortOrder.ascending;
          } else {
            _retentionSortOrder = SortOrder.descending;
          }
          // Reset other sort orders
          _incomeSortOrder = SortOrder.none;
          _bookingsSortOrder = SortOrder.none;
          break;
      }
    });
  }

  Widget _buildSortIcon(SortOrder order) {
    if (order == SortOrder.none) {
      return const Icon(Icons.unfold_more, size: 14, color: Colors.grey);
    } else if (order == SortOrder.ascending) {
      return const Icon(Icons.arrow_upward, size: 14, color: Colors.black87);
    } else {
      return const Icon(Icons.arrow_downward, size: 14, color: Colors.black87);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
            if (_datesChanged) {
              Navigator.pop(context, DateTimeRange(start: _localStartDate, end: _localEndDate));
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          'Staff Performance $_titlePeriod',
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

          // Filter Section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                // Filter by label
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Filter By', // Changed from Sort by to Filter By
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Income button - full width
                Expanded(
                  child: _buildFilterChip(
                    label: 'Income',
                    isSelected: _sortMode == SortMode.income,
                    onTap: () async {
                      if (_sortMode != SortMode.income) {
                        setState(() {
                          _isLoading = true;
                          _sortMode = SortMode.income;
                          _selectedTab = StaffTab.income;
                          // Reset sort orders when switching mode
                          _incomeSortOrder = SortOrder.descending;
                          _bookingsSortOrder = SortOrder.none;
                          _retentionSortOrder = SortOrder.none;
                        });

                        // Reset animation
                        _animationController.reset();

                        // Simulate loading
                        await Future.delayed(const Duration(milliseconds: 300));

                        setState(() => _isLoading = false);

                        // Replay animation
                        _animationController.forward(from: 0.0);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Bookings button - full width
                Expanded(
                  child: _buildFilterChip(
                    label: 'Bookings',
                    isSelected: _sortMode == SortMode.bookings,
                    onTap: () async {
                      if (_sortMode != SortMode.bookings) {
                        setState(() {
                          _isLoading = true;
                          _sortMode = SortMode.bookings;
                          _selectedTab = StaffTab.bookings;
                          // Reset sort orders when switching mode
                          _incomeSortOrder = SortOrder.none;
                          _bookingsSortOrder = SortOrder.descending;
                          _retentionSortOrder = SortOrder.none;
                        });

                        // Reset animation
                        _animationController.reset();

                        // Simulate loading
                        await Future.delayed(const Duration(milliseconds: 300));

                        setState(() => _isLoading = false);

                        // Replay animation
                        _animationController.forward(from: 0.0);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // Table Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                // Staff name column
                const Expanded(
                  flex: 4,
                  child: Text(
                    'Staff name',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),

                // Income/Bookings header with sort
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: () => _handleHeaderSort(_sortMode == SortMode.income ? 'income' : 'bookings'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _sortMode == SortMode.income ? 'Income' : 'Bookings',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 4),
                        _buildSortIcon(_sortMode == SortMode.income ? _incomeSortOrder : _bookingsSortOrder),
                      ],
                    ),
                  ),
                ),

                // Retention header with sort
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: () => _handleHeaderSort('retention'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text(
                          'Retention',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 4),
                        _buildSortIcon(_retentionSortOrder),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Divider below header
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.grey[200],
          ),

          // Staff List or Shimmer Loading
          Expanded(
            child: Container(
              color: Colors.white,
              child: _isLoading
                  ? _buildShimmerLoading()
                  : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: sortedStaffList.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.grey[100],
                  indent: 80,
                ),
                itemBuilder: (context, index) {
                  final staff = sortedStaffList[index];
                  return _buildStaffItem(staff);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 10,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        thickness: 1,
        color: Colors.grey[100],
        indent: 80,
      ),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              // Avatar shimmer
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),

              // Name shimmer only (no role)
              Expanded(
                flex: 4,
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

              // Value shimmer
              Expanded(
                flex: 2,
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

              // Retention shimmer
              Expanded(
                flex: 2,
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}