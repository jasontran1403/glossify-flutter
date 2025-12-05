import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/utils/navigation/navigation_file.dart';
import 'package:hair_sallon/view/bokking_screen/widgets/e_recipt_screen.dart';
import 'package:hair_sallon/view/saloncardpage/widget/payment_methods.dart';
import 'package:hair_sallon/widgets/common_appbar/common_appbar.dart';


class ReviewSummaryScreen extends StatelessWidget {
  final Color redColor = Color(0xFFEF5350);

  ReviewSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor, // light background
      appBar: ComAppbar(
        bgColor: AppColors.whiteColor,
        title: "Review Summary",
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildInfoCard(),
              SizedBox(height: 10),
              _buildInfoCard1(),
              SizedBox(height: 10,),
              _buildPaymentMethod(context),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
          onPressed: () {
            Navigation.push(context, EReciptScreen());
          },
          child: const Text("Confirm Payment", style: TextStyle(fontSize: 16,color: AppColors.whiteColor)),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            // color: AppColors.blackColor.withOpacity(0.05),
            color: AppColors.blackColor.withAlpha(13),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Barber/Salon', 'Glamour Haven'),
          _buildInfoRow('Address', 'G8502 Preston Rd. Inglewood'),
          _buildInfoRow('Name', 'Esther Howard'),
          _buildInfoRow('Phone', '629.555.0129'),
          _buildInfoRow('Booking Date', 'August 23, 2023'),
          _buildInfoRow('Booking Hours', '10:00 AM'),
          _buildInfoRow('Specialist', 'Nathan Alexander', bold: true),
        ],
      ),
    );
  }

  Widget _buildInfoCard1() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            // color: AppColors.blackColor.withOpacity(0.05),
            color: AppColors.blackColor.withAlpha(13),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow1('Haircut (Quiff)', '\$60.00'),
          _buildInfoRow1('Hair Wash (Aloe Vera Shampoo)', '\$80.00'),
          _buildInfoRow1('Shaving (Thin Shaving)', '\$30.00'),
          SizedBox(height: 10),
          _buildInfoRow1('Total', '\$30.00', bold: true),
        ],
      ),
    );
  }

  Widget _buildInfoRow1(String title, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(
              title,
              maxLines: 1,
              style: TextStyle(fontSize: 14))),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(
              title,
              maxLines: 1,
              style: TextStyle(fontSize: 14))),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethod(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.mistBlueColor),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: AppColors.primaryColor),
              SizedBox(width: 8),
              Text("Cash", style: TextStyle(fontSize: 14)),
            ],
          ),
          GestureDetector(
            onTap: (){
              Navigation.push(context, PaymentMethods());
            },
              child: Text("Change", style: TextStyle(color: AppColors.primaryColor, fontSize: 14))),
        ],
      ),
    );
  }
}