import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hair_sallon/api/api_service.dart';
import 'package:hair_sallon/api/management_category_model.dart';
import 'package:hair_sallon/view/owner_screen/shimmer_loading.dart';
import 'package:image_picker/image_picker.dart';

class CategoryTab extends StatefulWidget {
  const CategoryTab({super.key});

  @override
  State<CategoryTab> createState() => _CategoryTabState();
}

class _CategoryTabState extends State<CategoryTab> {
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  List<ManagementCategoryDTO> _categoryData = [];
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
    _fetchCategoryData(isRefresh: true);
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
      _fetchCategoryData(isRefresh: true);
    });
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (maxScroll - currentScroll <= _loadThreshold) {
      _fetchCategoryData(isRefresh: false);
    }
  }

  Future<void> _fetchCategoryData({required bool isRefresh}) async {
    if (isRefresh) {
      setState(() {
        _isLoading = true;
        _categoryData.clear();
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
      final response = await ApiService.getCategoryList(
        page: _page,
        size: _pageSize,
        searchQuery: _lastSearchQuery,
      );

      if (!mounted) return;

      setState(() {
        if (isRefresh) {
          _categoryData = response.data ?? [];
        } else {
          _categoryData.addAll(response.data ?? []);
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
    await _fetchCategoryData(isRefresh: true);
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

  // ========== EDIT CATEGORY ==========
  void _showEditCategoryDialog(ManagementCategoryDTO category) {
    final TextEditingController nameController = TextEditingController(text: category.name);
    final TextEditingController descController = TextEditingController(text: category.description);
    List<int> selectedServiceIds = category.services?.map((s) => s.id).toList() ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Category - ${category.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                  border: OutlineInputBorder(),
                ),
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
                  // TODO: Show service selection dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Service selection - To be implemented')),
                  );
                },
                child: Text('Select Services (${selectedServiceIds.length})'),
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
              Navigator.pop(context);
              await _updateCategoryInfo(
                category.id,
                nameController.text,
                descController.text,
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

  Future<void> _updateCategoryInfo(
      int categoryId,
      String name,
      String description,
      List<int> serviceIds,
      ) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final response = await ApiService.updateCategoryInfo(
        categoryId: categoryId,
        name: name,
        description: description,
        serviceIds: serviceIds,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.isSuccess) {
        await _fetchCategoryData(isRefresh: true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Category updated successfully'),
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
  Future<void> _uploadAvatar(ManagementCategoryDTO category) async {
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

      final response = await ApiService.uploadCategoryAvatar(
        categoryId: category.id,
        imagePath: image.path,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.isSuccess) {
        await _fetchCategoryData(isRefresh: true);
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

  Widget _buildCategoryDetail(ManagementCategoryDTO category) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Services:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        if (category.services!.isEmpty)
          Text(
            'No services',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
          )
        else
          ...category.services!.map((service) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(service.avatar),
                  backgroundColor: Colors.grey.shade200,
                  child: service.avatar.isEmpty
                      ? const Icon(Icons.cleaning_services, size: 16, color: Colors.grey)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(service.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      Text(
                        '\$${service.price.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.green),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )).toList(),
        const SizedBox(height: 16),
        Center(
          child: ElevatedButton.icon(
            onPressed: () => _showEditCategoryDialog(category),
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Edit Category'),
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
          child: Stack(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search categories...',
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
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshData,
            child: _isLoading
                ? const ShimmerListLoading(itemCount: 8)
                : ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _categoryData.length + (_isLoadingMore ? 1 : 0) + (_hasMore ? 0 : 1),
              itemBuilder: (context, index) {
                if (_isLoadingMore && index == _categoryData.length) {
                  return _buildLoadingMoreItem();
                }

                if (!_hasMore && index == _categoryData.length) {
                  return _buildNoMoreDataItem();
                }

                final category = _categoryData[index];
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
                                onTap: () => _uploadAvatar(category),
                                child: Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 25,
                                      backgroundImage: NetworkImage(category.avatar),
                                      backgroundColor: Colors.grey.shade200,
                                      child: category.avatar.isEmpty
                                          ? const Icon(Icons.category, color: Colors.grey)
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
                                      category.name,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    if (category.description.isNotEmpty)
                                      Text(
                                        category.description,
                                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
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
                            firstChild: _buildCategoryDetail(category),
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
            Text('Loading more categories...', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildNoMoreDataItem() {
    return const Padding(
      padding: EdgeInsets.all(0.0),
      child: Center(
        child: Text('', style: TextStyle(color: Colors.grey, fontSize: 14)),
      ),
    );
  }
}