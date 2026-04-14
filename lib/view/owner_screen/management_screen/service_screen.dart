import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hair_sallon/api/api_service.dart';
import 'package:hair_sallon/api/management_service_model.dart';
import 'package:hair_sallon/view/owner_screen/shimmer_loading.dart';
import 'package:image_picker/image_picker.dart';

import '../../../api/management_category_model.dart';

class ServiceTab extends StatefulWidget {
  const ServiceTab({super.key});

  @override
  State<ServiceTab> createState() => _ServiceTabState();
}

class _ServiceTabState extends State<ServiceTab> {
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  List<ManagementServiceDTO> _serviceData = [];
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
    _fetchServiceData(isRefresh: true);
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
      _fetchServiceData(isRefresh: true);
    });
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (maxScroll - currentScroll <= _loadThreshold) {
      _fetchServiceData(isRefresh: false);
    }
  }

  Future<void> _fetchServiceData({required bool isRefresh}) async {
    if (isRefresh) {
      setState(() {
        _isLoading = true;
        _serviceData.clear();
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
      final response = await ApiService.getServiceList(
        page: _page,
        size: _pageSize,
        searchQuery: _lastSearchQuery,
      );

      if (!mounted) return;

      setState(() {
        if (isRefresh) {
          _serviceData = response.data ?? [];
        } else {
          _serviceData.addAll(response.data ?? []);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _refreshData() async {
    if (_searchDebounce?.isActive ?? false) {
      _searchDebounce?.cancel();
    }
    _expandedCardIndex = null;
    await _fetchServiceData(isRefresh: true);
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

  // ========== CREATE SERVICE ==========
  void _showCreateServiceDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController priceController = TextEditingController();
    final TextEditingController cashPriceController = TextEditingController();
    final TextEditingController timeController = TextEditingController();
    final TextEditingController descController = TextEditingController();
    bool isPlusService = false;
    int? selectedCategoryId;
    String? selectedCategoryName; // ✅ ADD THIS

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New Service'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.7,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Service Name *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceController,
                    decoration: const InputDecoration(
                      labelText: 'Price *',
                      border: OutlineInputBorder(),
                      prefixText: '\$ ',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: timeController,
                    decoration: const InputDecoration(
                      labelText: 'Est. Time *',
                      border: OutlineInputBorder(),
                      suffixText: ' mins',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),

                  // ✅ PLUS SERVICE CHECKBOX
                  CheckboxListTile(
                    title: const Text('Plus Service'),
                    subtitle: const Text('Mark this as a plus/premium service'),
                    value: isPlusService,
                    onChanged: (value) {
                      setDialogState(() {
                        isPlusService = value ?? false;
                      });
                    },
                    activeColor: Colors.orange,
                  ),

                  const SizedBox(height: 12),

                  // ✅ UPDATED: Category Selection Button
                  ElevatedButton.icon(
                    onPressed: () async {
                      final categoryId = await _showCategorySelectionDialog();
                      if (categoryId != null) {
                        setDialogState(() {
                          selectedCategoryId = categoryId;
                          // Optionally fetch category name for display
                        });
                      }
                    },
                    icon: Icon(
                      selectedCategoryId == null
                          ? Icons.category_outlined
                          : Icons.check_circle,
                    ),
                    label: Text(
                      selectedCategoryId == null
                          ? 'Select Category *'
                          : 'Category Selected (ID: $selectedCategoryId)',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedCategoryId == null
                          ? Colors.grey
                          : Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
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
                // ✅ Validation
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Service name is required'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (priceController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Price is required'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (selectedCategoryId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a category'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(context);

                // ✅ Call create service
                await _createService(
                  nameController.text.trim(),
                  double.parse(priceController.text.trim()),
                  descController.text.trim().isEmpty
                      ? null
                      : descController.text.trim(),
                  cashPriceController.text.trim().isEmpty
                      ? null
                      : double.parse(cashPriceController.text.trim()),
                  isPlusService,
                  timeController.text.trim().isEmpty
                      ? 30 // Default 30 mins
                      : int.parse(timeController.text.trim()),
                  selectedCategoryId!,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createService(
      String name,
      double price,
      String? description,
      double? cashPrice,
      bool plus,
      int time,
      int categoryId,
      ) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final response = await ApiService.createService(
        name: name,
        price: price,
        description: description,
        cashPrice: cashPrice,
        plus: plus,
        time: time,
        categoryId: categoryId,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (response.isSuccess) {
        await _fetchServiceData(isRefresh: true); // Refresh list

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating service: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  // ========== EDIT SERVICE ==========
  void _showEditServiceDialog(ManagementServiceDTO service) {
    final TextEditingController nameController = TextEditingController(
      text: service.name,
    );
    final TextEditingController priceController = TextEditingController(
      text: service.price.toString(),
    );
    final TextEditingController timeController = TextEditingController(
      text: service.time.toString(),
    );
    final TextEditingController cashPriceController = TextEditingController(
      text: service.cashPrice?.toString() ?? '',
    );
    final TextEditingController descController = TextEditingController(
      text: service.description,
    );
    bool isPlusService = service.plus;
    int? selectedCategoryId = service.category?.id;
    String? selectedCategoryName = service.category?.name; // ✅ ADD THIS

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit Service - ${service.name}'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.7,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Service Name *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceController,
                    decoration: const InputDecoration(
                      labelText: 'Price *',
                      border: OutlineInputBorder(),
                      prefixText: '\$ ',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: cashPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Cash Price',
                      border: OutlineInputBorder(),
                      prefixText: '\$ ',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: timeController,
                    decoration: const InputDecoration(
                      labelText: 'Est. Time *',
                      border: OutlineInputBorder(),
                      suffixText: ' mins',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),

                  // ✅ PLUS SERVICE CHECKBOX
                  CheckboxListTile(
                    title: const Text('Plus Service'),
                    subtitle: const Text('Mark this as a plus/premium service'),
                    value: isPlusService,
                    onChanged: (value) {
                      setDialogState(() {
                        isPlusService = value ?? false;
                      });
                    },
                    activeColor: Colors.orange,
                  ),

                  const SizedBox(height: 12),

                  // ✅ FIXED: Category Selection Button
                  ElevatedButton.icon(
                    onPressed: () async {
                      final categoryId = await _showCategorySelectionDialog();
                      if (categoryId != null) {
                        setDialogState(() {
                          selectedCategoryId = categoryId;
                          selectedCategoryName = 'Category ID: $categoryId'; // Or fetch name if needed
                        });
                      }
                    },
                    icon: Icon(
                      selectedCategoryId == null
                          ? Icons.category_outlined
                          : Icons.check_circle,
                    ),
                    label: Text(
                      selectedCategoryName ?? 'Select Category *',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedCategoryId == null
                          ? Colors.grey
                          : Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
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
                // ✅ Validation
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Service name is required'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (priceController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Price is required'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                if (selectedCategoryId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a category'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(context);

                await _updateServiceInfo(
                  service.id,
                  nameController.text.trim(),
                  double.parse(priceController.text.trim()),
                  descController.text.trim().isEmpty
                      ? null
                      : descController.text.trim(),
                  cashPriceController.text.trim().isEmpty
                      ? null
                      : double.parse(cashPriceController.text.trim()),
                  isPlusService,
                  int.parse(timeController.text.trim()),
                  selectedCategoryId!,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateServiceInfo(
    int serviceId,
    String name,
    double price,
    String? description,
    double? cashPrice,
    bool plus,
    int time,
    int categoryId,
  ) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final response = await ApiService.updateServiceInfo(
        serviceId: serviceId,
        name: name,
        price: price,
        description: description,
        cashPrice: cashPrice,
        plus: plus,
        time: time,
        categoryId: categoryId,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.isSuccess) {
        await _fetchServiceData(isRefresh: true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.red,
          ),
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

  // ========== UPLOAD AVATAR ==========
  Future<void> _uploadAvatar(ManagementServiceDTO service) async {
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

      final response = await ApiService.uploadServiceAvatar(
        serviceId: service.id,
        imagePath: image.path,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.isSuccess) {
        await _fetchServiceData(isRefresh: true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Avatar updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.red,
          ),
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

  Widget _buildServiceDetail(ManagementServiceDTO service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        if (service.description.isNotEmpty) ...[
          const Text(
            'Description:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            service.description,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 16),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Price: \$${service.price.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 14, color: Colors.blue),
                  ),
                ],
              ),
            ),
            if (service.plus)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'PLUS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Est. Time: ${service.time} mins',
                    style: const TextStyle(fontSize: 14, color: Colors.blue),
                  ),
                ],
              ),
            ),
            if (service.plus)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'PLUS',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
                ),
              ),
          ],
        ),
        if (service.category != null) ...[
          const SizedBox(height: 16),
          const Text(
            'Category:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(service.category!.avatar),
                backgroundColor: Colors.grey.shade200,
                child:
                    service.category!.avatar.isEmpty
                        ? const Icon(
                          Icons.category,
                          size: 16,
                          color: Colors.grey,
                        )
                        : null,
              ),
              const SizedBox(width: 12),
              Text(
                service.category!.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton.icon(
            onPressed: () => _showEditServiceDialog(service),
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Edit Service'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
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
                        hintText: 'Search services...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: const BorderSide(color: Colors.orange),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
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
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.orange.shade600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton(
                mini: true,
                onPressed: _showCreateServiceDialog,
                backgroundColor: Colors.green,
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshData,
            child:
                _isLoading
                    ? const ShimmerListLoading(itemCount: 8)
                    : ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount:
                          _serviceData.length +
                          (_isLoadingMore ? 1 : 0) +
                          (_hasMore ? 0 : 1),
                      itemBuilder: (context, index) {
                        if (_isLoadingMore && index == _serviceData.length) {
                          return _buildLoadingMoreItem();
                        }

                        if (!_hasMore && index == _serviceData.length) {
                          return _buildNoMoreDataItem();
                        }

                        final service = _serviceData[index];
                        final isExpanded = _expandedCardIndex == index;

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
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
                                        onTap: () => _uploadAvatar(service),
                                        child: Stack(
                                          children: [
                                            CircleAvatar(
                                              radius: 25,
                                              backgroundImage: NetworkImage(
                                                service.avatar,
                                              ),
                                              backgroundColor:
                                                  Colors.grey.shade200,
                                              child:
                                                  service.avatar.isEmpty
                                                      ? const Icon(
                                                        Icons.cleaning_services,
                                                        color: Colors.grey,
                                                      )
                                                      : null,
                                            ),
                                            Positioned(
                                              right: 0,
                                              bottom: 0,
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  2,
                                                ),
                                                decoration: const BoxDecoration(
                                                  color: Colors.orange,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.camera_alt,
                                                  size: 12,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              service.name,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '\$${service.price.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      AnimatedRotation(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        turns: isExpanded ? 0.5 : 0,
                                        child: const Icon(
                                          Icons.expand_more,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  AnimatedCrossFade(
                                    duration: const Duration(milliseconds: 300),
                                    crossFadeState:
                                        isExpanded
                                            ? CrossFadeState.showFirst
                                            : CrossFadeState.showSecond,
                                    firstChild: _buildServiceDetail(service),
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
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.orange.shade600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Loading more services...',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoMoreDataItem() {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Center(
        child: Text(
          'No more services',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ),
    );
  }

  Future<int?> _showCategorySelectionDialog() async {
    List<ManagementCategoryDTO> categories = [];
    bool isLoading = true;
    int? selectedCategoryId;
    String? errorMessage;

    // ✅ Load categories immediately
    Future<void> loadCategories(StateSetter setDialogState) async {
      try {
        final response = await ApiService.getCategoryList(
          page: 0,
          size: 100,
          searchQuery: '',
        );

        setDialogState(() {
          categories = response.data ?? [];
          isLoading = false;
          errorMessage = null;
        });
      } catch (e) {
        setDialogState(() {
          isLoading = false;
          errorMessage = 'Error loading categories: $e';
        });
      }
    }

    return await showDialog<int?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // ✅ Load on first build
          if (isLoading && categories.isEmpty && errorMessage == null) {
            loadCategories(setDialogState);
          }

          return AlertDialog(
            title: const Text('Select Category'),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.height * 0.6,
              child: isLoading
                  ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading categories...'),
                  ],
                ),
              )
                  : errorMessage != null
                  ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setDialogState(() {
                          isLoading = true;
                          errorMessage = null;
                        });
                        loadCategories(setDialogState);
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
                  : categories.isEmpty
                  ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.category_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No categories found', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              )
                  : ListView.builder(
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final isSelected = selectedCategoryId == category.id;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    elevation: isSelected ? 4 : 1,
                    child: RadioListTile<int>(
                      value: category.id,
                      groupValue: selectedCategoryId,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedCategoryId = value;
                        });
                      },
                      title: Text(
                        category.name,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.orange : Colors.black,
                        ),
                      ),
                      subtitle: category.description.isNotEmpty
                          ? Text(
                        category.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                          : null,
                      secondary: CircleAvatar(
                        backgroundImage: category.avatar.isNotEmpty
                            ? NetworkImage(category.avatar)
                            : null,
                        backgroundColor: Colors.grey.shade200,
                        child: category.avatar.isEmpty
                            ? const Icon(Icons.category, size: 20)
                            : null,
                      ),
                      activeColor: Colors.orange,
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedCategoryId != null
                    ? () => Navigator.pop(context, selectedCategoryId)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedCategoryId != null ? Colors.orange : Colors.grey,
                ),
                child: const Text('Select'),
              ),
            ],
          );
        },
      ),
    );
  }
}
