import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../api/api_service.dart';
import '../../api/day_off_model.dart';
import '../../utils/app_colors/app_colors.dart';

// ========================================
// ✅ MAIN SCREEN - DayOffScreen with Tabs
// ========================================
class DayOffScreen extends StatefulWidget {
  const DayOffScreen({super.key});

  @override
  State<DayOffScreen> createState() => _DayOffScreenState();
}

class _DayOffScreenState extends State<DayOffScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Day Off Management'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'My Requests'),
            Tab(icon: Icon(Icons.add_circle_outline), text: 'New Request'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          MyRequestsTab(onRequestCreated: () => _tabController.animateTo(0)),
          NewRequestTab(
            onRequestCreated: () {
              _tabController.animateTo(0);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }
}

// ========================================
// ✅ TAB 1: My Requests (same as before)
// ========================================
class MyRequestsTab extends StatefulWidget {
  final VoidCallback onRequestCreated;
  const MyRequestsTab({super.key, required this.onRequestCreated});

  @override
  State<MyRequestsTab> createState() => _MyRequestsTabState();
}

class _MyRequestsTabState extends State<MyRequestsTab> {
  List<DayOffModel> dayOffs = [];
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDayOffs();
  }

  Future<void> _loadDayOffs() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await ApiService.getMyDayOffs();
      setState(() {
        dayOffs = result;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading day-offs: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _cancelDayOff(int dayOffId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Day-Off'),
        content: const Text('Are you sure you want to cancel this day-off request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await ApiService.cancelDayOff(dayOffId);
      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']), backgroundColor: Colors.green),
        );
        _loadDayOffs();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadDayOffs, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (dayOffs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No day-off requests yet', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('Tap "New Request" tab to create one', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDayOffs,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: dayOffs.length,
        itemBuilder: (context, index) => _buildDayOffCard(dayOffs[index]),
      ),
    );
  }

  Widget _buildDayOffCard(DayOffModel dayOff) {
    final statusColor = dayOff.getStatusColor();
    final canCancel = dayOff.status == 'PENDING' || dayOff.status == 'ACTIVE';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.3), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Text(
                    dayOff.status,
                    style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                // ✅ Cancel button only shows for PENDING or ACTIVE
                if (canCancel)
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    onPressed: () => _cancelDayOff(dayOff.id),
                    tooltip: 'Cancel request',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(dayOff.isFullDay ? Icons.event_busy : Icons.access_time, size: 20, color: Colors.grey[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dayOff.isFullDay ? 'Full Day Off' : dayOff.timeRangeString,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.repeat, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dayOff.recurrenceDescription,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
            if (dayOff.staffNote != null && dayOff.staffNote!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your Note:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue[900])),
                    const SizedBox(height: 4),
                    Text(dayOff.staffNote!, style: TextStyle(fontSize: 14, color: Colors.blue[800])),
                  ],
                ),
              ),
            ],
            if (dayOff.adminNote != null && dayOff.adminNote!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Admin Note:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange[900])),
                    const SizedBox(height: 4),
                    Text(dayOff.adminNote!, style: TextStyle(fontSize: 14, color: Colors.orange[800])),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text('Requested: ${_formatDate(dayOff.createdAt)}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return DateFormat('MMM dd, yyyy').format(date);
  }
}

// ========================================
// ✅ TAB 2: New Request (WITH DATE_RANGE)
// ========================================
class NewRequestTab extends StatefulWidget {
  final VoidCallback onRequestCreated;
  const NewRequestTab({super.key, required this.onRequestCreated});

  @override
  State<NewRequestTab> createState() => _NewRequestTabState();
}

class _NewRequestTabState extends State<NewRequestTab> {
  String dayOffType = 'FULL_DAY';
  String recurrenceType = 'ONCE';
  DateTime? selectedDate;
  DateTime? startDate;  // ✅ NEW for DATE_RANGE
  DateTime? endDate;    // ✅ NEW for DATE_RANGE
  int? selectedDayOfWeek;
  int? selectedDayOfMonth;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  final TextEditingController _noteController = TextEditingController();
  bool isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Day-Off Type'),
          _buildDayOffTypeSelector(),
          const SizedBox(height: 24),
          if (dayOffType == 'PARTIAL_DAY') ...[
            _buildSectionTitle('Time Range'),
            _buildTimeRangeSelector(),
            const SizedBox(height: 24),
          ],
          _buildSectionTitle('Recurrence'),
          _buildRecurrenceTypeSelector(),
          const SizedBox(height: 24),
          _buildRecurrenceOptions(),
          const SizedBox(height: 24),
          _buildSectionTitle('Reason (Optional)'),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Enter reason for day off...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _canSubmit() ? _submitRequest : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Submit Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDayOffTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildRadioOption(
            title: 'Full Day',
            subtitle: 'Entire day off',
            value: 'FULL_DAY',
            groupValue: dayOffType,
            onChanged: (val) => setState(() {
              dayOffType = val!;
              startTime = null;
              endTime = null;
            }),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildRadioOption(
            title: 'Partial Day',
            subtitle: 'Specific hours',
            value: 'PARTIAL_DAY',
            groupValue: dayOffType,
            onChanged: (val) => setState(() => dayOffType = val!),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeRangeSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildTimePickerField(
            label: 'Start Time',
            time: startTime,
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: startTime ?? const TimeOfDay(hour: 7, minute: 0),
              );
              if (picked != null) setState(() => startTime = picked);
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('—', style: TextStyle(fontSize: 24)),
        ),
        Expanded(
          child: _buildTimePickerField(
            label: 'End Time',
            time: endTime,
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: endTime ?? const TimeOfDay(hour: 19, minute: 0),
              );
              if (picked != null) setState(() => endTime = picked);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTimePickerField({required String label, required TimeOfDay? time, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text(
              time?.format(context) ?? 'Select time',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurrenceTypeSelector() {
    return Column(
      children: [
        _buildRadioTile(
          title: 'One Time',
          subtitle: 'Specific date only',
          value: 'ONCE',
          groupValue: recurrenceType,
          onChanged: (val) => setState(() {
            recurrenceType = val!;
            selectedDate = null;
            startDate = null;
            endDate = null;
            selectedDayOfWeek = null;
            selectedDayOfMonth = null;
          }),
        ),
        _buildRadioTile(
          title: 'Date Range',
          subtitle: 'From date to date',
          value: 'DATE_RANGE',
          groupValue: recurrenceType,
          onChanged: (val) => setState(() {
            recurrenceType = val!;
            selectedDate = null;
            startDate = null;
            endDate = null;
            selectedDayOfWeek = null;
            selectedDayOfMonth = null;
          }),
        ),
        _buildRadioTile(
          title: 'Daily',
          subtitle: 'Every day',
          value: 'DAILY',
          groupValue: recurrenceType,
          onChanged: (val) => setState(() {
            recurrenceType = val!;
            selectedDate = null;
            startDate = null;
            endDate = null;
            selectedDayOfWeek = null;
            selectedDayOfMonth = null;
          }),
        ),
        _buildRadioTile(
          title: 'Weekly',
          subtitle: 'Same day each week',
          value: 'WEEKLY',
          groupValue: recurrenceType,
          onChanged: (val) => setState(() {
            recurrenceType = val!;
            selectedDate = null;
            startDate = null;
            endDate = null;
            selectedDayOfWeek = 1;
            selectedDayOfMonth = null;
          }),
        ),
        _buildRadioTile(
          title: 'Monthly',
          subtitle: 'Same date each month',
          value: 'MONTHLY',
          groupValue: recurrenceType,
          onChanged: (val) => setState(() {
            recurrenceType = val!;
            selectedDate = null;
            startDate = null;
            endDate = null;
            selectedDayOfWeek = null;
            selectedDayOfMonth = 1;
          }),
        ),
      ],
    );
  }

  Widget _buildRecurrenceOptions() {
    switch (recurrenceType) {
      case 'ONCE':
        return _buildDatePicker();
      case 'DATE_RANGE':
        return _buildDateRangePicker();
      case 'WEEKLY':
        return _buildDayOfWeekPicker();
      case 'MONTHLY':
        return _buildDayOfMonthPicker();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) setState(() => selectedDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: AppColors.primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(
                    selectedDate != null ? DateFormat('MMM dd, yyyy').format(selectedDate!) : 'Tap to select',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ NEW: Date Range Picker
  Widget _buildDateRangePicker() {
    return Column(
      children: [
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: startDate ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              setState(() {
                startDate = picked;
                if (endDate != null && endDate!.isBefore(picked)) {
                  endDate = null;
                }
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: AppColors.primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Start Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        startDate != null ? DateFormat('MMM dd, yyyy').format(startDate!) : 'Tap to select',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: startDate == null
              ? null
              : () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: endDate ?? startDate!.add(const Duration(days: 1)),
              firstDate: startDate!,
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) setState(() => endDate = picked);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: startDate == null ? Colors.grey[300]! : Colors.grey),
              borderRadius: BorderRadius.circular(8),
              color: startDate == null ? Colors.grey[100] : Colors.white,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.event,
                  color: startDate == null ? Colors.grey[400] : AppColors.primaryColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'End Date',
                        style: TextStyle(fontSize: 12, color: startDate == null ? Colors.grey[400] : Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        endDate != null
                            ? DateFormat('MMM dd, yyyy').format(endDate!)
                            : (startDate == null ? 'Select start date first' : 'Tap to select'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: startDate == null ? Colors.grey[400] : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (startDate != null && endDate != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Duration: ${endDate!.difference(startDate!).inDays + 1} day(s)',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue[900],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDayOfWeekPicker() {
    final weekDays = [
      {'value': 1, 'name': 'Monday'},
      {'value': 2, 'name': 'Tuesday'},
      {'value': 3, 'name': 'Wednesday'},
      {'value': 4, 'name': 'Thursday'},
      {'value': 5, 'name': 'Friday'},
      {'value': 6, 'name': 'Saturday'},
      {'value': 7, 'name': 'Sunday'},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: weekDays.map((day) {
        final isSelected = selectedDayOfWeek == day['value'];
        return ChoiceChip(
          label: Text(day['name'] as String),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) setState(() => selectedDayOfWeek = day['value'] as int);
          },
        );
      }).toList(),
    );
  }

  Widget _buildDayOfMonthPicker() {
    return DropdownButtonFormField<int>(
      value: selectedDayOfMonth,
      decoration: InputDecoration(
        labelText: 'Day of Month',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: List.generate(31, (index) => index + 1)
          .map((day) => DropdownMenuItem(value: day, child: Text('Day $day')))
          .toList(),
      onChanged: (value) => setState(() => selectedDayOfMonth = value),
    );
  }

  Widget _buildRadioOption({
    required String title,
    required String subtitle,
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
  }) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryColor.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? AppColors.primaryColor : Colors.grey,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.primaryColor : Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioTile({
    required String title,
    required String subtitle,
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
  }) {
    return RadioListTile<String>(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
    );
  }

  bool _canSubmit() {
    if (isSubmitting) return false;
    if (dayOffType == 'PARTIAL_DAY') {
      if (startTime == null || endTime == null) return false;
    }
    switch (recurrenceType) {
      case 'ONCE':
        return selectedDate != null;
      case 'DATE_RANGE':
        return startDate != null && endDate != null;
      case 'WEEKLY':
        return selectedDayOfWeek != null;
      case 'MONTHLY':
        return selectedDayOfMonth != null;
      case 'DAILY':
        return true;
      default:
        return false;
    }
  }

  Future<void> _submitRequest() async {
    setState(() => isSubmitting = true);

    try {
      final result = await ApiService.createDayOffRequest(
        dayOffType: dayOffType,
        recurrenceType: recurrenceType,
        specificDate: selectedDate != null
            ? '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}'
            : null,
        startDate: startDate != null
            ? '${startDate!.year}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}'
            : null,
        endDate: endDate != null
            ? '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}'
            : null,
        dayOfWeek: selectedDayOfWeek,
        dayOfMonth: selectedDayOfMonth,
        startTime: startTime != null
            ? '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}'
            : null,
        endTime: endTime != null
            ? '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}'
            : null,
        staffNote: _noteController.text.isNotEmpty ? _noteController.text : null,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']), backgroundColor: Colors.green),
        );

        setState(() {
          dayOffType = 'FULL_DAY';
          recurrenceType = 'ONCE';
          selectedDate = null;
          startDate = null;
          endDate = null;
          selectedDayOfWeek = null;
          selectedDayOfMonth = null;
          startTime = null;
          endTime = null;
          _noteController.clear();
        });

        widget.onRequestCreated();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message']), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }
}