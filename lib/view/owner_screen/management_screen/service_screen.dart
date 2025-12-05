import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hair_sallon/api/api_service.dart';
import 'package:hair_sallon/api/management_service_model.dart';
import 'package:hair_sallon/view/owner_screen/shimmer_loading.dart';
import 'package:image_picker/image_picker.dart';

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
    final TextEditingController descController = TextEditingController();
    bool isPlusService = false;
    int? selectedCategoryId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create New Service'),
          content: SingleChildScrollView(
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
                    labelText: 'Credit Price *',
                    border: OutlineInputBorder(),
                    prefixText: '\$ ',
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
                ElevatedButton(
                  onPressed: () {
                    // TODO: Show category selection dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Category selection - To be implemented')),
                    );
                  },
                  child: Text(selectedCategoryId == null ? 'Select Category *' : 'Category Selected'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    priceController.text.isEmpty ||
                    selectedCategoryId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill required fields'), backgroundColor: Colors.red),
                  );
                  return;
                }

                Navigator.pop(context);
                await _createService(
                  nameController.text,
                  double.parse(priceController.text),
                  descController.text,
                  cashPriceController.text.isEmpty ? null : double.parse(cashPriceController.text),
                  isPlusService,
                  selectedCategoryId!,
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
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
        categoryId: categoryId,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.isSuccess) {
        await _fetchServiceData(isRefresh: true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service created successfully'),
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

  // ========== EDIT SERVICE ==========
  void _showEditServiceDialog(ManagementServiceDTO service) {
    final TextEditingController nameController = TextEditingController(text: service.name);
    final TextEditingController priceController = TextEditingController(text: service.price.toString());
    final TextEditingController cashPriceController = TextEditingController(
      text: service.cashPrice?.toString() ?? '',
    );
    final TextEditingController descController = TextEditingController(text: service.description);
    bool isPlusService = service.plus;
    int? selectedCategoryId = service.category?.id;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit Service - ${service.name}'),
          content: SingleChildScrollView(
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
                    labelText: 'Credit Price *',
                    border: OutlineInputBorder(),
                    prefixText: '\$ ',
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
                ElevatedButton(
                  onPressed: () {
                    // TODO: Show category selection dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Category selection - To be implemented')),
                    );
                  },
                  child: Text(service.category?.name ?? 'Select Category *'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    priceController.text.isEmpty ||
                    selectedCategoryId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill required fields'), backgroundColor: Colors.red),
                  );
                  return;
                }

                Navigator.pop(context);
                await _updateServiceInfo(
                  service.id,
                  nameController.text,
                  double.parse(priceController.text),
                  descController.text,
                  cashPriceController.text.isEmpty ? null : double.parse(cashPriceController.text),
                  isPlusService,
                  selectedCategoryId!,
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
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

  Widget _buildServiceDetail(ManagementServiceDTO service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        if (service.description.isNotEmpty) ...[
          const Text(
            'Description:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(service.description, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
          const SizedBox(height: 16),
        ],
        const Text(
          'Pricing:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
        ),
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
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
                ),
              ),
          ],
        ),
        if (service.category != null) ...[
          const SizedBox(height: 16),
          const Text(
            'Category:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(service.category!.avatar),
                backgroundColor: Colors.grey.shade200,
                child: service.category!.avatar.isEmpty
                    ? const Icon(Icons.category, size: 16, color: Colors.grey)
                    : null,
              ),
              const SizedBox(width: 12),
              Text(
                service.category!.name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
            child: _isLoading
                ? const ShimmerListLoading(itemCount: 8)
                : ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _serviceData.length + (_isLoadingMore ? 1 : 0) + (_hasMore ? 0 : 1),
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
                                onTap: () => _uploadAvatar(service),
                                child: Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 25,
                                      backgroundImage: NetworkImage(service.avatar),
                                      backgroundColor: Colors.grey.shade200,
                                      child: service.avatar.isEmpty
                                          ? const Icon(Icons.cleaning_services, color: Colors.grey)
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
                                      service.name,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade600),
              ),
            ),
            const SizedBox(width: 12),
            Text('Loading more services...', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildNoMoreDataItem() {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Center(
        child: Text('No more services', style: TextStyle(color: Colors.grey, fontSize: 14)),
      ),
    );
  }
}