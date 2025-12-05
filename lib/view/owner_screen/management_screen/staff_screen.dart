import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hair_sallon/api/api_service.dart';
import 'package:hair_sallon/api/management_staff_model.dart';
import 'package:hair_sallon/view/owner_screen/management_screen/promote_screen.dart';
import 'package:hair_sallon/view/owner_screen/shimmer_loading.dart';
import 'package:image_picker/image_picker.dart';

import '../../../api/payment_model.dart';

class StaffTab extends StatefulWidget {
  const StaffTab({super.key});

  @override
  State<StaffTab> createState() => _StaffTabState();
}

class _StaffTabState extends State<StaffTab> {
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  List<ManagementStaffDTO> _staffData = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  int _page = 0;
  final int _pageSize = 12;
  final double _loadThreshold = 200.0;
  Timer? _searchDebounce;
  String _lastSearchQuery = '';
  int? _expandedCardIndex;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchStaffData(isRefresh: true);
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final currentQuery = _searchController.text.trim();
    if (currentQuery == _lastSearchQuery) return;

    if (_searchDebounce?.isActive ?? false) {
      _searchDebounce?.cancel();
    }

    _searchDebounce = Timer(const Duration(seconds: 2), () {
      _lastSearchQuery = currentQuery;
      _expandedCardIndex = null;
      _fetchStaffData(isRefresh: true);
    });
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (maxScroll - currentScroll <= _loadThreshold) {
      _fetchStaffData(isRefresh: false);
    }
  }

  Future<void> _showAddServicesDialog(ManagementStaffDTO staff) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Get available services
      final response = await ApiService.getAvailableServiceListForStaff(staff.id);

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (!response.isSuccess || response.data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final availableServices = response.data!.availableServices;

      if (availableServices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No more services available to add'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Show selection dialog
      List<int> selectedServiceIds = [];

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Add Services - ${staff.fullName}'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select services to add (${availableServices.length} available):',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      ...availableServices.map((service) {
                        final isSelected = selectedServiceIds.contains(service.id);
                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                selectedServiceIds.add(service.id);
                              } else {
                                selectedServiceIds.remove(service.id);
                              }
                            });
                          },
                          title: Text(service.name),
                          subtitle: Text(
                            '\$${service.price.toStringAsFixed(2)}${service.categoryName != null ? ' - ${service.categoryName}' : ''}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          secondary: service.avatar != null && service.avatar!.isNotEmpty
                              ? CircleAvatar(
                            backgroundImage: NetworkImage(service.avatar!),
                            radius: 20,
                          )
                              : const CircleAvatar(
                            child: Icon(Icons.cut, size: 20),
                            radius: 20,
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedServiceIds.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: Text('Add (${selectedServiceIds.length})'),
                ),
              ],
            );
          },
        ),
      );

      if (confirmed == true && selectedServiceIds.isNotEmpty) {
        // Confirm addition
        final confirmAdd = await _showConfirmDialog(
          title: 'Confirm Add Services',
          message: 'Add ${selectedServiceIds.length} service(s) to ${staff.fullName}?',
          confirmText: 'Add',
          confirmColor: Colors.green,
        );

        if (confirmAdd) {
          await _addServicesToStaff(staff.id, selectedServiceIds);
        }
      }
    } catch (e) {
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _addServicesToStaff(int staffId, List<int> serviceIds) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final response = await ApiService.addServicesToStaff(
        staffId: staffId,
        serviceIds: serviceIds,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.isSuccess) {
        await _fetchStaffData(isRefresh: true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

// ========== REMOVE SERVICE DIALOG ==========
  Future<void> _showRemoveServiceDialog(ManagementStaffDTO staff, ServiceDTO service) async {
    final confirmed = await _showConfirmDialog(
      title: 'Remove Service',
      message: 'Remove "${service.name}" from ${staff.fullName}?',
      confirmText: 'Remove',
      confirmColor: Colors.red,
    );

    if (confirmed) {
      await _removeServiceFromStaff(staff.id, service.id);
    }
  }

  Future<void> _removeServiceFromStaff(int staffId, int serviceId) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final response = await ApiService.removeServiceFromStaff(
        staffId: staffId,
        serviceId: serviceId,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.isSuccess) {
        await _fetchStaffData(isRefresh: true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

// ========== HELPER: CONFIRM DIALOG ==========
  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    ) ?? false;
  }


  Future<void> _fetchStaffData({required bool isRefresh}) async {
    if (isRefresh) {
      setState(() {
        _isLoading = true;
        _staffData.clear();
        _page = 0;
        _hasMore = true;
      });
    } else if (_isLoadingMore || !_hasMore) {
      return;
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final response = await ApiService.getStaffList(
        page: _page,
        size: _pageSize,
        searchQuery: _lastSearchQuery,
      );

      if (!mounted) return;

      setState(() {
        if (isRefresh) {
          _staffData = response.data ?? [];
        } else {
          _staffData.addAll(response.data ?? []);
        }

        if ((response.data ?? []).length < _pageSize) {
          _hasMore = false;
        }

        _page++;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });

      if (!isRefresh) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _refreshData() async {
    if (_searchDebounce?.isActive ?? false) {
      _searchDebounce?.cancel();
    }
    _expandedCardIndex = null;
    await _fetchStaffData(isRefresh: true);
  }

  void _toggleCardExpansion(int index) {
    setState(() {
      if (_expandedCardIndex == index) {
        _expandedCardIndex = null;
      } else {
        _expandedCardIndex = index;
      }
    });
  }

  // ========== EDIT STAFF INFO ==========
  void _showEditStaffDialogFixed(ManagementStaffDTO staff) {
    final TextEditingController nameController = TextEditingController(text: staff.fullName);
    List<int> selectedServiceIds = staff.services.map((s) => s.id).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Staff - ${staff.fullName}'),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        content: SizedBox(
          width: 500, // ✅ Fixed width 500px
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _updateStaffInfo(
                staff.id,
                nameController.text,
                selectedServiceIds,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStaffInfo(
      int staffId,
      String fullName,
      List<int> serviceIds,
      ) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final response = await ApiService.updateStaffInfo(
        staffId: staffId,
        fullName: fullName,
        serviceIds: serviceIds,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.isSuccess) {
        await _fetchStaffData(isRefresh: true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Staff information updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print(e);
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ========== REMOVE STAFF ==========
  void _showRemoveStaffDialog(ManagementStaffDTO staff) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Staff'),
        content: Text('Are you sure you want to remove ${staff.fullName} from staff?\n\nThey will be converted back to a regular user.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _removeStaff(staff.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeStaff(int staffId) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final response = await ApiService.removeStaff(staffId);

      if (!mounted) return;
      Navigator.pop(context);

      if (response.isSuccess) {
        await _fetchStaffData(isRefresh: true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Staff removed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ========== PROMOTE USER ==========
  void _showPromoteUserDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PromoteUserScreen(
          onPromoteSuccess: () => _fetchStaffData(isRefresh: true),
        ),
      ),
    );
  }

  // ========== UPLOAD AVATAR ==========
  Future<void> _uploadAvatar(ManagementStaffDTO staff) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final response = await ApiService.uploadStaffAvatar(
        staffId: staff.id,
        imagePath: image.path,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.isSuccess) {
        await _fetchStaffData(isRefresh: true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Avatar updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ========== SERVICE SELECTION (PLACEHOLDER) ==========
  void _showServiceSelectionDialog(ManagementStaffDTO staff, List<int> selectedIds) {
    // TODO: Implement service selection dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Service selection dialog - To be implemented')),
    );
  }

  Widget _buildStaffDetail(ManagementStaffDTO staff) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Contact Information:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.phone, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(staff.phoneNumber, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.email, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(staff.email, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
          ],
        ),

        if (staff.store != null) ...[
          const SizedBox(height: 16),
          const Text('Store:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(staff.store!.avatar),
                child: staff.store!.avatar.isEmpty ? const Icon(Icons.store, size: 16) : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(staff.store!.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  Text(staff.store!.location, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ],
          ),
        ],

        if (staff.services.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Services:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.green),
                onPressed: () => _showAddServicesDialog(staff),
                tooltip: 'Add services',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: staff.services
                .map((service) => GestureDetector(
              onTap: () => _showRemoveServiceDialog(
                staff,
                ServiceDTO(
                  id: service.id,
                  name: service.name,
                  price: 0, // Not used in dialog
                  plus: false,
                ),
              ),
              child: Chip(
                label: Text(service.name),
                backgroundColor: Colors.orange.shade50,
                labelStyle: const TextStyle(fontSize: 10),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () => _showRemoveServiceDialog(
                  staff,
                  ServiceDTO(
                    id: service.id,
                    name: service.name,
                    price: 0,
                    plus: false,
                  ),
                ),
              ),
            ))
                .toList(),
          ),
        ] else ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Services:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.green),
                onPressed: () => _showAddServicesDialog(staff),
                tooltip: 'Add services',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const Text(
            'No services assigned',
            style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ],

        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: () => _showEditStaffDialog(staff),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Edit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _showRemoveStaffDialog(staff),
              icon: const Icon(Icons.remove_circle, size: 16),
              label: const Text('Remove'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showEditStaffDialog(ManagementStaffDTO staff) {
    final TextEditingController nameController = TextEditingController(text: staff.fullName);
    List<int> selectedServiceIds = staff.services.map((s) => s.id).toList();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        // ✅ Custom shape
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        // ✅ Minimal padding
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9, // ✅ 90% width
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                'Edit Staff - ${staff.fullName}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Content
              SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _updateStaffInfo(
                        staff.id,
                        nameController.text,
                        selectedServiceIds,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Update'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  // Share rate dialogs
  void _showEditShareRateDialog(ManagementStaffDTO staff) {
    final TextEditingController controller = TextEditingController(
      text: staff.shareRate.toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Share Rate - ${staff.fullName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter new bill split percentage (10-100):', style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Share Rate (%)',
                hintText: 'Enter 10-100',
                prefixIcon: const Icon(Icons.monetization_on, color: Colors.orange),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.orange, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final value = controller.text.trim();
              final number = double.tryParse(value);

              if (number == null || number < 10 || number > 100) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid number between 10 and 100'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              await _updateShareRate(staff.id, number);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showEditTipShareRateDialog(ManagementStaffDTO staff) {
    final TextEditingController controller = TextEditingController(
      text: staff.tipShareRate.toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Tip Share Rate - ${staff.fullName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter new tip split percentage (10-100):', style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Tip Share Rate (%)',
                hintText: 'Enter 10-100',
                prefixIcon: const Icon(Icons.attach_money, color: Colors.green),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.green, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final value = controller.text.trim();
              final number = double.tryParse(value);

              if (number == null || number < 10 || number > 100) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid number between 10 and 100'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              await _updateTipShareRate(staff.id, number);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateShareRate(int staffId, double newShareRate) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final response = await ApiService.updateStaffShareRate(
        staffId: staffId,
        shareRate: newShareRate,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.isSuccess) {
        await _fetchStaffData(isRefresh: true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share rate updated to ${newShareRate.toStringAsFixed(0)}%'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _updateTipShareRate(int staffId, double newTipShareRate) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final response = await ApiService.updateStaffTipShareRate(
        staffId: staffId,
        tipShareRate: newTipShareRate,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.isSuccess) {
        await _fetchStaffData(isRefresh: true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tip share rate updated to ${newTipShareRate.toStringAsFixed(0)}%'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search staff...',
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: const BorderSide(color: Colors.orange),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                    ),
                    if (_searchDebounce?.isActive ?? false)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade600),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _showPromoteUserDialog,
                icon: const Icon(Icons.person_add, size: 20),
                label: const Text('Promote'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshData,
            child: _isLoading
                ? const ShimmerListLoading(itemCount: 8)
                : ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _staffData.length + (_isLoadingMore ? 1 : 0) + (_hasMore ? 0 : 1),
              itemBuilder: (context, index) {
                if (_isLoadingMore && index == _staffData.length) {
                  return _buildLoadingMoreItem();
                }

                if (!_hasMore && index == _staffData.length) {
                  return _buildNoMoreDataItem();
                }

                final staff = _staffData[index];
                final isExpanded = _expandedCardIndex == index;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: InkWell(
                    onTap: () => _toggleCardExpansion(index),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => _uploadAvatar(staff),
                                child: Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 25,
                                      backgroundImage: NetworkImage(staff.avatar),
                                      backgroundColor: Colors.grey.shade200,
                                      child: staff.avatar.isEmpty
                                          ? const Icon(Icons.person, color: Colors.grey)
                                          : null,
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.orange,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
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
                                      staff.fullName,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      staff.role,
                                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onLongPress: () => _showEditShareRateDialog(staff),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.orange.shade200, width: 1),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.monetization_on, size: 14, color: Colors.orange.shade700),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Bill: ${staff.shareRate.toStringAsFixed(0)}%',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.orange.shade700,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onLongPress: () => _showEditTipShareRateDialog(staff),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.green.shade200, width: 1),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.attach_money, size: 14, color: Colors.green.shade700),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Tips: ${staff.tipShareRate.toStringAsFixed(0)}%',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.green.shade700,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              AnimatedRotation(
                                duration: const Duration(milliseconds: 300),
                                turns: isExpanded ? 0.5 : 0,
                                child: const Icon(Icons.expand_more, color: Colors.grey),
                              ),
                            ],
                          ),
                          AnimatedCrossFade(
                            duration: const Duration(milliseconds: 300),
                            crossFadeState:
                            isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                            firstChild: _buildStaffDetail(staff),
                            secondChild: const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingMoreItem() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade600),
              ),
            ),
            const SizedBox(width: 12),
            Text('Loading more staff...', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildNoMoreDataItem() {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Center(
        child: Text('No more staff members', style: TextStyle(color: Colors.grey, fontSize: 14)),
      ),
    );
  }
}
