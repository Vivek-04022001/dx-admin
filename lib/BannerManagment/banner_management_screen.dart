import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/colors.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker_web/image_picker_web.dart';
import '../utils/api_constants.dart';

class BannerManagementScreen extends StatefulWidget {
  const BannerManagementScreen({super.key});

  @override
  State<BannerManagementScreen> createState() => _BannerManagementScreenState();
}

class _BannerManagementScreenState extends State<BannerManagementScreen> {
  final TextEditingController _offerTextController = TextEditingController();
  Uint8List? _imageDataBytes;
  String? _imageFileName;
  bool _isLoadingForm = false;
  List _bannerList = [];
  bool _isLoadingList = true;
  bool _isFormVisible = false;
  List categories = [];
  String? selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _fetchBanners();
    fetchCategories();
  }

  Future<void> fetchCategories() async {
    try {
      final res = await http.get(Uri.parse(ApiConstants.MAIN_VIEW_CATEGORY));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        print('Categories fetched: ${data.length} items');
        print('Sample category: ${data.isNotEmpty ? data[0] : 'No data'}');

        setState(() => categories = data);
      } else {
        _showSnackBar('Failed to load categories: ${res.statusCode}', AppColors.errorColor);
      }
    } catch (e) {
      _showSnackBar('Error fetching categories: $e', AppColors.errorColor);
    }
  }

  Future<void> _fetchBanners() async {
    setState(() => _isLoadingList = true);
    try {
      final response = await http.get(Uri.parse(ApiConstants.VIEW_BANNER));
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        print('Banner API Response: ${jsonResponse.keys}');

        if (jsonResponse['success'] == true) {
          // ✅ Debug: Print first banner data to see keys
          if (jsonResponse['data']['offer_banners'].isNotEmpty) {
            print('First banner keys: ${jsonResponse['data']['offer_banners'][0].keys}');
          }

          setState(() {
            _bannerList = jsonResponse['data']['offer_banners'];
            _isLoadingList = false;
          });
        } else {
          _showSnackBar("Failed to load data", AppColors.errorColor);
          setState(() => _isLoadingList = false);
        }
      } else {
        _showSnackBar("Error fetching banners: ${response.statusCode}", AppColors.errorColor);
        setState(() => _isLoadingList = false);
      }
    } catch (e) {
      _showSnackBar("Connection error: $e", AppColors.errorColor);
      setState(() => _isLoadingList = false);
    }
  }

  Future<void> _uploadBanner() async {
    if (selectedCategoryId == null) {
      _showSnackBar("Please Select Category!", AppColors.warningColor);
      return;
    }
    if (_imageDataBytes == null) {
      _showSnackBar("Please select a banner image!", AppColors.warningColor);
      return;
    }

    setState(() => _isLoadingForm = true);

    try {
      final apiUrl = ApiConstants.ADD_BANNER;

      final body = {
        "category_id": selectedCategoryId.toString(),
        "data": base64Encode(_imageDataBytes!),
        "name": _imageFileName ?? "banner_image_${DateTime.now().millisecondsSinceEpoch}.jpg",
      };

      print('Uploading banner with category_id: $selectedCategoryId');

      final res = await http.post(Uri.parse(apiUrl), body: body);
      final response = jsonDecode(res.body);

      print('Upload response: $response');

      setState(() => _isLoadingForm = false);

      if (response["success"] == "true" || response["success"] == true) {
        _showSnackBar("Banner Added Successfully! ✅", AppColors.successColor);
        _resetForm();
        _fetchBanners();
      } else {
        _showSnackBar("Error: ${response['message'] ?? 'Unknown error'}", AppColors.errorColor);
      }
    } catch (e) {
      setState(() => _isLoadingForm = false);
      _showSnackBar("Network error: $e", AppColors.errorColor);
    }
  }

  void _showDeleteDialog(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Confirm Delete", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: const Text("This banner will be permanently deleted. This action cannot be undone."),
        actions: [
          TextButton(
            child: Text("Cancel", style: GoogleFonts.poppins(color: AppColors.secondaryTextColor)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text("Delete", style: GoogleFonts.poppins(color: AppColors.errorColor)),
            onPressed: () {
              Navigator.pop(context);
              _deleteBanner(id);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBanner(String id) async {
    setState(() => _isLoadingList = true);
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.DELETE_BANNER),
        body: {"id": id},
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && (responseData["success"] == "true" || responseData["success"] == true)) {
        _showSnackBar("Banner deleted successfully", AppColors.successColor);
        await _fetchBanners();
      } else {
        _showSnackBar("Error: ${responseData['message'] ?? 'Unknown error'}", AppColors.errorColor);
      }
    } catch (e) {
      _showSnackBar("Deletion error: $e", AppColors.errorColor);
    } finally {
      setState(() => _isLoadingList = false);
    }
  }

  Future<void> _getImage() async {
    final Uint8List? bytesFromPicker = await ImagePickerWeb.getImageAsBytes();

    if (bytesFromPicker != null) {
      if (bytesFromPicker.lengthInBytes <= 204800) {
        setState(() {
          _imageDataBytes = bytesFromPicker;
          _imageFileName = "banner_image_${DateTime.now().millisecondsSinceEpoch}.png";
        });
      } else {
        _showSnackBar("Please select an image smaller than 200 KB", AppColors.warningColor);
      }
    }
  }

  void _resetForm() {
    _offerTextController.clear();
    setState(() {
      _imageDataBytes = null;
      _imageFileName = null;
      selectedCategoryId = null;
      if (MediaQuery.of(context).size.width < 800) {
        _isFormVisible = false;
      }
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

  Widget _buildBannerForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Add New Banner", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),

          // Category Dropdown
          DropdownButtonFormField<String>(
            value: selectedCategoryId,
            items: [
              DropdownMenuItem<String>(
                value: null,
                child: Text('Select Category', style: GoogleFonts.poppins(color: AppColors.hintTextColor)),
              ),
              ...categories.map((c) {
                return DropdownMenuItem(
                  value: c['id'].toString(),
                  child: Text(c['name'] ?? 'Unknown', style: GoogleFonts.poppins()),
                );
              }).toList(),
            ],
            onChanged: (val) {
              setState(() {
                selectedCategoryId = val;
              });
            },
            style: GoogleFonts.poppins(),
            decoration: InputDecoration(
              labelText: 'Category',
              labelStyle: GoogleFonts.poppins(color: AppColors.secondaryTextColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.borderColor),
              ),
              prefixIcon: const Icon(Icons.category, color: AppColors.hintTextColor),
              filled: true,
              fillColor: AppColors.backgroundColor,
            ),
            dropdownColor: AppColors.surfaceColor,
          ),
          const SizedBox(height: 16),

          Text("Banner Image", style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
          GestureDetector(
            onTap: _getImage,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                color: Colors.grey[50],
              ),
              child: _imageDataBytes != null
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(_imageDataBytes!, fit: BoxFit.cover),
              )
                  : _buildPlaceholder(),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _isLoadingForm
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                  onPressed: _uploadBanner,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text("Add Banner", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _resetForm,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: AppColors.secondaryTextColor),
                ),
                child: Text("Cancel", style: GoogleFonts.poppins(color: AppColors.secondaryTextColor)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text("Tap to select image 300 / 150", style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 14)),
          const SizedBox(height: 4),
          Text("JPG, PNG (Max 200KB)", style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildBannerCard(Map<String, dynamic> banner) {
    // ✅ CORRECT: Use 'main_category_name' instead of 'category_name'
    final categoryName = banner['main_category_name'] ?? 'No Category';
    final bannerImage = banner['banner_image'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: bannerImage.isNotEmpty
                ? Image.network(
              "${ApiConstants.BASE_URL}banner_api/$bannerImage",
              width: 300,
              height: 150,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 300,
                height: 150,
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
              ),
            )
                : Container(
              width: 300,
              height: 150,
              color: Colors.grey[200],
              child: const Icon(Icons.image, size: 50, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Category: $categoryName',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: AppColors.errorColor),
                onPressed: () => _showDeleteDialog(banner['id'].toString()),
              ),
            ],
          ),
          if (banner['main_category_id'] != null)
            Text(
              'Category ID: ${banner['main_category_id']}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.secondaryTextColor,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBannerList() {
    if (_isLoadingList) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primaryColor),
      );
    }
    if (_bannerList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_search, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              "No banners found!",
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: AppColors.secondaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Add your first banner using the form",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.hintTextColor,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _bannerList.length,
      itemBuilder: (context, index) => _buildBannerCard(_bannerList[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Banner Management",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppColors.primaryTextColor,
          ),
        ),
        backgroundColor: AppColors.surfaceColor,
        elevation: 1,
      ),
      backgroundColor: AppColors.backgroundColor,
      body: isLargeScreen
          ? Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _buildBannerList(),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 2,
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SingleChildScrollView(
                  child: _buildBannerForm(),
                ),
              ),
            ),
          ],
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isFormVisible
            ? Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: _buildBannerForm(),
          ),
        )
            : Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: _buildBannerList(),
        ),
      ),
      floatingActionButton: !isLargeScreen && !_isFormVisible
          ? FloatingActionButton(
        backgroundColor: AppColors.primaryColor,
        onPressed: () => setState(() => _isFormVisible = true),
        child: const Icon(Icons.add, color: Colors.white),
      )
          : null,
    );
  }
}