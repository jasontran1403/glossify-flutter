import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/utils/navigation/navigation_file.dart';
import 'package:hair_sallon/view/sign_in/sign_in.dart';
import 'package:intl/intl.dart';

import '../../api/api_service.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();

  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _dobFocus = FocusNode();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      FocusScope.of(context).unfocus();
    });

    // Add listener to format phone number
    _phoneController.addListener(_formatPhoneNumber);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _dobController.dispose();
    _phoneFocus.dispose();
    _nameFocus.dispose();
    _passwordFocus.dispose();
    _dobFocus.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

  void _clearPassword() {
    _passwordController.clear();
  }

  // ===== PHONE NUMBER FORMATTER =====
  void _formatPhoneNumber() {
    final text = _phoneController.text;
    final digitsOnly = text.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.length <= 10) {
      String formatted = '';

      if (digitsOnly.isNotEmpty) {
        // First 3 digits
        formatted = '(${digitsOnly.substring(0, digitsOnly.length.clamp(0, 3))}';

        if (digitsOnly.length > 3) {
          // Next 3 digits
          formatted += ') ${digitsOnly.substring(3, digitsOnly.length.clamp(3, 6))}';

          if (digitsOnly.length > 6) {
            // Last 4 digits
            formatted += '-${digitsOnly.substring(6, digitsOnly.length.clamp(6, 10))}';
          }
        }
      }

      // Only update if different to avoid cursor jumping
      if (formatted != text) {
        _phoneController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    }
  }

  // ===== DATE PICKER =====
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = DateFormat('MM/dd/yyyy').format(picked);
      });
    }
  }

  // ===== CUSTOM SNACKBAR =====
  void _showCustomSnackBar(BuildContext context, String message, bool isSuccess) {
    final Color textColor = isSuccess ? Colors.green : Colors.red;

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
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  // ===== VALIDATION =====
  String? _validatePhone(String phone) {
    final digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) {
      return 'Phone number is required';
    }
    if (digitsOnly.length != 10) {
      return 'Phone number must be 10 digits';
    }
    return null;
  }

  String? _validateName(String name) {
    if (name.trim().isEmpty) {
      return 'Full name is required';
    }
    if (name.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  String? _validatePassword(String password) {
    if (password.isEmpty) {
      return 'Password is required';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? _validateDOB(String dob) {
    if (dob.isEmpty || _selectedDate == null) {
      return 'Date of birth is required';
    }

    // Check if user is at least 13 years old
    final now = DateTime.now();
    final age = now.year - _selectedDate!.year;
    if (age < 13 || (age == 13 && now.month < _selectedDate!.month) ||
        (age == 13 && now.month == _selectedDate!.month && now.day < _selectedDate!.day)) {
      return 'You must be at least 13 years old';
    }

    return null;
  }

  // ===== HANDLE SIGN UP =====
  Future<void> _handleSignUp() async {
    FocusScope.of(context).unfocus();

    // Validate all fields
    final phoneError = _validatePhone(_phoneController.text);
    final nameError = _validateName(_nameController.text);
    final passwordError = _validatePassword(_passwordController.text);
    final dobError = _validateDOB(_dobController.text);

    if (phoneError != null) {
      _showCustomSnackBar(context, phoneError, false);
      return;
    }
    if (nameError != null) {
      _showCustomSnackBar(context, nameError, false);
      return;
    }
    if (passwordError != null) {
      _showCustomSnackBar(context, passwordError, false);
      return;
    }
    if (dobError != null) {
      _showCustomSnackBar(context, dobError, false);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // ⭐ PREPARE DATA FOR API
      final phoneDigitsOnly = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
      final formattedPhone = '+1$phoneDigitsOnly'; // Add country code for API
      final formattedDOB = _selectedDate != null
          ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
          : '';

      final result = await ApiService.registerUser(phoneNumber: formattedPhone, fullName: _nameController.text, email: "", dob: formattedDOB, password: _passwordController.text);

      print(result);

      // ⭐ FAKE API CALL (3 seconds delay)
      await Future.delayed(const Duration(milliseconds: 1200));

      // ⭐ SIMULATE SUCCESS RESPONSE
      final fakeSuccess = true; // Change to false to test error

      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;

      if (fakeSuccess) {
        _showCustomSnackBar(
          context,
          'Account created successfully! Please sign in.',
          true,
        );

        // Wait for snackbar to show, then navigate
        await Future.delayed(const Duration(milliseconds: 1500));

        if (!mounted) return;

        Navigation.pushReplacement(
          context,
          const SignInScreen(),
        );
      } else {
        _showCustomSnackBar(
          context,
          'Failed to create account. Please try again.',
          false,
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;

      _showCustomSnackBar(
        context,
        'An error occurred: $e',
        false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.porcelainColor,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = constraints.maxWidth;
              final isWideScreen = screenWidth > 600;

              final signUpCard = SingleChildScrollView(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: isWideScreen ? 40 : 60),

                    // ===== HEADER =====
                    const Center(
                      child: Text(
                        'Create Account',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Center(
                      child: Text(
                        'Fill your information below',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.mistBlueColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // ===== PHONE NUMBER =====
                    // ===== PHONE NUMBER =====
                    // ===== PHONE NUMBER =====
                    const Text(
                      'Phone Number',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _phoneController,
                      focusNode: _phoneFocus,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: '+1 (123) 456-7890',
                        // ⭐ +1 PREFIX - SAME BACKGROUND
                        prefix: Container(
                          margin: const EdgeInsets.only(right: 2),
                          padding: const EdgeInsets.only(right: 2),
                          child: const Text(
                            '+1',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ===== FULL NAME =====
                    const Text(
                      'Full Name',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _nameController,
                      focusNode: _nameFocus,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'John Doe',
                        prefixIcon: Icon(Icons.person, size: 20),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ===== DATE OF BIRTH =====
                    const Text(
                      'Date of Birth',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _dobController,
                      focusNode: _dobFocus,
                      readOnly: true,
                      onTap: () => _selectDate(context),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: 'MM/DD/YYYY',
                        prefixIcon: const Icon(Icons.calendar_today, size: 20),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.event, size: 20),
                          onPressed: () => _selectDate(context),
                          padding: EdgeInsets.zero,
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ===== PASSWORD =====
                    const Text(
                      'Password',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      decoration: InputDecoration(
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: _clearPassword,
                              padding: EdgeInsets.zero,
                            ),
                            IconButton(
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                size: 20,
                              ),
                              onPressed: _togglePasswordVisibility,
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                        border: const OutlineInputBorder(),
                        hintText: '••••••••',
                        prefixIcon: const Icon(Icons.lock, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 12,
                        ),
                      ),
                      obscureText: !_isPasswordVisible,
                    ),
                    const SizedBox(height: 8),

                    // Password hint
                    Text(
                      'At least 6 characters',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // ===== SIGN UP BUTTON =====
                    GestureDetector(
                      onTap: _isLoading ? null : _handleSignUp,
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
                            ),
                          )
                              : const Text(
                            'Sign Up',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 35),

                    // ===== SIGN IN LINK =====
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          Navigation.pop(context);
                        },
                        child: RichText(
                          text: const TextSpan(
                            text: 'Already have an account?',
                            style: TextStyle(color: Colors.black),
                            children: [
                              TextSpan(
                                text: '  Sign In',
                                style: TextStyle(
                                  color: AppColors.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
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

              // ===== RESPONSIVE LAYOUT =====
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
                      child: signUpCard,
                    ),
                  ),
                ),
              )
                  : signUpCard;
            },
          ),
        ),
      ),
    );
  }
}