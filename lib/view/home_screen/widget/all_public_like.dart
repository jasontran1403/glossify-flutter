import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/utils/local_images/local_images.dart';
import 'package:hair_sallon/widgets/common_appbar/common_appbar.dart' show ComAppbar;

import '../../../utils/navigation/navigation_file.dart' show Navigation;

class PublicLikeScreen extends StatelessWidget {
  const PublicLikeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> publicServices = [
      {'name': 'Hair Cut', 'image': AppImages.primeCuts},
      {'name': 'Beard Trim', 'image': AppImages.beardTrim},
      {'name': 'Hair Color', 'image': AppImages.hairColour},
      {'name': 'Facial', 'image': AppImages.facial},
      {'name': 'Shaving', 'image': AppImages.shaving},
      {'name': 'Spa', 'image': AppImages.spa},
      {'name': 'Hair Wash', 'image': AppImages.hairWash},
      {'name': 'Blow Dry', 'image': AppImages.primeCuts},
      {'name': 'Styling', 'image': AppImages.primeCuts},
    ];

    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      appBar: ComAppbar(
        bgColor: AppColors.whiteColor,
        title: 'Public Like',
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
        padding: const EdgeInsets.all(12),
        child: GridView.builder(
          itemCount: publicServices.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.75,
          ),
          itemBuilder: (context, index) {
            final service = publicServices[index];
            return LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth;
                final imageHeight = cardWidth * 0.85;

                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
                    color: Colors.white,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: Image.asset(
                          service['image']!,
                          width: double.infinity,
                          height: imageHeight,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          service['name']!,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
