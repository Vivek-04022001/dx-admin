import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../BannerManagment/banner_management_screen.dart';
import '../CouponCodeManagment/coupanCodeScreen.dart';
import '../Dashboard/dashboard_screen.dart';
import '../LocationScreen/locationManagementScreen.dart';
import '../MainCategory/main_category.dart';
import '../Order/order_management_screen.dart';
import '../Product/product_management_screen.dart';
import '../Settings/setting_screen.dart';
import '../StockManagement/stockManagementScreen.dart';
import '../User/user_management_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {


  int _selectedIndex = 0;
  bool isSidebarExpanded = true;

  final List<Map<String, dynamic>> menuItems = [

    {'icon': Icons.dashboard, 'label': 'Dashboard', 'screen': const DashboardScreen()},
    {'icon': Icons.category_rounded, 'label': 'Category', 'screen': const MainCategory()},
    {'icon': Icons.shopping_bag, 'label': 'Product', 'screen': const ProductManagementScreen()},
    {'icon': Icons.local_offer, 'label': 'Coupon Code', 'screen': const CouponCodeScreen()},
    {'icon': Icons.image, 'label': 'Banners', 'screen': const BannerManagementScreen()},
    {'icon': Icons.shopping_cart_checkout, 'label': 'Order', 'screen': const OrderManagementScreen()},
    {'icon': Icons.person, 'label': 'User', 'screen': const UserManagementScreen()},
    {'icon': Icons.location_city, 'label': 'Location', 'screen': LocationManagementScreen()},
    {'icon': Icons.inventory_2, 'label': 'Stock', 'screen': StockManagementScreen()},
    {'icon': Icons.settings, 'label': 'Setting', 'screen': SettingScreen()},

  ];

  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = menuItems.map((item) => item['screen'] as Widget).toList();
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.white,
        systemNavigationBarColor: Colors.white,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildNavigationRail(),
          Expanded(
            child: Container(
              color: const Color(0xFFF8F9FC),
              child: _screens[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildNavigationRail() {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: IntrinsicHeight(
            child: NavigationRail(
              minWidth: isSidebarExpanded ? 70.w : 55.w,
              extended: isSidebarExpanded,
              backgroundColor: Colors.white,
              elevation: 4,
              leading: Column(
                children: [
                  SizedBox(height: 20.h),
                  IconButton(
                    icon: Icon(
                      isSidebarExpanded ? Icons.menu_open : Icons.menu,
                      color: const Color(0xFF0F969c),
                      size: 22.sp,
                    ),
                    onPressed: () {
                      setState(() {
                        isSidebarExpanded = !isSidebarExpanded;
                      });
                    },
                  ),
                ],
              ),
              destinations: menuItems
                  .map((item) => _buildRailDestination(item['icon'], item['label']))
                  .toList(),
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
            ),
          ),
        ),
      ),
    );
  }

  NavigationRailDestination _buildRailDestination(IconData icon, String label) {
    return NavigationRailDestination(
      icon: Icon(icon, color: const Color(0xFF2C3E50), size: 22.sp),
      label: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF2C3E50),
          ),
        ),
      ),
    );
  }
}
