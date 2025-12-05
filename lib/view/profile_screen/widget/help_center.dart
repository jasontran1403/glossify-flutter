import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/utils/navigation/navigation_file.dart';
import 'package:hair_sallon/widgets/common_appbar/common_appbar.dart';

class HelpCenter extends StatefulWidget {
  const HelpCenter({super.key});

  @override
  State<HelpCenter> createState() => _HelpCenterState();
}

class _HelpCenterState extends State<HelpCenter> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.whiteColor,
        appBar: ComAppbar(
          bgColor: AppColors.whiteColor,
          title: "Help Center",
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
                colorFilter: ColorFilter.mode(
                  AppColors.blackColor,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          bottom: TabBar(
            indicatorColor: AppColors.primaryColor,
            labelColor: AppColors.primaryColor,
            unselectedLabelColor: AppColors.mistBlueColor,
            tabs: const [Tab(text: "FAQ"), Tab(text: "Contact Us")],
          ),
        ),
        body: const TabBarView(children: [_FAQTab(), _ContactTab()]),
      ),
    );
  }
}

class _FAQTab extends StatelessWidget {
  const _FAQTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        FAQItem(
          question: "How can I reset my password?",
          answer:
              "Go to the login screen and tap on 'Forgot Password'. Follow the instructions sent to your email.",
        ),
        FAQItem(
          question: "How do I book an appointment?",
          answer:
              "Navigate to the booking section from the bottom menu, choose your service and confirm the time.",
        ),
        FAQItem(
          question: "Can I cancel my booking?",
          answer:
              "Yes, you can cancel your booking up to 1 hour before the scheduled time via your bookings tab.",
        ),
      ],
    );
  }
}

class FAQItem extends StatelessWidget {
  final String question;
  final String answer;

  const FAQItem({super.key, required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 8.0),
      title: Text(
        question,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(answer, style: const TextStyle(color: Colors.black54)),
        ),
      ],
    );
  }
}

class _ContactTab extends StatelessWidget {
  const _ContactTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Need help?",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Reach out to us anytime. We are here to help you.",
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          const ContactTile(
            icon: Icons.phone,
            title: "Call Us",
            subtitle: "+1-(219)-661-1636",
          ),
          const ContactTile(
            icon: Icons.email,
            title: "Email",
            subtitle: "crownpointnails@gmail.com",
          ),
          const ContactTile(
            icon: Icons.location_on,
            title: "Visit Us",
            subtitle:
                "1302 North Main Street #6, Crown Point, IN 46307, USA",
          ),
        ],
      ),
    );
  }
}

class ContactTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const ContactTile({super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryColor.withAlpha(25),
          child: Icon(icon, color: AppColors.primaryColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
      ),
    );
  }
}
