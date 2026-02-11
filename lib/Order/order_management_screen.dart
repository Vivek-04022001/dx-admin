import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import '../utils/api_constants.dart';
import '../utils/colors.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  List orders = [];
  List filteredOrders = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  int currentPage = 1;
  int totalPages = 1;
  int totalOrders = 0;
  int limit = 10;
  bool hasMore = true;
  String selectedFilter = 'all';
  final ScrollController _scrollController = ScrollController();

  // Date filter variables
  DateTime? selectedStartDate;
  DateTime? selectedEndDate;
  TextEditingController searchController = TextEditingController();

  // Filter options
  final List<String> filterOptions = [
    'all',
    'pending',
    'packed',
    'way',
    'delivered',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    fetchOrders();

    // Add scroll listener for pagination
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        if (hasMore && !isLoadingMore) {
          loadMoreOrders();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    searchController.dispose();
    super.dispose();
  }

  // Calculate summary statistics for ALL orders (not just displayed ones)
  Map<String, dynamic> getOrderSummary() {
    int pendingCount = 0;
    int packedCount = 0;
    int wayCount = 0;
    int deliveredCount = 0;
    int cancelledCount = 0;

    double pendingAmount = 0;
    double packedAmount = 0;
    double wayAmount = 0;
    double deliveredAmount = 0;
    double cancelledAmount = 0;
    double totalAmount = 0;

    for (var orderData in orders) {
      final order = orderData["order"];
      final status = order["status"].toString().toLowerCase();
      final amount = double.tryParse(order["final_amount"].toString()) ?? 0;

      totalAmount += amount;

      switch (status) {
        case 'pending':
          pendingCount++;
          pendingAmount += amount;
          break;
        case 'packed':
          packedCount++;
          packedAmount += amount;
          break;
        case 'way':
          wayCount++;
          wayAmount += amount;
          break;
        case 'delivered':
          deliveredCount++;
          deliveredAmount += amount;
          break;
        case 'cancelled':
          cancelledCount++;
          cancelledAmount += amount;
          break;
      }
    }

    return {
      'all': {'count': orders.length, 'amount': totalAmount},
      'pending': {'count': pendingCount, 'amount': pendingAmount},
      'packed': {'count': packedCount, 'amount': packedAmount},
      'way': {'count': wayCount, 'amount': wayAmount},
      'delivered': {'count': deliveredCount, 'amount': deliveredAmount},
      'cancelled': {'count': cancelledCount, 'amount': cancelledAmount},
      'total': {'count': orders.length, 'amount': totalAmount},
    };
  }

  // Apply filter to orders
  void applyFilter(String filter) {
    setState(() {
      selectedFilter = filter;
      filteredOrders = _filterOrdersByCriteria(
        orders,
        filter,
        searchController.text,
        selectedStartDate,
        selectedEndDate,
      );
    });
  }

  List _filterOrdersByCriteria(
    List ordersList,
    String statusFilter,
    String searchText,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    List filtered = ordersList.where((orderData) {
      final order = orderData["order"];

      // Status filter
      if (statusFilter != 'all' &&
          order["status"].toString().toLowerCase() != statusFilter) {
        return false;
      }

      // Search filter
      if (searchText.isNotEmpty) {
        final searchLower = searchText.toLowerCase();
        final orderId = order["id"].toString().toLowerCase();
        final customerName = (order["name"] ?? "").toString().toLowerCase();
        final customerPhone = (order["phone"] ?? "").toString().toLowerCase();

        if (!orderId.contains(searchLower) &&
            !customerName.contains(searchLower) &&
            !customerPhone.contains(searchLower)) {
          return false;
        }
      }

      // Date filter
      if (startDate != null || endDate != null) {
        try {
          final orderDateStr = order["order_datetime"].toString();
          final orderDate = DateFormat(
            "dd-MM-yyyy hh:mm a",
          ).parse(orderDateStr);

          if (startDate != null && orderDate.isBefore(startDate)) {
            return false;
          }
          if (endDate != null &&
              orderDate.isAfter(endDate.add(Duration(days: 1)))) {
            return false;
          }
        } catch (e) {
          // If date parsing fails, include the order
          print("Date parsing error: $e");
        }
      }

      return true;
    }).toList();

    return filtered;
  }

  Future<void> fetchOrders({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        currentPage = 1;
        hasMore = true;
      });
    }

    final url = Uri.parse(
      "${ApiConstants.GET_ALL_ORDER}?page=$currentPage&limit=$limit",
    );
    try {
      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data["success"] == true) {
        setState(() {
          if (isRefresh || currentPage == 1) {
            orders = data["orders"];
          } else {
            orders.addAll(data["orders"]);
          }

          // Apply current filter to new data
          filteredOrders = _filterOrdersByCriteria(
            orders,
            selectedFilter,
            searchController.text,
            selectedStartDate,
            selectedEndDate,
          );

          currentPage = data["pagination"]["current_page"];
          totalPages = data["pagination"]["total_pages"];
          totalOrders = data["pagination"]["total_orders"];
          hasMore = data["pagination"]["has_next"];

          isLoading = false;
          isLoadingMore = false;
        });
      } else {
        setState(() {
          isLoading = false;
          isLoadingMore = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"] ?? "Failed to fetch orders")),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        isLoadingMore = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> loadMoreOrders() async {
    if (!hasMore || isLoadingMore) return;

    setState(() {
      isLoadingMore = true;
    });

    currentPage++;
    await fetchOrders();
  }

  Future<void> updateOrderStatus(int orderId, String newStatus) async {
    final url = Uri.parse(ApiConstants.UPDATE_ORDER_STATUS);
    try {
      final response = await http.post(
        url,
        body: {'order_id': orderId.toString(), 'status': newStatus},
      );

      final data = json.decode(response.body);

      if (data["success"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Order status updated to $newStatus"),
            backgroundColor: AppColors.successColor,
          ),
        );
        // Refresh the orders list
        fetchOrders(isRefresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data["message"] ?? "Failed to update order status"),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: AppColors.errorColor,
        ),
      );
    }
  }

  // Date selection methods
  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedStartDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        selectedStartDate = picked;
        applyFilter(selectedFilter);
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedEndDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        selectedEndDate = picked;
        applyFilter(selectedFilter);
      });
    }
  }

  void _clearDateFilters() {
    setState(() {
      selectedStartDate = null;
      selectedEndDate = null;
      applyFilter(selectedFilter);
    });
  }

  void _clearSearch() {
    setState(() {
      searchController.clear();
      applyFilter(selectedFilter);
    });
  }

  Widget _buildCompactSummaryCard(
    String title,
    int count,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Container(
      width: 100.sp,
      margin: EdgeInsets.symmetric(horizontal: 2.sp),
      padding: EdgeInsets.all(10.sp),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12.sp, color: color),
              SizedBox(width: 4.sp),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.sp),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 12.sp,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = getOrderSummary();

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Padding(
        padding: EdgeInsets.only(left: 20, right: 20),
        child: Container(
          color: AppColors.backgroundColor,
          child: isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryColor,
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Text(
                            "${AppConfig.appName} - Order Management",
                            style: GoogleFonts.jost(
                              color: AppColors.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 20.sp,
                            ),
                          ),
                          Spacer(),
                          IconButton(
                            icon: Icon(Icons.refresh, size: 24.sp),
                            onPressed: () {
                              fetchOrders(isRefresh: true);
                            },
                          ),
                        ],
                      ),
                    ),

                    // Search and Filter Section - Compact Version
                    Column(
                      children: [
                        // Compact Search and Date Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Search Bar - Compact
                            Expanded(
                              flex: 4,
                              child: Container(
                                height: 40.sp,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceColor,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: TextField(
                                  controller: searchController,
                                  decoration: InputDecoration(
                                    hintText: "Search...",
                                    hintStyle: TextStyle(fontSize: 12.sp),
                                    prefixIcon: Icon(
                                      Icons.search,
                                      size: 18.sp,
                                      color: AppColors.primaryColor,
                                    ),
                                    suffixIcon: searchController.text.isNotEmpty
                                        ? IconButton(
                                            icon: Icon(
                                              Icons.clear,
                                              size: 16.sp,
                                              color: AppColors.primaryColor,
                                            ),
                                            onPressed: _clearSearch,
                                            padding: EdgeInsets.zero,
                                          )
                                        : null,
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  onChanged: (value) {
                                    applyFilter(selectedFilter);
                                  },
                                ),
                              ),
                            ),
                            SizedBox(width: 8.sp),

                            // Start Date
                            Expanded(
                              flex: 1,
                              child: GestureDetector(
                                onTap: () => _selectStartDate(context),
                                child: Container(
                                  height: 40.sp,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.sp,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceColor,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.borderColor,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        size: 14.sp,
                                        color: AppColors.primaryColor,
                                      ),
                                      SizedBox(width: 4.sp),
                                      Flexible(
                                        child: Text(
                                          selectedStartDate != null
                                              ? DateFormat(
                                                  'dd/MM',
                                                ).format(selectedStartDate!)
                                              : "From",
                                          style: TextStyle(
                                            fontSize: 10.sp,
                                            color: selectedStartDate != null
                                                ? AppColors.primaryTextColor
                                                : AppColors.secondaryTextColor,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 4.sp),

                            // End Date
                            Expanded(
                              flex: 1,
                              child: GestureDetector(
                                onTap: () => _selectEndDate(context),
                                child: Container(
                                  height: 40.sp,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.sp,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceColor,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.borderColor,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        size: 14.sp,
                                        color: AppColors.primaryColor,
                                      ),
                                      SizedBox(width: 4.sp),
                                      Flexible(
                                        child: Text(
                                          selectedEndDate != null
                                              ? DateFormat(
                                                  'dd/MM',
                                                ).format(selectedEndDate!)
                                              : "To",
                                          style: TextStyle(
                                            fontSize: 10.sp,
                                            color: selectedEndDate != null
                                                ? AppColors.primaryTextColor
                                                : AppColors.secondaryTextColor,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 4.sp),

                            // Filter Dropdown
                            Expanded(
                              flex: 2,
                              child: Container(
                                height: 40.sp,
                                padding: EdgeInsets.symmetric(horizontal: 8.sp),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedFilter,
                                    isExpanded: true,
                                    items: filterOptions.map((filter) {
                                      final filterSummary =
                                          summary[filter] ??
                                          {'count': 0, 'amount': 0};
                                      return DropdownMenuItem<String>(
                                        value: filter,
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.circle,
                                              size: 12,
                                              color: _getStatusColor(filter),
                                            ),
                                            SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                '${filter.toUpperCase()} (${filterSummary['count']})',
                                                style: TextStyle(
                                                  fontSize: 10.sp,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        applyFilter(value);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 4.sp),

                            // Clear Date Filter - Compact
                            if (selectedStartDate != null ||
                                selectedEndDate != null)
                              GestureDetector(
                                onTap: _clearDateFilters,
                                child: Container(
                                  width: 40.sp,
                                  height: 40.sp,
                                  decoration: BoxDecoration(
                                    color: AppColors.errorColor.withOpacity(
                                      0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.errorColor,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.clear,
                                    size: 16.sp,
                                    color: AppColors.errorColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: 8.sp),
                      ],
                    ),

                    // Summary Cards - Divide equally in screen width
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        vertical: 8.sp,
                        horizontal: 12.sp,
                      ),
                      color: AppColors.surfaceColor,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: _buildCompactSummaryCard(
                              'TOTAL',
                              summary['total']['count'],
                              summary['total']['amount'],
                              AppColors.primaryColor,
                              Icons.shopping_cart,
                            ),
                          ),
                          Expanded(
                            child: _buildCompactSummaryCard(
                              'PENDING',
                              summary['pending']['count'],
                              summary['pending']['amount'],
                              AppColors.warningColor,
                              Icons.pending_actions,
                            ),
                          ),
                          Expanded(
                            child: _buildCompactSummaryCard(
                              'PACKED',
                              summary['packed']['count'],
                              summary['packed']['amount'],
                              AppColors.infoColor,
                              Icons.inventory_2,
                            ),
                          ),
                          Expanded(
                            child: _buildCompactSummaryCard(
                              'ON WAY',
                              summary['way']['count'],
                              summary['way']['amount'],
                              AppColors.accentColor,
                              Icons.local_shipping,
                            ),
                          ),
                          Expanded(
                            child: _buildCompactSummaryCard(
                              'DELIVERED',
                              summary['delivered']['count'],
                              summary['delivered']['amount'],
                              AppColors.successColor,
                              Icons.check_circle,
                            ),
                          ),
                          Expanded(
                            child: _buildCompactSummaryCard(
                              'CANCELLED',
                              summary['cancelled']['count'],
                              summary['cancelled']['amount'],
                              AppColors.errorColor,
                              Icons.cancel,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Results Info
                    Container(
                      padding: EdgeInsets.symmetric(
                        vertical: 8.sp,
                        horizontal: 16.sp,
                      ),
                      color: AppColors.surfaceColor,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Showing: ${filteredOrders.length}",
                            style: TextStyle(
                              color: AppColors.primaryTextColor,
                              fontWeight: FontWeight.w500,
                              fontSize: 12.sp,
                            ),
                          ),
                          Text(
                            "Total: $totalOrders",
                            style: TextStyle(
                              color: AppColors.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Orders List
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => fetchOrders(isRefresh: true),
                        child: filteredOrders.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.inbox,
                                      size: 64.sp,
                                      color: AppColors.secondaryTextColor,
                                    ),
                                    SizedBox(height: 16.sp),
                                    Text(
                                      "No Orders Found",
                                      style: TextStyle(
                                        color: AppColors.secondaryTextColor,
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: 8.sp),
                                    Text(
                                      "Try adjusting your filters or search criteria",
                                      style: TextStyle(
                                        color: AppColors.secondaryTextColor,
                                        fontSize: 14.sp,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                itemCount:
                                    filteredOrders.length +
                                    (isLoadingMore ? 1 : 0) +
                                    (hasMore ? 0 : 1),
                                itemBuilder: (context, index) {
                                  if (index == filteredOrders.length) {
                                    if (isLoadingMore) {
                                      return Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            color: AppColors.primaryColor,
                                          ),
                                        ),
                                      );
                                    } else if (!hasMore) {
                                      return Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Center(
                                          child: Text(
                                            "No more orders to load",
                                            style: TextStyle(
                                              color:
                                                  AppColors.secondaryTextColor,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  }

                                  if (index >= filteredOrders.length)
                                    return SizedBox();

                                  final orderData = filteredOrders[index];
                                  final order = orderData["order"];
                                  final items = orderData["items"] as List;
                                  final status = order["status"]
                                      .toString()
                                      .toLowerCase();

                                  return _buildOrderCard(
                                    order,
                                    items,
                                    status,
                                    orderData,
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(
    Map<String, dynamic> order,
    List items,
    String status,
    dynamic orderData,
  ) {
    return Padding(
      padding: EdgeInsets.only(top: 10, bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: AppColors.surfaceColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 1,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ExpansionTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide.none,
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide.none,
          ),
          leading: Container(
            width: 40.sp,
            height: 40.sp,
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _getStatusColor(status), width: 2),
            ),
            child: Center(
              child: Text(
                "#${order["id"]}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(status),
                  fontSize: 12.sp,
                ),
              ),
            ),
          ),
          title: Text(
            "Order #${order["id"]}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryTextColor,
              fontSize: 16.sp,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 4.sp),
              Text(
                "Customer: ${order["name"] ?? "N/A"}",
                style: TextStyle(
                  color: AppColors.secondaryTextColor,
                  fontSize: 12.sp,
                ),
              ),
              SizedBox(height: 4.sp),
              Row(
                children: [
                  Text(
                    "₹${order["final_amount"]}",
                    style: TextStyle(
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                    ),
                  ),
                  SizedBox(width: 16.sp),
                  Text(
                    DateFormat('dd MMM yyyy').format(
                      DateFormat(
                        "dd-MM-yyyy hh:mm a",
                      ).parse(order["order_datetime"]),
                    ),
                    style: TextStyle(
                      color: AppColors.secondaryTextColor,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4.sp),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.sp, vertical: 4.sp),
                decoration: BoxDecoration(
                  color: _getStatusColor(status),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          trailing: Icon(
            Icons.arrow_drop_down,
            color: AppColors.primaryColor,
            size: 24.sp,
          ),
          children: [
            Padding(
              padding: EdgeInsets.all(16.0.sp),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order Information Section
                  Text(
                    "ORDER INFORMATION",
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryColor,
                    ),
                  ),
                  SizedBox(height: 12.sp),
                  _buildInfoRow(
                    Icons.calendar_today,
                    "Order Date",
                    order["order_datetime"],
                  ),
                  _buildInfoRow(
                    Icons.local_shipping,
                    "Delivery",
                    "${formatDate(order["delivery_date"])} at ${order["delivery_time"]}",
                  ),
                  _buildInfoRow(
                    Icons.payment,
                    "Payment Method",
                    order["payment_method"],
                  ),
                  _buildInfoRow(
                    Icons.local_shipping,
                    "Delivery Charge",
                    "₹${order["delivery_charge"]}",
                  ),
                  _buildInfoRow(
                    Icons.inventory_2,
                    "Handling Charge",
                    "₹${order["handling_charge"]}",
                  ),

                  SizedBox(height: 16.sp),

                  // Customer Information Section
                  Text(
                    "CUSTOMER INFORMATION",
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryColor,
                    ),
                  ),
                  SizedBox(height: 12.sp),
                  _buildInfoRow(Icons.person, "Name", order["name"] ?? "N/A"),
                  _buildInfoRowWithCopy(
                    Icons.phone,
                    "Phone",
                    order["phone"] ?? "N/A",
                    () => _copyPhone(order['phone']),
                  ),
                  _buildInfoRowWithCopy(
                    Icons.location_on,
                    "Address",
                    "${order["full_address"]}, ${order["pin_code"]}",
                    () => _copyAddress(order['full_address']),
                  ),
                  if (order["landmark"] != null &&
                      order["landmark"].toString().isNotEmpty)
                    _buildInfoRow(Icons.place, "Landmark", order["landmark"]),

                  SizedBox(height: 16.sp),

                  // Order Items Section
                  Text(
                    "ORDER ITEMS",
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryColor,
                    ),
                  ),
                  SizedBox(height: 12.sp),
                  ...items.map((item) => _buildOrderItem(item)),

                  SizedBox(height: 16.sp),

                  // Action Buttons (Now only 2 buttons)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(
                        "Update Status",
                        Icons.update,
                        AppColors.primaryColor,
                        () => _showStatusUpdateDialog(
                          order["id"],
                          order["status"],
                        ),
                      ),
                      _buildActionButton(
                        "Print Bill",
                        Icons.print,
                        AppColors.successColor,
                        () => printBill(orderData),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.sp),
      child: Row(
        children: [
          Icon(icon, size: 16.sp, color: AppColors.secondaryTextColor),
          SizedBox(width: 8.sp),
          Text(
            "$label: ",
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.primaryTextColor,
              fontSize: 12.sp,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: AppColors.secondaryTextColor,
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRowWithCopy(
    IconData icon,
    String label,
    String value,
    VoidCallback onCopy,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.sp),
      child: Row(
        children: [
          Icon(icon, size: 16.sp, color: AppColors.secondaryTextColor),
          SizedBox(width: 8.sp),
          Text(
            "$label: ",
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.primaryTextColor,
              fontSize: 12.sp,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.secondaryTextColor,
                fontSize: 12.sp,
              ),
            ),
          ),
          IconButton(
            onPressed: onCopy,
            icon: Icon(Icons.copy, size: 16.sp, color: AppColors.primaryColor),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(Map<String, dynamic> item) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.sp),
      padding: EdgeInsets.all(12.sp),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              item["image_url"],
              width: 60.sp,
              height: 60.sp,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 60.sp,
                height: 60.sp,
                color: AppColors.borderColor,
                child: Icon(
                  Icons.image,
                  color: AppColors.secondaryTextColor,
                  size: 24.sp,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.sp),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item["product_name"],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryTextColor,
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 4.sp),
                Text(
                  "Variant: ${item["name"] ?? "Default"}",
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.secondaryTextColor,
                  ),
                ),
                SizedBox(height: 4.sp),
                Row(
                  children: [
                    Text(
                      "Qty: ${item["quantity"]}",
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.secondaryTextColor,
                      ),
                    ),
                    SizedBox(width: 12.sp),
                    Text(
                      "Stock: ${item["stock"]}",
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "₹${item["selling_price"]}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryColor,
                  fontSize: 14.sp,
                ),
              ),
              SizedBox(height: 4.sp),
              Text(
                "₹${item["price"]}",
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.secondaryTextColor,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback? onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: EdgeInsets.symmetric(horizontal: 12.sp, vertical: 8.sp),
        minimumSize: Size(0, 40.sp),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16.sp, color: Colors.white),
          SizedBox(width: 6.sp),
          Text(
            text,
            style: TextStyle(color: Colors.white, fontSize: 12.sp),
          ),
        ],
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

  String formatDate(String rawDate) {
    try {
      DateTime parsedDate = DateTime.parse(rawDate);
      return DateFormat("dd MMM yyyy").format(parsedDate);
    } catch (e) {
      return rawDate;
    }
  }

  void _copyPhone(String phone) {
    Clipboard.setData(ClipboardData(text: phone));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Phone copied: $phone')));
  }

  void _copyAddress(String address) {
    Clipboard.setData(ClipboardData(text: address));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Address copied')));
  }

  void _showStatusUpdateDialog(int orderId, String currentStatus) {
    String? selectedStatus;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            "Update Order Status",
            style: TextStyle(
              color: AppColors.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Current Status: $currentStatus",
                style: TextStyle(
                  color: AppColors.primaryTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: "Select Status",
                  labelStyle: TextStyle(color: AppColors.primaryColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.primaryColor),
                  ),
                ),
                initialValue: selectedStatus ?? currentStatus,
                items: [
                  DropdownMenuItem(value: "pending", child: Text("Pending")),
                  DropdownMenuItem(value: "packed", child: Text("Packed")),
                  DropdownMenuItem(value: "way", child: Text("On the Way")),
                  DropdownMenuItem(
                    value: "delivered",
                    child: Text("Delivered"),
                  ),
                  DropdownMenuItem(
                    value: "cancelled",
                    child: Text("Cancelled"),
                  ),
                ],
                onChanged: (value) {
                  selectedStatus = value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                "Cancel",
                style: TextStyle(color: AppColors.secondaryTextColor),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedStatus != null) {
                  updateOrderStatus(orderId, selectedStatus!);
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text("Update", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> printBill(dynamic orderData) async {
    final order = orderData["order"];
    final items = orderData["items"] as List;

    // Create PDF document
    final pdf = pw.Document();

    // Add content to PDF
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      AppConfig.appName,
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'INVOICE',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Order Information
              pw.Text(
                'Order Information',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [pw.Text('Order ID:'), pw.Text('#${order["id"]}')],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Order Date:'),
                  pw.Text('${order["order_datetime"]}'),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Delivery Date:'),
                  pw.Text(formatDate(order["delivery_date"])),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Delivery Time:'),
                  pw.Text('${order["delivery_time"]}'),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Payment Method:'),
                  pw.Text('${order["payment_method"]}'),
                ],
              ),

              pw.SizedBox(height: 20),

              // Customer Information
              pw.Text(
                'Customer Information',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Name:'),
                  pw.Text('${order["name"] ?? "N/A"}'),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Phone:'),
                  pw.Text('${order["phone"] ?? "N/A"}'),
                ],
              ),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Address:'),
                  pw.Expanded(
                    child: pw.Text(
                      '${order["full_address"]}, ${order["pin_code"]}',
                    ),
                  ),
                ],
              ),
              if (order["landmark"] != null &&
                  order["landmark"].toString().isNotEmpty)
                pw.Row(
                  children: [
                    pw.Text('Landmark:'),
                    pw.Text('${order["landmark"]}'),
                  ],
                ),
              pw.SizedBox(height: 20),

              // Order Items
              pw.Text(
                'Order Items',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Divider(),
              ...items.map(
                (item) => pw.Container(
                  margin: pw.EdgeInsets.only(bottom: 10),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('${item["product_name"]}'),
                            pw.Text(
                              'Variant: ${item["name"] ?? "Default"}',
                              style: pw.TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text('Qty: ${item["quantity"]}'),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Row(
                          children: [
                            pw.Row(
                              children: [
                                pw.Text('Rs.'),
                                pw.Text(
                                  '${item["price"]}',
                                  style: pw.TextStyle(
                                    decoration: pw.TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ),

                            pw.SizedBox(width: 10),
                            pw.Text('Rs.${item["selling_price"]}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(height: 20),

              // Order Summary
              pw.Text(
                'Order Summary',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Items Total:'),
                  pw.Text('Rs${order["total_amount"]}'),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Delivery Charge:'),
                  pw.Text('Rs.${order["delivery_charge"]}'),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Handling Charge:'),
                  pw.Text('Rs.${order["handling_charge"]}'),
                ],
              ),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Discount:'),
                  pw.Text('Rs.${order["discount_amount"]}'),
                ],
              ),

              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total Amount:',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'Rs.${order["final_amount"]}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Footer
              pw.Center(
                child: pw.Text(
                  'Thank you for your order!',
                  style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
                ),
              ),
            ],
          );
        },
      ),
    );

    // Print/Preview
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: "invoice_${order["id"]}.pdf",
    );

    // Save PDF File
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = "${directory.path}/invoice_${order["id"]}.pdf";
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());
      print("PDF Saved: $filePath");
    } catch (e) {
      print("Error saving PDF: $e");
    }
  }
}
