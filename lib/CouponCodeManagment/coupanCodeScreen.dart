import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../utils/api_constants.dart';
import '../utils/colors.dart';

class CouponCodeScreen extends StatefulWidget {
  const CouponCodeScreen({super.key});

  @override
  State<CouponCodeScreen> createState() => _CouponCodeScreenState();
}

class _CouponCodeScreenState extends State<CouponCodeScreen> {
  final TextEditingController coupon_title = TextEditingController();
  final TextEditingController coupon_description = TextEditingController();
  final TextEditingController coupon_name = TextEditingController();
  final TextEditingController coupon_discount = TextEditingController();
  final TextEditingController coupon_expri_date = TextEditingController();
  final TextEditingController min_order_value = TextEditingController();
  String? selectedStatus; // Put this in your State




  bool _isLoadingForm = false;
  List<Map<String, dynamic>> _couponList = [];
  bool _isLoadingList = true;

  @override
  void initState() {
    super.initState();
    _fetchCoupons();
  }

  Future<void> _fetchCoupons() async {
    setState(() => _isLoadingList = true);
    try {
      final response = await http.get(Uri.parse(ApiConstants.VIEW_COUPON));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded['success'] == true && decoded['data'] is List) {
          setState(() {
            _couponList = List<Map<String, dynamic>>.from(decoded['data']);
          });
        } else {
          _showSnackBar("No coupons found", AppColors.warningColor);
        }
      } else {
        _showSnackBar("Error fetching coupons: ${response.statusCode}", AppColors.errorColor);
      }
    } catch (e) {
      _showSnackBar("Connection error: $e", AppColors.errorColor);
    } finally {
      setState(() => _isLoadingList = false);
    }
  }


  Future<void> _uploadCoupon() async {
    if (coupon_title.text.isEmpty) {
      _showSnackBar("Please enter coupon title!", AppColors.warningColor);
      return;
    }

    if (coupon_description.text.isEmpty) {
      _showSnackBar("Please enter coupon description!", AppColors.warningColor);
      return;
    }
    if (coupon_name.text.isEmpty) {
      _showSnackBar("Please enter coupon code name!", AppColors.warningColor);
      return;
    }

    if (coupon_discount.text.isEmpty) {
      _showSnackBar("Please enter coupon discount % !", AppColors.warningColor);
      return;
    }

    if (min_order_value.text.isEmpty) {
      _showSnackBar("Please enter min order value !", AppColors.warningColor);
      return;
    }



    if (coupon_expri_date.text.isEmpty) {
      _showSnackBar("Please select expiry date", AppColors.warningColor);
      return;
    }







    if (selectedStatus == null) {
      _showSnackBar("Please select states", AppColors.warningColor);
      return;
    }

    setState(() => _isLoadingForm = true);

    try {
      final res = await http.post(
        Uri.parse(ApiConstants.ADD_COUPON),
        body: {
          "title": coupon_title.text.toUpperCase(),
          "description": coupon_description.text,
          "code_name": coupon_name.text.toUpperCase(),
          "discount": coupon_discount.text,
          "min_amount" : min_order_value.text.toString(),
          "expri_date": coupon_expri_date.text,
          "status": selectedStatus,

        },
      );

      final response = jsonDecode(res.body);
      if (response["success"] == "true") {
        _showSnackBar("Coupon Added Successfully! ✅", AppColors.successColor);
        _resetForm();
        _fetchCoupons();
      } else {
        _showSnackBar("Error: ${response["message"] ?? "Unknown error"}", AppColors.errorColor);
      }
    } catch (e) {
      _showSnackBar("Network error: $e", AppColors.errorColor);
    } finally {
      setState(() => _isLoadingForm = false);
    }
  }

  Future<void> _deleteCoupon(String id) async {
    setState(() => _isLoadingList = true);
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.DELETE_COUPON),
        body: {"id": id},
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData["success"] == true) {
        _showSnackBar("Coupon deleted successfully", AppColors.successColor);
        await _fetchCoupons();
      } else {
        _showSnackBar("Failed to delete: ${responseData["message"]}", AppColors.errorColor);
      }
    } catch (e) {
      _showSnackBar("Deletion error: $e", AppColors.errorColor);
    } finally {
      setState(() => _isLoadingList = false);
    }
  }


  void _resetForm() {
    coupon_title.clear();
    coupon_description.clear();
    coupon_name.clear();
    coupon_discount.clear();
    coupon_expri_date.clear();
    min_order_value.clear();

    setState(() {
      selectedStatus = null;
    });


  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showDeleteDialog(String couponId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Confirm Delete", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: const Text("This coupon will be permanently deleted. This action cannot be undone."),
        actions: [
          TextButton(
            child: Text("Cancel", style: GoogleFonts.poppins(color: AppColors.secondaryTextColor)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text("Delete", style: GoogleFonts.poppins(color: AppColors.errorColor)),
            onPressed: () {
              Navigator.pop(context);
              _deleteCoupon(couponId);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCouponForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Add New Coupon", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryTextColor)),
          const SizedBox(height: 24),

          TextFormField(
            controller: coupon_title,
            maxLength: 16,
            decoration: InputDecoration(
              labelText: "Enter Coupon Title (max 16)",
              labelStyle: GoogleFonts.poppins(color: AppColors.secondaryTextColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryColor, width: 2)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            maxLength: 28,
            controller: coupon_description,
            decoration: InputDecoration(
              labelText: "Enter Coupon Description (max 28)",
              labelStyle: GoogleFonts.poppins(color: AppColors.secondaryTextColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryColor, width: 2)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 24),

          TextFormField(
            controller: coupon_name,
            maxLength: 10,
            decoration: InputDecoration(
              labelText: "Enter Coupon Name(max 10 without any space)",
              labelStyle: GoogleFonts.poppins(color: AppColors.secondaryTextColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryColor, width: 2)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 24),

          TextFormField(
            controller: coupon_discount,
            maxLength: 10,
            decoration: InputDecoration(
              labelText: "Enter Coupon Discount % (enter number only 5 )",
              labelStyle: GoogleFonts.poppins(color: AppColors.secondaryTextColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryColor, width: 2)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 24),


          TextFormField(
            controller: min_order_value,
            maxLength: 10,
            decoration: InputDecoration(
              labelText: "Enter Minimum Order Value)",
              labelStyle: GoogleFonts.poppins(color: AppColors.secondaryTextColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryColor, width: 2)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 24),


          TextFormField(
            controller: coupon_expri_date,
            readOnly: true,
            onTap: () async {
              DateTime now = DateTime.now();
              DateTime? picked = await showDatePicker(
                context: context,
                initialDate: now,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(
                        primary: AppColors.primaryColor,
                        onPrimary: Colors.white,
                        onSurface: Colors.black,
                      ),
                      textButtonTheme: TextButtonThemeData(
                        style: TextButton.styleFrom(foregroundColor: AppColors.primaryColor),
                      ),
                    ),
                    child: child!,
                  );
                },
              );

              if (picked != null) {
                // ✅ User के selected date को ही use करें
                String formatted = "${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}";
                coupon_expri_date.text = formatted;
              }
            },
            decoration: InputDecoration(
              labelText: "Select Expiry Date",
              labelStyle: GoogleFonts.poppins(color: AppColors.secondaryTextColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primaryColor, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),


          const SizedBox(height: 24),


          DropdownButtonFormField<String>(
            value: selectedStatus,
            onChanged: (value) {
              setState(() {
                selectedStatus = value!;
              });
            },
            items: ["Public", "Private"].map((status) {
              return DropdownMenuItem(
                value: status,
                child: Text(
                  status,
                  style: GoogleFonts.poppins(),
                ),
              );
            }).toList(),
            decoration: InputDecoration(
              labelText: "Select Coupon Status",
              labelStyle: GoogleFonts.poppins(color: AppColors.secondaryTextColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primaryColor, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),


          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _isLoadingForm
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                  onPressed: _uploadCoupon,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text("Add Coupon", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.surfaceColor)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCouponCard(Map<String, dynamic> coupon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.confirmation_num,
                  color: AppColors.primaryColor,
                  size: 28),
              IconButton(
                icon: Icon(Icons.delete, color: AppColors.errorColor),
                onPressed: () => _showDeleteDialog(coupon['id'].toString()),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Coupon Title
          Text(
            coupon['title']?.toUpperCase() ?? "UNNAMED COUPON",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryTextColor,
            ),
          ),

          const SizedBox(height: 12),

          // Details Row
          Row(
            children: [
              _buildDetailItem(
                icon: Icons.local_offer,
                label: "Discount",
                value: coupon['discount']+'%' ?? "N/A",
                valueColor: AppColors.secondaryColor, // Gold for discount
              ),
              const SizedBox(width: 16),
              _buildDetailItem(
                icon: Icons.calendar_today,
                label: "Expires",
                value: coupon['expri_date'] ?? "N/A",
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Coupon Code
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "CODE: ${coupon['code_name']?.toUpperCase() ?? "N/A"}",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryColor, // Deep blue
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.content_copy,
                      size: 20,
                      color: AppColors.accentColor), // Teal
                  onPressed: () => _copyToClipboard(coupon['code_name']),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),



          Row(
            children: [

              if (coupon['description'] != null && coupon['description'].isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    coupon['description']!,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppColors.secondaryTextColor,
                    ),
                  ),
                ),

              SizedBox(width: 10.w,),

              if (coupon['min_amount'] != null && coupon['min_amount'].isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    ':  Order Value  ₹'+coupon['min_amount']!,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppColors.secondaryTextColor,
                    ),
                  ),
                ),



            ],
          ),



          const SizedBox(height: 12),

          // Status Chip
          Container(
            alignment: Alignment.centerRight,
            child: Chip(
              label: Text(
                coupon['status']?.toString().toUpperCase() ?? "UNKNOWN",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              backgroundColor: _getStatusColor(coupon['status']),
              labelStyle: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

// Helper Widget for Detail Items
  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.secondaryTextColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.secondaryTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.primaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

// Helper Function for Status Colors
  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return AppColors.successColor; // Green
      case 'expired':
        return AppColors.errorColor; // Red
      case 'upcoming':
        return AppColors.warningColor; // Orange
      case 'info':
        return AppColors.infoColor; // Blue
      default:
        return AppColors.hintTextColor; // Grey
    }
  }

// Helper Function for Copy to Clipboard
  void _copyToClipboard(String? text) {
    if (text != null) {
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Copied to clipboard!"),
          backgroundColor: AppColors.successColor,
        ),
      );
    }
  }

  Widget _buildCouponList() {
    if (_isLoadingList) {
      return Center(child: CircularProgressIndicator(color: AppColors.primaryColor));
    }

    if (_couponList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: AppColors.secondaryTextColor),
            const SizedBox(height: 16),
            Text("No Coupons Found", style: GoogleFonts.poppins(fontSize: 18, color: AppColors.secondaryTextColor)),
            const SizedBox(height: 8),
            Text("Try adding a new coupon", style: GoogleFonts.poppins(fontSize: 14, color: AppColors.secondaryTextColor)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 16),
      itemCount: _couponList.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) => _buildCouponCard(_couponList[index]),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("Coupon Code Management", style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primaryTextColor)),
                const SizedBox(height: 24),
                Text("${_couponList.length} Coupons", style: GoogleFonts.poppins(fontSize: 16, color: AppColors.secondaryTextColor)),
                const SizedBox(height: 16),
                Expanded(child: _buildCouponList()),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 2,
          child: Container(padding: const EdgeInsets.all(16), child: _buildCouponForm()),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: _buildDesktopLayout(),
    );
  }

}
