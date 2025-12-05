import 'package:flutter/material.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/utils/local_images/local_images.dart';

class SpecialistDetailScreen extends StatelessWidget {
  const SpecialistDetailScreen({super.key});

  Widget serviceCard(String image, String title, String time, String price) {
    return Card(
      color: AppColors.whiteColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(image, width: 70, height: 70, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 16, color: AppColors.primaryColor),
                      const SizedBox(width: 4),
                      Text(time, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text("\$$price",
                      style: const TextStyle(
                          color: AppColors.primaryColor, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            // Book button
            Column(
              children: [
                IconButton(
                    icon: const Icon(Icons.favorite_border, color: AppColors.primaryColor),
                    onPressed: () {}),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text("Book Now", style: TextStyle(fontSize: 12,color: AppColors.whiteColor)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      body: Stack(
        children: [
// Background salon image
          SizedBox(
            height: 230,
            width: double.infinity,
            child: Image.asset(AppImages.salon, fit: BoxFit.cover),
          ),

          // Content container
          Container(
            margin: const EdgeInsets.only(top: 170),
            decoration: const BoxDecoration(
              color: AppColors.whiteColor,
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(25), topRight: Radius.circular(25)),
            ),
            child: ListView(
              padding: const EdgeInsets.only(top: 45),
              children: [
                // Name
                const Center(
                  child: Column(
                    children: [
                      Text("Jenny Wilson",
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      Text("Glamour Haven",
                          style: TextStyle(color: AppColors.mistBlueColor)),
                      SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.star, color: Colors.orange, size: 16),
                          SizedBox(width: 4),
                          Text("4.8 (1k+ Review)",
                              style: TextStyle(color: AppColors.mistBlueColor)),
                        ],
                      ),
                      SizedBox(height: 15),
                      Divider(indent: 16,endIndent:17)
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text("Service List (28)",
                      style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),

                serviceCard(AppImages.user, "Men's Hair Cut", "30 Min", "125.00"),
                serviceCard(AppImages.user, "Women's Hair Cut", "35 Min", "140.00"),
                serviceCard(AppImages.user, "Bridal Beauty Makeup", "45 Min", "250.00"),
              ],
            ),
          ),

          Positioned(
            top: 40,
            left: 16,
            child: CircleAvatar(
              backgroundColor: AppColors.whiteColor,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {},
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 70,
            child: const CircleAvatar(
              backgroundColor: AppColors.whiteColor,
              child: Icon(Icons.call, color: AppColors.blackColor),
            ),
          ),
          Positioned(
            top: 40,
            right: 16,
            child: const CircleAvatar(
              backgroundColor: AppColors.whiteColor,
              child: Icon(Icons.more_vert, color: AppColors.blackColor),
            ),
          ),

          // Profile image
          Positioned(
            top: 130,
            left: MediaQuery.of(context).size.width / 2 - 40,
            child:  CircleAvatar(
              radius: 40,
              backgroundImage: AssetImage(AppImages.user),
            ),
          ),
        ],
      ),
    );
  }
}