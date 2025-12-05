import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/utils/navigation/navigation_file.dart';
import 'package:hair_sallon/widgets/common_appbar/common_appbar.dart';

class PrivacyPolicy extends StatefulWidget {
  const PrivacyPolicy({super.key});

  @override
  State<PrivacyPolicy> createState() => _PrivacyPolicyState();
}

class _PrivacyPolicyState extends State<PrivacyPolicy> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      appBar: ComAppbar(
        bgColor: AppColors.whiteColor,
        title: "Privacy Policy",
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              // Privacy Policy
              Text(
                "Privacy Policy",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryColor,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '''We value your privacy and are committed to protecting your personal information. We collect and use your data only for providing and improving our services.

Information such as name, email, phone number, and usage data may be collected. Your data is stored securely and never shared with third parties without consent.

You have full control over your data. You may request to update or delete your data at any time.

By using our services, you agree to the terms of this Privacy Policy.''',
                style: TextStyle(fontSize: 16),
              ),

              SizedBox(height: 24),

              // Cancellation Policy
              Text(
                "Cancellation Policy",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryColor,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '''You may cancel your appointment up to 24 hours before the scheduled time for a full refund.

Cancellations made within 24 hours of the appointment may be subject to a partial charge.

In case of no-show or same-day cancellation, the full amount will be charged.

To cancel or reschedule, please use the app or contact our support team directly.''',
                style: TextStyle(fontSize: 16),
              ),

              SizedBox(height: 24),

              // Terms & Conditions
              Text(
                "Terms & Conditions",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryColor,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '''By using this app, you agree to the following terms:

1. You will use the services for lawful purposes only.
2. All appointments and transactions must be made through the app.
3. We reserve the right to refuse service for violations of our policies.
4. All content in the app is protected and may not be copied or reused without permission.
5. Prices and services are subject to change without prior notice.

Continued use of the app means you accept these terms.''',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
