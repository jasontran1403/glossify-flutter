import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hair_sallon/api/api_service.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/utils/common_string/string.dart';
import 'package:hair_sallon/utils/navigation/navigation_file.dart';
import 'package:hair_sallon/widgets/common_appbar/common_appbar.dart';

class CancelBooking extends StatefulWidget {
  final int bookingId;

  const CancelBooking({super.key, required this.bookingId});

  @override
  State<CancelBooking> createState() => _CancelBookingState();
}

class _CancelBookingState extends State<CancelBooking> {
  TextEditingController problemController = TextEditingController();
  int selectedOption = AppStrings.cancellations.length; // Default to "Other" index

  Future<void> _submitCancel() async {
    String cancelReason;
    if (selectedOption < AppStrings.cancellations.length) {
      cancelReason = AppStrings.cancellations[selectedOption];
    } else {
      cancelReason = problemController.text.trim();
      if (cancelReason.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please provide a cancel reason')),
        );
        return;
      }
      if (cancelReason.length > 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reason must be 200 characters or less')),
        );
        return;
      }
    }

    try {
      await ApiService.cancelBooking(widget.bookingId, cancelReason);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking cancelled successfully')),
      );
      Navigator.pop(context, true); // Signal parent to refresh
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel booking: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final int otherIndex = AppStrings.cancellations.length;
    final bool isOtherSelected = selectedOption == otherIndex;

    return Scaffold(
      appBar: ComAppbar(
        title: "Cancel Booking",
        bgColor: AppColors.whiteColor,
        isTitleBold: true,
        iconTheme: IconThemeData(color: AppColors.whiteColor),
        leading: GestureDetector(
          onTap: () {
            Navigation.pop(context);
          },
          child: Transform.scale(
            scale: 0.5,
            child: SvgPicture.asset(
              'assets/icon/back-button.svg',
              colorFilter: ColorFilter.mode(
                AppColors.blackColor,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
      backgroundColor: AppColors.whiteColor,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please select the reason for cancellations',
                style: TextStyle(color: AppColors.mistBlueColor, fontSize: 18),
              ),
              SizedBox(height: 5),
              ...List.generate(AppStrings.cancellations.length, (index) {
                return ListTile(
                  title: Text(AppStrings.cancellations[index]),
                  leading: Radio<int>(
                    value: index,
                    activeColor: AppColors.primaryColor,
                    groupValue: selectedOption,
                    onChanged: (value) {
                      setState(() {
                        selectedOption = value!;
                      });
                    },
                  ),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                );
              }),
              // Add "Other" as a selectable option
              ListTile(
                title: Text('Other'),
                leading: Radio<int>(
                  value: otherIndex,
                  activeColor: AppColors.primaryColor,
                  groupValue: selectedOption,
                  onChanged: (value) {
                    setState(() {
                      selectedOption = value!;
                    });
                  },
                ),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              if (isOtherSelected) ...[
                SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: TextField(
                    controller: problemController,
                    maxLines: 3,
                    maxLength: 200, // Limit to 200 characters
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Enter Your Problem Here (max 200 characters)',
                      counterText: '${problemController.text.length}/200', // Show counter
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
          onPressed: _submitCancel,
          child: const Text(
            "Cancel Booking",
            style: TextStyle(fontSize: 16, color: AppColors.whiteColor),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    problemController.dispose();
    super.dispose();
  }
}