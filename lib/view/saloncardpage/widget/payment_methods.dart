// import 'package:flutter/material.dart';
// import 'package:flutter_svg/flutter_svg.dart';
// import 'package:hair_sallon/utils/app_colors/app_colors.dart';
// import 'package:hair_sallon/utils/navigation/navigation_file.dart';
//
// import 'package:hair_sallon/widgets/common_appbar/common_appbar.dart';
//
// class PaymentMethods extends StatefulWidget {
//   const PaymentMethods({super.key});
//
//   @override
//   State<PaymentMethods> createState() => _PaymentMethodState();
// }
//
// class _PaymentMethodState extends State<PaymentMethods> {
//   String _selectedMethod = 'Cash';
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.whiteColor,
//       appBar: ComAppbar(
//         bgColor: AppColors.whiteColor,
//         title: "Payment Method",
//         elevation: 0.0,
//         centerTitle: true,
//         isTitleBold: true,
//         iconTheme: const IconThemeData(color: AppColors.whiteColor),
//         leading: GestureDetector(
//           onTap: () {
//             Navigation.pop(context);
//           },
//           child: Transform.scale(
//             scale: 0.5,
//             child: SvgPicture.asset(
//               'assets/icon/back-button.svg',
//               colorFilter: const ColorFilter.mode(
//                 AppColors.blackColor,
//                 BlendMode.srcIn,
//               ),
//             ),
//           ),
//         ),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(12),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const SizedBox(height: 5),
//             const Text('Pay On Cash', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 5),
//             _buildPaymentTile('Cash', Icons.currency_rupee),
//
//             const SizedBox(height: 10),
//             const Text('Credit & Debit Card', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 5),
//             _buildPaymentTile('Card', Icons.add_card_outlined),
//
//             const SizedBox(height: 10),
//             const Text('More Payment Options', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//             const SizedBox(height: 5),
//             _buildPaymentTile('Paypal', Icons.paypal),
//             const SizedBox(height: 5),
//             _buildPaymentTile('Apple Pay', Icons.payments_sharp),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildPaymentTile(String method, IconData icon) {
//     return Container(
//       margin: const EdgeInsets.symmetric(vertical: 4),
//       decoration: BoxDecoration(
//         color: AppColors.whiteColor,
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: AppColors.blackColor.withOpacity(0.05),
//             blurRadius: 6,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: ListTile(
//         leading: Icon(icon,color: AppColors.primaryColor,),
//         title: Text(method),
//         trailing: Radio<String>(
//           value: method,
//           groupValue: _selectedMethod,
//           activeColor: AppColors.primaryColor,
//           onChanged: (value) {
//             setState(() {
//               _selectedMethod = value!;
//             });
//
//           },
//         ),
//         onTap: () {
//           setState(() {
//             _selectedMethod = method;
//           });
//         },
//       ),
//     );
//   }
// }



import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/utils/navigation/navigation_file.dart';
import 'package:hair_sallon/widgets/common_appbar/common_appbar.dart';

class PaymentMethods extends StatefulWidget {
  const PaymentMethods({super.key});

  @override
  State<PaymentMethods> createState() => _PaymentMethodState();
}

class _PaymentMethodState extends State<PaymentMethods> {
  String _selectedMethod = 'Cash';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      appBar: ComAppbar(
        bgColor: AppColors.whiteColor,
        title: "Payment Method",
        elevation: 0.0,
        centerTitle: true,
        isTitleBold: true,
        iconTheme: const IconThemeData(color: AppColors.whiteColor),
        leading: GestureDetector(
          onTap: () {
            Navigation.pop(context);
          },
          child: Transform.scale(
            scale: 0.5,
            child: SvgPicture.asset(
              'assets/icon/back-button.svg',
              colorFilter: const ColorFilter.mode(
                AppColors.blackColor,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            const Text('Pay On Cash', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            _buildPaymentTile(
              'Cash',
              const Icon(Icons.currency_rupee, color: AppColors.primaryColor),
            ),

            const SizedBox(height: 10),
            const Text('Credit & Debit Card', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            _buildPaymentTile(
              'Card',
              const Icon(Icons.add_card_outlined, color: AppColors.darkSkyBlueColor),
            ),

            const SizedBox(height: 10),
            const Text('More Payment Options', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            _buildPaymentTile(
              'Paypal',
              const Icon(Icons.paypal, color: AppColors.persianBlueColor),
            ),
            const SizedBox(height: 5),
            _buildPaymentTile(
              'Apple Pay',
              const Icon(Icons.payments_sharp, color: AppColors.greenColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentTile(String method, Widget leadingIcon) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackColor.withAlpha(13),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: leadingIcon,
        title: Text(method),
        trailing: Radio<String>(
          value: method,
          groupValue: _selectedMethod,
          activeColor: AppColors.primaryColor,
          onChanged: (value) {
            setState(() {
              _selectedMethod = value!;
            });
          },
        ),
        onTap: () {
          setState(() {
            _selectedMethod = method;
          });
        },
      ),
    );
  }
}
