import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/utils/local_images/local_images.dart';
import 'package:hair_sallon/utils/navigation/navigation_file.dart';
import 'package:hair_sallon/view/get_started/get_started.dart';
import 'package:hair_sallon/view/bottombar_screen/bottomscreen_view_user.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController logoController;
  late Animation<double> logoScale;
  late Animation<double> logoFade;

  late AnimationController dotsController;

  @override
  void initState() {
    super.initState();

    // ---- Logo animation ----
    logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: logoController, curve: Curves.easeOutBack),
    );

    logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: logoController, curve: Curves.easeIn),
    );

    logoController.forward();

    // ---- Dots animation (nhảy lên xuống) ----
    dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    // Navigate after 3s
    Future.delayed(const Duration(seconds: 3), _handleNavigation);
  }

  Future<void> _handleNavigation() async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("accessToken");

    if (token != null && token.isNotEmpty) {
      Navigation.pushReplacement(context, const BottomNavBarView());
    } else {
      Navigation.pushReplacement(context, const GetStarted());
    }
  }

  @override
  void dispose() {
    logoController.dispose();
    dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(seconds: 3),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryColor.withOpacity(0.2),
              AppColors.primaryColor,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ---- Logo ----
            ScaleTransition(
              scale: logoScale,
              child: FadeTransition(
                opacity: logoFade,
                child: Container(
                  height: 200,
                  width: 140,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(AppImages.splash),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // ---- Text ----
            const Text(
              "CP Nails & Spa",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 30),

            // ---- 3 dots jumping ----
            AnimatedBuilder(
              animation: dotsController,
              builder: (_, __) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _jumpingDot(0),
                    const SizedBox(width: 8),
                    _jumpingDot(0.2),
                    const SizedBox(width: 8),
                    _jumpingDot(0.4),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _jumpingDot(double delay) {
    return AnimatedBuilder(
      animation: dotsController,
      builder: (_, __) {
        double progress =
            (dotsController.value + delay) % 1.0; // offset từng dot
        double offset = -10 * (1 - (progress * 2 - 1).abs()); // nhảy lên xuống
        return Transform.translate(
          offset: Offset(0, offset),
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
