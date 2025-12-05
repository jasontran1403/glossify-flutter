import 'package:flutter/material.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/view/bokking_screen/bokking_upcoming_screen.dart';
import 'package:hair_sallon/view/chat_view/chat_view_screen.dart';
import 'package:hair_sallon/view/explore_map/explore_map_screen.dart';
import 'package:hair_sallon/view/home_screen/home_screen_view.dart';
import 'package:hair_sallon/view/owner_screen/campaign_screen.dart';
import 'package:hair_sallon/view/owner_screen/giftcard_screen.dart';
import 'package:hair_sallon/view/profile_screen/profile_view.dart';
import 'package:hair_sallon/view/staff_statistic_screen/staff_statistic_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dashboard_screen/dashboard_screen.dart';
import '../owner_screen/management_screen.dart';
import '../receptionist_screen/schedule_manage_screen.dart';
import '../front_desk_screen/front_desk_welcome_screen.dart';

class BottomNavBarView extends StatefulWidget {
  final int initialTabIndex;

  const BottomNavBarView({
    super.key,
    this.initialTabIndex = 0,
  });

  static final GlobalKey<_BottomNavBarViewState> globalKey =
  GlobalKey<_BottomNavBarViewState>();

  static void switchToTab(int index) {
    if (globalKey.currentState != null) {
      globalKey.currentState!.switchTab(index);
    }
  }

  static int getCurrentTab() {
    return globalKey.currentState?.selectedIndex ?? 0;
  }

  @override
  State<BottomNavBarView> createState() => _BottomNavBarViewState();
}

class _BottomNavBarViewState extends State<BottomNavBarView> {
  int selectedIndex = 0;
  String _userRole = "USER";
  bool _isRoleLoaded = false;

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialTabIndex;
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString("role") ?? "USER";

    if (mounted) {
      setState(() {
        _userRole = role;
        _isRoleLoaded = true;
      });

      final newLength = _currentWidgetOptions.length;
      if (selectedIndex >= newLength) {
        if (mounted) {
          setState(() {
            selectedIndex = 0;
          });
        }
      }
    }
  }

  void switchTab(int index) {
    if (mounted) {
      setState(() {
        selectedIndex = index;
      });
    }
  }

  void onMenuTapped(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  // Widget options cho USER
  final List<Widget> _userWidgetOptions = const <Widget>[
    HomeScreenView(),
    ExploreMapScreen(),
    BookingScreen(),
    ProfileScreen(),
  ];

  // Widget options cho STAFF
  final List<Widget> _staffWidgetOptions = const <Widget>[
    ChatViewScreen(),
    StaffStatisticScreen(),
    ProfileScreen(),
  ];

  // Widget options cho OWNER/SUPER_OWNER
  final List<Widget> _ownerWidgetOptions = const <Widget>[
    DashboardScreen(),
    ManagementScreen(),
    CampaignScreen(),
    // GiftcardScreen(),
    ProfileScreen(),
  ];

  // ⭐ FIXED: Widget options cho RECEPTIONIST - KHÔNG TRUYỀN storeId
  final List<Widget> _receptionistWidgetOptions = const <Widget>[
    ScheduleManagementScreen(), // ⭐ Bỏ storeId, để screen tự fetch
    GiftcardScreen(),
    ProfileScreen(),
  ];

  // Widget options cho FRONT_DESK
  final List<Widget> _frontDeskWidgetOptions = const <Widget>[
    FrontDeskWelcomeScreen(),
  ];

  // Bottom nav items cho FRONT_DESK
  final List<BottomNavigationBarItem> _frontDeskNavItems = const [
    BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Welcome'),
  ];

  // Bottom nav items cho RECEPTIONIST
  final List<BottomNavigationBarItem> _receptionistNavItems = const [
    BottomNavigationBarItem(icon: Icon(Icons.manage_accounts), label: 'Schedule'),
    BottomNavigationBarItem(icon: Icon(Icons.card_giftcard), label: 'Gift Cards'),
    BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
  ];

  // Bottom nav items cho USER
  final List<BottomNavigationBarItem> _userNavItems = const [
    BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.location_on), label: 'Explore'),
    BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Booking'),
    BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
  ];

  // Bottom nav items cho STAFF
  final List<BottomNavigationBarItem> _staffNavItems = const [
    BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
    BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Booking'),
    BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
  ];

  // Bottom nav items cho OWNER/SUPER_OWNER
  final List<BottomNavigationBarItem> _ownerNavItems = const [
    BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
    BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Management'),
    BottomNavigationBarItem(icon: Icon(Icons.campaign), label: 'Campaign'),
    // BottomNavigationBarItem(icon: Icon(Icons.card_giftcard), label: 'Gift card'),
    BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
  ];

  List<Widget> get _currentWidgetOptions {
    switch (_userRole) {
      case "STAFF":
        return _staffWidgetOptions;
      case "OWNER":
      case "SUPER_OWNER":
        return _ownerWidgetOptions;
      case "RECEPTIONIST":
        return _receptionistWidgetOptions;
      case "FRONTDESK":
        return _frontDeskWidgetOptions;
      default:
        return _userWidgetOptions;
    }
  }

  List<BottomNavigationBarItem> get _currentNavItems {
    switch (_userRole) {
      case "STAFF":
        return _staffNavItems;
      case "OWNER":
      case "SUPER_OWNER":
        return _ownerNavItems;
      case "RECEPTIONIST":
        return _receptionistNavItems;
      case "FRONTDESK":
        return _frontDeskNavItems;
      default:
        return _userNavItems;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isRoleLoaded) {
      return Scaffold(
        backgroundColor: AppColors.whiteColor,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      body: _currentWidgetOptions.elementAt(
        selectedIndex.clamp(0, _currentWidgetOptions.length - 1),
      ),
      bottomNavigationBar: _userRole == "FRONTDESK"
          ? null
          : Theme(
        data: ThemeData(
          splashColor: AppColors.transparent,
          highlightColor: AppColors.transparent,
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          iconSize: 20,
          backgroundColor: AppColors.whiteColor,
          currentIndex: selectedIndex.clamp(0, _currentNavItems.length - 1),
          selectedItemColor: AppColors.primaryColor,
          unselectedItemColor: AppColors.color_525252,
          showUnselectedLabels: true,
          onTap: onMenuTapped,
          items: _currentNavItems,
        ),
      ),
    );
  }

  Widget navItem(IconData icon, int index, String label) {
    final isSelected = selectedIndex == index;
    final color = isSelected ? AppColors.primaryColor : AppColors.color_525252;

    return GestureDetector(
      onTap: () => onMenuTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}