import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/utils/local_images/local_images.dart';
import 'package:hair_sallon/utils/navigation/navigation_file.dart';
import 'package:hair_sallon/widgets/common_appbar/common_appbar.dart';

class SpecialOfferScreen extends StatelessWidget {
  SpecialOfferScreen({super.key});

  final List<Map<String, String>> offerList = [
    {
      'image': AppImages.salon,
      'title': 'Get Special Discount Up to 40%',
      'subtitle': 'All Salon available | T&C Applied',
      'tag': 'Limited time!',
    },
    {
      'image': AppImages.salon1,
      'title': 'Hair Spa Deals This Week',
      'subtitle': 'Upto 30% off on Hair & Skin',
      'tag': 'Hot Offer',
    },
    {
      'image': AppImages.salon,
      'title': 'Free Hair Cut on Facial Booking',
      'subtitle': 'Book Now | Limited Seats',
      'tag': 'Flash Deal',
    },
    {
      'image': AppImages.salon,
      'title': 'Get Special Discount Up to 40%',
      'subtitle': 'All Salon available | T&C Applied',
      'tag': 'Limited time!',
    },
    {
      'image': AppImages.salon1,
      'title': 'Hair Spa Deals This Week',
      'subtitle': 'Upto 30% off on Hair & Skin',
      'tag': 'Hot Offer',
    },
    {
      'image': AppImages.salon,
      'title': 'Free Hair Cut on Facial Booking',
      'subtitle': 'Book Now | Limited Seats',
      'tag': 'Flash Deal',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      appBar: ComAppbar(
        bgColor: AppColors.whiteColor,
        title: 'Special Offers',
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
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: offerList.length,
        itemBuilder: (context, index) {
          final offer = offerList[index];
          return _buildOfferCard(offer);
        },
      ),
    );
  }

  Widget _buildOfferCard(Map<String, String> offer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(
          image: AssetImage(offer['image']!),
          fit: BoxFit.cover,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.whiteColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                offer['tag']!,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          Positioned(
            top: 45,
            left: 10,
            right: 10,
            child: Text(
              offer['title']!,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.whiteColor,
                shadows: [
                  Shadow(
                    blurRadius: 2,
                    color: Colors.black54,
                    offset: Offset(0.5, 1),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 10,
            child: Text(
              offer['subtitle']!,
              style: const TextStyle(fontSize: 12, color: AppColors.whiteColor),
            ),
          ),
          Positioned(
            bottom: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryColor,
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Text(
                'Claim',
                style: TextStyle(
                  color: AppColors.whiteColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
