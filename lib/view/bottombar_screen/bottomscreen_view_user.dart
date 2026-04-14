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
import 'package:hair_sallon/api/jwt_service.dart';
import 'package:hair_sallon/main.dart';

import '../dashboard_screen/dashboard_screen.dart';
import '../owner_screen/management_screen.dart';
import '../owner_screen/management_screen/day_off_management_screen.dart';
import '../receptionist_screen/payment_screen.dart';
import '../receptionist_screen/schedule_manage_screen.dart';
import '../front_desk_screen/front_desk_welcome_screen.dart';
import '../staff_screen/day_off_screen.dart';

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
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialTabIndex;
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      if (token != null && token.isNotEmpty) {
        bool isValid = await JwtService.isTokenValid();

        if (!isValid) {
          if (mounted) {
            showTopNotification(
              "Session Expired",
              "Please log in again to continue",
            );

            await Future.delayed(const Duration(seconds: 3));
            await _handleTokenExpiration();
          }

          return;
        }

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
      } else {
        if (mounted) {
          setState(() {
            _userRole = "USER";
            _isRoleLoaded = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userRole = "USER";
          _isRoleLoaded = true;
        });
      }
    }
  }

  Future<void> _handleTokenExpiration() async {
    if (_isLoggingOut) return;

    setState(() {
      _isLoggingOut = true;
    });

    bool isOnHomeScreen = selectedIndex == 0;

    if (isOnHomeScreen) {
      await Future.delayed(const Duration(seconds: 1));
      await JwtService.clearAuthData();

      if (mounted) {
        setState(() {
          _userRole = "USER";
          _isRoleLoaded = true;
          selectedIndex = 0;
          _isLoggingOut = false;
        });
      }
    } else {

      if (mounted) {
        setState(() {
          selectedIndex = 0;
        });
      }

      await Future.delayed(const Duration(seconds: 1));

      await JwtService.clearAuthData();

      if (mounted) {
        setState(() {
          _userRole = "USER";
          _isRoleLoaded = true;
          _isLoggingOut = false;
        });
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

  Future<void> onMenuTapped(int index) async {
    bool isValid = await JwtService.isTokenValid();

    if (!isValid) {
      if (mounted) {
        await showTopNotification(
          "Session Expired",
          "Please log in again to continue",
        );

        await Future.delayed(const Duration(seconds: 3));
        await _handleTokenExpiration();
      }

      return;
    }

    if (mounted) {
      setState(() {
        selectedIndex = index;
      });
    }
  }

  final List<Widget> _userWidgetOptions = const <Widget>[
    HomeScreenView(),
    ExploreMapScreen(),
    BookingScreen(),
    ProfileScreen(),
  ];

  // ✅ UPDATED: Add DayOffScreen for STAFF
  final List<Widget> _staffWidgetOptions = const <Widget>[
    ChatViewScreen(),
    StaffStatisticScreen(),
    DayOffScreen(), // ✅ NEW: Day-off management
    ProfileScreen(),
  ];

  final List<Widget> _ownerWidgetOptions = const <Widget>[
    DashboardScreen(),
    ManagementScreen(),
    CampaignScreen(),
    DayOffManagementScreen(),
    ProfileScreen(),
  ];

  final List<Widget> _receptionistWidgetOptions = const <Widget>[
    ScheduleManagementScreen(),
    PaymentScreen(),
    GiftcardScreen(),
    ProfileScreen(),
  ];

  final List<Widget> _frontDeskWidgetOptions = const <Widget>[
    FrontDeskWelcomeScreen(),
  ];

  final List<BottomNavigationBarItem> _frontDeskNavItems = const [
    BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Welcome'),
  ];

  final List<BottomNavigationBarItem> _receptionistNavItems = const [
    BottomNavigationBarItem(
        icon: Icon(Icons.manage_accounts), label: 'Schedule'),
    BottomNavigationBarItem(icon: Icon(Icons.payment), label: 'Payment'),
    BottomNavigationBarItem(
        icon: Icon(Icons.card_giftcard), label: 'Gift Cards'),
    BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
  ];

  final List<BottomNavigationBarItem> _userNavItems = const [
    BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.location_on), label: 'Explore'),
    BottomNavigationBarItem(
        icon: Icon(Icons.calendar_month), label: 'Booking'),
    BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
  ];

  // ✅ UPDATED: Change icon from calendar to event_busy for Day Off
  final List<BottomNavigationBarItem> _staffNavItems = const [
    BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
    BottomNavigationBarItem(
        icon: Icon(Icons.calendar_month), label: 'Booking'),
    BottomNavigationBarItem(
        icon: Icon(Icons.event_busy), label: 'Day Off'), // ✅ NEW
    BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
  ];

  final List<BottomNavigationBarItem> _ownerNavItems = const [
    BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
    BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Management'),
    BottomNavigationBarItem(icon: Icon(Icons.campaign), label: 'Campaign'),
    BottomNavigationBarItem(icon: Icon(Icons.event_busy), label: 'Day Off'),
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

    return Stack(
      children: [
        Scaffold(
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
              currentIndex:
              selectedIndex.clamp(0, _currentNavItems.length - 1),
              selectedItemColor: AppColors.primaryColor,
              unselectedItemColor: AppColors.color_525252,
              showUnselectedLabels: true,
              onTap: onMenuTapped,
              items: _currentNavItems,
            ),
          ),
        ),
        if (_isLoggingOut)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Clearing old session...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
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