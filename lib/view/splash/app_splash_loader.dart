import 'package:flutter/material.dart';
import 'package:hair_sallon/view/splash/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hair_sallon/view/bottombar_screen/bottomscreen_view_user.dart';
import 'package:hair_sallon/view/get_started/get_started.dart';
import 'package:hair_sallon/utils/navigation/navigation_file.dart';

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
    // Hiển thị SplashScreen trong 2.2s (animation của bạn)
    await Future.delayed(const Duration(seconds: 2));

    // Check token
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("accessToken");

    // Chuyển màn hình
    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      Navigation.pushReplacement(context, const BottomNavBarView());
    } else {
      Navigation.pushReplacement(context, const GetStarted());
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen(); // UI splashscreen cũ của bạn
  }
}
