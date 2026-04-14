import 'package:flutter/material.dart';
import 'package:hair_sallon/api/api_service.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/utils/local_images/local_images.dart';
import 'package:hair_sallon/utils/navigation/navigation_file.dart';
import 'package:hair_sallon/view/home_screen/widget/all_top_rated_sallon.dart';
import 'package:hair_sallon/view/home_screen/widget/audio_manager.dart';
import 'package:hair_sallon/view/home_screen/widget/salon_special_detail_page.dart';
import 'package:hair_sallon/view/home_screen/widget/specialofferscreen.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../api/api_response_model.dart';
import '../../api/gallery_model.dart';
import '../../api/review_model.dart';
import '../../utils/constant/staff_simple.dart';

import '../../utils/constant/nail_store_model.dart';
import '../../utils/constant/nail_store_simple.dart';
import 'detail_stylist.dart';
import 'quick_book.dart';

class HomeScreenView extends StatefulWidget {
  const HomeScreenView({super.key});

  @override
  State<HomeScreenView> createState() => _HomeScreenViewState();
}

class _HomeScreenViewState extends State<HomeScreenView> with TickerProviderStateMixin {
  final List<String> mainContainerImages = [
    AppImages.salon,
    AppImages.salon1,
    AppImages.salon,
  ];

  final AudioManager _audioManager = AudioManager();

  final String defaultCategoryImage = AppImages.salon;

  // Navigation state
  bool _showSalonList = true;
  NailStoreSimple? _selectedSalon;

  void _showSalonInfoModal({int initialTab = 0}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SalonInfoModal(
        salon: _selectedSalon!,
        storeDetails: nailStore!,
        initialTabIndex: initialTab,
      ),
    );
  }

  // Salon list data
  List<NailStoreSimple> stores = [];
  List<NailStoreSimple> filteredStores = [];
  bool _isStoreLoading = true;
  String? _errorMessage;

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Salon detail data
  NailStoreModel? nailStore;
  bool _isDetailLoading = true;
  List<StaffSimple> stylists = [];
  List<StaffSimple> filteredStylists = [];
  bool _isLoadingStylists = true;
  bool _isMutedTheme = true;
  final TextEditingController _stylistSearchController = TextEditingController();

  // Blinking animation for Book Now button
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  // Bell animation for floating action button
  AnimationController? _bellController;
  Animation<double>? _shakeAnimation;
  Animation<double>? _rotateAnimation;

  // Responsive breakpoints
  static const double tabletBreakpoint = 600;
  static const double desktopBreakpoint = 1200;

  bool get isTablet => MediaQuery.of(context).size.width >= tabletBreakpoint;
  bool get isDesktop => MediaQuery.of(context).size.width >= desktopBreakpoint;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();

    _fetchStores();
    _searchController.addListener(_filterStores);
    _stylistSearchController.addListener(_filterStylists);

    if (!_isMutedTheme) _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    await _audioManager.initialize();
    await _audioManager.play();
  }

  void _initializeAnimations() {
    _blinkController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _blinkAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _blinkController,
      curve: Curves.easeInOut,
    ));
    _blinkController.repeat(reverse: true);
  }

  void _startBellAnimation() {
    if (_bellController == null) {
      _bellController = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      );

      _shakeAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: _bellController!,
          curve: Curves.elasticOut,
        ),
      );

      _rotateAnimation = Tween<double>(
        begin: -0.1,
        end: 0.1,
      ).animate(
        CurvedAnimation(
          parent: _bellController!,
          curve: Curves.easeInOut,
        ),
      );
    }

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _bellController != null) {
        _bellController!.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _stylistSearchController.dispose();
    _blinkController.dispose();
    _bellController?.dispose();

    super.dispose();
  }

  Future<void> _fetchStores() async {
    setState(() {
      _isStoreLoading = true;
      _errorMessage = null;
    });
    try {
      final storeData = await ApiService.getStores();

      setState(() {
        stores = storeData;
        filteredStores = storeData;
        _isStoreLoading = false;
      });
    } catch (e) {
      setState(() {
        stores = [];
        filteredStores = [];
        _errorMessage = 'Failed to load stores data';
        _isStoreLoading = false;
      });
    }
  }

  void _filterStores() {
    final query = _searchController.text.toLowerCase().trim();

    if (query.isEmpty) {
      setState(() {
        filteredStores = stores;
      });
      return;
    }

    setState(() {
      filteredStores = stores.where((store) {
        final nameMatch = store.name.toLowerCase().contains(query);
        final locationMatch = store.location.toLowerCase().contains(query);
        final smartLocationMatch = _checkSmartLocationMatch(store.location, query);

        return nameMatch || locationMatch || smartLocationMatch;
      }).toList();
    });
  }

  bool _checkSmartLocationMatch(String location, String query) {
    final locationLower = location.toLowerCase();

    final locationMap = {
      'new york': ['ny', 'new york', 'new york city', 'nyc'],
      'illinois': ['il', 'illinois', 'chicago'],
      'california': ['ca', 'california', 'los angeles', 'san francisco'],
      'texas': ['tx', 'texas', 'dallas', 'houston'],
      'florida': ['fl', 'florida', 'miami', 'orlando'],
      'washington': ['wa', 'washington', 'seattle'],
      'district of columbia': ['dc', 'washington dc', 'district of columbia'],
    };

    for (final entry in locationMap.entries) {
      if (entry.value.any((alias) => query.contains(alias))) {
        if (locationLower.contains(entry.key)) {
          return true;
        }
      }
    }

    return false;
  }

  Future<void> _fetchNailStore(String storeName) async {
    setState(() {
      _isDetailLoading = true;
      _errorMessage = null;
    });
    try {
      final storeData = await ApiService.getStoreByName(storeName);
      setState(() {
        nailStore = storeData;
        _isDetailLoading = false;
      });
    } catch (e) {
      print('Error fetching store: $e');
      setState(() {
        nailStore = null;
        _errorMessage = 'Failed to load store data';
        _isDetailLoading = false;
      });
    }
  }

  Future<void> _fetchStylists() async {
    if (_selectedSalon == null) return;

    setState(() {
      _isLoadingStylists = true;
      _errorMessage = null;
    });

    try {
      final staffData = await ApiService.getAllStaff(_selectedSalon!.id);

      // ✅ Bỏ qua user có name là "Anyone"
      final filteredData = staffData.where((staff) {
        return staff.fullName?.toLowerCase() != 'anyone';
      }).toList();

      setState(() {
        stylists = filteredData;
        filteredStylists = filteredData;
        _isLoadingStylists = false;
      });
    } catch (e) {
      print('Error fetching staff: $e');
      setState(() {
        stylists = [];
        filteredStylists = [];
        _errorMessage = 'Failed to load staff';
        _isLoadingStylists = false;
      });
    }
  }

  void _filterStylists() {
    final query = _stylistSearchController.text.toLowerCase();
    setState(() {
      filteredStylists = stylists.where((stylist) {
        return stylist.fullName.toLowerCase().contains(query);
      }).toList();
    });
  }

  void _navigateToSalonDetail(NailStoreSimple salon) {
    setState(() {
      _selectedSalon = salon;
      _showSalonList = false;
    });
    _fetchNailStore(salon.name);
    _fetchStylists();
  }

  void _navigateBackToList() {
    setState(() {
      _showSalonList = true;
      _selectedSalon = null;
      _searchController.clear();
      _stylistSearchController.clear();
    });
  }

  void _navigateToQuickBook() {
    if (_selectedSalon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No salon selected for booking.')),
      );
      return;
    }
    Navigation.push(
      context,
      QuickBookScreen(
          storeId: _selectedSalon!.id,
          storeName: _selectedSalon!.name,
          storeAvt: _selectedSalon!.avt,
          storeLocation: _selectedSalon!.location
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.porcelainColor,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Stack(
            children: [
              _showSalonList ? _buildSalonListView() : _buildSalonDetailView(),
              if (!_showSalonList) _buildTopNotificationBell(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopNotificationBell() {
    if (_bellController == null || _shakeAnimation == null || _rotateAnimation == null) {
      return Container();
    }

    final bellSize = isTablet ? 64.0 : 56.0;
    final iconSize = isTablet ? 28.0 : 24.0;

    return Positioned(
      bottom: 20,
      right: 20,
      child: AnimatedBuilder(
        animation: _bellController!,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(
              _shakeAnimation!.value * 8 * (0.8 - _shakeAnimation!.value),
              0,
            ),
            child: Transform.rotate(
              angle: _rotateAnimation!.value,
              child: Container(
                width: bellSize,
                height: bellSize,
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryColor.withOpacity(0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(bellSize / 2),
                    onTap: _navigateToQuickBook,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.notifications_active,
                          color: Colors.white,
                          size: iconSize,
                        ),
                        Positioned(
                          right: isTablet ? 14 : 12,
                          top: isTablet ? 14 : 12,
                          child: Container(
                            width: isTablet ? 10 : 8,
                            height: isTablet ? 10 : 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // SALON LIST VIEW - RESPONSIVE UPDATES
  Widget _buildSalonListView() {
    return Padding(
      padding: EdgeInsets.all(isTablet ? 24.0 : 12.0),
      child: Column(
        children: [
          _buildListHeader(),
          SizedBox(height: isTablet ? 24.0 : 20.0),
          _buildSearchBar(),
          SizedBox(height: isTablet ? 24.0 : 20.0),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSpecialForYouSection(),
                  SizedBox(height: isTablet ? 24.0 : 20.0),
                  _buildSalonsGridSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListHeader() {
    return Row(
      children: [
        Icon(Icons.location_on, color: AppColors.primaryColor, size: isTablet ? 24 : null),
        SizedBox(width: isTablet ? 8 : 4),
        Text(
          'Choose Your Salon',
          style: TextStyle(
            fontSize: isTablet ? 22 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        CircleAvatar(
          radius: isTablet ? 20 : 15,
          child: Icon(
            Icons.notification_add,
            color: AppColors.blackColor,
            size: isTablet ? 20 : null,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: isTablet ? 55 : 45,
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search, size: isTablet ? 24 : null),
                hintText: 'Search by salon name or city...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(isTablet ? 15 : 10),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: Icon(Icons.clear, size: isTablet ? 24 : null),
                  onPressed: () {
                    _searchController.clear();
                    _filterStores();
                  },
                )
                    : null,
              ),
              onChanged: (value) => _filterStores(),
            ),
          ),
        ),
        SizedBox(width: isTablet ? 16 : 10),
        _buildTuneButton(),
      ],
    );
  }

  Widget _buildTuneButton() {
    return Container(
      height: isTablet ? 55 : 45,
      width: isTablet ? 60 : 47,
      decoration: BoxDecoration(
        color: AppColors.primaryColor,
        borderRadius: BorderRadius.circular(isTablet ? 15 : 12),
      ),
      child: Icon(
        Icons.tune,
        color: AppColors.whiteColor,
        size: isTablet ? 24 : null,
      ),
    );
  }

  Widget _buildSpecialForYouSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Special For You',
              () => Navigation.push(context, SpecialOfferScreen()),
        ),
        SizedBox(height: isTablet ? 16 : 5),
        InkWell(
          onTap: () => Navigation.push(context, const SalonServiceDetailsPage()),
          child: SizedBox(
            height: isTablet ? 200 : 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: mainContainerImages.length,
              itemBuilder: (context, index) {
                return mainContainer(imageUrl: mainContainerImages[index]);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSalonsGridSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Available Salons',
              () => Navigation.push(context, TopRatedSalonsScreen()),
        ),
        SizedBox(height: isTablet ? 20 : 16),

        if (_searchController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Found ${filteredStores.length} results for "${_searchController.text}"',
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),

        if (_isStoreLoading)
          _buildShimmerGrid()
        else if (_errorMessage != null)
          Center(
            child: Column(
              children: [
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: isTablet ? 18 : 16,
                  ),
                ),
                SizedBox(height: isTablet ? 16 : 10),
                ElevatedButton(
                  onPressed: _fetchStores,
                  child: Text(
                    'Retry',
                    style: TextStyle(fontSize: isTablet ? 16 : 14),
                  ),
                ),
              ],
            ),
          )
        else if (filteredStores.isEmpty)
            _buildEmptyState()
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isTablet ? 3 : 2,
                crossAxisSpacing: isTablet ? 16 : 12,
                mainAxisSpacing: isTablet ? 16 : 12,
                childAspectRatio: isTablet ? 0.85 : 0.9, // Thu nhỏ tỷ lệ cho tablet
              ),
              itemCount: filteredStores.length,
              itemBuilder: (context, index) {
                final store = filteredStores[index];
                return _buildStoreCard(store);
              },
            ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(isTablet ? 60 : 40),
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            size: isTablet ? 80 : 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: isTablet ? 20 : 16),
          Text(
            'No salons found',
            style: TextStyle(
              fontSize: isTablet ? 22 : 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: isTablet ? 12 : 8),
          Text(
            _searchController.text.isEmpty
                ? 'There are no salons available at the moment.'
                : 'No salons found for "${_searchController.text}". Try searching with different keywords.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isTablet ? 16 : 14,
              color: Colors.grey[500],
            ),
          ),
          SizedBox(height: isTablet ? 20 : 16),
          if (_searchController.text.isNotEmpty)
            ElevatedButton(
              onPressed: () {
                _searchController.clear();
                _filterStores();
              },
              child: Text(
                'Clear Search',
                style: TextStyle(fontSize: isTablet ? 16 : 14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStoreCard(NailStoreSimple store) {
    return GestureDetector(
      onTap: () => _navigateToSalonDetail(store),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
          side: BorderSide(
            color: AppColors.primaryColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(isTablet ? 16 : 12),
                ),
                child: store.avt.isNotEmpty
                    ? CachedNetworkImage(
                  imageUrl: store.avt,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => _buildImageShimmer(),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[200],
                    child: Icon(
                      Icons.store,
                      size: isTablet ? 60 : 50,
                      color: Colors.grey,
                    ),
                  ),
                )
                    : Container(
                  color: Colors.grey[200],
                  child: Icon(
                    Icons.store,
                    size: isTablet ? 60 : 50,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(isTablet ? 12.0 : 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      store.name,
                      style: TextStyle(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: isTablet ? 16 : 14,
                          color: AppColors.primaryColor,
                        ),
                        SizedBox(width: isTablet ? 4 : 2),
                        Expanded(
                          child: Text(
                            store.location,
                            style: TextStyle(
                              fontSize: isTablet ? 14 : 12,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // SALON DETAIL VIEW - RESPONSIVE UPDATES
  Widget _buildSalonDetailView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_bellController == null) {
        _startBellAnimation();
      }
    });

    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 24.0 : 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStoreInfo(),
                SizedBox(height: isTablet ? 32 : 24),
                _buildDetailSpecialForYouSection(),
                SizedBox(height: isTablet ? 32 : 24),
                _buildStylistsSection(),
                SizedBox(height: isTablet ? 24 : 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: isTablet ? 350 : 250,
      pinned: true,
      backgroundColor: AppColors.primaryColor,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: AppColors.whiteColor,
          size: isTablet ? 28 : null,
        ),
        onPressed: _navigateBackToList,
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          _selectedSalon?.name ?? '',
          style: TextStyle(
            color: AppColors.whiteColor,
            fontSize: isTablet ? 20 : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        background: _selectedSalon?.avt.isNotEmpty == true
            ? CachedNetworkImage(
          imageUrl: _selectedSalon!.avt,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildImageShimmer(),
          errorWidget: (context, url, error) => Container(
            color: AppColors.primaryColor,
            child: Icon(
              Icons.store,
              size: isTablet ? 100 : 80,
              color: AppColors.whiteColor,
            ),
          ),
        )
            : Container(
          color: AppColors.primaryColor,
          child: Icon(
            Icons.store,
            size: isTablet ? 100 : 80,
            color: AppColors.whiteColor,
          ),
        ),
      ),
    );
  }

  Widget _buildStoreInfo() {
    if (_selectedSalon == null) return Container();

    // ✅ USE REAL DATA FROM SELECTED SALON
    final double rating = _selectedSalon!.rating;
    final int reviewCount = _selectedSalon!.reviews;

    return Card(
      elevation: 2,
      color: AppColors.porcelainColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 20.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedSalon!.name,
              style: TextStyle(
                fontSize: isTablet ? 24 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: isTablet ? 12 : 8),
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: isTablet ? 20 : 16,
                  color: AppColors.primaryColor,
                ),
                SizedBox(width: isTablet ? 6 : 4),
                Expanded(
                  child: Text(
                    _selectedSalon!.location,
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isTablet ? 12 : 8),
            Row(
              children: [
                Icon(
                  Icons.star,
                  size: isTablet ? 20 : 16,
                  color: Colors.amber,
                ),
                SizedBox(width: isTablet ? 6 : 4),

                // ===== CLICKABLE REVIEWS SECTION =====
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showSalonInfoModal(initialTab: 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          // ✅ FORMAT RATING: Show 1 decimal if > 0, otherwise "No rating"
                          reviewCount > 0
                              ? '${rating.toStringAsFixed(1)} ($reviewCount review${reviewCount == 1 ? "" : "s"})'
                              : 'No reviews yet',
                          style: TextStyle(
                            fontSize: isTablet ? 16 : 14,
                            color: reviewCount > 0 ? Colors.black87 : Colors.grey[600],
                          ),
                        ),
                        if (reviewCount > 0) ...[
                          SizedBox(width: isTablet ? 6 : 4),
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: isTablet ? 20 : 18,
                            color: AppColors.primaryColor,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const Spacer(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSpecialForYouSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Special For You',
              () => Navigation.push(context, SpecialOfferScreen()),
        ),
        SizedBox(height: isTablet ? 16 : 5),
        InkWell(
          onTap: () => Navigation.push(context, const SalonServiceDetailsPage()),
          child: SizedBox(
            height: isTablet ? 200 : 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: mainContainerImages.length,
              itemBuilder: (context, index) {
                return mainContainer(imageUrl: mainContainerImages[index]);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStylistsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Beauty Specialists',
          style: TextStyle(
            fontSize: isTablet ? 22 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: isTablet ? 16 : 10),
        TextField(
          controller: _stylistSearchController,
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.search, size: isTablet ? 24 : null),
            hintText: 'Search beauty specialist by name...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isTablet ? 15 : 10),
            ),
            contentPadding: EdgeInsets.symmetric(
              vertical: isTablet ? 16 : 12,
              horizontal: isTablet ? 16 : 12,
            ),
          ),
        ),
        SizedBox(height: isTablet ? 20 : 16),
        if (_isLoadingStylists)
          _buildStylistsShimmerGrid()
        else if (_errorMessage != null)
          Center(
            child: Column(
              children: [
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: isTablet ? 18 : 16,
                  ),
                ),
                SizedBox(height: isTablet ? 16 : 10),
                ElevatedButton(
                  onPressed: _fetchStylists,
                  child: Text(
                    'Retry',
                    style: TextStyle(fontSize: isTablet ? 16 : 14),
                  ),
                ),
              ],
            ),
          )
        else if (filteredStylists.isEmpty)
            Center(
              child: Text(
                _stylistSearchController.text.isEmpty
                    ? 'No stylists available'
                    : 'No stylists found',
                style: TextStyle(fontSize: isTablet ? 18 : 16),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isTablet ? 3 : 2,
                crossAxisSpacing: isTablet ? 16 : 10,
                mainAxisSpacing: isTablet ? 16 : 10,
                childAspectRatio: isTablet ? 0.85 : 0.9,
              ),
              itemCount: filteredStylists.length,
              itemBuilder: (context, index) {
                final stylist = filteredStylists[index];
                return _buildStylistCard(stylist);
              },
            ),
      ],
    );
  }

  Widget _buildStylistCard(StaffSimple staff) {
    String formatRating(double rating) {
      String ratingStr = rating.toStringAsFixed(2);
      if (ratingStr.contains('.')) {
        ratingStr = ratingStr.replaceAll(RegExp(r'0*$'), '');
        ratingStr = ratingStr.replaceAll(RegExp(r'\.$'), '');
      }
      return ratingStr;
    }

    final avatarSize = isTablet ? 110.0 : 90.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.grey.shade50,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StylistDetailScreen(staffId: staff.id, storeId: _selectedSalon!.id,),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 20.0 : 16.0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primaryColor.withOpacity(0.8),
                        AppColors.primaryColor,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryColor.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: ClipOval(
                      child: SizedBox(
                        width: avatarSize,
                        height: avatarSize,
                        child: CachedNetworkImage(
                          imageUrl: staff.avatar,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => _buildCircularShimmer(),
                          errorWidget: (context, url, error) => Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Colors.grey.shade200, Colors.grey.shade300],
                              ),
                            ),
                            child: Icon(
                              Icons.person,
                              size: isTablet ? 45 : 35,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: isTablet ? 16 : 12),
                Text(
                  staff.fullName,
                  style: TextStyle(
                    fontSize: isTablet ? 17 : 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isTablet ? 12 : 8),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 12 : 8,
                    vertical: isTablet ? 6 : 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(isTablet ? 14 : 12),
                    color: Colors.amber.withOpacity(0.1),
                    border: Border.all(
                      color: Colors.amber.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: isTablet ? 18 : 16,
                        color: Colors.amber,
                      ),
                      SizedBox(width: isTablet ? 6 : 4),
                      Text(
                        formatRating(staff.rating),
                        style: TextStyle(
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onTap) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(fontSize: isTablet ? 22 : 18),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onTap,
          child: Text(
            'See All',
            style: TextStyle(
              fontSize: isTablet ? 16 : 14,
              color: AppColors.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget mainContainer({required String imageUrl}) {
    final double containerWidth;
    if (isTablet) {
      containerWidth = (MediaQuery.of(context).size.width - 72) / 3;
    } else {
      containerWidth = 290.0;
    }

    return Container(
      margin: EdgeInsets.only(right: isTablet ? 16.0 : 15.0),
      width: containerWidth,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(imageUrl),
          fit: BoxFit.cover,
        ),
        borderRadius: BorderRadius.circular(isTablet ? 12.0 : 8.0),
      ),
      child: Stack(
        children: [
          Positioned(
            top: isTablet ? 16.0 : 10.0,
            left: isTablet ? 16.0 : 10.0,
            child: Container(
              height: isTablet ? 32.0 : 25.0,
              width: isTablet ? 120.0 : 100.0,
              decoration: BoxDecoration(
                color: AppColors.whiteColor,
                borderRadius: BorderRadius.circular(isTablet ? 25.0 : 20.0),
              ),
              child: Center(
                child: Text(
                  'Limited time!',
                  style: TextStyle(
                    fontSize: isTablet ? 14.0 : 12.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: isTablet ? 55.0 : 40.0,
            left: isTablet ? 16.0 : 10.0,
            child: SizedBox(
              width: containerWidth - (isTablet ? 32.0 : 20.0),
              child: Text(
                'Get Special Discount Up to 40%',
                style: TextStyle(
                  fontSize: isTablet ? 22.0 : 20.0,
                  fontWeight: FontWeight.bold,
                  color: AppColors.whiteColor,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: isTablet ? 16.0 : 10.0,
            left: isTablet ? 16.0 : 10.0,
            child: Text(
              'All Salon available | T&C Applied',
              style: TextStyle(
                fontSize: isTablet ? 14.0 : 12.0,
                color: AppColors.whiteColor,
              ),
            ),
          ),
          Positioned(
            bottom: isTablet ? 16.0 : 10.0,
            right: isTablet ? 16.0 : 10.0,
            child: Container(
              height: isTablet ? 32.0 : 25.0,
              width: isTablet ? 70.0 : 55.0,
              decoration: BoxDecoration(
                color: AppColors.primaryColor,
                borderRadius: BorderRadius.circular(isTablet ? 30.0 : 25.0),
              ),
              child: Center(
                child: Text(
                  'Claim',
                  style: TextStyle(
                    fontSize: isTablet ? 14.0 : 12.0,
                    color: AppColors.whiteColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: double.infinity,
        color: Colors.white,
      ),
    );
  }

  Widget _buildCircularShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: 80,
        height: 80,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isTablet ? 3 : 2,
        crossAxisSpacing: isTablet ? 16 : 12,
        mainAxisSpacing: isTablet ? 16 : 12,
        childAspectRatio: isTablet ? 0.85 : 0.9,
      ),
      itemCount: isTablet ? 6 : 4,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
            ),
            child: Column(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(isTablet ? 16 : 12),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: EdgeInsets.all(isTablet ? 12.0 : 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: isTablet ? 16 : 14,
                          width: double.infinity,
                          color: Colors.white,
                        ),
                        SizedBox(height: isTablet ? 10 : 8),
                        Container(
                          height: isTablet ? 14 : 12,
                          width: 100,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStylistsShimmerGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isTablet ? 3 : 2,
        crossAxisSpacing: isTablet ? 16 : 12,
        mainAxisSpacing: isTablet ? 16 : 12,
        childAspectRatio: isTablet ? 0.85 : 0.75,
      ),
      itemCount: isTablet ? 6 : 6,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
            ),
            child: Padding(
              padding: EdgeInsets.all(isTablet ? 16.0 : 12.0),
              child: Column(
                children: [
                  Container(
                    width: isTablet ? 100 : 80,
                    height: isTablet ? 100 : 80,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(height: isTablet ? 12 : 8),
                  Container(
                    height: isTablet ? 16 : 14,
                    width: double.infinity,
                    color: Colors.white,
                  ),
                  SizedBox(height: isTablet ? 8 : 4),
                  Container(
                    height: isTablet ? 14 : 12,
                    width: 60,
                    color: Colors.white,
                  ),
                  SizedBox(height: isTablet ? 6 : 2),
                  Container(
                    height: isTablet ? 12 : 10,
                    width: 80,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class StylistModel {
  final int id;
  final String name;
  final String avatar;
  final double rating;
  final String experience;

  StylistModel({
    required this.id,
    required this.name,
    required this.avatar,
    required this.rating,
    required this.experience,
  });

  factory StylistModel.fromJson(Map<String, dynamic> json) {
    return StylistModel(
      id: json['id'],
      name: json['name'],
      avatar: json['avatar'],
      rating: json['rating']?.toDouble() ?? 0.0,
      experience: json['experience'],
    );
  }
}

class SalonInfoModal extends StatefulWidget {
  final NailStoreSimple salon;
  final NailStoreModel storeDetails;
  final int initialTabIndex; // Add this parameter

  const SalonInfoModal({
    super.key,
    required this.salon,
    required this.storeDetails,
    this.initialTabIndex = 0, // Default to Reviews tab
  });

  @override
  State<SalonInfoModal> createState() => _SalonInfoModalState();
}

class _SalonInfoModalState extends State<SalonInfoModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Reviews data
  List<ReviewModel> reviews = [];
  bool _isLoadingReviews = false;
  bool _hasMoreReviews = true;
  int _reviewPage = 0;
  final ScrollController _reviewScrollController = ScrollController();

  // Gallery data
  List<GalleryModel> gallery = [];
  bool _isLoadingGallery = false;
  bool _hasMoreGallery = true;
  int _galleryPage = 0;
  final ScrollController _galleryScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );

    // Add scroll listeners
    _reviewScrollController.addListener(_onReviewScroll);
    _galleryScrollController.addListener(_onGalleryScroll);

    // Load initial data
    _loadReviews();
    _loadGallery();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reviewScrollController.dispose();
    _galleryScrollController.dispose();
    super.dispose();
  }

  // ===== LOAD REVIEWS =====
  Future<void> _loadReviews() async {
    if (_isLoadingReviews || !_hasMoreReviews) return;

    setState(() => _isLoadingReviews = true);

    try {
      final response = await ApiService.getStoreReviews(
        storeId: widget.salon.id,
        page: _reviewPage,
        size: 10,
      );

      if (response.isSuccess && response.data != null) {
        // Try parsing
        try {
          final newReviews = PageResponseParser.parsePageContent<ReviewModel>(
            response.data!,
                (json) => ReviewModel.fromJson(json),
          );

          final isLast = PageResponseParser.isLastPage(response.data!);

          setState(() {
            reviews.addAll(newReviews);
            _reviewPage++;
            _hasMoreReviews = !isLast;
            _isLoadingReviews = false;
          });
        } catch (parseError) {
          print('❌ PARSE ERROR: $parseError');
          print('❌ Parse stack trace: ${StackTrace.current}');
          setState(() => _isLoadingReviews = false);
        }

      } else {
        setState(() => _isLoadingReviews = false);
      }
    } catch (e, stackTrace) {
      print('❌ EXCEPTION loading reviews: $e');
      print('❌ Stack trace: $stackTrace');
      setState(() => _isLoadingReviews = false);
    }
  }

  // ===== LOAD GALLERY =====
  Future<void> _loadGallery() async {
    if (_isLoadingGallery || !_hasMoreGallery) {
      print('⚠️ Skip loading gallery: isLoading=$_isLoadingGallery, hasMore=$_hasMoreGallery');
      return;
    }

    setState(() => _isLoadingGallery = true);

    try {
      final response = await ApiService.getStoreGallery(
        storeId: widget.salon.id,
        page: _galleryPage,
        size: 12,
      );

      if (response.isSuccess && response.data != null) {
        try {
          final newGallery = PageResponseParser.parsePageContent<GalleryModel>(
            response.data!,
                (json) => GalleryModel.fromJson(json),
          );

          final isLast = PageResponseParser.isLastPage(response.data!);

          setState(() {
            gallery.addAll(newGallery);
            _galleryPage++;
            _hasMoreGallery = !isLast;
            _isLoadingGallery = false;
          });

        } catch (parseError, stackTrace) {
          setState(() => _isLoadingGallery = false);
        }

      } else {
        setState(() => _isLoadingGallery = false);
      }
    } catch (e, stackTrace) {
      setState(() => _isLoadingGallery = false);
    }
  }

  // ===== SCROLL LISTENERS =====
  void _onReviewScroll() {
    if (_reviewScrollController.position.pixels >=
        _reviewScrollController.position.maxScrollExtent - 200) {
      _loadReviews();
    }
  }

  void _onGalleryScroll() {
    if (_galleryScrollController.position.pixels >=
        _galleryScrollController.position.maxScrollExtent - 200) {
      _loadGallery();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final modalWidth = screenWidth > 600
        ? (screenWidth * 0.7).clamp(500.0, 700.0)
        : screenWidth * 0.95;

    final modalHeight = screenHeight * 0.85;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: modalWidth,
        height: modalHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            // ===== HANDLE BAR & CLOSE BUTTON =====
            Stack(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 4,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 24),
                    onPressed: () => Navigator.of(context).pop(),
                    color: Colors.grey[600],
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),

            // Tab bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorPadding: const EdgeInsets.all(4),
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade300,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: Colors.black,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.normal,
                  fontSize: 15,
                ),
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                tabs: const [
                  Tab(text: "Reviews"),
                  Tab(text: "Gallery"),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildReviewsTab(),
                  _buildGalleryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== REVIEWS TAB =====
  Widget _buildReviewsTab() {
    if (reviews.isEmpty && _isLoadingReviews) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.teal),
      );
    }

    if (reviews.isEmpty && !_isLoadingReviews) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No reviews yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      controller: _reviewScrollController,
      padding: const EdgeInsets.all(20),
      itemCount: reviews.length + (_hasMoreReviews ? 1 : 0),
      separatorBuilder: (context, index) => const Divider(height: 24),
      itemBuilder: (context, index) {
        // Loading indicator at the end
        if (index == reviews.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(color: Colors.teal),
            ),
          );
        }

        final review = reviews[index];
        return _buildReviewItem(review);
      },
    );
  }

  // ===== REVIEW ITEM =====
  Widget _buildReviewItem(ReviewModel review) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar
        CircleAvatar(
          radius: 20,
          backgroundImage: review.avatarUrl.isNotEmpty
              ? NetworkImage(review.avatarUrl)
              : null,
          backgroundColor: Colors.teal.withOpacity(0.1),
          child: review.avatarUrl.isEmpty
              ? Text(
            review.name.isNotEmpty ? review.name[0].toUpperCase() : '?',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
          )
              : null,
        ),

        const SizedBox(width: 12),

        // Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name & Rating
              Row(
                children: [
                  Expanded(
                    child: Text(
                      review.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  // Rating
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.amber.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star,
                          size: 14,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          review.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Date
              Text(
                review.formattedDate,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),

              const SizedBox(height: 8),

              // Review text
              if (review.text.isNotEmpty)
                Text(
                  review.text,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[800],
                    height: 1.4,
                  ),
                ),

              // Photos
              if (review.photos.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: review.photos.length,
                    itemBuilder: (context, photoIndex) {
                      return GestureDetector(
                        onTap: () => _showPhotoViewer(review.photos, photoIndex),
                        child: Container(
                          width: 80,
                          margin: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              review.photos[photoIndex],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.image, color: Colors.grey),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ===== GALLERY TAB =====
  Widget _buildGalleryTab() {
    if (gallery.isEmpty && _isLoadingGallery) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.teal),
      );
    }

    if (gallery.isEmpty && !_isLoadingGallery) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No gallery images yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      controller: _galleryScrollController,
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: gallery.length + (_hasMoreGallery ? 1 : 0),
      itemBuilder: (context, index) {
        // Loading indicator at the end
        if (index == gallery.length) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.teal),
          );
        }

        final image = gallery[index];
        return GestureDetector(
          onTap: () => _showPhotoViewer(
            gallery.map((g) => g.imageUrl).toList(),
            index,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              image.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.image, size: 48, color: Colors.grey),
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: Colors.grey[200],
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                          : null,
                      color: Colors.teal,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ===== PHOTO VIEWER =====
  void _showPhotoViewer(List<String> photos, int initialIndex) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            PageView.builder(
              itemCount: photos.length,
              controller: PageController(initialPage: initialIndex),
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  child: Image.network(
                    photos[index],
                    fit: BoxFit.contain,
                  ),
                );
              },
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
