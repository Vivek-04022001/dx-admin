import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shimmer/shimmer.dart';

import '../utils/api_constants.dart';
import '../utils/colors.dart';

class StockManagementScreen extends StatefulWidget {
  const StockManagementScreen({super.key});

  @override
  State<StockManagementScreen> createState() => _StockManagementScreenState();
}

class _StockManagementScreenState extends State<StockManagementScreen> {
  // Product list state
  List<dynamic> products = [];
  List<dynamic> filteredProducts = [];
  int currentPage = 1;
  int itemsPerPage = 10;
  int totalProducts = 0;
  bool isLoading = false;
  bool isInitialLoad = true;
  TextEditingController searchController = TextEditingController();
  String searchQuery = '';

  // Filter state
  bool showLowStockOnly = false;
  int lowStockThreshold = 10;

  // Stock update state
  Map<int, TextEditingController> _stockControllers = {};
  Map<int, bool> _isUpdating = {};
  Map<int, bool> _expandedProducts = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchProducts();

    });
  }

  @override
  void dispose() {
    searchController.dispose();
    _stockControllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> fetchProducts() async {
    if (isInitialLoad) {
      setState(() => isLoading = true);
    }

    try {
      // ✅ Base URL build
      String url = '${ApiConstants.VIEW_ALL_PRODUCTS}?page=$currentPage&limit=$itemsPerPage';

      // ✅ Add search query if available
      if (searchQuery.isNotEmpty) {
        url += '&search=$searchQuery';
      }

      final res = await http.get(Uri.parse(url));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        if (data['success']) {
          setState(() {
            products = List<Map<String, dynamic>>.from(data['products']);
            totalProducts = data['total'];
            isInitialLoad = false;
          });

          // ✅ Apply filters for UI refresh
          applyFilters();

          // ✅ Initialize stock controllers
          for (var product in products) {
            if (product['variants'] != null && product['variants'].isNotEmpty) {
              for (var variant in product['variants']) {
                final variantId = int.tryParse(variant['id'].toString()) ?? 0;
                if (!_stockControllers.containsKey(variantId)) {
                  _stockControllers[variantId] = TextEditingController(text: '0');
                }
              }
            }
          }
        } else {
          _showSnackBar('Failed to load products: ${data['message']}', AppColors.errorColor);
        }
      } else {
        _showSnackBar('Failed to load products: ${res.statusCode}', AppColors.errorColor);
      }
    } catch (e) {
      // _showSnackBar('Error fetching products: $e', AppColors.errorColor);
    } finally {
      setState(() => isLoading = false);
    }
  }


  void applyFilters() {
    setState(() {
      if (showLowStockOnly) {
        filteredProducts = products.where((product) {
          if (product['variants'] != null && product['variants'].isNotEmpty) {
            return product['variants'].any((variant) {
              final currentStock = int.tryParse(variant['stock']?.toString() ?? '0') ?? 0;
              return currentStock <= lowStockThreshold;
            });
          }
          return false;
        }).toList();
      } else {
        filteredProducts = List<Map<String, dynamic>>.from(products);
      }
    });
  }



  Future<void> updateVariantStock(int variantId, int stockChange, int currentStock) async {
    setState(() => _isUpdating[variantId] = true);

    try {
      final newTotalStock = currentStock + stockChange;

      if (newTotalStock < 0) {
        _showSnackBar("Stock cannot be negative", AppColors.errorColor);
        setState(() => _isUpdating[variantId] = false);
        return;
      }

      final res = await http.post(
        Uri.parse(ApiConstants.UPDATE_STOCK),
        body: {
          'variant_id': variantId.toString(),
          'stock': newTotalStock.toString(),
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success']) {
          _showSnackBar('Stock updated successfully. New total: $newTotalStock', AppColors.successColor);

          // Update the UI immediately without waiting for API refresh
          setState(() {
            // Find and update the variant in our local data
            for (var product in products) {
              if (product['variants'] != null && product['variants'].isNotEmpty) {
                for (var variant in product['variants']) {
                  if (int.tryParse(variant['id']?.toString() ?? '0') == variantId) {
                    variant['stock'] = newTotalStock.toString();
                    break;
                  }
                }
              }
            }
            applyFilters(); // Reapply filters to refresh the list
          });

          // Clear the input field after successful update
          _stockControllers[variantId]?.text = '0';
        } else {
          _showSnackBar('Failed to update stock: ${data['message']}', AppColors.errorColor);
        }
      } else {
        _showSnackBar('Failed to update stock: ${res.statusCode}', AppColors.errorColor);
      }
    } catch (e) {
      _showSnackBar('Error updating stock: $e', AppColors.errorColor);
    } finally {
      setState(() => _isUpdating[variantId] = false);
    }
  }

  Widget _buildPaginationControls() {
    final totalPages = (totalProducts / itemsPerPage).ceil();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: currentPage > 1
              ? () {
            setState(() => currentPage--);
            fetchProducts();
          }
              : null,
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
          onPressed: currentPage < totalPages
              ? () {
            setState(() => currentPage++);
            fetchProducts();
          }
              : null,
          color: currentPage < totalPages ? AppColors.primaryColor : Colors.grey,
        ),
      ],
    );
  }

  Widget _buildStockProgress(int currentStock, int maxStock) {
    int effectiveMaxStock =
    maxStock > 0 ? maxStock : (currentStock * 2).clamp(100, 1000);
    double progress = currentStock / effectiveMaxStock;

    Color progressColor;
    if (progress < 0.2) {
      progressColor = AppColors.errorColor;
    } else if (progress < 0.5) {
      progressColor = AppColors.warningColor;
    } else {
      progressColor = AppColors.successColor;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.inventory_2,
              size: 16,
              color: currentStock <= lowStockThreshold
                  ? AppColors.errorColor
                  : AppColors.successColor,
            ),
            const SizedBox(width: 4),
            Text(
              'Stock: $currentStock',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: currentStock <= lowStockThreshold
                    ? AppColors.errorColor
                    : AppColors.primaryTextColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: AppColors.backgroundColor,
          valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 4),
        Text(
          '${(progress * 100).toStringAsFixed(0)}% of $effectiveMaxStock',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: AppColors.secondaryTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildVariantItem(Map<String, dynamic> variant, String productName) {
    final variantId = int.tryParse(variant['id']?.toString() ?? '0') ?? 0;
    final variantName = variant['name']?.toString() ?? 'Unnamed Variant';
    final currentStock = int.tryParse(variant['stock']?.toString() ?? '0') ?? 0;

    // Initialize controller if not exists
    if (!_stockControllers.containsKey(variantId)) {
      _stockControllers[variantId] = TextEditingController(text: '0');
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: currentStock <= lowStockThreshold
              ? AppColors.errorColor.withOpacity(0.3)
              : AppColors.borderColor,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$productName - $variantName',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                _buildStockProgress(currentStock, 100),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Stock Update Section
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _stockControllers[variantId],
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Stock Change',
                    hintText: 'e.g., +5 or -3',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _isUpdating[variantId] == true
                  ? const CircularProgressIndicator()
                  : Row(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      final stockChange = int.tryParse(
                          _stockControllers[variantId]?.text ?? '') ?? 0;

                      if (stockChange != 0) {
                        updateVariantStock(variantId, stockChange, currentStock);
                      } else {
                        _showSnackBar("Please enter a valid number", AppColors.errorColor);
                      }
                    },
                    child: const Text("Update"),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      _stockControllers[variantId]?.text = '0';
                    },
                    tooltip: 'Reset',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductListItem(Map<String, dynamic> product) {
    final productId = product['id'];
    final productName = product['name'];
    final imageUrl = product['images'] != null && product['images'].isNotEmpty
        ? ApiConstants.BASE_IMAGE_URL + product['images'][0]
        : null;

    final hasVariants =
        product['variants'] != null && product['variants'].isNotEmpty;
    final isExpanded = _expandedProducts[productId] ?? false;

    // Check if any variant has low stock
    final hasLowStockVariant = hasVariants && product['variants'].any((variant) {
      final currentStock = int.tryParse(variant['stock']?.toString() ?? '0') ?? 0;
      return currentStock <= lowStockThreshold;
    });

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: hasLowStockVariant ? AppColors.errorColor.withOpacity(0.05) : null,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              _expandedProducts[productId] = expanded;
            });
          },
          leading: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: AppColors.backgroundColor,
              image: imageUrl != null
                  ? DecorationImage(
                image: NetworkImage(imageUrl),
                fit: BoxFit.cover,
              )
                  : null,
            ),
            child: imageUrl == null
                ? const Icon(Icons.image,
                color: AppColors.hintTextColor, size: 30)
                : null,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  productName,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasLowStockVariant) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.errorColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Low Stock',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ]
            ],
          ),
          subtitle: Text(
            '${hasVariants ? product['variants'].length : 0} variants',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.secondaryTextColor,
            ),
          ),
          children: hasVariants
              ? product['variants']
              .map<Widget>(
                  (variant) => _buildVariantItem(variant, productName))
              .toList()
              : const [
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No variants available'),
            )
          ],
        ),
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
                  width: 60,
                  height: 60,
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
              ],
            ),
          ),
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Stock Management",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppColors.primaryTextColor,
          ),
        ),
        actions: [
          // Low stock filter toggle
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                Text(
                  'Low Stock Only',
                  style: GoogleFonts.poppins(
                    color: AppColors.primaryTextColor,
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: showLowStockOnly,
                  onChanged: (value) {
                    setState(() {
                      showLowStockOnly = value;
                      applyFilters();
                    });
                  },
                  activeColor: AppColors.primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search and filter bar
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: AppColors.surfaceColor,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            onChanged: (value) {
                              setState(() {
                                searchQuery = value;
                              });
                            },
                            onSubmitted: (value) {
                              setState(() {
                                currentPage = 1;
                              });
                              fetchProducts();
                            },
                            style: GoogleFonts.poppins(),
                            decoration: InputDecoration(
                              labelText: 'Search Products',
                              labelStyle: GoogleFonts.poppins(
                                  color: AppColors.secondaryTextColor),
                              prefixIcon: const Icon(Icons.search,
                                  color: AppColors.hintTextColor),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                const BorderSide(color: AppColors.borderColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                const BorderSide(color: AppColors.borderColor),
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
                            icon: const Icon(Icons.search, color: Colors.white),
                            onPressed: () {
                              setState(() {
                                currentPage = 1;
                              });
                              fetchProducts();
                            },
                            tooltip: 'Search',
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
                                showLowStockOnly = false;
                              });
                              fetchProducts();
                            },
                            tooltip: 'Refresh',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Low stock threshold slider
                    Row(
                      children: [
                        Text(
                          'Low Stock Threshold: ',
                          style: GoogleFonts.poppins(
                            color: AppColors.primaryTextColor,
                          ),
                        ),
                        Text(
                          '$lowStockThreshold',
                          style: GoogleFonts.poppins(
                            color: AppColors.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: lowStockThreshold.toDouble(),
                            min: 1,
                            max: 50,
                            divisions: 49,
                            label: lowStockThreshold.toString(),
                            onChanged: (value) {
                              setState(() {
                                lowStockThreshold = value.toInt();
                                applyFilters();
                              });
                            },
                            activeColor: AppColors.primaryColor,
                            inactiveColor: AppColors.borderColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Results counter
            Row(
              children: [
                Text(
                  'Showing ${filteredProducts.length} of $totalProducts products',
                  style: GoogleFonts.poppins(
                    color: AppColors.secondaryTextColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Product List
            Expanded(
              child: isLoading && isInitialLoad
                  ? _buildShimmerLoader()
                  : filteredProducts.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inventory_2,
                      size: 64,
                      color: AppColors.hintTextColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      showLowStockOnly
                          ? 'No products with low stock found'
                          : 'No products found',
                      style: GoogleFonts.poppins(
                        color: AppColors.secondaryTextColor,
                        fontSize: 16,
                      ),
                    ),
                    if (isLoading) const CircularProgressIndicator(),
                  ],
                ),
              )
                  : Stack(
                children: [
                  ListView.builder(
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      return _buildProductListItem(product);
                    },
                  ),
                  if (isLoading)
                    Container(
                      color: Colors.black.withOpacity(0.1),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                ],
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
    );
  }
}