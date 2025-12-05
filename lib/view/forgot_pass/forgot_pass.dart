import 'package:flutter/material.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/api/api_service.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocus = FocusNode();
  bool _isLoading = false;
  bool _isSuccess = false;
  String _errorMessage = '';

  // Create mask formatter for US phone number
  final MaskTextInputFormatter _phoneFormatter = MaskTextInputFormatter(
    mask: '(###) ###-####',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      FocusScope.of(context).unfocus();
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  // ======== VALIDATE PHONE NUMBER ========
  bool _validatePhoneNumber() {
    final formattedPhone = _phoneController.text;
    final digits = formattedPhone.replaceAll(RegExp(r'[^\d]'), '');

    // Check if phone number has exactly 10 digits
    if (digits.length != 10) {
      _errorMessage = 'Phone number must be 10 digits';
      return false;
    }

    return true;
  }

  // ======== HANDLE FORGOT PASSWORD ========
  Future<void> _handleForgotPassword() async {
    FocusScope.of(context).unfocus();

    // Reset states
    setState(() {
      _isSuccess = false;
      _errorMessage = '';
    });

    final formattedPhone = _phoneController.text;
    final digitsOnly = formattedPhone.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your phone number';
      });
      return;
    }

    if (!_validatePhoneNumber()) {
      setState(() {
        _errorMessage = _errorMessage;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.forgotPassword(digitsOnly);

      setState(() {
        _isLoading = false;
      });

      if (response.isSuccess) {
        if (response.data == true) {
          setState(() {
            _isSuccess = true;
            _errorMessage = '';
          });
        } else {
          setState(() {
            _isSuccess = false;
            _errorMessage = response.message;
          });
        }
      } else {
        setState(() {
          _isSuccess = false;
          _errorMessage = response.message;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _errorMessage = 'Network error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.porcelainColor,
      appBar: AppBar(
        backgroundColor: AppColors.whiteColor,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Forgot Password",
          style: TextStyle(
            color: AppColors.blackColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.blackColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = constraints.maxWidth;
              final isWideScreen = screenWidth > 600;

              final content = SingleChildScrollView(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: isWideScreen ? 40 : 60),

                    // Title
                    const Center(
                      child: Text(
                        "Reset Your Password",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.blackColor,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Subtitle
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Text(
                          "Enter your registered phone number to reset your password",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.mistBlueColor,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Phone Number Input
                    const Padding(
                      padding: EdgeInsets.only(left: 4.0),
                      child: Text(
                        "Phone Number",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                        color: Colors.white,
                      ),
                      child: Row(
                        children: [
                          // Country Code
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.mistBlueColor.withOpacity(0.1),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                bottomLeft: Radius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "+1",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                          // Phone Number Field
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              focusNode: _phoneFocus,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [_phoneFormatter],
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: "(123) 456-7890",
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                hintStyle: TextStyle(color: Colors.grey),
                              ),
                              style: const TextStyle(
                                fontSize: 16,
                                letterSpacing: 0.5,
                              ),
                              onChanged: (_) {
                                // Clear error when user types
                                if (_errorMessage.isNotEmpty) {
                                  setState(() {
                                    _errorMessage = '';
                                  });
                                }
                              },
                              onSubmitted: (_) => _handleForgotPassword(),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Error message
                    if (_errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0, top: 8),
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.red,
                          ),
                        ),
                      ),

                    // Success message
                    if (_isSuccess)
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0, top: 8),
                        child: Text(
                          "Password reset instructions have been sent to your phone number",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green[700],
                          ),
                        ),
                      ),

                    const SizedBox(height: 40),

                    // Submit Button
                    GestureDetector(
                      onTap: _isLoading ? null : _handleForgotPassword,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          color: _isLoading
                              ? AppColors.primaryColor.withOpacity(0.7)
                              : AppColors.primaryColor,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isLoading
                              ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ))
                              : const Text(
                            "Reset Password",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Sign In Button (only show on success)
                    if (_isSuccess) ...[
                      const SizedBox(height: 20),

                      // Divider
                      Row(
                        children: const [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              "OR",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Sign In Button
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            color: Colors.white,
                            border: Border.all(
                              color: AppColors.primaryColor,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              "Sign In",
                              style: TextStyle(
                                fontSize: 18,
                                color: AppColors.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 40),
                  ],
                ),
              );

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
                    child: content,
                  ),
                ),
              )
                  : content;
            },
          ),
        ),
      ),
    );
  }
}