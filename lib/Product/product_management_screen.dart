import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker_web/image_picker_web.dart';
import 'package:shimmer/shimmer.dart';
import '../utils/api_constants.dart';
import '../utils/colors.dart';

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  State<ProductManagementScreen> createState() => _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  // Form controllers and state
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String? selectedMainCategoryId;
  final List<TextEditingController> _variantNameControllers = [];
  final List<TextEditingController> _variantPriceControllers = [];
  final List<TextEditingController> _wholesalePriceControllers = [];
  final List<TextEditingController> _sellingPriceControllers = [];
  final List<TextEditingController> _variantStockControllers = [];
  final List<Uint8List> _imageBytes = [];
  final List<TextEditingController> _infoAttributeControllers = [];
  final List<TextEditingController> _infoValueControllers = [];
  final List<TextEditingController> _highlightAttributeControllers = [];
  final List<TextEditingController> _highlightValueControllers = [];

  List<String> _uploadedImageUrls = [];

  // State variables
  List<String?> _existingVariantIds = [];
  List<String?> _existingInfoIds = [];
  List<String?> _existingHighlightIds = [];

  // Product list state
  List<dynamic> products = [];
  int currentPage = 1;
  int itemsPerPage = 10;
  int totalProducts = 0;
  bool isLoading = false;
  bool isFormLoading = false;
  TextEditingController searchController = TextEditingController();
  String searchQuery = '';
  Map<String, dynamic>? editingProduct;
  Map<int, List<String>> selectedTypesMap = {};

  List _mainCategoryList = [];
  String? _filterCategoryId;

  @override
  void initState() {
    super.initState();

    fetchProducts();
    _addVariantField();
    _addInfoField();
    _addHighlightField();

    _fetchMainCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    for (var controller in _variantNameControllers) controller.dispose();
    for (var controller in _variantPriceControllers) controller.dispose();
    for (var controller in _sellingPriceControllers) controller.dispose();
    for (var controller in _wholesalePriceControllers) controller.dispose();
    for (var controller in _variantStockControllers) controller.dispose();
    for (var controller in _infoAttributeControllers) controller.dispose();
    for (var controller in _infoValueControllers) controller.dispose();
    for (var controller in _highlightAttributeControllers) controller.dispose();
    for (var controller in _highlightValueControllers) controller.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchProducts() async {
    setState(() => isLoading = true);
    try {
      String url = '${ApiConstants.VIEW_ALL_PRODUCTS}?page=$currentPage&limit=$itemsPerPage';

      if (searchQuery.isNotEmpty) {
        url += '&search=$searchQuery';
      }

      if (_filterCategoryId != null && _filterCategoryId != 'all') {
        url += '&category_id=$_filterCategoryId';
      }

      print('Fetching from URL: $url'); // Debug

      final res = await http.get(Uri.parse(url));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success']) {
          setState(() {
            products = data['products'];
            totalProducts = int.tryParse(data['total'].toString()) ?? 0;

            // Reset selected types map
            selectedTypesMap.clear();

            // Initialize types for each product
            for (var product in products) {
              final productId = int.tryParse(product['id'].toString()) ?? 0;
              selectedTypesMap[productId] = getSelectedTypes(product['types'] ?? "");
            }
          });
        } else {
          _showSnackBar('Failed to load products: ${data['message']}', AppColors.errorColor);
        }
      } else {
        _showSnackBar('Failed to load products: ${res.statusCode}', AppColors.errorColor);
      }
    } catch (e) {
      print('Error fetching products: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchMainCategories() async {
    try {
      final response = await http.get(Uri.parse(ApiConstants.MAIN_VIEW_CATEGORY));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Main categories fetched: ${data.length} items');

        setState(() {
          _mainCategoryList = data;
        });
      } else {
        _showSnackBar("Error fetching main categories: ${response.statusCode}", AppColors.errorColor);
      }
    } catch (e) {
      _showSnackBar("Connection error fetching main categories: $e", AppColors.errorColor);
    }
  }

  Future<void> _getImage() async {
    final Uint8List? bytes = await ImagePickerWeb.getImageAsBytes();
    if (bytes != null) {
      if (bytes.length <= 1024 * 1024) {
        setState(() => _imageBytes.add(bytes));
      } else {
        _showSnackBar('Image must be smaller than 1 MB', AppColors.warningColor);
      }
    }
  }

  Future<void> _saveProductHandler() async {
    if (_nameController.text.isEmpty || selectedMainCategoryId == null) {
      _showSnackBar('Please fill all main product fields', AppColors.errorColor);
      return;
    }

    if (editingProduct != null) {
      await _updateProduct();
    } else {
      await _saveProduct();
    }
  }

  Future<void> _saveProduct() async {
    if (_nameController.text.isEmpty || selectedMainCategoryId == null) {
      _showSnackBar('Please fill all main product fields', AppColors.errorColor);
      return;
    }

    _showSnackBar('Saving product...', AppColors.infoColor);

    try {
      final body = {
        'name': _nameController.text.trim(),
        'description': "test",
        'main_category_id': selectedMainCategoryId,
        'images': _uploadedImageUrls,
      };

      final res = await http.post(
        Uri.parse(ApiConstants.SAVE_PRODUCT),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final savedProductId = data['id']?.toString();

        if (data['success'] && savedProductId != null) {
          // Upload Images
          for (int i = 0; i < _imageBytes.length; i++) {
            await _uploadImage(_imageBytes[i], int.parse(savedProductId));
          }

          // Save Variants
          for (int i = 0; i < _variantNameControllers.length; i++) {
            if (_variantNameControllers[i].text.isNotEmpty) {
              await _saveVariant(
                savedProductId,
                _variantNameControllers[i].text,
                _variantPriceControllers[i].text,
                _sellingPriceControllers[i].text,
                _wholesalePriceControllers[i].text,
                _variantStockControllers[i].text,
              );
            }
          }

          // Save Info
          for (int i = 0; i < _infoAttributeControllers.length; i++) {
            if (_infoAttributeControllers[i].text.isNotEmpty &&
                _infoValueControllers[i].text.isNotEmpty) {
              await _saveProductDetail(
                ApiConstants.SAVE_PRODUCT_INFO,
                savedProductId,
                _infoAttributeControllers[i].text,
                _infoValueControllers[i].text,
              );
            }
          }

          // Save Highlights
          for (int i = 0; i < _highlightAttributeControllers.length; i++) {
            if (_highlightAttributeControllers[i].text.isNotEmpty &&
                _highlightValueControllers[i].text.isNotEmpty) {
              await _saveProductDetail(
                ApiConstants.SAVE_PRODUCT_HIGHLIGHT,
                savedProductId,
                _highlightAttributeControllers[i].text,
                _highlightValueControllers[i].text,
              );
            }
          }

          _showSnackBar(
            'Product and all details added successfully!',
            AppColors.successColor,
          );

          _clearFields();
          fetchProducts();
        } else {
          _showSnackBar(
            'Product save failed: ${data['message'] ?? 'Unknown error'}',
            AppColors.errorColor,
          );
        }
      } else {
        _showSnackBar('HTTP Error: ${res.statusCode}', AppColors.errorColor);
      }
    } catch (e) {
      _showSnackBar('Error occurred: $e', AppColors.errorColor);
    }
  }

  Future<void> _updateProduct() async {
    if (editingProduct == null) return;

    final productId = editingProduct!['id'].toString();
    _showSnackBar('Updating product...', AppColors.infoColor);

    try {
      final body = {
        'id': productId,
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'main_category_id': selectedMainCategoryId,
        'images': _uploadedImageUrls,
        'variants': [
          for (int i = 0; i < _variantNameControllers.length; i++)
            {
              'id': _existingVariantIds.length > i ? _existingVariantIds[i] : null,
              'name': _variantNameControllers[i].text,
              'price': _variantPriceControllers[i].text,
              'selling_price': _sellingPriceControllers[i].text,
              'wholesale_price': _wholesalePriceControllers[i].text,
              'stock_quantity': _variantStockControllers[i].text,
            }
        ],
        'info': [
          for (int i = 0; i < _infoAttributeControllers.length; i++)
            {
              'id': _existingInfoIds.length > i ? _existingInfoIds[i] : null,
              'attribute': _infoAttributeControllers[i].text,
              'value': _infoValueControllers[i].text,
            }
        ],
        'highlights': [
          for (int i = 0; i < _highlightAttributeControllers.length; i++)
            {
              'id': _existingHighlightIds.length > i ? _existingHighlightIds[i] : null,
              'attribute': _highlightAttributeControllers[i].text,
              'value': _highlightValueControllers[i].text,
            }
        ],
      };

      final res = await http.post(
        Uri.parse(ApiConstants.UPDATE_PRODUCT),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success']) {
          for (int i = 0; i < _imageBytes.length; i++) {
            await _uploadImage(_imageBytes[i], int.parse(productId));
          }

          _showSnackBar('Product updated successfully!', AppColors.successColor);
          _clearFields();
          fetchProducts();
        } else {
          _showSnackBar('Product update failed: ${data['message'] ?? 'Unknown error'}',
              AppColors.errorColor);
        }
      } else {
        _showSnackBar('HTTP Error: ${res.statusCode}', AppColors.errorColor);
      }
    } catch (e) {
      _showSnackBar('Error occurred: $e', AppColors.errorColor);
    }
  }

  Future<void> _saveVariant(
      String productId,
      String name,
      String price,
      String sellingPrice,
      String wholesalePrice,
      String stockQuantity,
      {String? variantId}) async {
    try {
      double? parsedPrice = double.tryParse(price) ?? 0.0;
      double? parsedWholesalePrice = double.tryParse(wholesalePrice) ?? 0.0;
      int? parsedStock = int.tryParse(stockQuantity) ?? 0;

      final body = {
        'product_id': productId,
        'name': name,
        'price': parsedPrice.toString(),
        'selling_price': sellingPrice,
        'wholesale_price': parsedWholesalePrice.toString(),
        'stock_quantity': parsedStock.toString(),
        if (variantId != null) 'id': variantId,
      };

      final res = await http.post(Uri.parse(ApiConstants.SAVE_VARIANT), body: body);

      if (res.statusCode != 200) {
        print('Failed to save variant "$name". HTTP Status: ${res.statusCode}');
      }
    } catch (e) {
      print('Error saving variant "$name": $e');
    }
  }

  Future<void> _uploadImage(Uint8List bytes, int productId) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstants.SAVE_IMAGE),
      );

      request.fields['product_id'] = productId.toString();
      request.files.add(http.MultipartFile.fromBytes('image', bytes, filename: 'image.png'));

      var response = await request.send();
      if (response.statusCode != 200) {
        print('Image upload failed for product ID: $productId. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error uploading image: $e');
    }
  }

  final List<String> typeOptions = [
    'Everyday Essentials',
    'Best selling',
    'Hot deals',
  ];

  List<String> getSelectedTypes(String typeString) {
    return typeString.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  void _updateProductType(int productId, String newType) async {
    try {
      print('Updating product type: id=$productId, type=$newType');

      final response = await http.post(
        Uri.parse(ApiConstants.UPDATE_PRODUCT_TYPE),
        body: {
          'id': productId.toString(),
          'type': newType,
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          _showSnackBar('Product type updated successfully', AppColors.successColor);

          // Update local state
          setState(() {
            selectedTypesMap[productId] = getSelectedTypes(newType);
          });

          // Refresh products list
          fetchProducts();
        } else {
          _showSnackBar('Failed to update product type', AppColors.errorColor);
        }
      } else {
        _showSnackBar('Failed to update product type', AppColors.errorColor);
      }
    } catch (e) {
      print('Exception: $e');
      _showSnackBar('Error updating product type: $e', AppColors.errorColor);
    }
  }

  Widget _buildPaginationControls() {
    final totalPages = (totalProducts / itemsPerPage).ceil();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: currentPage > 1 ? () {
            setState(() => currentPage--);
            fetchProducts();
          } : null,
          color: currentPage > 1 ? AppColors.primaryColor : Colors.grey,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Text(
            'Page $currentPage of $totalPages',
            style: GoogleFonts.poppins(
              color: AppColors.primaryTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: currentPage < totalPages ? () {
            setState(() => currentPage++);
            fetchProducts();
          } : null,
          color: currentPage < totalPages ? AppColors.primaryColor : Colors.grey,
        ),
      ],
    );
  }

  void _editProduct(Map<String, dynamic> product) {
    setState(() {
      editingProduct = product;

      _nameController.text = product['name'] ?? '';
      _descriptionController.text = product['description'] ?? '';
      selectedMainCategoryId = product['main_category_id']?.toString() ?? '';

      // Clear previous fields
      _variantNameControllers.clear();
      _variantPriceControllers.clear();
      _sellingPriceControllers.clear();
      _wholesalePriceControllers.clear();
      _variantStockControllers.clear();
      _existingVariantIds.clear();

      // Load Variants
      final variants = product['variants'] ?? [];
      if (variants.isNotEmpty) {
        for (var variant in variants) {
          _variantNameControllers.add(TextEditingController(text: variant['name'] ?? ''));
          _variantPriceControllers.add(TextEditingController(text: variant['price']?.toString() ?? ''));
          _sellingPriceControllers.add(TextEditingController(text: variant['selling_price']?.toString() ?? ''));
          _wholesalePriceControllers.add(TextEditingController(text: variant['wholesale_price']?.toString() ?? ''));
          _variantStockControllers.add(TextEditingController(text: variant['stock_quantity']?.toString() ?? variant['stock']?.toString() ?? ''));
          _existingVariantIds.add(variant['id']?.toString());
        }
      } else {
        _addVariantField();
      }

      // Load Info
      _infoAttributeControllers.clear();
      _infoValueControllers.clear();
      _existingInfoIds.clear();
      final infoList = product['info'] ?? [];
      if (infoList.isNotEmpty) {
        for (var info in infoList) {
          _infoAttributeControllers.add(TextEditingController(text: info['attribute'] ?? ''));
          _infoValueControllers.add(TextEditingController(text: info['value'] ?? ''));
          _existingInfoIds.add(info['id']?.toString());
        }
      } else {
        _addInfoField();
      }

      // Load Highlights
      _highlightAttributeControllers.clear();
      _highlightValueControllers.clear();
      _existingHighlightIds.clear();
      final highlights = product['highlights'] ?? [];
      if (highlights.isNotEmpty) {
        for (var highlight in highlights) {
          _highlightAttributeControllers.add(TextEditingController(text: highlight['attribute'] ?? ''));
          _highlightValueControllers.add(TextEditingController(text: highlight['value'] ?? ''));
          _existingHighlightIds.add(highlight['id']?.toString());
        }
      } else {
        _addHighlightField();
      }

      // Load Uploaded Images
      _uploadedImageUrls.clear();
      final imageUrls = product['images'] ?? [];
      for (var url in imageUrls) {
        if (url is String && url.isNotEmpty) {
          _uploadedImageUrls.add(url);
        }
      }
    });
  }

  Future<void> _deleteProduct(String productId) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Delete', style: GoogleFonts.poppins(color: AppColors.primaryTextColor)),
        content: Text('Are you sure you want to delete this product?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: AppColors.secondaryTextColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.poppins(color: AppColors.errorColor)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => isLoading = true);
      try {
        final res = await http.post(
          Uri.parse(ApiConstants.DELETE_PRODUCTS),
          body: {'id': productId},
        );

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['success']) {
            _showSnackBar('Product deleted successfully', AppColors.successColor);
            fetchProducts();
          } else {
            _showSnackBar('Failed to delete product: ${data['message']}', AppColors.errorColor);
          }
        } else {
          _showSnackBar('Failed to delete product: ${res.statusCode}', AppColors.errorColor);
        }
      } catch (e) {
        _showSnackBar('Error deleting product: $e', AppColors.errorColor);
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Product Management",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppColors.primaryTextColor,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left side - Product List
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  // Search bar
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: AppColors.surfaceColor,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: searchController,
                              onChanged: (value) {
                                setState(() {
                                  searchQuery = value;
                                  currentPage = 1;
                                });
                                fetchProducts();
                              },
                              style: GoogleFonts.poppins(),
                              decoration: InputDecoration(
                                labelText: 'Search Products',
                                labelStyle: GoogleFonts.poppins(color: AppColors.secondaryTextColor),
                                prefixIcon: const Icon(Icons.search, color: AppColors.hintTextColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: AppColors.borderColor),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: AppColors.borderColor),
                                ),
                                filled: true,
                                fillColor: AppColors.backgroundColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.primaryColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.refresh, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  searchQuery = '';
                                  searchController.clear();
                                  currentPage = 1;
                                });
                                fetchProducts();
                              },
                              tooltip: 'Refresh',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  _buildCategoryFilterDropdown(),

                  const SizedBox(height: 16),

                  Text(
                    'Total Products: ${totalProducts.toString()}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryTextColor,
                    ),
                  ),

                  // Product List
                  Expanded(
                    child: isLoading
                        ? _buildShimmerLoader()
                        : products.isEmpty
                        ? Center(
                      child: Text(
                        'No products found',
                        style: GoogleFonts.poppins(
                          color: AppColors.secondaryTextColor,
                          fontSize: 16,
                        ),
                      ),
                    )
                        : ListView.builder(
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return _buildProductListItem(product);
                      },
                    ),
                  ),

                  if (totalProducts > itemsPerPage)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: _buildPaginationControls(),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 20),

            // Right side - Product Form
            Expanded(
              flex: 2,
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: AppColors.surfaceColor,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          editingProduct != null ? "Edit Product" : "Add New Product",
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildProductForm(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductForm() {
    final validatedMainCategoryId = _mainCategoryList.any((mc) => mc['id'].toString() == selectedMainCategoryId)
        ? selectedMainCategoryId
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameController,
          style: GoogleFonts.poppins(),
          decoration: InputDecoration(
            labelText: 'Product Name',
            labelStyle: GoogleFonts.poppins(color: AppColors.secondaryTextColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borderColor),
            ),
            prefixIcon: const Icon(Icons.shopping_bag, color: AppColors.hintTextColor),
            filled: true,
            fillColor: AppColors.backgroundColor,
          ),
        ),
        const SizedBox(height: 16),

        DropdownButtonFormField<String>(
          value: validatedMainCategoryId,
          items: _mainCategoryList.map((mc) {
            return DropdownMenuItem(
              value: mc['id'].toString(),
              child: Text(mc['name'], style: GoogleFonts.poppins()),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              selectedMainCategoryId = val;
            });
          },
          style: GoogleFonts.poppins(),
          decoration: InputDecoration(
            labelText: 'Main Category',
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

        Text(
          'Product Gallery',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppColors.primaryTextColor,
            fontSize: 16,
          ),
        ),
        Text(
          'नोट: कृपया पहले प्रोडक्ट की मेन इमेज चुनें।',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppColors.primaryTextColor,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 10),
        _buildImageUploadSection(),
        const SizedBox(height: 20),
        _buildVariantSection(),
        const SizedBox(height: 20),
        _buildInfoSection(),
        const SizedBox(height: 20),
        _buildHighlightSection(),
        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (editingProduct != null)
              TextButton(
                onPressed: () {
                  setState(() {
                    editingProduct = null;
                    _clearFields();
                  });
                },
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(
                    color: AppColors.secondaryTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _saveProductHandler,
              icon: const Icon(Icons.save, size: 20),
              label: Text(
                editingProduct != null ? "Update Product" : "Save Product",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryFilterDropdown() {
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
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filterCategoryId,
                hint: Text(
                  "Filter by Category",
                  style: GoogleFonts.poppins(
                      color: AppColors.secondaryTextColor
                  ),
                ),
                items: [
                  DropdownMenuItem<String>(
                    value: 'all',
                    child: Text(
                      "All Categories",
                      style: GoogleFonts.poppins(
                          color: AppColors.primaryTextColor
                      ),
                    ),
                  ),
                  ..._mainCategoryList.map<DropdownMenuItem<String>>((category) {
                    return DropdownMenuItem<String>(
                      value: category['id'].toString(),
                      child: Text(
                        category['name'],
                        style: GoogleFonts.poppins(
                            color: AppColors.primaryTextColor
                        ),
                      ),
                    );
                  }).toList(),
                ],
                onChanged: (String? newValue) {
                  setState(() {
                    _filterCategoryId = newValue;
                    currentPage = 1;
                  });
                  fetchProducts();
                },
                style: GoogleFonts.poppins(
                    color: AppColors.primaryTextColor,
                    fontSize: 14
                ),
                icon: const Icon(
                    Icons.arrow_drop_down,
                    color: AppColors.primaryColor
                ),
                isExpanded: true,
              ),
            ),
          ),
          if (_filterCategoryId != null && _filterCategoryId != 'all')
            IconButton(
              icon: const Icon(Icons.clear, size: 20),
              onPressed: () {
                setState(() {
                  _filterCategoryId = null;
                  currentPage = 1;
                });
                fetchProducts();
              },
              tooltip: 'Clear filter',
            ),
        ],
      ),
    );
  }

  Widget _buildImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (int i = 0; i < _uploadedImageUrls.length; i++)
              Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage(ApiConstants.BASE_IMAGE_URL + _uploadedImageUrls[i]),
                        fit: BoxFit.cover,
                      ),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => setState(() => _uploadedImageUrls.removeAt(i)),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.errorColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),

            for (int i = 0; i < _imageBytes.length; i++)
              Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: MemoryImage(_imageBytes[i]),
                        fit: BoxFit.cover,
                      ),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => setState(() => _imageBytes.removeAt(i)),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.errorColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),

            GestureDetector(
              onTap: _getImage,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.backgroundColor,
                  border: Border.all(color: AppColors.borderColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo, size: 20, color: AppColors.hintTextColor),
                    const SizedBox(height: 4),
                    Text(
                      'Add',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.hintTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Add images 1:1 (100K each)',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppColors.hintTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildVariantSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Product Variants',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: AppColors.primaryTextColor,
                fontSize: 16,
              ),
            ),
            IconButton(
              onPressed: _addVariantField,
              icon: const Icon(Icons.add_circle, color: AppColors.successColor),
              tooltip: 'Add Variant',
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(_variantNameControllers.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _variantNameControllers[i],
                        style: GoogleFonts.poppins(),
                        decoration: InputDecoration(
                          labelText: 'Name',
                          labelStyle: GoogleFonts.poppins(color: AppColors.secondaryTextColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.borderColor),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          filled: true,
                          fillColor: AppColors.backgroundColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _variantPriceControllers[i],
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.poppins(),
                        decoration: InputDecoration(
                          labelText: 'MRP Price',
                          labelStyle: GoogleFonts.poppins(color: AppColors.secondaryTextColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.borderColor),
                          ),
                          prefixText: '₹ ',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          filled: true,
                          fillColor: AppColors.backgroundColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _sellingPriceControllers[i],
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.poppins(),
                        decoration: InputDecoration(
                          labelText: 'Selling Price',
                          labelStyle: GoogleFonts.poppins(color: AppColors.secondaryTextColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.borderColor),
                          ),
                          prefixText: '₹ ',
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.borderColor),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          filled: true,
                          fillColor: AppColors.backgroundColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _wholesalePriceControllers[i],
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.poppins(),
                        decoration: InputDecoration(
                          labelText: 'Purchase Price',
                          labelStyle: GoogleFonts.poppins(color: AppColors.secondaryTextColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.borderColor),
                          ),
                          prefixText: '₹ ',
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.borderColor),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          filled: true,
                          fillColor: AppColors.backgroundColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _variantStockControllers[i],
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.poppins(),
                        decoration: InputDecoration(
                          labelText: 'Stock',
                          labelStyle: GoogleFonts.poppins(color: AppColors.secondaryTextColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.borderColor),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          filled: true,
                          fillColor: AppColors.backgroundColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.remove_circle, color: AppColors.errorColor),
                      onPressed: () => _removeVariantField(i),
                      tooltip: 'Remove Variant',
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Product Information',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: AppColors.primaryTextColor,
                fontSize: 16,
              ),
            ),
            IconButton(
              onPressed: _addInfoField,
              icon: const Icon(Icons.add_circle, color: AppColors.successColor),
              tooltip: 'Add Info',
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(_infoAttributeControllers.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _infoAttributeControllers[i],
                    style: GoogleFonts.poppins(),
                    decoration: InputDecoration(
                      labelText: 'Attribute',
                      labelStyle: GoogleFonts.poppins(color: AppColors.secondaryTextColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.borderColor),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      filled: true,
                      fillColor: AppColors.backgroundColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _infoValueControllers[i],
                    style: GoogleFonts.poppins(),
                    decoration: InputDecoration(
                      labelText: 'Value',
                      labelStyle: GoogleFonts.poppins(color: AppColors.secondaryTextColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.borderColor),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      filled: true,
                      fillColor: AppColors.backgroundColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle, color: AppColors.errorColor),
                  onPressed: () => _removeInfoField(i),
                  tooltip: 'Remove Info',
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildHighlightSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Product Highlights',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: AppColors.primaryTextColor,
                fontSize: 16,
              ),
            ),
            IconButton(
              onPressed: _addHighlightField,
              icon: const Icon(Icons.add_circle, color: AppColors.successColor),
              tooltip: 'Add Highlight',
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(_highlightAttributeControllers.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _highlightAttributeControllers[i],
                    style: GoogleFonts.poppins(),
                    decoration: InputDecoration(
                      labelText: 'Attribute',
                      labelStyle: GoogleFonts.poppins(color: AppColors.secondaryTextColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.borderColor),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      filled: true,
                      fillColor: AppColors.backgroundColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _highlightValueControllers[i],
                    style: GoogleFonts.poppins(),
                    decoration: InputDecoration(
                      labelText: 'Value',
                      labelStyle: GoogleFonts.poppins(color: AppColors.secondaryTextColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.borderColor),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      filled: true,
                      fillColor: AppColors.backgroundColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle, color: AppColors.errorColor),
                  onPressed: () => _removeHighlightField(i),
                  tooltip: 'Remove Highlight',
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildProductListItem(Map<String, dynamic> product) {
    final int productId = int.tryParse(product['id'].toString()) ?? 0;
    final List<String> selectedTypes = selectedTypesMap[productId] ?? getSelectedTypes(product['types'] ?? "");

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tilePadding: const EdgeInsets.all(16),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: AppColors.backgroundColor,
                    image: product['images'] != null && product['images'].isNotEmpty
                        ? DecorationImage(
                      image: NetworkImage(ApiConstants.BASE_URL+'product_api_project/${product['images'][0]}'),
                      fit: BoxFit.cover,
                    )
                        : null,
                  ),
                  child: product['images'] == null || product['images'].isEmpty
                      ? const Icon(Icons.image, color: AppColors.hintTextColor)
                      : null,
                ),
                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['name'],
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryTextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('C : '+
                                product['main_category_name'],
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.primaryTextColor,
                              ),
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${product['variants']?.length ?? 0} variants',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          color: AppColors.infoColor,
                          onPressed: () => _editProduct(product),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20),
                          color: AppColors.errorColor,
                          onPressed: () => _deleteProduct(product['id'].toString()),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                const Text(
                  'Product Types:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: typeOptions.map((type) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: selectedTypes.contains(type),
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                selectedTypes.add(type);
                              } else {
                                selectedTypes.remove(type);
                              }
                              selectedTypesMap[productId] = List.from(selectedTypes);
                            });
                          },
                        ),
                        Text(type, style: GoogleFonts.poppins(fontSize: 14)),
                      ],
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    print("Updating product ID: $productId with types: ${selectedTypes.join(',')}");
                    _updateProductType(productId, selectedTypes.join(','));
                  },
                  child: const Text("Update Type"),
                ),
              ],
            ),
          ],
        ),
        children: [
          if (product['variants'] != null && product['variants'].isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Variants:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...product['variants'].map<Widget>((variant) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${variant['name']} - MRP: ₹${variant['price']} | Selling: ₹${variant['selling_price']} | Wholesale: ₹${variant['wholesale_price'] ?? 'N/A'}",
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                        Text(
                          "Stock: ${variant['stock'].toString()}",
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[600]
                          ),
                        )
                      ],
                    ),
                  );
                }).toList(),
                const SizedBox(height: 12),
              ],
            )
          else
            const Text("No variants found", style: TextStyle(fontSize: 14)),

          if (product['info'] != null && product['info'].isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Info:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...product['info'].map<Widget>((info) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        "${info['attribute']}: ${info['value']}",
                        style: GoogleFonts.poppins(fontSize: 14),
                        textAlign: TextAlign.left,
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 12),
                ],
              ),
            )
          else
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("No info found", style: TextStyle(fontSize: 14)),
            ),

          if (product['highlights'] != null && product['highlights'].isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Highlights:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...product['highlights'].map<Widget>((high) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        "${high['attribute']}: ${high['value']}",
                        style: GoogleFonts.poppins(fontSize: 14),
                        textAlign: TextAlign.left,
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 8),
                ],
              ),
            )
          else
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("No highlights found", style: TextStyle(fontSize: 14)),
            ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoader() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 100,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Container(
                      width: 80,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: 60,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveProductDetail(String apiUrl, String productId, String attribute, String value) async {
    try {
      final res = await http.post(Uri.parse(apiUrl), body: {
        'product_id': productId,
        'attribute': attribute,
        'value': value,
      });

      if (res.statusCode != 200) {
        print('Failed to save detail (Attribute: $attribute). HTTP Status: ${res.statusCode}');
      }
    } catch (e) {
      print('Error saving detail (Attribute: $attribute): $e');
    }
  }

  void _addVariantField() {
    setState(() {
      _variantNameControllers.add(TextEditingController());
      _variantPriceControllers.add(TextEditingController());
      _sellingPriceControllers.add(TextEditingController());
      _wholesalePriceControllers.add(TextEditingController());
      _variantStockControllers.add(TextEditingController());
    });
  }

  void _removeVariantField(int index) {
    setState(() {
      _variantNameControllers[index].dispose();
      _variantPriceControllers[index].dispose();
      _sellingPriceControllers[index].dispose();
      _wholesalePriceControllers[index].dispose();
      _variantStockControllers[index].dispose();
      _variantNameControllers.removeAt(index);
      _variantPriceControllers.removeAt(index);
      _sellingPriceControllers.removeAt(index);
      _wholesalePriceControllers.removeAt(index);
      _variantStockControllers.removeAt(index);
    });
  }

  void _addInfoField() {
    setState(() {
      _infoAttributeControllers.add(TextEditingController());
      _infoValueControllers.add(TextEditingController());
    });
  }

  void _removeInfoField(int index) {
    setState(() {
      _infoAttributeControllers[index].dispose();
      _infoValueControllers[index].dispose();
      _infoAttributeControllers.removeAt(index);
      _infoValueControllers.removeAt(index);
    });
  }

  void _addHighlightField() {
    setState(() {
      _highlightAttributeControllers.add(TextEditingController());
      _highlightValueControllers.add(TextEditingController());
    });
  }

  void _removeHighlightField(int index) {
    setState(() {
      _highlightAttributeControllers[index].dispose();
      _highlightValueControllers[index].dispose();
      _highlightAttributeControllers.removeAt(index);
      _highlightValueControllers.removeAt(index);
    });
  }

  void _clearFields() {
    _nameController.clear();
    _descriptionController.clear();
    setState(() {
      _imageBytes.clear();
      editingProduct = null;
      selectedMainCategoryId = null;

      _uploadedImageUrls.clear();
      _imageBytes.clear();

      _variantNameControllers.clear();
      _variantPriceControllers.clear();
      _sellingPriceControllers.clear();
      _wholesalePriceControllers.clear();
      _variantStockControllers.clear();
      _addVariantField();

      _infoAttributeControllers.clear();
      _infoValueControllers.clear();
      _addInfoField();

      _highlightAttributeControllers.clear();
      _highlightValueControllers.clear();
      _addHighlightField();
    });
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}