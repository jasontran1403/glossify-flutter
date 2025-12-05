import 'package:flutter/material.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/utils/local_images/local_images.dart';
import 'package:hair_sallon/utils/navigation/navigation_file.dart';
import '../bottombar_screen/bottomscreen_view_user.dart';

class SplashSuccess extends StatefulWidget {
  const SplashSuccess({super.key});

  @override
  State<SplashSuccess> createState() => _SplashSuccessState();
}

class _SplashSuccessState extends State<SplashSuccess>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  late AnimationController dotsController;

  @override
  void initState() {
    super.initState();

    // ---- Scale + Fade animation ----
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();

    // ---- Dots animation ----
    dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    // Auto navigate
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigation.pushReplacement(context, const BottomNavBarView());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.whiteColor, AppColors.primaryColor],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            const Spacer(),
            ScaleTransition(
              scale: _animation,
              child: FadeTransition(
                opacity: _animation,
                child: Column(
                  children: [
                    // === Logo cũ ===
                    Container(
                      height: 240,
                      width: 150,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage(AppImages.splash),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Text success
                    const Text(
                      "Welcome back",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 3 chấm nhảy lên xuống
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
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _jumpingDot(double delay) {
    return AnimatedBuilder(
      animation: dotsController,
      builder: (_, __) {
        double progress = (dotsController.value + delay) % 1.0;
        double offset = -10 * (1 - (progress * 2 - 1).abs());
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
