import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

class CustomTimePickerDialog extends StatefulWidget {
  final TimeOfDay initialTime;
  final ValueChanged<TimeOfDay> onTimeChanged;

  const CustomTimePickerDialog({
    Key? key,
    required this.initialTime,
    required this.onTimeChanged,
  }) : super(key: key);

  @override
  _CustomTimePickerDialogState createState() => _CustomTimePickerDialogState();
}

class _CustomTimePickerDialogState extends State<CustomTimePickerDialog> {
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late FixedExtentScrollController _periodController;

  final List<int> _minuteOptions = [0, 15, 30, 45];

  // 👇 Gán giá trị mặc định để tránh LateInitializationError
  int _selectedHour = 12;
  int _selectedMinute = 0;
  int _selectedPeriod = 0; // 0 = AM, 1 = PM

  @override
  void initState() {
    super.initState();

    _selectedMinute = _getNearestMinute(widget.initialTime.minute);
    _selectedPeriod = widget.initialTime.hour >= 12 ? 1 : 0;
    _selectedHour = _get12HourFormat(widget.initialTime.hour);

    _hourController = FixedExtentScrollController(
      initialItem: _selectedHour - 1,
    );

    _minuteController = FixedExtentScrollController(
      initialItem: _minuteOptions.indexOf(_selectedMinute),
    );

    _periodController = FixedExtentScrollController(
      initialItem: _selectedPeriod,
    );
  }


  int _getNearestMinute(int minute) {
    if (_minuteOptions.contains(minute)) return minute;

    int nearest = _minuteOptions[0];
    for (int option in _minuteOptions) {
      if ((minute - option).abs() < (minute - nearest).abs()) {
        nearest = option;
      }
    }
    return nearest;
  }

  int _get12HourFormat(int hour) {
    if (hour == 0) return 12;
    if (hour > 12) return hour - 12;
    return hour;
  }

  int _get24HourFormat(int hour12, int period) {
    if (period == 0) { // AM
      if (hour12 == 12) return 0;
      return hour12;
    } else { // PM
      if (hour12 == 12) return 12;
      return hour12 + 12;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Time'),
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 50),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Time display preview
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getSelectedTime().format(context),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),

            // Wheel pickers
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Hour picker
                _buildWheelPicker(
                  controller: _hourController,
                  items: (_selectedPeriod == 0
                      ? List.generate(4, (i) => (8 + i).toString().padLeft(2, '0'))  // AM: 08 → 11
                      : List.generate(8, (i) {
                    int hour = (i == 0 ? 12 : i); // PM: 12, 1, 2, ... 7
                    return hour.toString().padLeft(2, '0');
                  })),
                  label: 'Hour',
                  onChanged: (index) {
                    setState(() {
                      if (_selectedPeriod == 0) {
                        _selectedHour = 8 + index; // AM: 8 → 11
                      } else {
                        _selectedHour = (index == 0 ? 12 : index); // PM: 12 → 7
                      }
                    });
                    _updateTime();
                  },
                  width: 80,
                ),


                const Padding(
                  padding: EdgeInsets.only(top: 15, left: 8, right: 8),
                  child: Text(
                    ':',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Minute picker
                _buildWheelPicker(
                  controller: _minuteController,
                  items: _minuteOptions.map((e) => e.toString().padLeft(2, '0')).toList(),
                  label: 'Minute',
                  onChanged: (index) {
                    setState(() {
                      _selectedMinute = _minuteOptions[index];
                    });
                    _updateTime();
                  },
                  width: 80,
                  physics: MagneticScrollPhysics(minuteOptions: _minuteOptions),
                ),

                const SizedBox(width: 16),

                // Period picker
                _buildWheelPicker(
                  controller: _periodController,
                  items: const ['AM', 'PM'],
                  label: 'Period',
                  onChanged: (index) {
                    setState(() {
                      _selectedPeriod = index;
                    });
                    _updateTime();
                  },
                  width: 70,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onTimeChanged(_getSelectedTime());
            Navigator.pop(context);
          },
          child: const Text('OK'),
        ),
      ],
    );
  }

  Widget _buildWheelPicker({
    required FixedExtentScrollController controller,
    required List<String> items,
    required String label,
    required ValueChanged<int> onChanged,
    required double width,
    ScrollPhysics? physics,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: width,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: ListWheelScrollView(
            controller: controller,
            itemExtent: 40,
            diameterRatio: 1.2,
            perspective: 0.005,
            offAxisFraction: 0,
            physics: physics ?? const FixedExtentScrollPhysics(),
            onSelectedItemChanged: onChanged,
            children: items.map((item) {
              return Center(
                child: Text(
                  item,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  TimeOfDay _getSelectedTime() {
    // Sử dụng state variables thay vì truy cập trực tiếp từ controller
    final int hour24 = _get24HourFormat(_selectedHour, _selectedPeriod);
    return TimeOfDay(hour: hour24, minute: _selectedMinute);
  }

  void _updateTime() {
    widget.onTimeChanged(_getSelectedTime());
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _periodController.dispose();
    super.dispose();
  }
}

// Custom Scroll Physics để tạo hiệu ứng "nam châm"
class MagneticScrollPhysics extends ScrollPhysics {
  final List<int> minuteOptions;

  const MagneticScrollPhysics({
    required this.minuteOptions,
    ScrollPhysics? parent,
  }) : super(parent: parent);

  @override
  MagneticScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return MagneticScrollPhysics(
      minuteOptions: minuteOptions,
      parent: buildParent(ancestor),
    );
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position,
      double velocity,
      ) {
    // Nếu velocity nhỏ, hút về vị trí gần nhất
    if ((velocity.abs() < 50.0) || velocity.isInfinite) {
      return _createMagneticSimulation(position, velocity);
    }

    return super.createBallisticSimulation(position, velocity);
  }

  Simulation _createMagneticSimulation(ScrollMetrics position, double velocity) {
    final double itemExtent = 40; // Fixed item extent
    final double offset = position.pixels - position.minScrollExtent;
    final int currentIndex = (offset / itemExtent).round().clamp(0, minuteOptions.length - 1);
    final double targetPixels = currentIndex * itemExtent + position.minScrollExtent;

    return ScrollSpringSimulation(
      SpringDescription.withDampingRatio(
        mass: 0.5,
        stiffness: 100.0,
        ratio: 1.1,
      ),
      position.pixels,
      targetPixels,
      velocity,
      tolerance: tolerance,
    );
  }
}