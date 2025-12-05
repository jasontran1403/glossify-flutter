import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/utils/navigation/navigation_file.dart';
import 'package:hair_sallon/widgets/common_appbar/common_appbar.dart';

class EReciptScreen extends StatefulWidget {
  const EReciptScreen({super.key});

  @override
  State<EReciptScreen> createState() => _EReciptScreenState();
}

class _EReciptScreenState extends State<EReciptScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor, // light background
      appBar: ComAppbar(
        bgColor: AppColors.whiteColor,
        title: "E-Receipt",
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Image.asset('assets/images/barcode.png',width: MediaQuery.of(context).size.width*0.63,),
              SizedBox(height: 10),
              _buildInfoCard(),
              SizedBox(height: 10),
              _buildInfoCard1(),
              SizedBox(height: 10),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
          onPressed: () {},
          child: const Text(
            "Download E-Receipt",
            style: TextStyle(fontSize: 16, color: AppColors.whiteColor),
          ),
        ),
      ),
    );
  }
}

Widget _buildInfoCard() {
  return Container(
    decoration: BoxDecoration(
      boxShadow: [
        BoxShadow(
          color: AppColors.blackColor.withAlpha(13),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
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
          color: AppColors.blackColor.withAlpha(13),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
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
        Flexible(
          child: Text(title, maxLines: 1, style: TextStyle(fontSize: 14)),
        ),
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
        Flexible(
          child: Text(title, maxLines: 1, style: TextStyle(fontSize: 14)),
        ),
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
