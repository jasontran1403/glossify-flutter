// import 'dart:ui';
//
// import 'package:flutter/material.dart';
// import 'package:flutter_svg/flutter_svg.dart';
// import 'package:shimmer/shimmer.dart';
// import 'package:hair_sallon/utils/app_colors/app_colors.dart';
// import 'package:hair_sallon/utils/navigation/navigation_file.dart';
// import 'package:hair_sallon/view/review_summary/review_summary.dart';
// import 'package:hair_sallon/utils/constant/service.dart';
//
// import '../../bokking_screen/booking_schedule_screen.dart'; // chứa class Staff
//
// class SallonBooking extends StatefulWidget {
//   final String imageUrl;
//   final String cateName;
//   final String des;
//   final int serviceId;
//   final int storeId;
//   final String serviceName;
//   final List<Staff> staffList; // danh sách nhân viên service
//
//   const SallonBooking({
//     super.key,
//     required this.imageUrl,
//     required this.cateName,
//     required this.des,
//     required this.staffList,
//     required this.serviceId,
//     required this.serviceName,
//     required this.storeId
//   });
//
//   @override
//   State<SallonBooking> createState() => _SallonBookingState();
// }
//
// class _SallonBookingState extends State<SallonBooking> {
//   int selectedSpecialistIndex = -1; // -1 = chưa chọn
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.whiteColor,
//       body: Column(
//         children: [
//           // Banner + Info cố định
//           Stack(
//             children: [
//               ClipRRect(
//                 borderRadius: const BorderRadius.only(
//                   bottomLeft: Radius.circular(20),
//                   bottomRight: Radius.circular(20),
//                 ),
//                 child: Image.network(
//                   widget.imageUrl,
//                   width: double.infinity,
//                   height: 300,
//                   fit: BoxFit.cover,
//                 ),
//               ),
//               Positioned(
//                 top: 40,
//                 left: 16,
//                 child: GestureDetector(
//                   onTap: () => Navigation.pop(context),
//                   child: Container(
//                     padding: const EdgeInsets.all(16),
//                     color: Colors.transparent,
//                     child: SvgPicture.asset(
//                       'assets/icon/back-button.svg',
//                       width: 30,
//                       height: 30,
//                       colorFilter: const ColorFilter.mode(
//                         AppColors.snowyMintColor,
//                         BlendMode.srcIn,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           Padding(
//             padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   widget.cateName,
//                   style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   widget.des,
//                   style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
//                 ),
//               ],
//             ),
//           ),
//
//           // Staff list scrollable
//           Expanded(
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 4),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Expanded(
//                     child:
//                     GridView.builder(
//                       itemCount: widget.staffList.length,
//                       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                         crossAxisCount: 3,
//                         mainAxisSpacing: 2,
//                         crossAxisSpacing: 2,
//                         childAspectRatio: 0.9,
//                       ),
//                       itemBuilder: (context, index) {
//                         final staff = widget.staffList[index];
//                         final isSelected = selectedSpecialistIndex == index;
//
//                         return GestureDetector(
//                           onTap: () {
//                             setState(() {
//                               if (isSelected) {
//                                 selectedSpecialistIndex = -1;
//                               } else {
//                                 selectedSpecialistIndex = index;
//                               }
//                             });
//                           },
//                           child: ClipRRect(
//                             borderRadius: BorderRadius.circular(16),
//                             child: Stack(
//                               children: [
//                                 // Avatar
//                                 Positioned.fill(
//                                   child: staff.avatar.isNotEmpty
//                                       ? Image.network(
//                                     staff.avatar,
//                                     fit: BoxFit.cover,
//                                     loadingBuilder: (context, child, loadingProgress) {
//                                       if (loadingProgress == null) return child;
//                                       return Shimmer.fromColors(
//                                         baseColor: Colors.grey.shade300,
//                                         highlightColor: Colors.grey.shade100,
//                                         child: Container(color: Colors.white),
//                                       );
//                                     },
//                                     errorBuilder: (context, error, stackTrace) {
//                                       return Container(
//                                         color: Colors.grey.shade300,
//                                         child: const Icon(Icons.person, size: 50, color: Colors.white),
//                                       );
//                                     },
//                                   )
//                                       : Container(
//                                     color: Colors.grey.shade300,
//                                     child: const Icon(Icons.person, size: 50, color: Colors.white),
//                                   ),
//                                 ),
//
//                                 // Glass effect + staff name
//                                 Positioned(
//                                   bottom: 0,
//                                   left: 0,
//                                   right: 0,
//                                   child: ClipRRect(
//                                     borderRadius: const BorderRadius.only(
//                                       bottomLeft: Radius.circular(16),
//                                       bottomRight: Radius.circular(16),
//                                     ),
//                                     child: BackdropFilter(
//                                       filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
//                                       child: Container(
//                                         color: Colors.white.withOpacity(0.4),
//                                         padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
//                                         alignment: Alignment.center,
//                                         child: Text(
//                                           staff.fullName,
//                                           textAlign: TextAlign.center,
//                                           style: const TextStyle(
//                                             color: Colors.black,
//                                             fontWeight: FontWeight.bold,
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//
//                                 // Border khi chọn
//                                 if (isSelected)
//                                   Positioned.fill(
//                                     child: Container(
//                                       decoration: BoxDecoration(
//                                         borderRadius: BorderRadius.circular(16),
//                                         border: Border.all(color: Colors.tealAccent, width: 3),
//                                       ),
//                                     ),
//                                   ),
//                               ],
//                             ),
//                           ),
//                         );
//                       },
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//
//         ],
//       ),
//
//       // Nút Schedule
//       // Trong SallonBooking bottomNavigationBar:
//       bottomNavigationBar: Padding(
//         padding: const EdgeInsets.all(16),
//         child: ElevatedButton(
//           style: ElevatedButton.styleFrom(
//             backgroundColor: selectedSpecialistIndex != -1
//                 ? AppColors.primaryColor
//                 : Colors.grey,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(20),
//             ),
//             padding: const EdgeInsets.symmetric(vertical: 14),
//           ),
//           onPressed: selectedSpecialistIndex != -1
//               ? () {
//             // Lấy staffId tạm: hiện mặc định là 1, sau này đổi thành widget.staffList[selectedSpecialistIndex].id
//             final staffId = widget.staffList[selectedSpecialistIndex].id;
//
//             Navigation.push(
//               context,
//               BookingScheduleScreen(staffId: staffId, staffName: widget.staffList[selectedSpecialistIndex].fullName, serviceId: widget.serviceId, serviceName: widget.serviceName, storeId: widget.storeId),
//             );
//           }
//               : null,
//           child: const Text(
//             "Schedule",
//             style: TextStyle(fontSize: 16, color: AppColors.whiteColor),
//           ),
//         ),
//       ),
//     );
//   }
// }
