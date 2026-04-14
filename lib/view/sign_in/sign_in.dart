import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/utils/common_string/string.dart';
import 'package:hair_sallon/utils/navigation/navigation_file.dart';
import 'package:hair_sallon/view/create_account/create_account_screen.dart';
import 'package:hair_sallon/view/forgot_pass/forgot_pass.dart';

import '../../api/api_service.dart';
import '../splash/success_login_splash.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController usernamecontroller = TextEditingController();
  final TextEditingController passwordcontroller = TextEditingController();
  bool _isPasswordVisible = false; // State for toggle visibility
  final FocusNode emailFocus = FocusNode();
  final FocusNode passwordFocus = FocusNode();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      FocusScope.of(context).unfocus();
    });
  }

  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

  // Handler for clear password
  void _clearPassword() {
    passwordcontroller.clear();
  }

  // ===== CUSTOM SNACKBAR =====
  void _showCustomSnackBar(BuildContext context, String message, int code) {
    final Color textColor = code == 900 ? Colors.green : Colors.red;

    final snackBar = SnackBar(
      content: Text(
        message,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 6.0,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: textColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      duration: const Duration(seconds: 2),
      margin: EdgeInsets.only(
        bottom: MediaQuery.of(context).size.height - 150,
        left: 20,
        right: 20,
      ),
      dismissDirection: DismissDirection.up,
      action: code == 900
          ? SnackBarAction(
        label: 'OK',
        textColor: Colors.green,
        onPressed: () {
          // chỉ đóng snackbar, không điều hướng tại đây
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        },
      )
          : null,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  // ======== HANDLE LOGIN ========
  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();

    if (usernamecontroller.text.isEmpty || passwordcontroller.text.isEmpty) {
      _showCustomSnackBar(context, AppStrings.bothNotifcation, 0);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.login(
        username: usernamecontroller.text,
        password: passwordcontroller.text,
        fullName: "",
        email: "",
        phoneNumber: "",
      );

      setState(() {
        _isLoading = false;
      });

      if (result["message"] == "Login successful") {
        final role = result["data"]?["role"]?.toString() ?? "";

        if ([
          "STAFF",
          "USER",
          "OWNER",
          "SUPER_OWNER",
          "ADMIN",
          "RECEPTIONIST",
          "FRONTDESK"
        ].contains(role)) {

          // Không show snack bar nữa — chuyển sang splash thành công
          Navigation.pushReplacement(
            context,
            const SplashSuccess(),
          );

        } else {
          _showCustomSnackBar(
            context,
            "Access denied. Only authorized user allowed.",
            0,
          );
        }

      } else {
        _showCustomSnackBar(
          context,
          result["message"] ?? "Login failed",
          0,
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      _showCustomSnackBar(context, "An error occurred: $e", 0);
    }
  }

  // ========== UI ==========

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Nếu màn hình rộng (tablet/landscape)
    final isWideScreen = screenWidth > 600;

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: isWideScreen ? 40 : screenHeight * 0.08),
          const Center(
            child: Text(AppStrings.login, style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(height: 5),
          Center(
            child: Text(
              AppStrings.welcomeBack,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.mistBlueColor,
              ),
            ),
          ),
          const SizedBox(height: 30),

          // Email
          const Text(AppStrings.email),
          TextField(
            controller: usernamecontroller,
            focusNode: emailFocus,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: AppStrings.emailDemo,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            ),
          ),
        const SizedBox(height: 20),

          // Password
        const Text(AppStrings.password),
        TextField(
          controller: passwordcontroller,
          focusNode: passwordFocus,
          decoration: InputDecoration(
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Clear button
                IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: _clearPassword,
                  padding: EdgeInsets.zero,
                ),
                // Eye icon for toggle
                IconButton(
                  icon: Icon(
                    _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                  ),
                  onPressed: _togglePasswordVisibility,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            border: const OutlineInputBorder(),
            hintText: '••••••••',
            isDense: true,
          ),
          obscureText: !_isPasswordVisible, // Toggle based on state
        ),

          const SizedBox(height: 20),

          Align(
            alignment: Alignment.topRight,
            child: InkWell(
              onTap: () {
                Navigation.push(context, ForgotPasswordScreen());
              },
              child: const Text(
                AppStrings.forgotpassword,
                style: TextStyle(color: AppColors.primaryColor),
              ),
            ),
          ),

          const SizedBox(height: 30),

          // Login Button
          GestureDetector(
            onTap: _isLoading ? null : _handleLogin,
            child: Container(
              height: 45,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                color: _isLoading
                    ? AppColors.primaryColor.withOpacity(0.7)
                    : AppColors.primaryColor,
              ),
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ))
                    : const Text(
                  AppStrings.login,
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ),

          Center(
            child: GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
                Navigation.push(context, const CreateAccountScreen());
              },
              child: RichText(
                text: const TextSpan(
                  text: 'Don\'t have an Account?',
                  style: TextStyle(color: Colors.black),
                  children: [
                    TextSpan(
                      text: '  Sign Up ',
                      style: TextStyle(color: AppColors.primaryColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.porcelainColor, // xanh nhạt làm nền
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = constraints.maxWidth;
              final isWideScreen = screenWidth > 600;

              final loginCard = SingleChildScrollView(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: isWideScreen ? 40 : 60),
                    const Center(
                      child: Text(AppStrings.login, style: TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(height: 5),
                    Center(
                      child: Text(
                        AppStrings.welcomeBack,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.mistBlueColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Email
                    const Text(AppStrings.emailDemo),
                    TextField(
                      controller: usernamecontroller,
                      focusNode: emailFocus,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: AppStrings.emailDemo,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Password
                    const Text(AppStrings.password),
                  TextField(
                    controller: passwordcontroller,
                    focusNode: passwordFocus,
                    decoration: InputDecoration(
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Clear button
                          IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: _clearPassword,
                            padding: EdgeInsets.zero,
                          ),
                          // Eye icon for toggle
                          IconButton(
                            icon: Icon(
                              _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                              size: 20,
                            ),
                            onPressed: _togglePasswordVisibility,
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                      border: const OutlineInputBorder(),
                      hintText: '••••••••',
                      isDense: true,
                    ),
                    obscureText: !_isPasswordVisible, // Toggle based on state
                  ),

                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.topRight,
                      child: InkWell(
                        onTap: () => Navigation.push(context, ForgotPasswordScreen()),
                        child: const Text(
                          AppStrings.forgotpassword,
                          style: TextStyle(color: AppColors.primaryColor),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Login Button
                    GestureDetector(
                      onTap: _isLoading ? null : _handleLogin,
                      child: Container(
                        height: 45,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          color: _isLoading
                              ? AppColors.primaryColor.withOpacity(0.7)
                              : AppColors.primaryColor,
                        ),
                        child: Center(
                          child: _isLoading
                              ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ))
                              : const Text(
                            AppStrings.login,
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 35),

                    Center(
                      child: GestureDetector(
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          Navigation.push(context, const CreateAccountScreen());
                        },
                        child: RichText(
                          text: const TextSpan(
                            text: 'Don\'t have an Account?',
                            style: TextStyle(color: Colors.black),
                            children: [
                              TextSpan(
                                text: '  Sign Up',
                                style: TextStyle(color: AppColors.primaryColor),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              );

              // Nếu tablet / width lớn, wrap form trong frosted card
              return isWideScreen
                  ? Center(
                child: Container(
                  width: 500,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.dawnPinkColor.withOpacity(0.08),
                        AppColors.primaryColor.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: loginCard,
                    ),
                  ),
                ),
              )
                  : loginCard;
            },
          ),
        ),
      ),
    );
  }

  // ===== Helper Widget =====
  Widget socialIcon(String asset) {
    return Container(
      height: 40,
      width: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: CircleAvatar(
        backgroundColor: Colors.white,
        child: ClipOval(
          child: Image.asset(asset, height: 28, width: 28),
        ),
      ),
    );
  }
}
