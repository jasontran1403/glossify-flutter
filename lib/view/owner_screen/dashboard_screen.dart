import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hair_sallon/view/owner_screen/store_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  String _userRole = 'OWNER';

  @override
  void initState() {
    super.initState();
    _initializeAndNavigate();
  }

  Future<void> _initializeAndNavigate() async {
    await _getUserRole();

    if (!mounted) return;

    // Navigate to OwnerStoreDetailScreen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => OwnerStoreDetailScreen(),
      ),
    );
  }

  Future<void> _getUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userRole = prefs.getString('role') ?? 'OWNER';
      });
    } catch (e) {
      print('Error getting user role: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}