import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/utils/local_images/local_images.dart';
import 'package:hair_sallon/utils/navigation/navigation_file.dart';
import 'package:hair_sallon/widgets/common_appbar/common_appbar.dart';

class SalonServiceDetailsPage extends StatelessWidget {
  const SalonServiceDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: ComAppbar(
        bgColor: AppColors.whiteColor,
        title: 'Special For You',
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCard(
            imageUrl: AppImages.bridal,
            title: "Bridal Makeup",
            description: "Get ready for your special day",
            price: "₹4999",
          ),
          const SizedBox(height: 16),
          _buildCard(
            imageUrl: AppImages.hairWash,
            title: "Hair Spa",
            description: "Relax and nourish your hair",
            price: "₹999",
          ),
          const SizedBox(height: 16),
          _buildCard(
            imageUrl: AppImages.facial,
            title: "Facial Glow",
            description: "Brighten your skin with facial treatment",
            price: "₹1299",
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String imageUrl,
    required String title,
    required String description,
    required String price,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackColor.withAlpha(13),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        color: Colors.white,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Image.asset(
                  imageUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.redAccentColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      price,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget _buildCard({
  //   required String imageUrl,
  //   required String title,
  //   required String description,
  //   required String price,
  // }) {
  //   return Card(
  //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  //     elevation: 4,
  //     clipBehavior: Clip.antiAlias,
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Image.asset(
  //           imageUrl,
  //           height: 180,
  //           width: double.infinity,
  //           fit: BoxFit.cover,
  //         ),
  //         Padding(
  //           padding: const EdgeInsets.all(12),
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text(title,
  //                   style: const TextStyle(
  //                       fontSize: 18, fontWeight: FontWeight.bold)),
  //               const SizedBox(height: 4),
  //               Text(description,
  //                   style: const TextStyle(color: Colors.grey, fontSize: 14)),
  //               const SizedBox(height: 8),
  //               Text(price,
  //                   style: const TextStyle(
  //                       fontWeight: FontWeight.bold, color: Colors.pinkAccent)),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }
}
