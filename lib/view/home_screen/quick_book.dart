import 'package:flutter/material.dart';
import '../../api/api_service.dart';
import '../../utils/constant/quick_booking_model.dart';
import '../../utils/navigation/navigation_file.dart';
import '../calendar_screen/todo_calendar_screen.dart';

class QuickBookScreen extends StatefulWidget {
  final int storeId;
  final String storeName;
  final String storeAvt;
  final String storeLocation;

  const QuickBookScreen({
    super.key,
    required this.storeId,
    required this.storeName,
    required this.storeAvt,
    required this.storeLocation
  });

  @override
  State<QuickBookScreen> createState() => _QuickBookScreenState();
}

class _QuickBookScreenState extends State<QuickBookScreen> with TickerProviderStateMixin {
  List<QuickServiceModel> allServices = [];
  List<QuickServiceModel> filteredServices = [];
  List<QuickServiceModel> selectedServices = [];
  int? currentStaffId;
  String? currentStaffName;
  bool isLoading = true;
  String? errorMessage;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Add scroll controller and collapse state
  final ScrollController _scrollController = ScrollController();
  bool _isStoreCardCollapsed = false;
  late AnimationController _collapseController;
  late Animation<double> _collapseAnimation;

  // Thêm controller cho search
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers FIRST
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    // Initialize collapse animation
    _collapseController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _collapseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _collapseController, curve: Curves.easeInOut),
    );

    // Add listeners AFTER animation controllers are initialized
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_filterServices);

    // Fetch services last
    _fetchServices();
  }

  void _onScroll() {
    const double collapseThreshold = 50.0; // Adjust this value as needed
    final bool shouldCollapse = _scrollController.hasClients &&
        _scrollController.offset > collapseThreshold;

    if (shouldCollapse != _isStoreCardCollapsed) {
      setState(() {
        _isStoreCardCollapsed = shouldCollapse;
      });

      if (_isStoreCardCollapsed) {
        _collapseController.forward();
      } else {
        _collapseController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _collapseController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Keep all your existing methods (_fetchServices, _filterServices, etc.)
  Future<void> _fetchServices() async {
    try {
      final services = await ApiService.getAllServiceByStore(widget.storeId);

      setState(() {
        allServices = services;
        filteredServices = services;
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load services: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading services: $e')),
      );
    }
  }

  void _filterServices() {
    final query = _searchController.text.toLowerCase().trim();

    if (query.isEmpty) {
      setState(() {
        filteredServices = _getSortedServices(allServices);
      });
      return;
    }

    if (currentStaffId != null) {
      setState(() {
        final filtered = allServices.where((service) {
          final isSupported = service.staffList.any((staff) => staff.id == currentStaffId);
          if (!isSupported) return false;
          return service.name.toLowerCase().contains(query);
        }).toList();

        filteredServices = _getSortedServices(filtered);
      });
    } else {
      setState(() {
        final filtered = allServices.where((service) {
          final matchesServiceName = service.name.toLowerCase().contains(query);
          final matchesCategoryName = service.categoryName.toLowerCase().contains(query);
          return matchesServiceName || matchesCategoryName;
        }).toList();

        filteredServices = _getSortedServices(filtered);
      });
    }
  }

  List<QuickServiceModel> _getSortedServices(List<QuickServiceModel> services) {
    final selected = services.where((service) => selectedServices.contains(service)).toList();
    final notSelected = services.where((service) => !selectedServices.contains(service)).toList();
    return [...selected, ...notSelected];
  }

  void _onServiceTap(QuickServiceModel service) {
    if (service.staffList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This service is not available at the moment.')),
      );
      return;
    }

    if (currentStaffId != null) {
      if (!service.staffList.any((staff) => staff.id == currentStaffId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('This service is not available for $currentStaffName')),
        );
        return;
      }

      setState(() {
        if (selectedServices.contains(service)) {
          selectedServices.remove(service);
        } else {
          selectedServices.add(service);
        }
        _filterServices();
      });
      return;
    }

    // ✅ TÌM STAFF CÓ FULLNAME LÀ "anyone" (case-insensitive)
    final anyoneStaff = service.staffList.firstWhere(
          (staff) => staff.fullName.toLowerCase() == 'anyone',
      orElse: () {
        // Nếu không tìm thấy "anyone", fallback về random như cũ
        service.staffList.shuffle();
        return service.staffList.first;
      },
    );

    setState(() {
      currentStaffId = anyoneStaff.id;
      currentStaffName = anyoneStaff.fullName;
      selectedServices.add(service);
      _filterServices();
    });

    _fadeController.forward().then((_) {
      _fadeController.reverse();
    });
  }

  void _bookNow() {
    if (selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one service.')),
      );
      return;
    }

    if (currentStaffId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a service to assign staff.')),
      );
      return;
    }

    Navigation.push(
      context,
      TodoCalendarScreen(
        staffId: currentStaffId!,
        staffName: currentStaffName ?? 'Selected Staff',
        serviceIds: selectedServices.map((e) => e.id).toList(),
        serviceNames: selectedServices.map((e) => e.name).toList(),
        storeId: widget.storeId,
      ),
    );
  }

  bool _isServiceSupported(QuickServiceModel service) {
    if (service.staffList.isEmpty) return false;
    return currentStaffId == null || service.staffList.any((staff) => staff.id == currentStaffId);
  }

  void _clearSelection() {
    setState(() {
      currentStaffId = null;
      currentStaffName = null;
      selectedServices.clear();
      _searchController.clear();
      filteredServices = _getSortedServices(allServices);
    });
  }

  void _clearSearch() {
    _searchController.clear();
  }

  String get _searchHintText {
    if (currentStaffId != null) {
      return 'Search by service name...';
    } else {
      return 'Search by service name or category...';
    }
  }

  // New method to build collapsible store card - SỬA ĐỔI Ở ĐÂY
  Widget _buildCollapsibleStoreCard() {
    return AnimatedBuilder(
      animation: _collapseAnimation,
      builder: (context, child) {
        // Calculate height based on animation progress - collapse hoàn toàn về 0
        final double expandedHeight = 140.0; // Full height
        final double collapsedHeight = 0.0;  // Collapse hoàn toàn
        final double currentHeight = expandedHeight * (1 - _collapseAnimation.value);

        // Opacity cho toàn bộ nội dung để fade out mượt mà
        final double currentOpacity = 1 - _collapseAnimation.value;

        // Avatar size animate theo animation để tránh overflow
        final double avatarSize = 60 * (1 - _collapseAnimation.value);

        return Opacity(
          opacity: currentOpacity,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            height: currentHeight,
            margin: const EdgeInsets.all(16),
            padding: EdgeInsets.all(16 * (1 - _collapseAnimation.value)), // Giảm padding theo animation
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1 * currentOpacity),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: currentHeight > 0
                ? ClipRect( // Thêm ClipRect để clip nội dung khi height nhỏ, tránh overflow
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store Avatar - size animate theo _collapseAnimation.value
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      widget.storeAvt,
                      width: avatarSize,
                      height: avatarSize,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: avatarSize,
                        height: avatarSize,
                        color: Colors.grey[200],
                        child: Icon(Icons.store, size: avatarSize * 0.7, color: Colors.grey),
                      ),
                    ),
                  ),
                  SizedBox(width: 12 * (1 - _collapseAnimation.value)),

                  // Store Details - wrap trong Flexible để tránh overflow
                  Expanded(
                    child:
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min, // Thêm min để fit content
                      children: [
                        // Store Name
                        Flexible( // Wrap Text trong Flexible để tránh overflow
                          child: Text(
                            widget.storeName,
                            style: TextStyle(
                              fontSize: 16 * (1 - _collapseAnimation.value * 0.3), // Giảm font size nhẹ
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        SizedBox(height: 4 * (1 - _collapseAnimation.value)),
                        // Store Slogan
                        if (currentOpacity > 0.5) // Chỉ show nếu chưa collapse quá nhiều
                          Flexible(
                            child: Text(
                              "DREAM BIG DOLL. YOU'RE UNSTOPABLE",
                              style: TextStyle(
                                fontSize: 12 * currentOpacity,
                                fontStyle: FontStyle.italic,
                                color: Colors.pink,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        SizedBox(height: 4 * currentOpacity),
                        // Store Address
                        if (currentOpacity > 0.3)
                          Flexible(
                            child: Row(
                              children: [
                                Icon(Icons.location_on, size: 14 * currentOpacity, color: Colors.grey),
                                SizedBox(width: 4 * currentOpacity),
                                Expanded(
                                  child: Text(
                                    widget.storeLocation,
                                    style: TextStyle(
                                      fontSize: 12 * currentOpacity,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        SizedBox(height: 4 * currentOpacity),
                        // Rating
                        if (currentOpacity > 0.1)
                          Flexible(
                            child: Row(
                              children: [
                                Icon(Icons.star, size: 14 * currentOpacity, color: Colors.amber[600]),
                                SizedBox(width: 2 * currentOpacity),
                                Text(
                                  '4.8',
                                  style: TextStyle(
                                    fontSize: 12 * currentOpacity,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                SizedBox(width: 2 * currentOpacity),
                                Flexible(
                                  child: Text(
                                    '(120 reviews)',
                                    style: TextStyle(
                                      fontSize: 12 * currentOpacity,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            )
                : const SizedBox.shrink(),  // Không render gì khi height=0
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Book (Random Specialist)'),
        actions: [
          if (currentStaffId != null)
            IconButton(
              onPressed: _clearSelection,
              icon: const Icon(Icons.clear),
              tooltip: 'Clear selection',
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchServices,
              child: const Text('Retry'),
            ),
          ],
        ),
      )
          : Column(
        children: [
          // Collapsible Store Information Card
          _buildCollapsibleStoreCard(),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: _searchHintText,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: _clearSearch,
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 12, horizontal: 16),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Selected Staff Info
          if (currentStaffId != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.green[50],
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selected: ${selectedServices.length} service(s) | Showing supported services only',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Search Results Info
          if (_searchController.text.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: Colors.blue[50],
              child: Text(
                'Found ${filteredServices.length} service(s) matching "${_searchController.text}"',
                style: const TextStyle(fontSize: 12, color: Colors.blue),
              ),
            ),

          // Services List - with scroll controller
          Expanded(
            child: filteredServices.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    _searchController.text.isEmpty
                        ? 'No services available'
                        : currentStaffId != null
                        ? 'No supported services found for "$currentStaffName" matching "${_searchController.text}"'
                        : 'No services found for "${_searchController.text}"',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  if (_searchController.text.isNotEmpty)
                    TextButton(
                      onPressed: _clearSearch,
                      child: const Text('Clear search'),
                    ),
                ],
              ),
            )
                : ListView.builder(
              controller: _scrollController, // Add scroll controller here
              padding: const EdgeInsets.all(16),
              itemCount: filteredServices.length,
              itemBuilder: (context, index) {
                final service = filteredServices[index];
                final isSelected = selectedServices.contains(service);
                final isSupported = _isServiceSupported(service);
                final hasStaff = service.staffList.isNotEmpty;

                if (currentStaffId != null && !isSupported) {
                  return const SizedBox.shrink();
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isSelected ? Colors.blue[50] : null,
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        service.avatar,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[200],
                          child: const Icon(Icons.spa, color: Colors.grey),
                        ),
                      ),
                    ),
                    title: Text(
                      service.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.blue[800] : null,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.description,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '\$${service.price.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.green : Colors.green,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.orange[200]
                                    : Colors.orange[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                service.categoryName,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : (hasStaff
                        ? null
                        : const Icon(Icons.block, color: Colors.red)),
                    onTap: hasStaff && isSupported
                        ? () => _onServiceTap(service)
                        : null,
                  ),
                );
              },
            ),
          ),

          // Book Now Button
          if (currentStaffId != null && selectedServices.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _bookNow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Quick Book Now',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}