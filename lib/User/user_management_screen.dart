import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../utils/api_constants.dart';
import '../utils/colors.dart';


class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List users = [];
  int limit = 10;
  int offset = 0;
  int totalUsers = 0;
  bool isLoading = false;
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchUsers();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Future<void> toggleUserStatus(int userId, String currentStatus) async {
    String newStatus = currentStatus == 'active' ? 'blocked' : 'active';

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.USER_STATUS_UPDATE),
        body: {
          'user_id': userId.toString(),
          'new_status': newStatus,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          fetchUsers();
        }
      }
    } catch (e) {
      debugPrint("Error toggling status: $e");
    }
  }

  void nextPage() {
    if (offset + limit < totalUsers) {
      offset += limit;
      fetchUsers();
    }
  }

  void previousPage() {
    if (offset >= limit) {
      offset -= limit;
      fetchUsers();
    }
  }

  void goToFirstPage() {
    if (offset != 0) {
      offset = 0;
      fetchUsers();
    }
  }

  void goToLastPage() {
    final lastPageOffset = (totalUsers ~/ limit) * limit;
    if (offset != lastPageOffset) {
      offset = lastPageOffset;
      fetchUsers();
    }
  }

  void performSearch(String value) {
    setState(() {
      offset = 0;
      searchQuery = value;
    });
    fetchUsers();
  }

  void _showConfirmationDialog(int userId, String name, String currentStatus) {
    bool isActive = currentStatus == 'active';
    String action = isActive ? 'Block' : 'Unblock';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$action User?', style: GoogleFonts.poppins(fontSize: 16.sp)),
        content: Text('Are you sure you want to $action $name?', style: GoogleFonts.poppins(fontSize: 14.sp)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14.sp)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              toggleUserStatus(userId, currentStatus);
            },
            child: Text(
              action,
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                color: isActive ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 20.h),
            Text(
              "User Management",
              style: GoogleFonts.poppins(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryTextColor,
              ),
            ),
            SizedBox(height: 20.h),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6.r,
                    offset: Offset(0, 3.h),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search by name or email...",
                  hintStyle: GoogleFonts.poppins(fontSize: 14.sp),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: Colors.grey, size: 20.sp),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: Icon(Icons.clear, size: 20.sp),
                    onPressed: () {
                      _searchController.clear();
                      performSearch("");
                    },
                  )
                      : null,
                  contentPadding: EdgeInsets.symmetric(vertical: 16.h),
                ),
                onSubmitted: performSearch,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              '$totalUsers users found',
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 16.h),
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator())
                  : users.isEmpty
                  ? Center(
                child: Text("No users found", style: GoogleFonts.poppins(fontSize: 16.sp)),
              )
                  : ListView.separated(
                itemCount: users.length,
                separatorBuilder: (context, index) => SizedBox(height: 12.h),
                itemBuilder: (context, index) {
                  final user = users[index];
                  final userId = int.tryParse(user['id'].toString()) ?? 0;
                  final status = user['status'].toString();
                  final isActive = status == 'active';

                  return Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6.r,
                          offset: Offset(0, 3.h),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("ID: ${user['id']}", style: GoogleFonts.poppins(fontSize: 13.sp, fontWeight: FontWeight.bold)),
                              SizedBox(height: 4.h),
                              Text("Name: ${user['name']}", style: GoogleFonts.poppins(fontSize: 13.sp)),
                              SizedBox(height: 2.h),
                              Text("Email: ${user['email']}", style: GoogleFonts.poppins(fontSize: 13.sp, color: Colors.grey[700])),
                              SizedBox(height: 4.h),
                              Row(
                                children: [
                                  Text(
                                    "Status: ${status[0].toUpperCase()}${status.substring(1)}",
                                    style: GoogleFonts.poppins(
                                      fontSize: 13.sp,
                                      color: isActive ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  Text(
                                    "Join Date: ${user['date_time']}",
                                    style: GoogleFonts.poppins(fontSize: 13.sp, color: Colors.grey[700]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _showConfirmationDialog(userId, user['name'], status),
                          icon: Icon(
                            isActive ? Icons.block : Icons.check_circle,
                            size: 18.sp,
                            color: Colors.white,
                          ),
                          label: Text(
                            isActive ? 'Block' : 'Unblock',
                            style: GoogleFonts.poppins(fontSize: 13.sp, color: AppColors.surfaceColor),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isActive ? Colors.red : Colors.green,
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 24.h),
            if (totalUsers > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text('Rows per page:', style: GoogleFonts.poppins(fontSize: 14.sp)),
                      SizedBox(width: 8.w),
                      DropdownButton<int>(
                        value: limit,
                        items: [5, 10, 20, 50].map((int value) {
                          return DropdownMenuItem<int>(
                            value: value,
                            child: Text('$value', style: GoogleFonts.poppins(fontSize: 14.sp)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              limit = value;
                              offset = 0;
                            });
                            fetchUsers();
                          }
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        '${offset + 1}-${offset + users.length} of $totalUsers',
                        style: GoogleFonts.poppins(fontSize: 14.sp),
                      ),
                      SizedBox(width: 16.w),
                      IconButton(
                        icon: Icon(Icons.first_page, size: 20.sp),
                        onPressed: offset == 0 ? null : goToFirstPage,
                        color: offset == 0 ? Colors.grey : Colors.blue,
                      ),
                      IconButton(
                        icon: Icon(Icons.chevron_left, size: 20.sp),
                        onPressed: offset == 0 ? null : previousPage,
                        color: offset == 0 ? Colors.grey : Colors.blue,
                      ),
                      IconButton(
                        icon: Icon(Icons.chevron_right, size: 20.sp),
                        onPressed: offset + limit >= totalUsers ? null : nextPage,
                        color: offset + limit >= totalUsers ? Colors.grey : Colors.blue,
                      ),
                      IconButton(
                        icon: Icon(Icons.last_page, size: 20.sp),
                        onPressed: offset + limit >= totalUsers ? null : goToLastPage,
                        color: offset + limit >= totalUsers ? Colors.grey : Colors.blue,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
