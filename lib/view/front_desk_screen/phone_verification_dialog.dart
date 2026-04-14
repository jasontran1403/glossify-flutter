import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../api/api_service.dart';
import '../../utils/app_colors/app_colors.dart';

class PhoneVerificationDialog extends StatefulWidget {
  const PhoneVerificationDialog({super.key});

  @override
  State<PhoneVerificationDialog> createState() =>
      _PhoneVerificationDialogState();
}

class _PhoneVerificationDialogState extends State<PhoneVerificationDialog> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();

  bool _isLoading = false;
  bool _showRegistration = false;
  String _phoneError = '';
  String _fullNameError = '';
  String _emailError = '';
  String _dobError = '';
  bool _isPhoneValid = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  String _formatPhoneNumber(String digits) {
    if (digits.isEmpty) return '';

    if (digits.startsWith('1') && digits.length == 1) {
      return '';
    }

    if (digits.length > 1) {
      digits = digits.substring(1);
    }

    if (digits.length > 11) {
      digits = digits.substring(0, 11);
    }

    if (digits.length <= 3) {
      return '+1 ($digits';
    } else if (digits.length <= 6) {
      return '+1 (${digits.substring(0, 3)}) ${digits.substring(3)}';
    } else {
      return '+1 (${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
    }
  }

  String _formatDOB(String digits) {
    if (digits.isEmpty) return '';

    // Remove all non-digits
    digits = digits.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.length > 8) {
      digits = digits.substring(0, 8);
    }

    if (digits.length <= 2) {
      return digits;
    } else if (digits.length <= 4) {
      return '${digits.substring(0, 2)}/${digits.substring(2)}';
    } else {
      return '${digits.substring(0, 2)}/${digits.substring(2, 4)}/${digits.substring(4)}';
    }
  }

  void _validatePhone(String phone) {
    final cleanedPhone = phone.replaceAll(RegExp(r'[^\d]'), '');

    if (cleanedPhone.isEmpty) {
      setState(() {
        _phoneError = 'Phone number is required';
        _isPhoneValid = false;
      });
      return;
    }

    if (cleanedPhone.length != 11) {
      setState(() {
        _phoneError = 'Phone number must be 10 digits (not include +1)';
        _isPhoneValid = false;
      });
      return;
    }

    final areaCode = int.parse(cleanedPhone.substring(1, 4));
    if (areaCode < 200 || areaCode > 999) {
      setState(() {
        _phoneError = 'Invalid area code';
        _isPhoneValid = false;
      });
      return;
    }

    setState(() {
      _phoneError = '';
      _isPhoneValid = true;
    });
  }

  void _validateFullName(String name) {
    if (name.trim().isEmpty) {
      setState(() {
        _fullNameError = 'Full name is required';
      });
    } else if (name.trim().length < 2) {
      setState(() {
        _fullNameError = 'Full name must be at least 2 characters';
      });
    } else {
      setState(() {
        _fullNameError = '';
      });
    }
  }

  void _validateEmail(String email) {
    if (email.trim().isEmpty) {
      setState(() {
        _emailError = 'Email is required';
      });
      return;
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(email.trim())) {
      setState(() {
        _emailError = 'Please enter a valid email';
      });
    } else {
      setState(() {
        _emailError = '';
      });
    }
  }

  void _validateDOB(String dob) {
    if (dob.trim().isEmpty) {
      setState(() {
        _dobError = 'Date of birth is required';
      });
      return;
    }

    final dobRegex = RegExp(r'^\d{2}/\d{2}/\d{4}$');
    if (!dobRegex.hasMatch(dob)) {
      setState(() {
        _dobError = 'Please use MM/DD/YYYY format';
      });
      return;
    }

    final parts = dob.split('/');
    final month = int.tryParse(parts[0]);
    final day = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);

    if (month == null || day == null || year == null) {
      setState(() {
        _dobError = 'Invalid date format';
      });
      return;
    }

    if (month < 1 || month > 12) {
      setState(() {
        _dobError = 'Month must be between 01-12';
      });
      return;
    }

    // Check day based on month
    final daysInMonth = _getDaysInMonth(month, year);
    if (day < 1 || day > daysInMonth) {
      setState(() {
        _dobError = 'Invalid day for month $month';
      });
      return;
    }

    // Check if date is not in the future
    final now = DateTime.now();
    final dobDate = DateTime(year, month, day);
    if (dobDate.isAfter(now)) {
      setState(() {
        _dobError = 'Date of birth cannot be in the future';
      });
      return;
    }

    // Check if user is at least 13 years old (for COPPA compliance)
    final age = now.year - year;
    if (age < 13) {
      setState(() {
        _dobError = 'You must be at least 13 years old';
      });
      return;
    }

    setState(() {
      _dobError = '';
    });
  }

  int _getDaysInMonth(int month, int year) {
    if (month == 2) {
      return _isLeapYear(year) ? 29 : 28;
    }
    const daysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return daysInMonth[month - 1];
  }

  bool _isLeapYear(int year) {
    return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
  }

  Future<void> _handleContinue() async {
    if (!_isPhoneValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid phone number'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final cleanedPhone = _phoneController.text.replaceAll(
        RegExp(r'[^\d]'),
        '',
      );
      final result = await ApiService.checkUserByPhone(cleanedPhone);

      if (!mounted) return;

      if (result['exists'] == true) {
        // User exists, return userId and close dialog
        Navigator.of(context).pop({
          'success': true,
          'userId': result['userId'],
          'isNewUser': false,
        });
      } else {
        // User doesn't exist, show registration form
        setState(() {
          _showRegistration = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleRegister() async {
    // Validate all fields
    _validateFullName(_fullNameController.text);
    _validateEmail(_emailController.text);
    _validateDOB(_dobController.text);

    if (_fullNameError.isNotEmpty ||
        _emailError.isNotEmpty ||
        _dobError.isNotEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final cleanedPhone = _phoneController.text.replaceAll(
        RegExp(r'[^\d]'),
        '',
      );

      final result = await ApiService.registerUser(
        phoneNumber: cleanedPhone,
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        dob: _dobController.text.trim(), // Use the actual DOB value
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // Registration successful
        Navigator.of(
          context,
        ).pop({'success': true, 'userId': result['userId'], 'isNewUser': true});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result['message'] ?? 'Account created successfully!',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Registration failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.phone_android,
                      color: AppColors.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _showRegistration
                          ? 'Create Account'
                          : 'Enter Phone Number',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _isLoading ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                      shape: const CircleBorder(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Phone Number Field (always visible)
              TextFormField(
                controller: _phoneController,
                enabled: !_showRegistration && !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Phone Number *',
                  hintText: '+1 (XXX) XXX-XXXX',
                  errorText: _phoneError.isNotEmpty ? _phoneError : null,
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor:
                      _showRegistration ? Colors.grey[100] : Colors.white,
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
                onChanged: (value) {
                  final digits = value.replaceAll(RegExp(r'[^\d]'), '');
                  if (digits.length > 11) {
                    final trimmedDigits = digits.substring(0, 11);
                    _phoneController.text = _formatPhoneNumber(trimmedDigits);
                    _phoneController.selection = TextSelection.collapsed(
                      offset: _phoneController.text.length,
                    );
                    _validatePhone(trimmedDigits);
                    return;
                  }

                  final formatted = _formatPhoneNumber(digits);
                  if (formatted != _phoneController.text) {
                    _phoneController.text = formatted;
                    _phoneController.selection = TextSelection.collapsed(
                      offset: formatted.length,
                    );
                  }

                  _validatePhone(digits);
                },
              ),

              // Registration Fields (only show when _showRegistration is true)
              if (_showRegistration) ...[
                const SizedBox(height: 16),

                // Full Name Field
                TextFormField(
                  controller: _fullNameController,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    labelText: 'Full Name *',
                    hintText: 'Enter your full name',
                    errorText:
                        _fullNameError.isNotEmpty ? _fullNameError : null,
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  textCapitalization: TextCapitalization.words,
                  onChanged: _validateFullName,
                ),

                const SizedBox(height: 16),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    labelText: 'Email *',
                    hintText: 'your.email@example.com',
                    errorText: _emailError.isNotEmpty ? _emailError : null,
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: _validateEmail,
                ),

                const SizedBox(height: 16),

                // Date of Birth Field
                TextFormField(
                  controller: _dobController,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    labelText: 'Date of Birth *',
                    hintText: 'MM/DD/YYYY',
                    errorText: _dobError.isNotEmpty ? _dobError : null,
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      onPressed: () => _showDatePicker(),
                      icon: const Icon(Icons.calendar_month),
                    ),
                  ),
                  keyboardType: TextInputType.datetime,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  onChanged: (value) {
                    final formatted = _formatDOB(value);
                    if (formatted != _dobController.text) {
                      _dobController.text = formatted;
                      _dobController.selection = TextSelection.collapsed(
                        offset: formatted.length,
                      );
                    }
                    _validateDOB(formatted);
                  },
                ),

                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'We\'ll create an account for you',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  if (_showRegistration)
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _isLoading
                                ? null
                                : () {
                                  setState(() {
                                    _showRegistration = false;
                                    _fullNameController.clear();
                                    _emailController.clear();
                                    _dobController.clear();
                                    _fullNameError = '';
                                    _emailError = '';
                                    _dobError = '';
                                  });
                                },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Back',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  if (_showRegistration) const SizedBox(width: 12),
                  Expanded(
                    flex: _showRegistration ? 1 : 2,
                    child: ElevatedButton(
                      onPressed:
                          _isLoading
                              ? null
                              : (_showRegistration
                                  ? _handleRegister
                                  : _handleContinue),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            (_showRegistration
                                    ? (_fullNameError.isEmpty &&
                                        _emailError.isEmpty &&
                                        _dobError.isEmpty &&
                                        _fullNameController.text.isNotEmpty &&
                                        _emailController.text.isNotEmpty &&
                                        _dobController.text.isNotEmpty)
                                    : _isPhoneValid)
                                ? AppColors.primaryColor
                                : Colors.grey,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child:
                          _isLoading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : Text(
                                _showRegistration
                                    ? 'Create Account'
                                    : 'Continue',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDatePicker() async {
    if (_isLoading) return;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(
        const Duration(days: 365 * 20),
      ), // Default to 20 years ago
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryColor,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formattedDate =
          '${picked.month.toString().padLeft(2, '0')}/'
          '${picked.day.toString().padLeft(2, '0')}/'
          '${picked.year}';

      setState(() {
        _dobController.text = formattedDate;
        _validateDOB(formattedDate);
      });
    }
  }
}
