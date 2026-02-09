import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import '../MainCategory/main_category.dart';
import '../Order/order_management_screen.dart';
import '../Product/product_management_screen.dart';
import '../StockManagement/stockManagementScreen.dart';
import '../utils/api_constants.dart';
import '../utils/colors.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List orders = [];
  bool isLoading = true;
  int totalOrders = 0;
  double todaySales = 0;
  int pendingOrders = 0;
  List<double> weeklySales = [0, 0, 0, 0, 0, 0, 0];
  List<Map<String, dynamic>> recentOrders = [];

  int totalUsers = 0;
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  List users = [];
  int limit = 10;
  int offset = 0;

  @override
  void initState() {
    super.initState();
    fetchDashboardData();
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    setState(() => isLoading = true);

    final uri = Uri.parse(
      "${ApiConstants.GET_ALL_USER}?limit=$limit&offset=$offset&search=${Uri.encodeComponent(searchQuery)}",
    );

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            users = data['users'];
            totalUsers = data['total'];
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching users: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchDashboardData() async {
    try {
      final url = Uri.parse(ApiConstants.GET_ALL_ORDER_DASHBOARD);
      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data["success"] == true) {
        setState(() {
          orders = data["orders"];
          _calculateDashboardData();
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching dashboard data: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  void _calculateDashboardData() {
    // Reset before calculation
    totalOrders = 0;
    todaySales = 0;
    pendingOrders = 0;
    weeklySales = [0, 0, 0, 0, 0, 0, 0];
    recentOrders = [];

    totalOrders = orders.length;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var orderData in orders) {
      final order = orderData["order"];
      final amount = double.tryParse(order["final_amount"].toString()) ?? 0;
      final status = order["status"].toString().toLowerCase();

      // ❌ Cancelled orders ko skip karo
      if (status == 'cancelled') continue;

      // ✅ Parse date correctly (handle both formats)
      DateTime? orderDate;
      try {
        orderDate = DateTime.parse(order["order_datetime"]);
      } catch (e) {
        try {
          final parts = order["order_datetime"].split(' ');
          final datePart = parts[0];
          final dateParts = datePart.split('-');
          if (dateParts.length == 3) {
            orderDate = DateTime(
              int.parse(dateParts[2]),
              int.parse(dateParts[1]),
              int.parse(dateParts[0]),
            );
          }
        } catch (e2) {
          print("Error parsing date: ${order["order_datetime"]}");
          continue;
        }
      }

      if (orderDate != null) {
        final orderDay = DateTime(orderDate.year, orderDate.month, orderDate.day);

        // ✅ Today's sales (skip cancelled already above)
        if (orderDay == today) {
          todaySales += amount;
        }
      }

      if (status == 'pending') {
        pendingOrders++;
      }
    }

    // ✅ Weekly sales calculation
    final weekAgo = now.subtract(const Duration(days: 6));
    for (int i = 0; i < 7; i++) {
      final day = weekAgo.add(Duration(days: i));
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      double daySales = 0;

      for (var orderData in orders) {
        final order = orderData["order"];
        final amount = double.tryParse(order["final_amount"].toString()) ?? 0;
        final status = order["status"].toString().toLowerCase();

        // ❌ Cancelled orders skip in weekly
        if (status == 'cancelled') continue;

        // Parse date for weekly calculation
        DateTime? orderDate;
        try {
          orderDate = DateTime.parse(order["order_datetime"]);
        } catch (e) {
          try {
            final parts = order["order_datetime"].split(' ');
            final datePart = parts[0];
            final dateParts = datePart.split('-');
            if (dateParts.length == 3) {
              orderDate = DateTime(
                int.parse(dateParts[2]),
                int.parse(dateParts[1]),
                int.parse(dateParts[0]),
              );
            }
          } catch (e2) {
            continue;
          }
        }

        if (orderDate != null &&
            !orderDate.isBefore(dayStart) &&
            orderDate.isBefore(dayEnd)) {
          daySales += amount;
        }
      }

      weeklySales[i] = daySales;
    }

    // ✅ Recent Orders (yaha bhi cancelled dikhaana ho to mat skip karo)
    recentOrders = orders.take(5).map((orderData) {
      final order = orderData["order"];
      return {
        'id': order["id"],
        'customer': order["name"] ?? "Customer",
        'amount': double.tryParse(order["final_amount"].toString()) ?? 0,
        'address': order["full_address"] ?? "Customer",
        'contact': order["phone"] ?? "Customer",
        'status': order["status"].toString(),
      };
    }).toList();
  }

  // ✅ New method: Show Revenue Report Dialog
  void _showRevenueReport() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final now = DateTime.now();
        final thisMonth = now.month;
        final thisYear = now.year;

        // Calculate monthly revenue
        double monthlyRevenue = 0;
        int monthlyOrders = 0;
        Map<String, double> statusWiseRevenue = {
          'delivered': 0,
          'pending': 0,
          'packed': 0,
          'way': 0,
        };

        for (var orderData in orders) {
          final order = orderData["order"];
          final amount = double.tryParse(order["final_amount"].toString()) ?? 0;
          final status = order["status"].toString().toLowerCase();

          // Check if order is from current month
          try {
            DateTime orderDate = DateTime.parse(order["order_datetime"]);
            if (orderDate.month == thisMonth && orderDate.year == thisYear) {
              monthlyRevenue += amount;
              monthlyOrders++;

              if (statusWiseRevenue.containsKey(status)) {
                statusWiseRevenue[status] = statusWiseRevenue[status]! + amount;
              }
            }
          } catch (e) {
            // Skip if date parsing fails
          }
        }

        // Calculate daily averages
        final daysInMonth = DateTime(thisYear, thisMonth + 1, 0).day;
        final avgDailyRevenue = monthlyRevenue / daysInMonth;
        final avgOrderValue = monthlyOrders > 0 ? monthlyRevenue / monthlyOrders : 0;

        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.bar_chart, color: AppColors.primaryColor),
              SizedBox(width: 10),
              Text(
                'Revenue Report - ${DateFormat('MMMM yyyy').format(now)}',
                style: TextStyle(
                  color: AppColors.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Monthly Summary



                SizedBox(height: 15),

                // Performance Metrics
                _buildReportCard(
                  title: 'Performance Metrics',
                  children: [
                    _buildMetricRow(
                      'Today\'s Sales',
                      '₹${todaySales.toStringAsFixed(2)}',
                      Icons.today,
                      AppColors.primaryColor,
                    ),
                    _buildMetricRow(
                      'Pending Orders',
                      pendingOrders.toString(),
                      Icons.pending,
                      AppColors.warningColor,
                    ),
                    _buildMetricRow(
                      'Total Users',
                      totalUsers.toString(),
                      Icons.people,
                      AppColors.successColor,
                    ),

                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: TextStyle(color: AppColors.primaryColor),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // Optionally, you can add export functionality here
                _showSnackBar('Report data ready for export');
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
              ),
              child: Text('Export Report', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReportCard({required String title, required List<Widget> children}) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryTextColor,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildReportRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.secondaryTextColor)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildReportRowWithColor(String label, String value, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8),
              Text(label, style: TextStyle(color: AppColors.secondaryTextColor)),
            ],
          ),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          SizedBox(width: 10),
          Expanded(
            child: Text(label, style: TextStyle(color: AppColors.secondaryTextColor)),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.successColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dashboard',
                      style: GoogleFonts.poppins(
                          fontSize: 28.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2C3E50))),
                  SizedBox(height: 4.h),
                  Text('DxMart - Admin Panel',
                      style: GoogleFonts.poppins(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey)),
                ],
              ),
              Row(
                children: [
                  // ✅ Changed from notifications icon to revenue report
                  IconButton(
                    icon: Icon(Icons.bar_chart, size: 26.sp, color: const Color(0xFF2C3E50)),
                    onPressed: _showRevenueReport,
                    tooltip: 'Revenue Report',
                  ),
                  SizedBox(width: 16.w),
                  const CircleAvatar(
                    radius: 22,
                    backgroundColor: Color(0xFFE0F7FA),
                    child: Icon(Icons.person, color: Color(0xFF0F969c)),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 32.h),

          // Summary Cards
          isLoading
              ? Center(child: CircularProgressIndicator(color: AppColors.primaryColor))
              : GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 20.w,
            mainAxisSpacing: 20.h,
            childAspectRatio: 1.7.w,
            children: [
              _buildSummaryCard('Total Orders', totalOrders.toString(), Icons.shopping_cart, const Color(0xFF0F969c)),
              _buildSummaryCard("Today's Sales", '₹${todaySales.toStringAsFixed(2)}', Icons.currency_rupee, const Color(0xFF6A67CE)),
              _buildSummaryCard('Total Users','' +totalUsers.toString(), Icons.people, const Color(0xFFFFA62B)),
              _buildSummaryCard('Pending Order', pendingOrders.toString(), Icons.pending_actions, const Color(0xFFFF6B6B)),
            ],
          ),

          const SizedBox(height: 24),

          // Sales Overview & Quick Actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _buildCard(
                  title: 'Sales Overview',
                  children: [
                    SizedBox(
                      height: 250.h,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: _getMaxY(weeklySales),
                          barTouchData: BarTouchData(enabled: true),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: true),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  const style = TextStyle(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  );

                                  // Start from 6 days ago to today
                                  final now = DateTime.now();
                                  final targetDay = now.subtract(Duration(days: 6 - value.toInt()));

                                  // Map weekday number (1 = Mon, 7 = Sun)
                                  const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

                                  return Text(
                                    dayNames[targetDay.weekday - 1], // ✅ Correct mapping
                                    style: style,
                                  );
                                },

                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: [
                            BarChartGroupData(x: 0, barRods: [
                              BarChartRodData(toY: weeklySales[0], color: Color(0xFF0F969c), width: 18),
                            ]),
                            BarChartGroupData(x: 1, barRods: [
                              BarChartRodData(toY: weeklySales[1], color: Color(0xFF0F969c), width: 18),
                            ]),
                            BarChartGroupData(x: 2, barRods: [
                              BarChartRodData(toY: weeklySales[2], color: Color(0xFF0F969c), width: 18),
                            ]),
                            BarChartGroupData(x: 3, barRods: [
                              BarChartRodData(toY: weeklySales[3], color: Color(0xFF0F969c), width: 18),
                            ]),
                            BarChartGroupData(x: 4, barRods: [
                              BarChartRodData(toY: weeklySales[4], color: Color(0xFF0F969c), width: 18),
                            ]),
                            BarChartGroupData(x: 5, barRods: [
                              BarChartRodData(toY: weeklySales[5], color: Color(0xFF0F969c), width: 18),
                            ]),
                            BarChartGroupData(x: 6, barRods: [
                              BarChartRodData(toY: weeklySales[6], color: Color(0xFF0F969c), width: 18),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 24.w),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _buildCard(
                      title: 'Quick Actions',
                      children: [
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 1.5,
                          children: [
                            _buildActionButton(Icons.category, 'Add Category', const Color(0xFF0F969c),(){
                              Navigator.push(context, MaterialPageRoute(builder: (context)=>MainCategory()));
                            }),
                            _buildActionButton(Icons.shopping_cart, 'Add Product', const Color(0xFF6A67CE),(){
                              Navigator.push(context, MaterialPageRoute(builder: (context)=>ProductManagementScreen()));
                            }),
                            _buildActionButton(Icons.inventory_2, 'Stock', const Color(0xFFFF6B6B),(){
                              Navigator.push(context, MaterialPageRoute(builder: (context)=>StockManagementScreen()));
                            }),
                            // ✅ Changed from Send Notification to Revenue Report
                            _buildActionButton(Icons.bar_chart, 'Revenue Report', const Color(0xFF34C759),(){
                              _showRevenueReport();
                            }),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 24.h),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 32.h),

          // Recent Orders
          _buildRecentOrdersCard(context),
        ],
      ),
    );
  }

  double _getMaxY(List<double> values) {
    double max = values.reduce((a, b) => a > b ? a : b);
    return max * 1.2; // Add 20% padding to the max value
  }

  Widget _buildRecentOrdersCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Orders',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context)=>OrderManagementScreen()));
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (isLoading)
              Center(child: CircularProgressIndicator(color: AppColors.primaryColor))
            else if (recentOrders.isEmpty)
              Center(
                child: Text(
                  'No recent orders',
                  style: TextStyle(color: AppColors.secondaryTextColor),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: constraints.maxWidth, // ✅ Table full width lega
                      child: DataTable(
                        columnSpacing: 20,
                        horizontalMargin: 10,
                        columns: const [
                          DataColumn(label: Text('Order ID')),
                          DataColumn(label: Text('Customer')),
                          DataColumn(label: Text('Address')),
                          DataColumn(label: Text('Contact')),
                          DataColumn(label: Text('Amount')),
                          DataColumn(label: Text('Status')),
                        ],
                        rows: recentOrders.map((order) {
                          final statusColor = _getStatusColor(order['status']);
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  '#${order['id']}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              DataCell(
                                Text(
                                  order['customer'],
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              DataCell(
                                Text(
                                  order['address'] ?? 'N/A',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              DataCell(
                                Text(
                                  order['contact'] ?? 'N/A',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              DataCell(
                                Text(
                                  '₹ ${order['amount'].toStringAsFixed(2)}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    order['status'],
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.warningColor;
      case 'packed':
        return AppColors.infoColor;
      case 'way':
        return AppColors.accentColor;
      case 'delivered':
        return AppColors.successColor;
      case 'cancelled':
        return AppColors.errorColor;
      default:
        return AppColors.secondaryTextColor;
    }
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return Container(
      margin: EdgeInsets.all(8.w),
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50.w,
              height: 50.w,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28.sp, color: color),
            ),
            SizedBox(height: 8.h),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF2C3E50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 12.r,
            spreadRadius: 4.r,
            offset: const Offset(0, 4),
          )
        ],
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: EdgeInsets.all(10.r),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24.sp, color: color),
          ),
          SizedBox(height: 12.h),
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 12.sp, color: Colors.black54, fontWeight: FontWeight.w500)),
          SizedBox(height: 4.h),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 20.sp, fontWeight: FontWeight.bold, color: const Color(0xFF2C3E50))),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    String? actionText,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: actionText != null
                  ? MainAxisAlignment.spaceBetween
                  : MainAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2C3E50))),
                if (actionText != null)
                  Text(actionText,
                      style: GoogleFonts.poppins(
                          color: const Color(0xFF0F969c),
                          fontWeight: FontWeight.w500,
                          fontSize: 13.sp)),
              ],
            ),
            SizedBox(height: 12.h),
            ...children
          ],
        ),
      ),
    );
  }
}