// import 'package:flutter/material.dart';
// import 'package:hair_sallon/utils/navigation/navigation_file.dart';
//
// class ProfileFullScreen extends StatelessWidget {
//   const ProfileFullScreen({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     final screenWidth = MediaQuery.of(context).size.width;
//
//     return DefaultTabController(
//       length: 2,
//       child: Scaffold(
//         backgroundColor: Colors.white,
//         body: Column(
//           children: [
//             Stack(
//               children: [
//                 // Cover Image
//                 ClipRRect(
//                   borderRadius: BorderRadius.only(
//                     bottomLeft: Radius.circular(24),
//                     bottomRight: Radius.circular(24),
//                   ),
//                   child: Image.asset(
//                     'assets/images/sallon1.jpeg',
//                     height: 240,
//                     width: double.infinity,
//                     fit: BoxFit.cover,
//                   ),
//                 ),
//
//                 Positioned(
//                   top: 40,
//                   left: 16,
//                   child: CircleAvatar(
//                     backgroundColor: Colors.white,
//                     child: IconButton(onPressed: (){
//                       Navigation.pop(context);
//                     }, icon: Icon(Icons.arrow_back)),
//                     // child: Icon(Icons.arrow_back),
//                   ),
//                 ),
//                 Positioned(
//                   top: 40,
//                   right: 16,
//                   child: CircleAvatar(
//                     backgroundColor: Colors.white,
//                     child: Icon(Icons.share),
//                   ),
//                 ),
//
//                 Positioned(
//                   top: 170,
//                   child: Row(
//                     children: [
//                       Container(
//                         width: screenWidth / 2,
//                         height: MediaQuery.of(context).size.height * 0.11,
//                         color: Colors.white,
//                         alignment: Alignment.center,
//                         child: Column(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             Text("1.5k", style: TextStyle(fontWeight: FontWeight.bold)),
//                             Text("Follower", style: TextStyle(color: Colors.grey)),
//                           ],
//                         ),
//                       ),
//                       Container(
//                         width: screenWidth / 2,
//                         height: MediaQuery.of(context).size.height * 0.11,
//                         color: Colors.white,
//                         alignment: Alignment.center,
//                         child: Column(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             Text("10", style: TextStyle(fontWeight: FontWeight.bold)),
//                             Text("Following", style: TextStyle(color: Colors.grey)),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 Positioned(
//                   top: 135,
//                   left: screenWidth / 2 - 45,
//                   child: CircleAvatar(
//                     radius: 45,
//                     backgroundImage: AssetImage('assets/images/user2.jpeg'),
//                   ),
//                 ),
//               ],
//             ),
//
//             SizedBox(height: 16),
//
//             // Name & Location
//             Text("Denise Howell",
//                 style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//             Text("📍 New York, USA", style: TextStyle(color: Colors.grey)),
//             SizedBox(height: 12),
//
//             // Profile Actions
//             Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 profileAction("Add review"),
//                 profileAction("Add photo"),
//                 profileAction("Edit Profile"),
//               ],
//             ),
//
//             SizedBox(height: 20),
//
//             // Tab Bar
//             TabBar(
//               indicatorColor: Colors.red,
//               labelColor: Colors.red,
//               unselectedLabelColor: Colors.grey,
//               tabs: [
//                 Tab(text: "Reviews"),
//                 Tab(text: "Photos"),
//               ],
//             ),
//
//             // Photos Title + Add Photo
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text("Photos (8)",
//                       style:
//                       TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//                 ],
//               ),
//             ),
//
//             // Tab View
//             Expanded(
//               child: TabBarView(
//                 children: [
//                   // Reviews Tab
//                   Center(
//                     child: Text("No reviews yet",
//                         style: TextStyle(color: Colors.grey)),
//                   ),
//                   // Photos Tab
//                   Padding(
//                     padding: const EdgeInsets.all(16.0),
//                     child: GridView.count(
//                       crossAxisCount: 2,
//                       mainAxisSpacing: 12,
//                       crossAxisSpacing: 12,
//                       childAspectRatio: 1,
//                       children: [
//                         'hair_cut.jpg',
//                         'hair_cut.jpg',
//                         'hair_cut.jpg',
//                         'hair_cut.jpg',
//                       ]
//                           .map((img) => ClipRRect(
//                         borderRadius: BorderRadius.circular(12),
//                         child: Image.asset(
//                           'assets/images/$img',
//                           fit: BoxFit.cover,
//                         ),
//                       ))
//                           .toList(),
//                     ),
//                   ),
//
//
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // Widget for profile action buttons
//   Widget profileAction(String title) {
//     return Container(
//       margin: EdgeInsets.symmetric(horizontal: 6),
//       padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//       decoration: BoxDecoration(
//         color: Colors.grey[100],
//         borderRadius: BorderRadius.circular(20),
//       ),
//       child: Text(title, style: TextStyle(fontSize: 13)),
//     );
//   }
//
//   // Widget for mini-tab items below "Following"
//   Widget tabItem(String title, bool isSelected) {
//     return Column(
//       children: [
//         Text(
//           title,
//           style: TextStyle(
//             color: isSelected ? Colors.red : Colors.grey,
//             fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
//           ),
//         ),
//         if (isSelected)
//           Container(
//             height: 2,
//             width: 40,
//             margin: EdgeInsets.only(top: 2),
//             color: Colors.red,
//           ),
//       ],
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart' show AppColors;
import 'package:hair_sallon/utils/local_images/local_images.dart';
import 'package:hair_sallon/utils/navigation/navigation_file.dart';

class ProfileFullScreen extends StatelessWidget {
  final String username;
  final String userImage;

  const ProfileFullScreen({
    super.key,
    required this.username,
    required this.userImage,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.porcelainColor,
        body: Column(
          children: [
            Stack(
              children: [
                // Cover Image
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  child: Image.asset(
                    AppImages.salon1,
                    height: 230,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),

                // Back Button
                Positioned(
                  top: 40,
                  left: 16,
                  child: GestureDetector(
                    onTap: () => Navigation.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.transparent,
                      child: SvgPicture.asset(
                        'assets/icon/back-button.svg',
                        width: 30,
                        height: 30,
                        colorFilter: const ColorFilter.mode(
                          AppColors.snowyMintColor,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ),

                // Profile Image
                Positioned(
                  top: 135,
                  left: screenWidth / 2 - 45,
                  child: CircleAvatar(
                    radius: 45,
                    backgroundImage: AssetImage(userImage),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Name & Location
            Text(
              username,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Profile Actions
            // Profile Actions
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                // profileAction("Add review"),
                // profileAction("Add photo"),
                // profileAction("Edit Profile"),
              ],
            ),

            // Row(
            //   mainAxisAlignment: MainAxisAlignment.center,
            //   children: [
            //     profileAction("Add review"),
            //     profileAction("Add photo"),
            //     profileAction("Edit Profile"),
            //   ],
            // ),

            const SizedBox(height: 20),

            // Tab Bar
            TabBar(
              indicatorColor: AppColors.primaryColor,
              labelColor: AppColors.primaryColor,
              unselectedLabelColor: AppColors.mistBlueColor,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              tabs: [
                Tab(text: "Reviews"),
                Tab(text: "Photos"),
              ],
            ),

            // Section Header
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Reviews (14)",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                children: [
                  Center(
                    child: ListView(
                      padding: const EdgeInsets.all(12),
                      children: const [
                        ListTile(
                          leading: CircleAvatar(child: Text("A")),
                          title: Text("Amit Patel"),
                          subtitle: Text("Amazing service and friendly staff. Highly recommended!"),
                          trailing: Text("⭐ 5"),
                        ),
                        ListTile(
                          leading: CircleAvatar(child: Text("S")),
                          title: Text("Sneha R."),
                          subtitle: Text("Great experience, very professional."),
                          trailing: Text("⭐ 4"),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1,
                      children: List.generate(
                        4,
                            (index) => ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            AppImages.hairCut,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Utility method for formatting large follower numbers
  String _formatFollowers(int number) {
    if (number >= 1000) {
      return "${(number / 1000).toStringAsFixed(1)}k";
    } else {
      return number.toString();
    }
  }

  // Reusable widget for actions like "Edit", "Review"
  Widget profileAction(String title) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(title, style: const TextStyle(fontSize: 13)),
    );
  }
}
