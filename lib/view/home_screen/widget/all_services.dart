import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/utils/navigation/navigation_file.dart';
import 'package:hair_sallon/view/home_screen/widget/service_detail_screen.dart';
import 'package:hair_sallon/widgets/common_appbar/common_appbar.dart';

class AllServicesScreen extends StatelessWidget {
  const AllServicesScreen({super.key});

  final List<Map<String, dynamic>> allServices = const [
    {'icon': Icons.cut, 'label': 'Pedicure'},
    {'icon': Icons.spa, 'label': 'Nails'},
    {'icon': Icons.brush, 'label': 'Miscellaneous'},
    {'icon': Icons.face, 'label': 'Waxing'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      appBar: ComAppbar(
        bgColor: AppColors.whiteColor,
        title: 'All Services',
        elevation: 0.0,
        centerTitle: true,
        isTitleBold: true,
        automaticallyImplyLeading: false,
        iconTheme: const IconThemeData(color: AppColors.blackColor),
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          itemCount: allServices.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.8,
          ),
          itemBuilder: (context, index) {
            final service = allServices[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ServiceDetailsScreen(
                      icon: service['icon'],
                      label: service['label'],
                    ),
                  ),
                );
              },
              child: Column(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.porcelainColor,
                    radius: 30,
                    child: Icon(service['icon'], color: AppColors.blackColor),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    service['label'],
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
