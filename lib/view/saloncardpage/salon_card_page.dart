// // salon_detail_screen.dart
// import 'package:flutter/material.dart';
// import 'package:flutter_svg/flutter_svg.dart';
// import 'package:hair_sallon/api/api_service.dart';
// import 'package:hair_sallon/utils/app_colors/app_colors.dart';
// import 'package:hair_sallon/utils/navigation/navigation_file.dart';
// import 'package:hair_sallon/view/saloncardpage/widget/sallon_booking.dart';
//
// import '../../utils/constant/service.dart';
//
// class SalonDetailScreen extends StatefulWidget {
//   final String imageUrl;
//   final String cateName;
//   final int storeId;
//   const SalonDetailScreen({super.key, required this.imageUrl, required this.cateName, required this.storeId});
//
//   @override
//   State<SalonDetailScreen> createState() => _SalonDetailScreenState();
// }
//
// class _SalonDetailScreenState extends State<SalonDetailScreen> {
//   late Future<List<ServiceModel>> _futureServices;
//   String description = "No description available";
//   ServiceModel? selectedService;
//
//
//   @override
//   void initState() {
//     super.initState();
//     _futureServices = ApiService.getServicesByCategory(widget.cateName, widget.storeId);
//
//     _futureServices.then((services) {
//       if (services.isNotEmpty) {
//         setState(() {
//           description = services[0].cateDescription;
//         });
//       }
//     });
//   }
//
//   Widget serviceItem(ServiceModel service) {
//     final isSelected = selectedService == service;
//     return Card(
//       color: isSelected ? AppColors.primaryColor.withOpacity(0.2) : AppColors.whiteColor,
//       child: ListTile(
//         contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//         title: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text(
//               service.name,
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.w500,
//                 color: isSelected ? AppColors.primaryColor : Colors.black,
//               ),
//             ),
//             Text(
//               "\$${service.price}",
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//                 color: isSelected ? AppColors.primaryColor : Colors.black,
//               ),
//             ),
//           ],
//         ),
//         onTap: () {
//           setState(() {
//             selectedService = (isSelected) ? null : service; // toggle chọn/bỏ chọn
//           });
//         },
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.whiteColor,
//       body: Column(
//         children: [
//           // Header ảnh + icons + salon info
//           Stack(
//             children: [
//               ClipRRect(
//                 borderRadius: const BorderRadius.only(
//                   bottomLeft: Radius.circular(20),
//                   bottomRight: Radius.circular(20),
//                 ),
//                 child:
//                 Image.network(
//                   widget.imageUrl, // URL hình ảnh
//                   width: double.infinity,
//                   height: 300,
//                   fit: BoxFit.cover,
//                 )
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
//               Positioned(
//                 bottom: 10,
//                 left: MediaQuery.of(context).size.width / 2 - 60,
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
//                   decoration: BoxDecoration(
//                     color: AppColors.primaryColor,
//                     borderRadius: BorderRadius.circular(20),
//                   ),
//                   child: const Text(
//                     "⭐ 4.8 (1k+ Review)",
//                     style: TextStyle(color: AppColors.whiteColor),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//
//           // Salon info
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//             child: Align(
//               alignment: Alignment.centerLeft,
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     widget.cateName,
//                     style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     description,
//                     style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//
//           // Services list scrollable
//           Expanded(
//             child: FutureBuilder<List<ServiceModel>>(
//               future: _futureServices,
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting) {
//                   return const Center(child: CircularProgressIndicator());
//                 } else if (snapshot.hasError) {
//                   return Center(child: Text('Error: ${snapshot.error}'));
//                 } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
//                   return const Center(child: Text('No services found'));
//                 }
//
//                 final services = snapshot.data!;
//                 return ListView.builder(
//                   padding: const EdgeInsets.all(12),
//                   itemCount: services.length,
//                   itemBuilder: (context, index) {
//                     return serviceItem(services[index]);
//                   },
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//       bottomNavigationBar: Padding(
//         padding: const EdgeInsets.all(24),
//         child: ElevatedButton(
//           style: ElevatedButton.styleFrom(
//             backgroundColor: selectedService != null
//                 ? AppColors.primaryColor
//                 : AppColors.mistBlueColor, // disable khi chưa chọn
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(20),
//             ),
//             padding: const EdgeInsets.symmetric(vertical: 10),
//           ),
//           onPressed: selectedService != null
//               ? () {
//             Navigation.push(
//               context,
//               SallonBooking(
//                 imageUrl: widget.imageUrl,
//                 cateName: selectedService!.name,
//                 des: description,
//                 serviceName: selectedService!.name,
//                 staffList: selectedService!.staffList,
//                 serviceId: selectedService!.id,
//                 storeId: widget.storeId
//               ),
//             );
//           }
//               : null,
//           child: Text(
//             selectedService != null ? "Schedule" : "Schedule",
//             style: const TextStyle(fontSize: 16, color: AppColors.whiteColor),
//           ),
//         ),
//       ),
//     );
//   }
// }
