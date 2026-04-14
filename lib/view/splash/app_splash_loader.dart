import 'package:flutter/material.dart';
import 'package:hair_sallon/view/splash/splash_screen.dart';
import 'package:hair_sallon/view/bottombar_screen/bottomscreen_view_user.dart';
import 'package:hair_sallon/view/get_started/get_started.dart';
import 'package:hair_sallon/utils/navigation/navigation_file.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSplashLoader extends StatefulWidget {
  const AppSplashLoader({super.key});

  @override
  State<AppSplashLoader> createState() => _AppSplashLoaderState();
}

class _AppSplashLoaderState extends State<AppSplashLoader> {
  @override
  void initState() {
    super.initState();
    _process();
  }

  Future<void> _process() async {
    // Hiển thị SplashScreen trong 2s
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // ✅ Check if user has seen GetStarted screen
    final prefs = await SharedPreferences.getInstance();
    final hasSeenGetStarted = prefs.getBool('hasSeenGetStarted') ?? false;

    if (hasSeenGetStarted) {
      // ✅ User đã xem GetStarted → Chuyển thẳng BottomNavBarView
      Navigation.pushReplacement(context, const BottomNavBarView());
    } else {
      // ✅ Lần đầu → Hiển thị GetStarted
      Navigation.pushReplacement(context, const GetStarted());
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}