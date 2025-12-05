import 'package:flutter/material.dart';
import 'management_screen/category_screen.dart';
import 'management_screen/service_screen.dart';
import 'management_screen/staff_screen.dart';
import 'management_screen/store_screen.dart';

class ManagementScreen extends StatefulWidget {
  const ManagementScreen({super.key});

  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: AppBar(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          centerTitle: true,
          title: null,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60.0),
            child: Center( // <-- THÊM CENTER Ở ĐÂY
              child: TabBar(
                controller: _tabController,
                isScrollable: false,
                tabs: const [
                  Tab(text: 'Staff'),
                  Tab(text: 'Category'),
                  Tab(text: 'Service'),
                  Tab(text: 'Store Info'),
                ],
                indicatorColor: Colors.white,
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          StaffTab(),
          CategoryTab(),
          ServiceTab(),
          StoreTab(),
        ],
      ),
    );
  }
}