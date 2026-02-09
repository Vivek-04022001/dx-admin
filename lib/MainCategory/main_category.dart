import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker_web/image_picker_web.dart';

import '../utils/api_constants.dart';
import '../utils/colors.dart';


class MainCategory extends StatefulWidget {
  const MainCategory({super.key});

  @override
  State<MainCategory> createState() => _MainCategoryState();
}

class _MainCategoryState extends State<MainCategory> {
  final TextEditingController _categoryTextController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  Uint8List? _imageDataBytes;
  String? _imageFileName;
  bool _isLoadingForm = false;
  List _categoryList = [];
  List _filteredCategoryList = [];
  bool _isLoadingList = true;
  String? _selectedCategoryIdForEdit;
  String? _initialCategoryName;
  String? _initialCategoryImage;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _searchController.addListener(_filterCategories);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterCategories);
    _searchController.dispose();
    super.dispose();
  }

  void _filterCategories() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCategoryList = List.from(_categoryList);
      } else {
        _filteredCategoryList = _categoryList.where((category) {
          final name = category['name'].toString().toLowerCase();
          return name.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _fetchCategories() async {
    setState(() => _isLoadingList = true);
    try {
      final response = await http.get(Uri.parse(ApiConstants.MAIN_VIEW_CATEGORY));
      if (response.statusCode == 200) {
        setState(() {
          _categoryList = jsonDecode(response.body);
          _filteredCategoryList = List.from(_categoryList);
          _isLoadingList = false;
        });
      } else {
        _showSnackBar("Error fetching categories: ${response.statusCode}", AppColors.errorColor);
        setState(() => _isLoadingList = false);
      }
    } catch (e) {
      _showSnackBar("Connection error: $e", AppColors.errorColor);
      setState(() => _isLoadingList = false);
    }
  }

  Future<void> _uploadCategory() async {
    if (_categoryTextController.text.isEmpty) {
      _showSnackBar("Please enter main name!", AppColors.warningColor);
      return;
    }

    setState(() => _isLoadingForm = true);

    try {
      final apiUrl = _selectedCategoryIdForEdit == null
          ? ApiConstants.MAIN_ADD_CATEGORY
          : ApiConstants.MAIN_EDIT_CATEGORY;

      final body = {
        "category_name": _categoryTextController.text,
        if (_selectedCategoryIdForEdit != null) "category_id": _selectedCategoryIdForEdit,
        if (_imageDataBytes != null) "data": base64Encode(_imageDataBytes!),
        if (_imageDataBytes != null) "name": _imageFileName ?? "category_image.jpg",
      };

      final res = await http.post(Uri.parse(apiUrl), body: body);
      final response = jsonDecode(res.body);

      setState(() => _isLoadingForm = false);

      if (response["success"] == "true") {
        _showSnackBar("Category ${_selectedCategoryIdForEdit == null ? 'Added' : 'Updated'} Successfully! ✅", AppColors.successColor);
        _resetForm();
        _fetchCategories();
      } else {
        _showSnackBar("Error: ${response["message"] ?? "Unknown error"}", AppColors.errorColor);
      }
    } catch (e) {
      setState(() => _isLoadingForm = false);
      _showSnackBar("Network error: $e", AppColors.errorColor);
    }
  }

  Future<void> _deleteCategory(String id) async {
    setState(() => _isLoadingList = true);
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.MAIN_DELETE_CATEGORY),
        body: {"id": id},
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData["success"] == "true") {
        _showSnackBar("Category deleted successfully", AppColors.successColor);
        await _fetchCategories();
      } else {
        _showSnackBar("Failed to delete: ${responseData["message"]}", AppColors.errorColor);
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
      // 100 KB = 102400 bytes
      if (bytesFromPicker.lengthInBytes <= 102400) {
        setState(() {
          _imageDataBytes = bytesFromPicker;
          _imageFileName = "category_image_${DateTime.now().millisecondsSinceEpoch}.png";
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please select an image smaller than 100 KB")),
        );
      }
    }
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

  void _resetForm() {
    _categoryTextController.clear();
    setState(() {
      _imageDataBytes = null;
      _imageFileName = null;
      _selectedCategoryIdForEdit = null;
      _initialCategoryName = null;
      _initialCategoryImage = null;
    });
  }

  void _startEdit(Map<String, dynamic> category) {
    setState(() {
      _selectedCategoryIdForEdit = category['id'];
      _initialCategoryName = category['name'];
      _initialCategoryImage = category['image'];
      _categoryTextController.text = category['name'];
    });
  }

  void _showDeleteDialog(String categoryId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Confirm Delete", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: const Text("This category will be permanently deleted. This action cannot be undone."),
        actions: [
          TextButton(
            child: Text("Cancel", style: GoogleFonts.poppins(color: AppColors.secondaryTextColor)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text("Delete", style: GoogleFonts.poppins(color: AppColors.errorColor)),
            onPressed: () {
              Navigator.pop(context);
              _deleteCategory(categoryId);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryForm() {
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
          Text(
            _selectedCategoryIdForEdit == null ? "Add New Category" : "Edit Category",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryTextColor,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _categoryTextController,
            decoration: InputDecoration(
              labelText: "Category Name",
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
          Text("Category Image", style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _getImage,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
                color: Colors.grey[50],
              ),
              child: _imageDataBytes != null
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  _imageDataBytes!,
                  fit: BoxFit.cover,
                ),
              )
                  : (_selectedCategoryIdForEdit != null && _initialCategoryImage != null
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  ApiConstants.BASE_URL + "main_category/${_initialCategoryImage!}",
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                ),
              )
                  : _buildPlaceholder()),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _isLoadingForm
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                  onPressed: _uploadCategory,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _selectedCategoryIdForEdit == null ? "Add Category" : "Update Category",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.surfaceColor,
                    ),
                  ),
                ),
              ),
              if (_selectedCategoryIdForEdit != null) ...[
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _resetForm,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: const BorderSide(color: AppColors.secondaryTextColor),
                  ),
                  child: Text("Cancel", style: GoogleFonts.poppins(color: AppColors.secondaryTextColor)),
                ),
              ]
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
          Text(
            "Tap to select image 1:1",
            style: GoogleFonts.poppins(color: Colors.grey[500], fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            "JPG, PNG (Max 100KB)",
            style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: "Search categories...",
          hintStyle: GoogleFonts.poppins(color: AppColors.secondaryTextColor),
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search, color: AppColors.primaryColor),
          suffixIcon: IconButton(
            icon: const Icon(Icons.close, color: AppColors.secondaryTextColor),
            onPressed: () {
              _searchController.clear();
              _filterCategories();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: category['image'] != null
                ? Image.network(
              ApiConstants.BASE_URL + "main_category/${category['image']}",
              fit: BoxFit.cover,
            )
                : Icon(Icons.category, color: AppColors.primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category['name'] ?? "Unnamed",
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit, color: AppColors.primaryColor),
            onPressed: () => _startEdit(category),
            tooltip: 'Edit',
          ),
          IconButton(
            icon: Icon(Icons.delete, color: AppColors.errorColor),
            onPressed: () => _showDeleteDialog(category['id']),
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    if (_isLoadingList) {
      return Center(child: CircularProgressIndicator(color: AppColors.primaryColor));
    }

    if (_filteredCategoryList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: AppColors.secondaryTextColor),
            const SizedBox(height: 16),
            Text(
              "No Categories Found",
              style: GoogleFonts.poppins(fontSize: 18, color: AppColors.secondaryTextColor),
            ),
            const SizedBox(height: 8),
            Text(
              "Try a different search term",
              style: GoogleFonts.poppins(fontSize: 14, color: AppColors.secondaryTextColor),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 16),
      itemCount: _filteredCategoryList.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final category = _filteredCategoryList[index];
        return _buildCategoryCard(category);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Main Category Management",
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSearchBar(),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Category List",
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryTextColor,
                        ),
                      ),
                      Text(
                        "${_filteredCategoryList.length} Items",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: AppColors.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _buildCategoryList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: _buildCategoryForm(),
            ),
          ),
        ],
      ),
    );
  }
}