import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/api_service.dart';

class RequestDayOffScreen extends StatefulWidget {
  const RequestDayOffScreen({super.key});

  @override
  State<RequestDayOffScreen> createState() => _RequestDayOffScreenState();
}

class _RequestDayOffScreenState extends State<RequestDayOffScreen> {
  // Form state
  String dayOffType = 'FULL_DAY'; // FULL_DAY or PARTIAL_DAY
  String recurrenceType = 'ONCE'; // ONCE, DAILY, WEEKLY, MONTHLY

  DateTime? selectedDate;
  int? selectedDayOfWeek; // 1=Mon...7=Sun
  int? selectedDayOfMonth;

  TimeOfDay? startTime;
  TimeOfDay? endTime;

  final TextEditingController _noteController = TextEditingController();

  bool isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Day Off'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day-off type
            _buildSectionTitle('Day-Off Type'),
            _buildDayOffTypeSelector(),
            const SizedBox(height: 24),

            // Time selection (for PARTIAL_DAY)
            if (dayOffType == 'PARTIAL_DAY') ...[
              _buildSectionTitle('Time Range'),
              _buildTimeRangeSelector(),
              const SizedBox(height: 24),
            ],

            // Recurrence type
            _buildSectionTitle('Recurrence'),
            _buildRecurrenceTypeSelector(),
            const SizedBox(height: 24),

            // Date/day selection based on recurrence type
            _buildRecurrenceOptions(),
            const SizedBox(height: 24),

            // Staff note
            _buildSectionTitle('Reason (Optional)'),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter reason for day off...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _canSubmit() ? _submitRequest : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  'Submit Request',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
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
                initialTime: startTime ?? const TimeOfDay(hour: 9, minute: 0),
              );
              if (picked != null) {
                setState(() => startTime = picked);
              }
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
                initialTime: endTime ?? const TimeOfDay(hour: 17, minute: 0),
              );
              if (picked != null) {
                setState(() => endTime = picked);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTimePickerField({
    required String label,
    required TimeOfDay? time,
    required VoidCallback onTap,
  }) {
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
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
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
            selectedDayOfWeek = 1; // Monday
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
        if (picked != null) {
          setState(() => selectedDate = picked);
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
            const Icon(Icons.calendar_today, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Date',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedDate != null
                        ? DateFormat('MMM dd, yyyy').format(selectedDate!)
                        : 'Tap to select',
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
            if (selected) {
              setState(() => selectedDayOfWeek = day['value'] as int);
            }
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      items: List.generate(31, (index) => index + 1)
          .map((day) => DropdownMenuItem(
        value: day,
        child: Text('Day $day'),
      ))
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
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey,
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
                color: isSelected ? Colors.blue : Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
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

    // Check day-off type requirements
    if (dayOffType == 'PARTIAL_DAY') {
      if (startTime == null || endTime == null) return false;
    }

    // Check recurrence type requirements
    switch (recurrenceType) {
      case 'ONCE':
        return selectedDate != null;
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
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }
}