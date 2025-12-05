import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/utils/local_images/local_images.dart';
import 'package:hair_sallon/utils/navigation/navigation_file.dart';
import 'package:hair_sallon/utils/constant/staff_simple.dart';
import 'package:hair_sallon/view/calendar_screen/todo_calendar_screen.dart';
import 'package:shimmer/shimmer.dart';

import '../../api/api_service.dart';

class StylistDetailScreen extends StatefulWidget {
  final int staffId;
  final int storeId;

  const StylistDetailScreen({
    super.key,
    required this.staffId,
    required this.storeId
  });

  @override
  State<StylistDetailScreen> createState() => _StylistDetailScreenState();
}

class _StylistDetailScreenState extends State<StylistDetailScreen> with TickerProviderStateMixin {
  StaffSimple? stylist;
  List<ServiceModel> services = [];
  List<ServiceModel> filteredServices = [];
  List<ServiceModel> cartItems = [];
  bool _isLoading = true;
  bool _isLoadingServices = true;
  String? _errorMessage;
  final TextEditingController _serviceSearchController = TextEditingController();
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  String? expandedServiceId;

  void _toggleExpand(ServiceModel service) {
    setState(() {
      if (expandedServiceId == service.id.toString()) { // Convert to string for comparison
        expandedServiceId = null; // Đang mở thì đóng lại
      } else {
        expandedServiceId = service.id.toString(); // Convert int to string
      }
    });
  }

  // Add TabController
  late TabController _tabController;
  bool _showSearchBar = true; // Track if search bar should be shown

  @override
  void initState() {
    super.initState();

    // Initialize TabController FIRST
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);

    // Animation controller
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _shakeAnimation = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.bounceOut),
    );

    _fetchStylistDetail();
    _serviceSearchController.addListener(_filterServices);
  }

  void _onTabChanged() {
    setState(() {
      _showSearchBar = _tabController.index == 0; // Show only for Services tab (index 0)
    });
  }

  @override
  void dispose() {
    _serviceSearchController.dispose();
    _shakeController.dispose();
    _tabController.dispose(); // Don't forget to dispose TabController
    super.dispose();
  }

  void _addToCart(ServiceModel service) {
    bool serviceExists = cartItems.any((item) => item.id == service.id); // This is fine since both are int

    if (!serviceExists) {
      setState(() {
        cartItems.add(service);
      });

      // Reset animation trước khi chạy
      _shakeController.reset();
      _shakeController.forward();
    }
  }

  void _showCartModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => _buildCartModal(setModalState),
      ),
    );
  }

  double get _totalPrice {
    return cartItems.fold(0.0, (sum, service) => sum + service.price);
  }

  Future<void> _fetchStylistDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final staffDetail = await ApiService.getStaffDetail(widget.staffId);

      setState(() {
        stylist = StaffSimple(
          id: staffDetail.id,
          fullName: staffDetail.fullName,
          avatar: staffDetail.avatar,
          description: staffDetail.description,
          rating: staffDetail.rating,
        );
        services = staffDetail.services;
        filteredServices = staffDetail.services;
        _isLoading = false;
        _isLoadingServices = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load stylist details: $e';
        _isLoading = false;
        _isLoadingServices = false;
      });
    }
  }

  void _filterServices() {
    final query = _serviceSearchController.text.toLowerCase();
    setState(() {
      filteredServices = services.where((service) {
        return service.name.toLowerCase().contains(query);
      }).toList();
    });
  }

  String _formatRating(double rating) {
    String ratingStr = rating.toStringAsFixed(1);
    if (ratingStr.endsWith('.0')) {
      ratingStr = ratingStr.substring(0, ratingStr.length - 2);
    }
    return ratingStr;
  }

  // Hàm mới để điều hướng đến BookingScheduleScreen
  void _navigateToBookingScreen() {
    if (cartItems.isEmpty) return;

    // Lấy danh sách serviceId và serviceName từ cartItems
    List<int> serviceIds = cartItems.map((service) => service.id).toList();
    List<String> serviceNames = cartItems.map((service) => service.name).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TodoCalendarScreen(
              staffId: widget.staffId,
              staffName: stylist?.fullName ?? 'Stylist',
              serviceIds: serviceIds, // Thay đổi từ serviceId thành serviceIds (list)
              serviceNames: serviceNames, // Thay đổi từ serviceName thành serviceNames (list)
              storeId: widget.storeId, // Thay bằng storeId thực tế nếu có
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.porcelainColor,
      floatingActionButton: AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(
              _shakeAnimation.value * 10 * (0.8 - _shakeAnimation.value),
              0,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.teal,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FloatingActionButton.small(
                onPressed: _showCartModal,
                backgroundColor: Colors.teal,
                elevation: 0,
                child: Stack(
                  children: [
                    const Icon(
                      Icons.shopping_cart,
                      color: Colors.white,
                      size: 20,
                    ),
                    if (cartItems.isNotEmpty)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            cartItems.length.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
          ? _buildErrorState()
          : NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            // Collapsing header with SliverAppBar
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              backgroundColor: AppColors.porcelainColor,
              leading: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                elevation: 4,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigation.pop(context),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black26,
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  stylist?.fullName ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        offset: Offset(1, 1),
                        blurRadius: 3,
                        color: Colors.black54,
                      ),
                    ],
                  ),
                ),
                centerTitle: true,
                background: Stack(
                  children: [
                    // Cover Image
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                      child: Image.asset(
                        AppImages.salon1,
                        height: 280,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    // Gradient overlay
                    Container(
                      height: 280,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(30),
                          bottomRight: Radius.circular(30),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.3),
                          ],
                        ),
                      ),
                    ),
                    // Profile Image - positioned lower in expanded state
                    Positioned(
                      bottom: 20,
                      left: screenWidth / 2 - 45,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 4,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 45,
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: stylist?.avatar ?? '',
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Shimmer.fromColors(
                                baseColor: Colors.grey[300]!,
                                highlightColor: Colors.grey[100]!,
                                child: Container(
                                  width: 90,
                                  height: 90,
                                  color: Colors.white,
                                ),
                              ),
                              errorWidget: (context, url, error) => const Icon(
                                Icons.person,
                                size: 45,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Profile info section
            SliverToBoxAdapter(
              child: _buildProfileInfo(),
            ),

            // Tab bar - pinned
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.primaryColor,
                  labelColor: AppColors.primaryColor,
                  unselectedLabelColor: Colors.grey,
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                  tabs: const [
                    Tab(text: "Services"),
                    Tab(text: "Reviews"),
                    Tab(text: "Gallery"),
                  ],
                ),
              ),
            ),

            // Conditional Search bar - only shows for Services tab
            if (_showSearchBar)
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverSearchBarDelegate(
                  Container(
                    color: AppColors.porcelainColor,
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _serviceSearchController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'Search services...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                    ),
                  ),
                ),
              ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildServicesTabSliver(),
            _buildReviewsTabSliver(),
            _buildPhotosTabSliver(),
          ],
        ),
      ),
    );
  }

  // Updated Services tab without search bar (since it's now in the header)
  Widget _buildServicesTabSliver() {
    return CustomScrollView(
      slivers: [
        // Services list (search bar removed from here)
        _isLoadingServices
            ? SliverToBoxAdapter(
          child: SizedBox(
            height: 400,
            child: _buildServicesShimmer(),
          ),
        )
            : filteredServices.isEmpty
            ? SliverToBoxAdapter(
          child: Container(
            height: 200,
            alignment: Alignment.center,
            child: Text(
              _serviceSearchController.text.isEmpty
                  ? 'No services available'
                  : 'No services found',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
        )
            : SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              final service = filteredServices[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildServiceCard(service),
              );
            },
            childCount: filteredServices.length,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsTabSliver() {
    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildListDelegate([
            const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  ListTile(
                    leading: CircleAvatar(child: Text("A")),
                    title: Text("Amit Patel"),
                    subtitle: Text("Amazing service and friendly staff. Highly recommended!"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 16),
                        Text(" 5"),
                      ],
                    ),
                  ),
                  Divider(),
                  ListTile(
                    leading: CircleAvatar(child: Text("S")),
                    title: Text("Sneha R."),
                    subtitle: Text("Great experience, very professional."),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 16),
                        Text(" 4"),
                      ],
                    ),
                  ),
                  Divider(),
                  ListTile(
                    leading: CircleAvatar(child: Text("M")),
                    title: Text("Maya K."),
                    subtitle: Text("Perfect nail art! Will definitely come back."),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 16),
                        Text(" 5"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _buildPhotosTabSliver() {
    final images = [
      AppImages.nail1,
      AppImages.nail2,
      AppImages.nail3,
      AppImages.nail4,
    ];

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16.0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            delegate: SliverChildBuilderDelegate(
                  (context, index) => ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  images[index],
                  fit: BoxFit.cover,
                ),
              ),
              childCount: 4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red, fontSize: 16),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _fetchStylistDetail,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfo() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Text(
            stylist?.description ?? '',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatItem('Rating', _formatRating(stylist?.rating ?? 0), Icons.star, Colors.amber),
              const SizedBox(width: 32),
              _buildStatItem('Reviews', '124', Icons.rate_review, AppColors.primaryColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildCartModal(StateSetter setModalState) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Modal handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Your Services',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(),
          // Cart items
          Expanded(
            child: cartItems.isEmpty
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Your cart is empty',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: cartItems.length,
              itemBuilder: (context, index) {
                final service = cartItems[index];
                return _buildCartItem(service, index, setModalState);
              },
            ),
          ),
          // Total and checkout
          if (cartItems.isNotEmpty) _buildCartFooter(),
        ],
      ),
    );
  }

  Widget _buildCartItem(ServiceModel service, int index, StateSetter setModalState) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: service.avatar,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) => Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.spa, color: Colors.grey),
            ),
          ),
        ),
        title: Text(
          service.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cash
            Text(
              '\$${service.price.toStringAsFixed(0)}',
              style: const TextStyle(
                color: AppColors.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          onPressed: () {
            setState(() {
              cartItems.removeAt(index);
            });
            setModalState(() {}); // Update modal state
            _shakeController.reset();
            _shakeController.forward();
          },
          icon: const Icon(
            Icons.remove_circle,
            color: Colors.red,
          ),
        ),
      ),
    );
  }

  Widget _buildCartFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '\$${_totalPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Đóng modal giỏ hàng
                _navigateToBookingScreen(); // Điều hướng đến BookingScheduleScreen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Book Now',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(ServiceModel service) {
    final isExpanded = expandedServiceId == service.id.toString();
    final isInCart = cartItems.any((item) => item.id == service.id); // Check if service is in cart

    return GestureDetector(
      onTap: () => _toggleExpand(service),
      onLongPress: () => _addToCart(service),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(isExpanded ? 0.2 : 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: isInCart
              ? Border.all(
            color: Colors.green,
            width: 2,
            style: BorderStyle.solid,
          )
              : null, // Highlight with green border if in cart
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: service.avatar,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Shimmer.fromColors(
                        baseColor: Colors.grey[300]!,
                        highlightColor: Colors.grey[100]!,
                        child: Container(
                          width: 60,
                          height: 60,
                          color: Colors.white,
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.spa,
                          color: Colors.grey,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${service.price.toStringAsFixed(0)}${service.plus == true ? "+" : ""}',
                          style: const TextStyle(
                            color: AppColors.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedRotation(
                        duration: const Duration(milliseconds: 300),
                        turns: isExpanded ? 0.5 : 0,
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: isExpanded ? AppColors.primaryColor : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Description với style nổi bật
              // Thay thế phần description trong Option 1 bằng:
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: Container(
                  height: isExpanded ? null : 0,
                  child: isExpanded
                      ? Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primaryColor.withOpacity(0.03),
                          AppColors.primaryColor.withOpacity(0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryColor.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start, // Thêm crossAxisAlignment
                          children: [
                            Icon(
                              Icons.star_rate_rounded,
                              color: AppColors.primaryColor,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded( // Thêm Expanded để text xuống dòng
                              child: Text(
                                service.description,
                                style: TextStyle(
                                  color: AppColors.darkSkyBlueColor,
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  height: 1.6,
                                  fontWeight: FontWeight.w500,
                                ),
                                softWrap: true, // Đảm bảo text xuống dòng
                                overflow: TextOverflow.visible, // Hoặc TextOverflow.fade/ellipsis tùy preference
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServicesShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                title: Container(
                  height: 16,
                  width: double.infinity,
                  color: Colors.white,
                ),
                subtitle: Container(
                  height: 14,
                  width: 200,
                  color: Colors.white,
                  margin: const EdgeInsets.only(top: 8),
                ),
                trailing: Container(
                  height: 16,
                  width: 40,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Service model class
class ServiceModel {
  final int id;
  final String name;
  final String description;
  final double price;
  final String avatar;
  final bool plus;

  ServiceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.avatar,
    required this.plus
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
        id: json['id'],
        name: json['name'],
        description: json['description'],
        price: json['price']?.toDouble() ?? 0.0,
        avatar: json['avatar'] ?? '',
        plus: json['plus']
    );
  }
}

// Extension cho DateTime để check isToday
extension DateTimeExtension on DateTime {
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  const _SliverTabBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.porcelainColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return _tabBar != oldDelegate._tabBar;
  }
}

class _SliverSearchBarDelegate extends SliverPersistentHeaderDelegate {
  const _SliverSearchBarDelegate(this._searchBar);

  final Widget _searchBar;

  @override
  double get minExtent => 80; // Height of search bar + padding

  @override
  double get maxExtent => 80;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return _searchBar;
  }

  @override
  bool shouldRebuild(_SliverSearchBarDelegate oldDelegate) {
    return _searchBar != oldDelegate._searchBar;
  }
}