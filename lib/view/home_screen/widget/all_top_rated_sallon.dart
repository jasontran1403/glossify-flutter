import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/utils/local_images/local_images.dart';
import 'package:hair_sallon/utils/navigation/navigation_file.dart';
import 'package:hair_sallon/view/saloncardpage/salon_card_page.dart';
import 'package:hair_sallon/widgets/common_appbar/common_appbar.dart';

class TopRatedSalonsScreen extends StatelessWidget {
   TopRatedSalonsScreen({super.key});

  final List<String> salonImages =  [
    AppImages.salon2,
    AppImages.salon4,
    AppImages.salon3,
    AppImages.salon,
    AppImages.salon4,
    AppImages.salon2,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      appBar: ComAppbar(
        bgColor: AppColors.whiteColor,
        title: 'Services',
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
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 3 / 4,
        ),
        itemCount: salonImages.length,
        itemBuilder: (context, index) {
          final imageUrl = salonImages[index];
          return GestureDetector(
            onTap: () {
              // Navigation.push(context, SalonDetailScreen(imageUrl:imageUrl, cateName: "Pedicure", storeId: 1,));
            },
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: NetworkImage(imageUrl),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 4),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: Container(
                    height: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: AppColors.whiteColor.withAlpha(204),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.star, color: Colors.amber, size: 16),
                        SizedBox(width: 3),
                        Text(
                          '4.8',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: CircleAvatar(
                    backgroundColor: AppColors.mistBlueColor.withAlpha(127),
                    child: const Icon(Icons.favorite_border,
                        color: AppColors.whiteColor),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
