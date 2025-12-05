import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/utils/local_images/local_images.dart';
import 'package:hair_sallon/utils/navigation/navigation_file.dart';
import 'package:hair_sallon/widgets/common_appbar/common_appbar.dart';

class SavedListScreen extends StatefulWidget {
  const SavedListScreen({super.key});

  @override
  State<SavedListScreen> createState() => _SavedListScreenState();
}

class _SavedListScreenState extends State<SavedListScreen> {
  final categories = ['All', 'Pedicure', 'Nails', 'Miscellaneous', 'Waxing'];
  String selectedCategory = 'All';

  final List<Map<String, String>> allServices = [
    {
      'image': AppImages.facial,
      'title': 'Basic Pedicure',
      'location': 'CP Nails & Spa, Indiana',
      'category': 'Pedicure',
    },
    {
      'image': AppImages.facial,
      'title': 'Deluxe Spa Pedicure',
      'location': 'Diamond Nails, California',
      'category': 'Pedicure',
    },
    {
      'image': AppImages.facial,
      'title': 'Herbal Deluxe Pedicure',
      'location': 'Star Nails & Beauty, Texas',
      'category': 'Pedicure',
    },
    {
      'image': AppImages.facial,
      'title': 'Signature Volcano Spa Pedicure',
      'location': 'Sunshine Nails, Florida',
      'category': 'Pedicure',
    },
    {
      'image': AppImages.facial,
      'title': 'Basic Manicure',
      'location': 'CP Nails & Spa, Indiana',
      'category': 'Nails',
    },
    {
      'image': AppImages.facial,
      'title': 'No-Chip Manicure',
      'location': 'Diamond Nails, California',
      'category': 'Nails',
    },
    {
      'image': AppImages.facial,
      'title': 'Full Set (artificial nails)',
      'location': 'Star Nails & Beauty, Texas',
      'category': 'Nails',
    },
    {
      'image': AppImages.facial,
      'title': 'Fill-Ins',
      'location': 'Sunshine Nails, Florida',
      'category': 'Nails',
    },
    {
      'image': AppImages.facial,
      'title': 'Dipping Powder',
      'location': 'CP Nails & Spa, Indiana',
      'category': 'Nails',
    },
    {
      'image': AppImages.facial,
      'title': 'Kid\'s Pedicure (11 and younger)',
      'location': 'Diamond Nails, California',
      'category': 'Nails',
    },
    {
      'image': AppImages.facial,
      'title': 'Basic Manicure & Pedicure Combo',
      'location': 'Star Nails & Beauty, Texas',
      'category': 'Nails',
    },
    {
      'image': AppImages.facial,
      'title': 'Full set Pink and White',
      'location': 'Sunshine Nails, Florida',
      'category': 'Nails',
    },
    {
      'image': AppImages.facial,
      'title': 'No-Chip Polish',
      'location': 'CP Nails & Spa, Indiana',
      'category': 'Miscellaneous',
    },
    {
      'image': AppImages.facial,
      'title': 'Artificial Nails Removal',
      'location': 'Diamond Nails, California',
      'category': 'Miscellaneous',
    },
    {
      'image': AppImages.facial,
      'title': 'No-Chip Polish Soak Off',
      'location': 'Star Nails & Beauty, Texas',
      'category': 'Miscellaneous',
    },
    {
      'image': AppImages.facial,
      'title': 'Artificial Nails Repair',
      'location': 'Sunshine Nails, Florida',
      'category': 'Miscellaneous',
    },
    {
      'image': AppImages.facial,
      'title': 'Cut Down',
      'location': 'CP Nails & Spa, Indiana',
      'category': 'Miscellaneous',
    },
    {
      'image': AppImages.facial,
      'title': 'Regular Polish Change',
      'location': 'Diamond Nails, California',
      'category': 'Miscellaneous',
    },
    {
      'image': AppImages.facial,
      'title': 'Nails Design',
      'location': 'Star Nails & Beauty, Texas',
      'category': 'Miscellaneous',
    },
    {
      'image': AppImages.facial,
      'title': 'French',
      'location': 'Sunshine Nails, Florida',
      'category': 'Miscellaneous',
    },
    {
      'image': AppImages.facial,
      'title': 'Eyebrows',
      'location': 'CP Nails & Spa, Indiana',
      'category': 'Waxing',
    },
    {
      'image': AppImages.facial,
      'title': 'Lip',
      'location': 'Diamond Nails, California',
      'category': 'Waxing',
    },
    {
      'image': AppImages.facial,
      'title': 'Under Arms',
      'location': 'Star Nails & Beauty, Texas',
      'category': 'Waxing',
    },
    {
      'image': AppImages.facial,
      'title': 'Full Face',
      'location': 'Sunshine Nails, Florida',
      'category': 'Waxing',
    },
    {
      'image': AppImages.facial,
      'title': 'Cheeks',
      'location': 'CP Nails & Spa, Indiana',
      'category': 'Waxing',
    },
    {
      'image': AppImages.facial,
      'title': 'Chin',
      'location': 'Diamond Nails, California',
      'category': 'Waxing',
    },
  ];

  final List<Map<String, String>> salons = [
    {"name": "CP Nails & Spa", "state": "Indiana"},
    {"name": "Diamond Nails", "state": "California"},
    {"name": "Star Nails & Beauty", "state": "Texas"},
    {"name": "Sunshine Nails", "state": "Florida"},
  ];

  @override
  Widget build(BuildContext context) {
    final filteredServices = selectedCategory == 'All'
        ? allServices
        : allServices.where((s) => s['category'] == selectedCategory).toList();

    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      appBar: ComAppbar(
        bgColor: AppColors.whiteColor,
        title: "Saved",
        elevation: 0.0,
        centerTitle: true,
        isTitleBold: true,
        iconTheme: IconThemeData(color: AppColors.whiteColor),
        leading: GestureDetector(
          onTap: () => Navigation.pop(context),
          child: Transform.scale(
            scale: 0.5,
            child: SvgPicture.asset(
              'assets/icon/back-button.svg',
              colorFilter: ColorFilter.mode(AppColors.blackColor, BlendMode.srcIn),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Categories
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: categories.map((cat) {
                  final isSelected = cat == selectedCategory;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedCategory = cat;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primaryColor : AppColors.whiteColor,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: AppColors.blackColor, width: 0.2),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: isSelected ? AppColors.whiteColor : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            // Cards
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filteredServices.length,
                itemBuilder: (context, index) {
                  final service = filteredServices[index];
                  return ServiceCard(
                    image: service['image']!,
                    title: service['title']!,
                    location: service['location']!,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ServiceCard extends StatelessWidget {
  final String image;
  final String title;
  final String location;

  const ServiceCard({
    super.key,
    required this.image,
    required this.title,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackColor.withAlpha(13),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              image,
              height: 70,
              width: 70,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_pin, size: 16, color: AppColors.primaryColor),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        location,
                        style: const TextStyle(fontSize: 13, color: Colors.black54),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: const [
                    Icon(Icons.star, size: 16, color: AppColors.primaryColor),
                    SizedBox(width: 4),
                    Text('4.8 (1k+ Review)',
                        style: TextStyle(fontSize: 13, color: Colors.black54)),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}


