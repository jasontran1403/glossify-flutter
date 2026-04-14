import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hair_sallon/api/api_service.dart';
import 'package:hair_sallon/view/receptionist_screen/pax_device_bysdk_screen.dart';
import 'package:hair_sallon/view/receptionist_screen/schedule_management/booking_state.dart';
import 'package:hair_sallon/view/receptionist_screen/schedule_management/booking_grid.dart';
import 'package:hair_sallon/view/receptionist_screen/task_model.dart';
import 'payment_detail_panel.dart';
import 'pax_device_screen.dart';

class PaymentScreen extends StatefulWidget {
  final int? storeId;

  const PaymentScreen({
    super.key,
    this.storeId,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late BookingState scheduleState;
  bool _isInitialized = false;

  int? _storeId;
  bool _isLoadingStoreId = false;
  String? _storeIdError;

  Task? _selectedTask;

  // ===== AUTO REFRESH =====
  Timer? _autoRefreshTimer;
  static const Duration _autoRefreshInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _initializeStoreId();
  }

  Future<void> _initializeStoreId() async {
    if (widget.storeId != null) {
      setState(() {
        _storeId = widget.storeId;
      });
      _initializeAfterStoreId();
    } else {
      await _fetchWorkingStoreId();
    }
  }

  Future<void> _fetchWorkingStoreId() async {
    setState(() {
      _isLoadingStoreId = true;
      _storeIdError = null;
    });

    try {
      final storeId = await ApiService.getWorkingStoreId();

      if (storeId != null) {
        setState(() {
          _storeId = storeId;
          _isLoadingStoreId = false;
        });
        _initializeAfterStoreId();
      } else {
        setState(() {
          _isLoadingStoreId = false;
          _storeIdError = 'Unable to get working store. Please check your account.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingStoreId = false;
        _storeIdError = 'Error: $e';
      });
    }
  }

  void _initializeAfterStoreId() {
    if (_storeId == null || _isInitialized) return;

    print('✅ PaymentScreen: Initializing with storeId: $_storeId');

    scheduleState = BookingState(
      storeId: _storeId!,
      onStateChanged: () {
        if (mounted) {
          setState(() {});
        }
      },
    );

    scheduleState.initialize();
    scheduleState.fetchSchedule();

    // ⭐ START AUTO-REFRESH WITH INCREMENTAL FETCH
    _startAutoRefresh();

    setState(() {
      _isInitialized = true;
    });
  }

  // ⭐ AUTO-REFRESH WITH DETAILED LOGGING
  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();

    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // ⭐ LOG BEFORE FETCH
      final beforeWaitingPayment = scheduleState.tasks
          .where((t) => t.status == 'WAITING_PAYMENT')
          .toList();


      // ⭐ KEY: Dùng fetchScheduleIncremental() - tự động handle fade in/out
      scheduleState.fetchScheduleIncremental().then((_) {
        // ⭐ LOG AFTER FETCH
        final afterWaitingPayment = scheduleState.tasks
            .where((t) => t.status == 'WAITING_PAYMENT')
            .toList();

        // ⭐ DETECT CHANGES
        final beforeIds = beforeWaitingPayment.map((t) => t.bookingId).toSet();
        final afterIds = afterWaitingPayment.map((t) => t.bookingId).toSet();

        final addedIds = afterIds.difference(beforeIds);
        final removedIds = beforeIds.difference(afterIds);
      });
    });
  }

  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    if (_isInitialized) {
      scheduleState.dispose();
    }
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    await scheduleState.fetchSchedule();
  }

  void _handleCardTap(Task task) {
    if (!mounted) return;

    setState(() {
      _selectedTask = task;
    });
  }

  void _closeDetailPanel() {
    if (!mounted) return;

    setState(() {
      _selectedTask = null;
    });
  }

  // ⭐ Navigate to PAX Device Screen
  Future<void> _navigateToPaxDevice() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PaxPaymentManagementScreen(),
      ),
    );

    // Handle payment result if returned
    if (result != null && mounted) {
      // You can process the payment result here if needed
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment completed successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // Refresh the schedule
      await _handleRefresh();
    }
  }

  // ⭐ Get filtered events by staff for WAITING_PAYMENT only
  Map<int, List<Task>> _getFilteredEventsByStaffId() {
    Map<int, List<Task>> filteredEventsByStaffId = {};

    scheduleState.eventsByStaffId.forEach((staffId, tasks) {
      final filtered = tasks.where((task) => task.status == 'WAITING_PAYMENT').toList();

      if (filtered.isNotEmpty) {
        filteredEventsByStaffId[staffId] = filtered;
      }
    });

    return filteredEventsByStaffId;
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.payment,
                size: 64,
                color: Colors.purple.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No pending payments',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pull down to refresh',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ⭐ LOADING STATE
    if (_isLoadingStoreId) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.purple),
              const SizedBox(height: 24),
              Text(
                'Loading store information...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ⭐ ERROR STATE
    if (_storeIdError != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: Colors.red,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red[400],
                ),
                const SizedBox(height: 24),
                Text(
                  _storeIdError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _fetchWorkingStoreId,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ⭐ MAIN BUILD
    if (_storeId == null || !_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.purple),
        ),
      );
    }

    final rightPadding = _selectedTask != null ? 440.0 : 0.0;
    final filteredEventsByStaffId = _getFilteredEventsByStaffId();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ===== MAIN CONTENT =====
          GestureDetector(
            onTap: () {
              if (_selectedTask != null) {
                _closeDetailPanel();
              }
            },
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: EdgeInsets.only(right: rightPadding),
              child: Column(
                children: [
                  // ===== HEADER =====
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE5E7EB), width: 2),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.payment,
                              color: Colors.purple,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Payment Processing',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  '${scheduleState.tasks.where((t) => t.status == 'WAITING_PAYMENT').length} pending payment(s)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          // ⭐ CHECK MOBILE PAYMENT BUTTON
                          ElevatedButton.icon(
                            onPressed: _navigateToPaxDevice,
                            icon: const Icon(Icons.credit_card, size: 20),
                            label: const Text('Connect to PAX'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ===== CONTENT =====
                  Expanded(
                    child: filteredEventsByStaffId.isEmpty
                        ? RefreshIndicator(
                      onRefresh: _handleRefresh,
                      color: Colors.purple,
                      child: _buildEmptyState(),
                    )
                        : RefreshIndicator(
                      onRefresh: _handleRefresh,
                      color: Colors.purple,
                      child: BookingGrid(
                        scheduleState: scheduleState,
                        onCardTap: _handleCardTap,
                        onStaffDropOnCard: (staff, task) {},
                        showStaffSheet: false,
                        showDetailPanel: _selectedTask != null,
                        selectedDate: scheduleState.selectedDate,
                        filteredEventsByStaffId: filteredEventsByStaffId,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ===== OVERLAY WHEN PANEL OPEN =====
          if (_selectedTask != null)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeDetailPanel,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  color: Colors.black.withOpacity(0.3),
                ),
              ),
            ),

          // ===== PAYMENT DETAIL PANEL =====
          if (_selectedTask != null)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () {},
                child: PaymentDetailPanel(
                  task: _selectedTask!,
                  scheduleState: scheduleState,
                  onClose: _closeDetailPanel,
                  onPaymentSuccess: () {
                    scheduleState.fetchSchedule();
                    _closeDetailPanel();
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}