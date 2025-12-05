// lib/view/profile_screen/profile_view.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:hair_sallon/api/api_service.dart';
import 'package:hair_sallon/api/promotion_request_models.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/utils/local_images/local_images.dart';
import 'package:hair_sallon/utils/navigation/navigation_file.dart';
import 'package:hair_sallon/view/card_method/card_method.dart';
import 'package:hair_sallon/view/profile_screen/widget/savehistory.dart';
import 'package:hair_sallon/view/profile_screen/widget/settings.dart';
import 'package:hair_sallon/view/profile_screen/widget/help_center.dart';
import 'package:hair_sallon/view/profile_screen/widget/privacy_policy.dart';
import 'package:hair_sallon/view/splash/app_splash_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../widgets/common_appbar/common_appbar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  String _fullName = "User";
  String? _avatarPath;
  String _role = "USER"; // DEFAULT

  // Promotion Request State
  bool _hasPendingRequest = false;
  PromotionRequestResponse? _currentRequest;
  bool _isCheckingRequest = false;

  final ImagePicker _imagePicker = ImagePicker();

  Future<File> compressImage(File file) async {
    final filePath = file.absolute.path;
    final splitIndex = filePath.lastIndexOf('.');
    final outPath = filePath.substring(0, splitIndex) + '_compressed.jpg';

    final XFile? compressed = await FlutterImageCompress.compressAndGetFile(
      filePath,
      outPath,
      quality: 70,
      minWidth: 1080,
      minHeight: 1080,
    );

    if (compressed == null) {
      return file;
    }

    return File(compressed.path);
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _fullName = prefs.getString('fullName') ?? "User";
        _avatarPath = prefs.getString('avatarPath');
        _role = prefs.getString('role') ?? "USER";
      });

      // Check promotion request status if user is USER
      if (_role == "USER") {
        await _checkPromotionRequestStatus();
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _fullName = "User";
        _role = "USER";
      });
    }

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  // ============================================================================
  // PROMOTION REQUEST METHODS
  // ============================================================================

  Future<void> _checkPromotionRequestStatus() async {
    try {
      setState(() => _isCheckingRequest = true);

      // Check if has pending request
      final statusResponse = await ApiService.hasPendingPromotionRequest();

      if (statusResponse.isSuccess && statusResponse.data == true) {
        // Get user's requests to find the pending one
        final requestsResponse = await ApiService.getMyPromotionRequests();

        if (requestsResponse.isSuccess && requestsResponse.data != null) {
          final requests = requestsResponse.data!;

          // Find the most recent pending request
          final pendingRequest = requests.firstWhere(
                (req) => req.status == 'PENDING',
            orElse: () => requests.first,
          );

          setState(() {
            _hasPendingRequest = true;
            _currentRequest = pendingRequest;
          });
        }
      }
    } catch (e) {
      print('Error checking promotion request: $e');
    } finally {
      setState(() => _isCheckingRequest = false);
    }
  }

  Future<void> _showCreatePromotionRequestDialog() async {
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Become Staff'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Submit a request to become a staff member. '
                  'The admin will review your request.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Tell us why you want to become staff',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 200,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
            ),
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _createPromotionRequest(notesController.text.trim());
    }
  }

  Future<void> _createPromotionRequest(String notes) async {
    try {
      _showLoadingDialog();

      final response = await ApiService.createPromotionRequest(
        notes: notes.isEmpty ? null : notes,
      );

      Navigator.of(context, rootNavigator: true).pop(); // Close loading

      if (response.isSuccess && response.data != null) {
        setState(() {
          _hasPendingRequest = true;
          _currentRequest = response.data;
        });

        _showSuccessDialog('Request submitted successfully!\nPlease wait for admin approval.');
      } else {
        _showErrorDialog(response.message);
      }
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      _showErrorDialog('Failed to submit request: $e');
    }
  }

  Future<void> _showCancelRequestDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Request'),
        content: const Text(
          'Are you sure you want to cancel your staff promotion request?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true && _currentRequest != null) {
      await _cancelPromotionRequest();
    }
  }

  Future<void> _cancelPromotionRequest() async {
    if (_currentRequest == null) return;

    try {
      _showLoadingDialog();

      final response = await ApiService.cancelPromotionRequest(_currentRequest!.id);

      Navigator.of(context, rootNavigator: true).pop(); // Close loading

      if (response.isSuccess) {
        setState(() {
          _hasPendingRequest = false;
          _currentRequest = null;
        });

        _showSuccessDialog('Request cancelled successfully');
      } else {
        _showErrorDialog(response.message);
      }
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      _showErrorDialog('Failed to cancel request: $e');
    }
  }

  // ============================================================================
  // AVATAR METHODS
  // ============================================================================

  Future<void> _showImageSourceOptions() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Choose Photo Source",
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.camera_alt,
                        color: AppColors.primaryColor),
                  ),
                  title: const Text('Take Photo',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Use camera to take a photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromCamera();
                  },
                ),

                const Divider(),

                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.photo_library,
                        color: AppColors.primaryColor),
                  ),
                  title: const Text('Choose from Gallery',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Select photo from your library'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromGallery();
                  },
                ),

                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo == null) return;

      File imageFile = File(photo.path);
      await _uploadAvatar(imageFile);

    } catch (e) {
      _showErrorDialog("Failed to take photo: $e");
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      FilePickerResult? result =
      await FilePicker.platform.pickFiles(type: FileType.image);

      if (result == null) return;

      PlatformFile file = result.files.first;
      String? imagePath = file.path;

      if (imagePath == null) {
        Uint8List bytes = file.bytes!;
        imagePath =
        '/tmp/temp_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await File(imagePath).writeAsBytes(bytes);
      }

      File imageFile = File(imagePath);
      await _uploadAvatar(imageFile);

      if (imagePath.startsWith('/tmp/')) {
        try {
          await File(imagePath).delete();
        } catch (_) {}
      }

    } catch (e) {
      _showErrorDialog("Failed to pick image: $e");
    }
  }

  Future<void> _uploadAvatar(File originalFile) async {
    try {
      File compressedFile = await compressImage(originalFile);

      _showLoadingDialog();

      final prefs = await SharedPreferences.getInstance();
      final int? userId = prefs.getInt('id');
      if (userId == null) throw Exception("User ID not found");

      final response =
      await ApiService.uploadAvatar(userId, compressedFile.path);

      Navigator.of(context, rootNavigator: true).pop();

      if (response.success && response.avatarPath != null) {
        setState(() => _avatarPath = response.avatarPath);
        await prefs.setString('avatarPath', response.avatarPath!);
        _showSuccessDialog("Avatar uploaded successfully!");
      } else {
        _showErrorDialog(response.message);
      }

      if (compressedFile.path.contains("_compressed")) {
        try {
          await compressedFile.delete();
        } catch (_) {}
      }

    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      _showErrorDialog("Failed to upload avatar: $e");
    }
  }

  // ============================================================================
  // DIALOG METHODS
  // ============================================================================

  void _showLoadingDialog() {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Loading...'),
            ],
          ),
        ),
      );
    } catch (e) {}
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:
        const Icon(Icons.check_circle, color: Colors.green, size: 40),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Icon(Icons.error, color: Colors.red, size: 40),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  // ============================================================================
  // UI BUILD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.porcelainColor,
      appBar: ComAppbar(
        title: "Profile",
        bgColor: AppColors.whiteColor,
        isTitleBold: true,
        iconTheme: const IconThemeData(color: AppColors.whiteColor),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 20, left: 12, right: 12),
          child: _isLoading ? buildShimmerUI() : buildProfileUI(context),
        ),
      ),
    );
  }

  Widget buildProfileUI(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.whiteColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.blackColor.withAlpha(13),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              GestureDetector(
                onTap: _showImageSourceOptions,
                child: Stack(
                  children: [
                    ClipOval(
                      child: _avatarPath != null
                          ? Image.network(
                        '${_avatarPath}?v=${DateTime.now().millisecondsSinceEpoch}',
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (context, error, stackTrace) =>
                            CircleAvatar(
                              radius: 30,
                              backgroundImage:
                              AssetImage(AppImages.user),
                            ),
                      )
                          : CircleAvatar(
                        radius: 30,
                        backgroundImage:
                        AssetImage(AppImages.user),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fullName,
                      style: const TextStyle(
                        color: AppColors.blackColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // ONLY USER CAN SEE THESE
                if (_role == "USER") ...[
                  buildMenuItem(Icons.credit_card, "Gift Card", () {
                    Navigation.push(context, CardMethodScreen());
                  }),
                  buildMenuItem(Icons.favorite_border, "Saved", () {
                    Navigation.push(context, SavedListScreen());
                  }),

                  // ✅ BECOME STAFF WITH STATUS
                  _buildBecomeStaffMenuItem(),
                ],

                buildMenuItem(Icons.settings_outlined, "Settings", () {
                  Navigation.push(context, Settings());
                }),
                buildMenuItem(Icons.help_outline, "Help Center", () {
                  Navigation.push(context, HelpCenter());
                }),
                buildMenuItem(Icons.privacy_tip_outlined, "Policy", () {
                  Navigation.push(context, PrivacyPolicy());
                }),
                buildMenuItem(Icons.logout, "Log out", () {
                  showLogoutBottomSheet(context);
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // ✅ NEW: Become Staff Menu Item with Status
  // ============================================================================
  Widget _buildBecomeStaffMenuItem() {
    // ✅ Only show status for PENDING and REJECTED
    final bool shouldShowStatus = _currentRequest != null &&
        (_currentRequest!.isPending || _currentRequest!.isRejected);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: InkWell(
        onTap: _hasPendingRequest
            ? _showCancelRequestDialog
            : _showCreatePromotionRequestDialog,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.work_outline,
                  color: shouldShowStatus
                      ? _currentRequest!.getStatusColor()
                      : AppColors.primaryColor,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Become Staff',
                        style: TextStyle(fontSize: 16),
                      ),

                      // ✅ Status - Only for PENDING and REJECTED
                      if (shouldShowStatus) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              _currentRequest!.getStatusIcon(),
                              size: 14,
                              color: _currentRequest!.getStatusColor(),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _currentRequest!.getStatusText(),
                              style: TextStyle(
                                fontSize: 12,
                                color: _currentRequest!.getStatusColor(),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // ✅ Action Icon - Only show cancel for PENDING
                Icon(
                  _hasPendingRequest ? Icons.cancel : Icons.arrow_forward_ios,
                  color: _hasPendingRequest
                      ? Colors.red
                      : AppColors.primaryColor,
                  size: 16,
                ),
              ],
            ),

            // ✅ Notes preview - Only for PENDING
            if (_currentRequest != null &&
                _currentRequest!.notes != null &&
                _currentRequest!.notes!.isNotEmpty &&
                _currentRequest!.isPending) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(left: 40),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _currentRequest!.notes!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildShimmerUI() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Column(
        children: [
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: 7,
              itemBuilder: (_, __) => Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryColor),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
            const Icon(Icons.arrow_forward_ios,
                color: AppColors.primaryColor, size: 16),
          ],
        ),
      ),
    );
  }

  void showLogoutBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.logout,
                  size: 40, color: AppColors.primaryColor),
              const SizedBox(height: 10),
              const Text(
                "Are you sure you want to log out?",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mistBlueColor,
                        foregroundColor: AppColors.blackColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await ApiService.clearSession();
                        Navigator.of(context).pop();
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AppSplashLoader()),
                              (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: AppColors.whiteColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text("Log out"),
                    ),
                  )
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class AvatarUploadResponse {
  final bool success;
  final String message;
  final String? avatarPath;

  AvatarUploadResponse({
    required this.success,
    required this.message,
    this.avatarPath,
  });

  factory AvatarUploadResponse.fromJson(Map<String, dynamic> json) {
    return AvatarUploadResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      avatarPath: json['avatarPath'],
    );
  }
}