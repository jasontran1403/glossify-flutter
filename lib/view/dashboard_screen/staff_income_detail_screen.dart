import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

import '../../api/api_response_model.dart';
import '../../api/api_service.dart';

enum TimeFilter { today, thisWeek, custom }

class StaffIncomeDetailScreen extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;

  const StaffIncomeDetailScreen({
    super.key,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<StaffIncomeDetailScreen> createState() =>
      _StaffIncomeDetailScreenState();
}

class _StaffIncomeDetailScreenState extends State<StaffIncomeDetailScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedStaffId;
  bool _isLoading = false;
  bool _isLoadingDetail = false;
  bool _datesChanged = false;
  late AnimationController _animationController;
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _staffList = [];
  Map<String, dynamic>? _selectedStaffDetail;

  late DateTime _localStartDate;
  late DateTime _localEndDate;
  TimeFilter _localSelectedFilter = TimeFilter.today;
  String _userRole = 'OWNER';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _localStartDate = DateTime.now();
    _localEndDate = DateTime.now();
    _datesChanged = false;

    _initData();
  }

  Future<void> _initData() async {
    await _getUserRole();
    if (!mounted) return;
    await _loadStaffList();
  }

  Future<void> _getUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      final role = prefs.getString('role') ?? 'OWNER';
      setState(() {
        _userRole = role;
      });

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
    final weekStartDate = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    );
    final weekEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    if (_localStartDate == weekStartDate && _localEndDate == weekEnd) {
      _localSelectedFilter = TimeFilter.thisWeek;
      return;
    }
    _localSelectedFilter = TimeFilter.custom;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadStaffList() async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.getStaffIncomeList(
        startDate: _localStartDate,
        endDate: _localEndDate,
      );

      if (response.isSuccess && response.data != null) {
        // ✅ Filter out "Anyone" staff
        final allStaff = (response.data as List)
            .map((item) => Map<String, dynamic>.from(item))
            .toList();

        final filteredStaff = allStaff.where((staff) {
          final name = (staff['fullName'] ?? staff['name'] ?? '').toString().trim().toLowerCase();
          return name != 'anyone';
        }).toList();

        setState(() {
          _staffList = filteredStaff;
          _isLoading = false;

          if (_staffList.isNotEmpty) {
            if (_selectedStaffId == null ||
                !_staffList.any((s) => s['id'] == _selectedStaffId)) {
              _selectedStaffId = _staffList[0]['id'].toString();
            }
            _loadStaffDetail(_selectedStaffId!);
          }
        });
      } else {
        setState(() => _isLoading = false);
        _showErrorSnackBar(response.message);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Error loading staff list: $e');
    }
  }

  Future<void> _loadStaffDetail(String staffId) async {
    setState(() => _isLoadingDetail = true);

    try {
      final response = await ApiService.getStaffIncomeDetail(
        staffId: staffId,
        startDate: _localStartDate,
        endDate: _localEndDate,
        role: _userRole,
      );

      if (response.isSuccess && response.data != null) {
        setState(() {
          _selectedStaffDetail = Map<String, dynamic>.from(response.data);
          _isLoadingDetail = false;
        });

        _animationController.forward(from: 0.0);
      } else {
        setState(() => _isLoadingDetail = false);
        _showErrorSnackBar(response.message);
      }
    } catch (e) {
      setState(() => _isLoadingDetail = false);
      _showErrorSnackBar('Error loading staff detail: $e');
    }
  }

  // ===== CLICK VÀO BOOKING ID - HIỂN THỊ DIALOG GIỮA MÀN HÌNH =====
  Future<void> _showBookingDetailDialog(String bookingId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.teal),
      ),
    );

    try {
      final response = await ApiService.getBookingIncomeDetail(
        staffId: _selectedStaffId!,
        bookingId: bookingId,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (response.isSuccess && response.data != null) {
        final data = Map<String, dynamic>.from(response.data);
        _showBookingDetailCenterDialog(data);
      } else {
        _showErrorSnackBar(response.message);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      _showErrorSnackBar('Error loading booking detail: $e');
    }
  }

  // ===== HIỂN THỊ DIALOG Ở GIỮA MÀN HÌNH =====
  void _showBookingDetailCenterDialog(Map<String, dynamic> data) {
    final services = (data['services'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final tipAmount = data['tipAmount'] ?? 0.0;
    final totalServicePrice = data['totalServicePrice'] ?? 0.0;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Booking #${data['bookingId']}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${data['customerName']} • ${data['bookingDate']}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 20),

              // Services
              const Text(
                'Services',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: services.map((service) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              service['serviceName'] ?? '',
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                          Text(
                            _formatCurrency(service['finalPrice'] ?? 0.0),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
              ),

              const Divider(height: 24),

              // Summary
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Service Total',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _formatCurrency(totalServicePrice),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tip (proportional)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _formatCurrency(tipAmount),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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

  void _selectStaff(String staffId) {
    setState(() {
      _selectedStaffId = staffId;
    });
    _loadStaffDetail(staffId);
  }

  List<Map<String, dynamic>> get _filteredStaffList {
    if (_searchQuery.isEmpty) return _staffList;
    return _staffList
        .where((staff) => staff['name']
        .toString()
        .toLowerCase()
        .contains(_searchQuery.toLowerCase()))
        .toList();
  }

  String get _selectedStaffName {
    if (_selectedStaffId == null) return '';
    final staff = _staffList.firstWhere(
          (s) => s['id'] == _selectedStaffId,
      orElse: () => {'name': ''},
    );
    return staff['name'] ?? '';
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
        _localStartDate = DateTime(
          _localStartDate.year,
          _localStartDate.month,
          _localStartDate.day,
        );
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
      initialDateRange: DateTimeRange(
        start: _localStartDate,
        end: _localEndDate,
      ),
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
      _loadStaffList();
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
        _loadStaffList();
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

  void _showStaffSelectionBottomSheet() {
    _searchController.clear();
    _searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'Select Staff',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search staff...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setModalState(() => _searchQuery = '');
                        },
                      )
                          : null,
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) {
                      setModalState(() => _searchQuery = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _filteredStaffList.isEmpty
                        ? const Center(
                      child: Text(
                        'No staff found',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                        : ListView.builder(
                      itemCount: _filteredStaffList.length,
                      itemBuilder: (context, index) {
                        final staff = _filteredStaffList[index];
                        final isSelected = staff['id'] == _selectedStaffId;

                        return ListTile(
                          leading: _buildStaffAvatar(staff),
                          title: Text(staff['name']),
                          trailing: Text(
                            '\$${staff['totalIncome'].toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          selected: isSelected,
                          selectedTileColor: Colors.grey.shade100,
                          onTap: () {
                            _selectStaff(staff['id']);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatCurrency(double value) {
    final format = NumberFormat.currency(
      locale: 'en_US',
      symbol: '\$',
      decimalDigits: 2,
    );
    return format.format(value);
  }

  Widget _buildAnimatedCurrency(double targetValue, {bool isBold = false}) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final animated = targetValue * _animationController.value;
        final formatted = _formatCurrency(animated);
        return Text(
          formatted,
          style: TextStyle(
            fontSize: 17,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: Colors.black87,
          ),
        );
      },
    );
  }

  Widget _buildAnimatedInt(int targetValue) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final animated = (targetValue * _animationController.value).toInt();
        return Text(
          animated.toString(),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w400,
            color: Colors.black87,
          ),
        );
      },
    );
  }

  Widget _buildAnimatedAvgTip(double targetValue) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final animated = targetValue * _animationController.value;
        final formatted = '\$${animated.toStringAsFixed(1)}';
        return Text(
          formatted,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w400,
            color: Colors.black87,
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
      String label,
      double targetValue, {
        bool isBold = false,
      }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 17,
            color: Colors.black87,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        _buildAnimatedCurrency(targetValue, isBold: isBold),
      ],
    );
  }

  Widget _buildSimpleStatRow(String label, Widget valueWidget) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 17,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w400,
            ),
          ),
          valueWidget,
        ],
      ),
    );
  }

  Widget _buildDetailShimmer() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(width: 200, height: 24, color: Colors.white),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ...List.generate(
              10,
                  (index) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(width: 150, height: 16, color: Colors.white),
                      Container(width: 100, height: 16, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffAvatar(Map<String, dynamic> staff) {
    final hasAvatar = staff['avt'] != null && staff['avt'].toString().isNotEmpty;
    final avatarUrl = staff['avt']?.toString() ?? '';
    final staffName = staff['name']?.toString() ?? '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: hasAvatar
          ? CachedNetworkImage(
        imageUrl: avatarUrl,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildStaffPlaceholderAvatar(staffName),
        errorWidget: (context, url, error) =>
            _buildStaffPlaceholderAvatar(staffName),
      )
          : _buildStaffPlaceholderAvatar(staffName),
    );
  }

  Widget _buildStaffPlaceholderAvatar(String name) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0] : '?',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final hasAvatar = _selectedStaffDetail!['avatar'] != null &&
        _selectedStaffDetail!['avatar'].toString().isNotEmpty;
    final avatarUrl = _selectedStaffDetail!['avatar']?.toString() ?? '';
    final staffName = _selectedStaffDetail!['name']?.toString() ?? '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: hasAvatar
          ? CachedNetworkImage(
        imageUrl: avatarUrl,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildPlaceholderAvatar(staffName),
        errorWidget: (context, url, error) =>
            _buildPlaceholderAvatar(staffName),
      )
          : _buildPlaceholderAvatar(staffName),
    );
  }

  Widget _buildPlaceholderAvatar(String name) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.teal.shade100,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0] : '?',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.teal.shade700,
          ),
        ),
      ),
    );
  }

  // ===== BUILD BOOKINGS TABLE - CẬP NHẬT PHẦN HIỂN THỊ SERVICES =====
  Widget _buildBookingsTable() {
    final bookings = (_selectedStaffDetail!['bookings'] as List?)
        ?.cast<Map<String, dynamic>>() ??
        [];

    if (bookings.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const Text(
          'No bookings found',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
          ),
          child: Row(
            children: const [
              Expanded(
                flex: 2,
                child: Text(
                  'Booking ID',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Services',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Price',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Tips',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Table Rows với HEIGHT CỐ ĐỊNH = 200px
        Container(
          height: 200, // ⭐ Giảm xuống 200px
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
          ),
          child: Scrollbar(
            thumbVisibility: bookings.length > 4,
            child: ListView.builder(
              itemCount: bookings.length,
              itemBuilder: (context, index) {
                final booking = bookings[index];
                final bookingId = booking['bookingId'].toString();
                final serviceNames =
                    (booking['serviceNames'] as List?)?.cast<String>() ?? [];
                final serviceTotal = booking['serviceTotal'] ?? 0.0;
                final tipAmount = booking['tipAmount'] ?? 0.0;

                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: index < bookings.length - 1
                          ? BorderSide(color: Colors.grey.shade200, width: 0.5)
                          : BorderSide.none,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Booking ID (clickable)
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: () => _showBookingDetailDialog(bookingId),
                          child: Text(
                            'Booking ID#$bookingId',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),

                      // ⭐ Services - MỖI SERVICE 1 DÒNG, TỐI ĐA 10 KÝ TỰ
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: serviceNames.map((serviceName) {
                            // Truncate nếu > 10 ký tự
                            final displayName = serviceName.length > 14
                                ? '${serviceName.substring(0, 14)}...'
                                : serviceName;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                displayName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.2,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      // Price
                      Expanded(
                        flex: 2,
                        child: Text(
                          _formatCurrency(serviceTotal),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),

                      // Tips
                      Expanded(
                        flex: 2,
                        child: Text(
                          _formatCurrency(tipAmount),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

// ===== THÊM 2 NÚT: COMMISSION STRUCTURE VÀ TẢI =====
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          // Commission Structure Button
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                // TODO: Show commission structure dialog
                _showCommissionStructureDialog();
              },
              label: const Text(
                'Commission Structure',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.teal,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: Colors.teal, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Download Button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                // TODO: Download functionality
                _showDownloadDialog();
              },
              label: const Text(
                'Download',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

// ===== DIALOG COMMISSION STRUCTURE =====
  void _showCommissionStructureDialog() {
    final detail = _selectedStaffDetail;
    if (detail == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Commission Structure',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildCommissionRow(
                'Service Commission',
                '${detail['commissionServiceRate']?.toStringAsFixed(1) ?? '0.0'}%',
              ),
              const Divider(height: 24),
              _buildCommissionRow(
                'Product Commission',
                '${detail['commissionProductRate']?.toStringAsFixed(1) ?? '0.0'}%',
              ),
              const Divider(height: 24),
              _buildCommissionRow(
                'Gift Card Commission',
                '${detail['commissionGiftcardRate']?.toStringAsFixed(1) ?? '0.0'}%',
              ),
              const Divider(height: 24),
              _buildCommissionRow(
                'Cash/Check Percentage',
                '${detail['cashCheckPercentage']?.toStringAsFixed(1) ?? '0.0'}%',
              ),
              const Divider(height: 24),
              _buildCommissionRow(
                'Credit Card Tip Charge',
                '${detail['percentageChargeForCreditCardTips']?.toStringAsFixed(1) ?? '0.0'}%',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommissionRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.teal,
          ),
        ),
      ],
    );
  }


  // ===== DIALOG TẢI - ĐƠN GIẢN =====
  void _showDownloadDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: const [
            Icon(Icons.download, color: Colors.teal, size: 24),
            SizedBox(width: 8),
            Text(
              'Export Payroll',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          'Export staff income report to Telegram?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _handleDownloadPayroll();
            },
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Export'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

// ===== HANDLE DOWNLOAD - ĐƠN GIẢN =====
  Future<void> _handleDownloadPayroll() async {
    if (_selectedStaffId == null) {
      _showToast('No staff selected', isSuccess: false);
      return;
    }

    // Show loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: const Center(
          child: Card(
            margin: EdgeInsets.symmetric(horizontal: 40),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      color: Colors.teal,
                      strokeWidth: 3,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Exporting payroll...',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Please wait',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final response = await ApiService.downloadPayroll(
        staffId: _selectedStaffId!,
        startDate: _localStartDate,
        endDate: _localEndDate,
        role: _userRole,
      );

      if (!mounted) return;

      Navigator.pop(context); // Close loading

      await Future.delayed(const Duration(milliseconds: 100));

      if (response.isSuccess) {
        _showToast(response.message ?? "Xuất bảng lương thành công", isSuccess: true);
      } else {
        _showToast(response.message ?? "Xuất bảng lương thất bại", isSuccess: false);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      await Future.delayed(const Duration(milliseconds: 100));
      _showToast('Export payroll failed: $e', isSuccess: false);
    }
  }

// ===== TOAST HELPER =====
  void _showToast(String message, {required bool isSuccess}) {
    if (!mounted) return;

    final screenHeight = MediaQuery.of(context).size.height;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess ? Colors.green.shade600 : Colors.red.shade600,
        duration: Duration(seconds: isSuccess ? 3 : 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        // Đưa lên top: bottom ≈ screenHeight - 100 (cách top ~80-100px)
        margin: EdgeInsets.only(
          bottom: screenHeight - 120,   // Điều chỉnh số này để lên cao/thấp hơn
          left: 16,
          right: 16,
        ),
        elevation: 6,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

// ===== CẬP NHẬT BUILD METHOD - THÊM 2 NÚT SAU BOOKINGS TABLE =====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.blue, size: 20),
          onPressed: () {
            if (_datesChanged) {
              Navigator.pop(
                context,
                DateTimeRange(start: _localStartDate, end: _localEndDate),
              );
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          'Staff Income Detail',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Date filter row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: Color(0xFF9E9E9E),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: GestureDetector(
                    onTap: _userRole == 'SUPER_OWNER' ? _selectCustomDateRange : null,
                    child: Text(
                      _getDateRangeText(),
                      style: const TextStyle(
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

          // Content
          Expanded(
            child: (_isLoadingDetail || _isLoading)
                ? _buildDetailShimmer()
                : _selectedStaffDetail == null
                ? const Center(
              child: CircularProgressIndicator(color: Colors.teal),
            )
                : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar and name
                    Row(
                      children: [
                        _buildAvatar(),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GestureDetector(
                            onTap: _showStaffSelectionBottomSheet,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedStaffDetail!['name'],
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tap to select another staff',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ===== BOOKINGS TABLE =====
                    _buildBookingsTable(),

                    // ⭐ 2 NÚT MỚI: COMMISSION STRUCTURE & TẢI
                    _buildActionButtons(),

                    const Divider(height: 24, thickness: 2),

                    // ===== FINANCIAL DETAILS =====
                    _buildDetailRow(
                      'Income',
                      _selectedStaffDetail!['income'] ?? 0.0,
                    ),
                    Divider(height: 24, color: Colors.grey.shade200),
                    _buildDetailRow(
                      'Supply Share',
                      -(_selectedStaffDetail!['supplyShare'] ?? 0.0),
                    ),
                    Divider(height: 24, color: Colors.grey.shade200),
                    _buildDetailRow(
                      'Commission',
                      _selectedStaffDetail!['commission'] ?? 0.0,
                    ),
                    Divider(height: 24, color: Colors.grey.shade200),
                    _buildDetailRow(
                      'Card Charge',
                      -(_selectedStaffDetail!['cardCharge'] ?? 0.0),
                    ),
                    Divider(height: 24, color: Colors.grey.shade200),
                    _buildDetailRow(
                      'Cash Discount Charge',
                      0.0,
                    ),
                    Divider(height: 24, color: Colors.grey.shade200),
                    _buildDetailRow(
                      'Discount Charge',
                      -(_selectedStaffDetail!['discountCharge'] ?? 0.0),
                    ),

                    const Divider(height: 32, thickness: 1),

                    _buildDetailRow(
                      'Tip by card (1)',
                      _selectedStaffDetail!['tipByCard'] ?? 0.0,
                    ),
                    Divider(height: 24, color: Colors.grey.shade200),
                    _buildDetailRow(
                      'Tip charge by card (2)',
                      -(_selectedStaffDetail!['tipChargeByCard'] ?? 0.0),
                    ),
                    Divider(height: 24, color: Colors.grey.shade200),
                    _buildDetailRow(
                      'Tip by cash (3)',
                      _selectedStaffDetail!['tipByCash'] ?? 0.0,
                    ),
                    Divider(height: 24, color: Colors.grey.shade200),
                    _buildDetailRow(
                      'Total tip (1-2+3)',
                      _selectedStaffDetail!['totalTip'] ?? 0.0,
                      isBold: true,
                    ),

                    const Divider(height: 32, thickness: 1),

                    _buildDetailRow(
                      'Cash Income:',
                      _selectedStaffDetail!['cashIncome'] ?? 0.0,
                    ),
                    Divider(height: 24, color: Colors.grey.shade200),
                    _buildDetailRow(
                      'Check Income:',
                      _selectedStaffDetail!['checkIncome'] ?? 0.0,
                    ),

                    const Divider(height: 32, thickness: 2),

                    // Total
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          _formatCurrency(_selectedStaffDetail!['total'] ?? 0.0),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Chart
                    if (_selectedStaffDetail!['dailyRevenue'] != null &&
                        (_selectedStaffDetail!['dailyRevenue'] as List)
                            .isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Daily Revenue (Last 7 Days)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 250,
                            child: _buildRevenueChart(),
                          ),
                        ],
                      ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart() {
    if (_selectedStaffDetail == null) return const SizedBox();

    final data = _selectedStaffDetail!['dailyRevenue'] as List;

    double maxY = 0;
    for (var item in data) {
      final amount = item['amount'] as double;
      if (amount > maxY) maxY = amount;
    }

    double niceMaxY = ((maxY * 1.1) / 100).ceil() * 100;
    double interval = 100;

    if (niceMaxY <= 500) {
      interval = 50;
    }
    if (niceMaxY <= 200) {
      interval = 25;
    }
    if (niceMaxY <= 100) {
      interval = 10;
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: niceMaxY,
            minY: 0,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                tooltipBgColor: Colors.teal.withOpacity(0.9),
                tooltipRoundedRadius: 8,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final day = data[groupIndex]['day'];
                  final amount = data[groupIndex]['amount'];
                  return BarTooltipItem(
                    '$day\n\$${amount.toStringAsFixed(0)}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= data.length) return const Text('');
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        data[index]['day'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  },
                  reservedSize: 30,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: interval,
                  reservedSize: 45,
                  getTitlesWidget: (value, meta) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '\$${value.toInt()}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    );
                  },
                ),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              drawHorizontalLine: true,
              horizontalInterval: interval,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: value == 0 ? Colors.grey.shade400 : Colors.grey.shade300,
                  strokeWidth: 1,
                  dashArray: value == 0 ? null : [4, 4],
                );
              },
            ),
            borderData: FlBorderData(
              show: true,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade400, width: 1),
                left: BorderSide(color: Colors.grey.shade400, width: 1),
              ),
            ),
            barGroups: data.asMap().entries.map((entry) {
              final amount =
                  (entry.value['amount'] as double) * _animationController.value;
              return BarChartGroupData(
                x: entry.key,
                barRods: [
                  BarChartRodData(
                    toY: amount,
                    color: Colors.blue.shade400,
                    width: 28,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }
}