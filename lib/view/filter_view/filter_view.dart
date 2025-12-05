import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/utils/navigation/navigation_file.dart';
import 'package:hair_sallon/widgets/common_appbar/common_appbar.dart';

class FilterView extends StatefulWidget {
  const FilterView({super.key});

  @override
  State<FilterView> createState() => _FilterViewState();
}

class _FilterViewState extends State<FilterView> {
  double minDistance = 7;
  double maxDistance = 100;

  int selectedRating = 5;

  final List ratings = [
    '4.5 and above',
    '4.0 - 4.5',
    '3.5 - 4.0',
    '3.0 - 3.5',
    '2.5 - 3.0',
  ];
  @override
  Widget build(BuildContext context) {
    final categories = ['All', 'Male', 'Female'];
    final salloncategories = ['HairCut', 'Makeup', 'Shaving', 'Massage'];
    final selectedSallon = 'HairCut';
    final selectedCategory = 'All';
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      appBar: ComAppbar(
        bgColor: AppColors.whiteColor,
        title: "Filter",
        elevation: 0.0,
        centerTitle: true,
        isTitleBold: true,
        iconTheme: IconThemeData(color: AppColors.whiteColor),
        leading: GestureDetector(
          onTap: () {
            // scaffoldKey.currentState?.openDrawer();
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
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              // Categories
              Row(
                children:
                    categories.map((cat) {
                      final isSelected = cat == selectedCategory;
                      return Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primaryColor : AppColors.mistBlueColor,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: isSelected ? AppColors.whiteColor : AppColors.blackColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
              ),
              const SizedBox(height: 25),
              Align(
                alignment: Alignment.topLeft,
                child: Text(
                  'Services',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 5),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children:
                      salloncategories.map((cat1) {
                        final isSelected = cat1 == selectedSallon;
                        return Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primaryColor : AppColors.mistBlueColor,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            cat1,
                            style: TextStyle(
                              color: isSelected ? AppColors.whiteColor : AppColors.blackColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),
              SizedBox(height: 25),
              Text(
                "Reviews",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),

              SizedBox(height: 10),
              ...List.generate(ratings.length, (index) {
                return ListTile(
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      5,
                      (i) => Icon(Icons.star, color: AppColors.primaryColor, size: 20),
                    ),
                  ),
                  title: Text(ratings[index]),
                  trailing: Radio<int>(
                    value: index,
                    activeColor: AppColors.primaryColor,
                    groupValue: selectedRating,
                    onChanged: (value) {
                      setState(() {
                        selectedRating = value!;
                      });
                    },
                  ),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                );
              }),

              SizedBox(height: 20),
              Text(
                "Distance",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              SizedBox(height: 10),
              RangeSlider(
                values: RangeValues(minDistance, maxDistance),
                min: 2,
                max: 150,
                divisions: 5,
                labels: RangeLabels(
                  '${minDistance.toInt()}',
                  '${maxDistance.toInt()}',
                ),
                activeColor: AppColors.primaryColor,
                inactiveColor: AppColors.mistBlueColor,
                onChanged: (RangeValues values) {
                  setState(() {
                    minDistance = values.start;
                    maxDistance = values.end;
                  });
                },
              ),

              // Padding(
              //   padding: const EdgeInsets.only(left: 24),
              //   child: Row(
              //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //     children: [
              //       Text("2"),
              //       Text("7"),
              //       Text("22"),
              //       Text("50"),
              //       Text("100"),
              //       Text("150+"),
              //     ],
              //   ),
              // )
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Reset Filter',
                    style: TextStyle(color: AppColors.primaryColor),
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Apply',
                  style: TextStyle(color: AppColors.whiteColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
