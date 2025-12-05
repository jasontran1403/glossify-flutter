import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/utils/navigation/navigation_file.dart';
import 'package:hair_sallon/widgets/common_appbar/common_appbar.dart';

class Transcations extends StatefulWidget {
  const Transcations({super.key});

  @override
  State<Transcations> createState() => _TranscationsState();
}

class _TranscationsState extends State<Transcations> {
  List<String> services = [
    'Haircut',
    'Facial Cleanup',
    'Hair Spa',
    'Beard Trim',
    'Shaving',
    'Hair Color',
    'Pedicure',
    'Manicure',
  ];

  List<String> times = [
    '09:00 AM',
    '10:30 AM',
    '12:00 PM',
    '02:45 PM',
    '04:15 PM',
    '05:30 PM',
    '07:00 PM',
    '08:20 PM',
  ];

  List<String> prices = [
    '\$2.40',
    '\$6.00',
    '\$9.60',
    '\$1.80',
    '\$1.20',
    '\$14.40',
    '\$8.40',
    '\$7.80',
  ];

  List<String> dates = [
    'Today',
    'Today',
    '23 June 2025',
    '23 June 2025',
    '23 June 2025',
    '22 June 2025',
    '22 June 2025',
    '21 June 2025',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      appBar: ComAppbar(
        bgColor: AppColors.whiteColor,
        title: "Transactions",
        elevation: 0.0,
        centerTitle: true,
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
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: services.length,
          itemBuilder: (context, index) {
            String currentDate = dates[index];
            String? previousDate = index > 0 ? dates[index - 1] : null;
            bool showDateHeader = currentDate != previousDate;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showDateHeader)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6, top: 12),
                    child: Text(
                      currentDate,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.whiteColor,
                    border: Border.all(color: AppColors.blackColor, width: 0.4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            services[index],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            times[index],
                            style: const TextStyle(
                              color: AppColors.mistBlueColor,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '-${prices[index]}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryColor,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
