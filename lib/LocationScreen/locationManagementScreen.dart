import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../utils/api_constants.dart';
import '../utils/colors.dart';



// --- District Model ---
class District {
  final String id;
  final String name;

  District({required this.id, required this.name});

  factory District.fromJson(Map<String, dynamic> json) {
    return District(
      id: json['id'].toString(),
      name: json['district_name'] ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is District && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}



// --- City Model ---
class City {
  final String id;
  final String name;
  final String districtId;

  City({
    required this.id,
    required this.name,
    required this.districtId,
  });

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: json['id']?.toString() ?? '',
      name: json['city_name'] ?? '',
      districtId: json['district_id']?.toString() ?? '',
    );
  }
}



class LocationManagementScreen extends StatefulWidget {
  const LocationManagementScreen({super.key});

  @override
  State<LocationManagementScreen> createState() => _LocationManagementScreenState();
}

class _LocationManagementScreenState extends State<LocationManagementScreen> {
  // State variables for District Management
  final _addDistrictFormKey = GlobalKey<FormState>();
  final TextEditingController _addDistrictNameController = TextEditingController();
  List<District> districts = [];
  bool isLoadingDistricts = true;
  bool isAddingDistrict = false;
  String? districtsErrorMessage;

  // State variables for City Management
  final _addCityFormKey = GlobalKey<FormState>();
  final TextEditingController _addCityNameController = TextEditingController();
  List<City> cities = [];
  bool isLoadingCities = true;
  bool isAddingCity = false;
  String? citiesErrorMessage;
  District? _selectedDistrictForCity; // For dropdown to select district for city

  @override
  void initState() {
    super.initState();
    _fetchDistricts(); // Fetch districts when the screen initializes
  }

  @override
  void dispose() {
    _addDistrictNameController.dispose();
    _addCityNameController.dispose();
    super.dispose();
  }

  // --- District Management Functions ---

  /// Fetches all districts from the backend API.
  Future<void> _fetchDistricts() async {
    setState(() {
      isLoadingDistricts = true;
      districtsErrorMessage = null;
    });

    try {
      final response = await http.get(Uri.parse(ApiConstants.VIEW_DISTRICT));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['districts'] != null) {
          setState(() {
            districts = (data['districts'] as List)
                .map((json) => District.fromJson(json))
                .toList();
            // After fetching districts, if there are any,
            // set the first district as selected and fetch its cities.
            if (districts.isNotEmpty && _selectedDistrictForCity == null) {
              _selectedDistrictForCity = districts.first;
              _fetchCitiesByDistrict(_selectedDistrictForCity!.id);
            } else if (districts.isEmpty) {
              cities = []; // No districts, so no cities to display
            }
          });
        } else {
          setState(() {
            districtsErrorMessage = data['message'] ?? 'Failed to load districts.';
          });
        }
      } else {
        setState(() {
          districtsErrorMessage = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        districtsErrorMessage = 'Network error: $e';
      });
      print('Error fetching districts: $e'); // Log the error for debugging
    } finally {
      setState(() {
        isLoadingDistricts = false;
      });
    }
  }

  /// Adds a new district to the backend.
  Future<void> _addDistrict() async {
    if (_addDistrictFormKey.currentState!.validate()) {
      setState(() {
        isAddingDistrict = true;
      });

      _showLoadingDialog(); // Show loading indicator

      try {
        final response = await http.post(
          Uri.parse(ApiConstants.ADD_DISTRICT),
          body: {
            "district_name": _addDistrictNameController.text.trim(),
          },
        );

        Navigator.of(context).pop(); // Close loading dialog
        setState(() {
          isAddingDistrict = false;
        });

        final Map<String, dynamic> data = json.decode(response.body);

        if (response.statusCode == 200 && data["success"] == true) {
          _showMessage("District added successfully", AppColors.successColor);
          _addDistrictNameController.clear(); // Clear input field
          _fetchDistricts(); // Refresh the district list
        } else {
          _showMessage(data['message'] ?? "Failed to add district", AppColors.errorColor);
        }
      } catch (e) {
        Navigator.of(context).pop(); // Close loading dialog
        setState(() {
          isAddingDistrict = false;
        });
        _showMessage("Something went wrong: $e", AppColors.errorColor);
        print('Error adding district: $e');
      }
    }
  }

  /// Updates an existing district in the backend.
  Future<void> _updateDistrict(String districtId, String newName) async {
    _showLoadingDialog(); // Show loading indicator

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.UPDATE_DISTRICT),
        body: {
          "district_id": districtId,
          "district_name": newName.trim(),
        },
      );

      Navigator.of(context).pop(); // Close loading dialog

      final Map<String, dynamic> data = json.decode(response.body);

      if (response.statusCode == 200 && data["success"] == true) {
        _showMessage("District updated successfully", AppColors.successColor);
        _fetchDistricts(); // Refresh the district list
      } else {
        _showMessage(data['message'] ?? "Failed to update district", AppColors.errorColor);
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      _showMessage("Something went wrong: $e", AppColors.errorColor);
      print('Error updating district: $e');
    }
  }

  /// Deletes a district from the backend after confirmation.
  /// Deletes a district from the backend after confirmation.
  Future<void> _deleteDistrict(String districtId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
          title: Text("Confirm Deletion", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Text("Are you sure you want to delete this district? This will also delete all cities under it.", style: GoogleFonts.poppins()),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text("Cancel", style: GoogleFonts.poppins(color: AppColors.primaryColor)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
              ),
              child: Text("Delete", style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (!confirm) return; // If user cancels, do nothing

    _showLoadingDialog(); // Show loading indicator

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.DELETE_DISTRICT),
        body: {"district_id": districtId},
      );

      Navigator.of(context).pop(); // Close loading dialog

      final Map<String, dynamic> data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        _showMessage("District deleted successfully", AppColors.successColor);

        // Update local state immediately
        setState(() {
          districts.removeWhere((district) => district.id == districtId);
          // If deleted district was the selected one, clear selection
          if (_selectedDistrictForCity?.id == districtId) {
            _selectedDistrictForCity = districts.isNotEmpty ? districts.first : null;
            cities = [];
          }
        });

        // Also refresh from server
        _fetchDistricts();
      } else {
        _showMessage(data['message'] ?? "Failed to delete district", AppColors.errorColor);
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      _showMessage("Network error: $e", AppColors.errorColor);
      print('Error deleting district: $e');
    }
  }

  // --- City Management Functions ---

  /// Fetches cities associated with a specific district from the backend.
  /// Fetches cities associated with a specific district from the backend.
  Future<void> _fetchCitiesByDistrict(String districtId) async {
    // If no district is selected, clear cities
    if (districtId.isEmpty) {
      setState(() {
        cities = [];
        isLoadingCities = false;
      });
      return;
    }

    setState(() {
      isLoadingCities = true;
      citiesErrorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.VIEW_CITY),
        body: {"district_id": districtId},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['cities'] != null) {
          setState(() {
            cities = (data['cities'] as List)
                .map((json) => City.fromJson(json))
                .toList();
          });
        } else {
          setState(() {
            citiesErrorMessage = data['message'] ?? 'Failed to load cities.';
            cities = []; // Clear cities on error
          });
        }
      } else {
        setState(() {
          citiesErrorMessage = 'Server error: ${response.statusCode}';
          cities = []; // Clear cities on error
        });
      }
    } catch (e) {
      setState(() {
        citiesErrorMessage = 'Network error: $e';
        cities = []; // Clear cities on error
      });
      print('Error fetching cities: $e');
    } finally {
      setState(() {
        isLoadingCities = false;
      });
    }
  }

  /// Adds a new city to the backend, associated with the selected district.
  Future<void> _addCity() async {
    if (_addCityFormKey.currentState!.validate() && _selectedDistrictForCity != null) {
      setState(() {
        isAddingCity = true;
      });

      _showLoadingDialog(); // Show loading indicator

      try {
        final response = await http.post(
          Uri.parse(ApiConstants.ADD_CITY),
          body: {
            "district_id": _selectedDistrictForCity!.id,
            "city_name": _addCityNameController.text.trim(),
          },
        );

        Navigator.of(context).pop(); // Close loading dialog
        setState(() {
          isAddingCity = false;
        });

        final Map<String, dynamic> data = json.decode(response.body);

        if (response.statusCode == 200 && data["success"] == true) {
          _showMessage("City added successfully", AppColors.successColor);
          _addCityNameController.clear(); // Clear input field
          _fetchCitiesByDistrict(_selectedDistrictForCity!.id); // Refresh cities for selected district
        } else {
          _showMessage(data['message'] ?? "Failed to add city", AppColors.errorColor);
        }
      } catch (e) {
        Navigator.of(context).pop(); // Close loading dialog
        setState(() {
          isAddingCity = false;
        });
        _showMessage("Something went wrong: $e", AppColors.errorColor);
        print('Error adding city: $e');
      }
    } else if (_selectedDistrictForCity == null) {
      _showMessage("Please select a district first.", AppColors.errorColor);
    }
  }

  /// Updates an existing city in the backend.
  Future<void> _updateCity(String cityId, String newName) async {
    _showLoadingDialog(); // Show loading indicator

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.UPDATE_CITY),
        body: {
          "city_id": cityId,
          "city_name": newName.trim(),
        },
      );

      Navigator.of(context).pop(); // Close loading dialog

      final Map<String, dynamic> data = json.decode(response.body);

      if (response.statusCode == 200 && data["success"] == true) {
        _showMessage("City updated successfully", AppColors.successColor);
        if (_selectedDistrictForCity != null) {
          _fetchCitiesByDistrict(_selectedDistrictForCity!.id); // Refresh cities
        }
      } else {
        _showMessage(data['message'] ?? "Failed to update city", AppColors.errorColor);
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      _showMessage("Something went wrong: $e", AppColors.errorColor);
      print('Error updating city: $e');
    }
  }

  /// Deletes a city from the backend after confirmation.
  Future<void> _deleteCity(String cityId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
          title: Text("Confirm Deletion", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Text("Are you sure you want to delete this city?", style: GoogleFonts.poppins()),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text("Cancel", style: GoogleFonts.poppins(color: AppColors.primaryColor)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
              ),
              child: Text("Delete", style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (!confirm) return; // If user cancels, do nothing

    _showLoadingDialog(); // Show loading indicator

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.DELETE_CITY),
        body: {"city_id": cityId},
      );

      Navigator.of(context).pop(); // Close loading dialog

      final Map<String, dynamic> data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        _showMessage("City deleted successfully", AppColors.successColor);
        if (_selectedDistrictForCity != null) {
          _fetchCitiesByDistrict(_selectedDistrictForCity!.id); // Refresh cities
        }
      } else {
        _showMessage(data['message'] ?? "Failed to delete city", AppColors.errorColor);
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      _showMessage("Network error: $e", AppColors.errorColor);
      print('Error deleting city: $e');
    }
  }

  // --- Utility Functions for UI Feedback ---

  /// Shows a SnackBar message to the user.
  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Shows a circular progress indicator dialog.
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: AppColors.primaryColor),
      ),
    );
  }

  // --- Build Method ---

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Two tabs: Districts and Cities
      child: Scaffold(
        backgroundColor: AppColors.surfaceColor,
        appBar: AppBar(
          title: Text(
            'Location Management',
            style: GoogleFonts.poppins(
              color: AppColors.primaryColor,
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          bottom: TabBar(
            indicatorColor: AppColors.primaryColor,
            labelColor: AppColors.primaryColor,
            unselectedLabelColor: AppColors.hintTextColor,
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16.sp),
            unselectedLabelStyle: GoogleFonts.poppins(fontSize: 15.sp),
            tabs: const [
              Tab(text: 'City'),
              Tab(text: 'Area'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // --- Districts Tab Content ---
            _buildDistrictManagementTab(),
            // --- Cities Tab Content ---
            _buildCityManagementTab(),
          ],
        ),
      ),
    );
  }

  // --- Widget Builders for Tabs ---

  /// Builds the UI for the District Management tab.
  Widget _buildDistrictManagementTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 10.h),
          // Add District Section
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.surfaceColor,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: const Offset(0, 0),
                )
              ],
            ),
            child: Form(
              key: _addDistrictFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add New City',
                    style: GoogleFonts.poppins(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryColor,
                    ),
                  ),
                  SizedBox(height: 15.h),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.backgroundColor,
                      borderRadius: BorderRadius.circular(12.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 8,
                          offset: const Offset(0, 0),
                        )
                      ],
                    ),
                    child: TextFormField(
                      controller: _addDistrictNameController,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Enter City Name',
                        hintStyle: GoogleFonts.poppins(color: AppColors.hintTextColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: Icon(Icons.location_city, color: AppColors.primaryColor, size: 24.sp),
                        contentPadding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 10.w),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Please enter city name";
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Center(
                    child: SizedBox(
                      width: 150.w,
                      height: 45.h,
                      child: ElevatedButton(
                        onPressed: isAddingDistrict ? null : _addDistrict,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          elevation: 5,
                        ),
                        child: isAddingDistrict
                            ? SizedBox(
                          width: 20.w,
                          height: 20.h,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.w),
                        )
                            : Text(
                          'Add City',
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 30.h),
          // View Districts Section
          Text(
            'All City',
            style: GoogleFonts.poppins(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryColor,
            ),
          ),
          SizedBox(height: 15.h),
          isLoadingDistricts
              ? Center(child: CircularProgressIndicator(color: AppColors.primaryColor))
              : districtsErrorMessage != null
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: AppColors.errorColor, size: 50.sp),
                SizedBox(height: 10.h),
                Text(
                  districtsErrorMessage!,
                  style: GoogleFonts.poppins(color: AppColors.errorColor, fontSize: 16.sp),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20.h),
                ElevatedButton.icon(
                  onPressed: _fetchDistricts,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                  ),
                  icon: Icon(Icons.refresh, color: Colors.white),
                  label: Text('Retry', style: GoogleFonts.poppins(color: Colors.white, fontSize: 16.sp)),
                ),
              ],
            ),
          )
              : districts.isEmpty
              ? Center(
            child: Text(
              'No City added yet.',
              style: GoogleFonts.poppins(fontSize: 16.sp, color: AppColors.hintTextColor),
              textAlign: TextAlign.center,
            ),
          )
              : ListView.builder(
            shrinkWrap: true, // Important for nested ListView in SingleChildScrollView
            physics: const NeverScrollableScrollPhysics(), // Disable scrolling for inner list
            itemCount: districts.length,
            itemBuilder: (context, index) {
              final district = districts[index];
              return Padding(
                padding:  EdgeInsets.only(bottom: 8.h),
                child: Container(
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
                  child: Padding(
                    padding:  EdgeInsets.symmetric(vertical: 10.h, horizontal: 20.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            district.name,
                            style: GoogleFonts.poppins(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryColor,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blueAccent, size: 24.sp),
                              onPressed: () {
                                _showEditDistrictDialog(district);
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: AppColors.errorColor, size: 24.sp),
                              onPressed: () => _deleteDistrict(district.id),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Builds the UI for the City Management tab.
  Widget _buildCityManagementTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 10.h),
          // Add City Section
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.surfaceColor,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: const Offset(0, 0),
                )
              ],
            ),
            child: Form(
              key: _addCityFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add New Area',
                    style: GoogleFonts.poppins(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryColor,
                    ),
                  ),
                  SizedBox(height: 15.h),
                  // District Dropdown
                  Container(
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
                    child: DropdownButtonFormField<District>(
                      value: _selectedDistrictForCity,
                      decoration: InputDecoration(

                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Select City',
                        hintStyle: GoogleFonts.poppins(color: AppColors.hintTextColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: Icon(Icons.map, color: AppColors.primaryColor, size: 24.sp),
                        contentPadding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 10.w),
                      ),
                      items: districts.map((district) {
                        return DropdownMenuItem(
                          value: district,
                          child: Text(district.name, style: GoogleFonts.poppins()),
                        );
                      }).toList(),
                      onChanged: (District? newValue) {
                        setState(() {
                          _selectedDistrictForCity = newValue;
                          if (newValue != null) {
                            _fetchCitiesByDistrict(newValue.id); // Fetch cities for selected district
                          } else {
                            cities = []; // Clear cities if no district selected
                          }
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return "Please select a city";
                        }
                        return null;
                      },
                      // Disable dropdown if no districts are loaded
                      isExpanded: true,
                      menuMaxHeight: 200.h,
                    ),
                  ),
                  SizedBox(height: 15.h),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.backgroundColor,
                      borderRadius: BorderRadius.circular(12.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 8,
                          offset: const Offset(0, 0),
                        )
                      ],
                    ),
                    child: TextFormField(
                      controller: _addCityNameController,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Enter Area Name',
                        hintStyle: GoogleFonts.poppins(color: AppColors.hintTextColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: Icon(Icons.location_on, color: AppColors.primaryColor, size: 24.sp),
                        contentPadding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 10.w),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Please enter area name";
                        }
                        return null;
                      },
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Center(
                    child: SizedBox(
                      width: 150.w,
                      height: 45.h,
                      child: ElevatedButton(
                        onPressed: isAddingCity || _selectedDistrictForCity == null ? null : _addCity,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          elevation: 5,
                        ),
                        child: isAddingCity
                            ? SizedBox(
                          width: 20.w,
                          height: 20.h,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.w),
                        )
                            : Text(
                          'Add Area',
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 30.h),
          // View Cities Section
          Text(
            'Area in ${_selectedDistrictForCity?.name ?? "Selected District"}',
            style: GoogleFonts.poppins(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryColor,
            ),
          ),
          SizedBox(height: 15.h),
          isLoadingCities
              ? Center(child: CircularProgressIndicator(color: AppColors.primaryColor))
              : citiesErrorMessage != null
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: AppColors.errorColor, size: 50.sp),
                SizedBox(height: 10.h),
                Text(
                  citiesErrorMessage!,
                  style: GoogleFonts.poppins(color: AppColors.errorColor, fontSize: 16.sp),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20.h),
                ElevatedButton.icon(
                  onPressed: _selectedDistrictForCity != null
                      ? () => _fetchCitiesByDistrict(_selectedDistrictForCity!.id)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                  ),
                  icon: Icon(Icons.refresh, color: Colors.white),
                  label: Text('Retry', style: GoogleFonts.poppins(color: Colors.white, fontSize: 16.sp)),
                ),
              ],
            ),
          )
              : cities.isEmpty
              ? Center(
            child: Text(
              _selectedDistrictForCity == null
                  ? 'Please select a City to view area.'
                  : 'No area added yet for this city.',
              style: GoogleFonts.poppins(fontSize: 16.sp, color: AppColors.hintTextColor),
              textAlign: TextAlign.center,
            ),
          )
              : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cities.length,
            itemBuilder: (context, index) {
              final city = cities[index];
              return Padding(
                padding:  EdgeInsets.only(bottom: 8.h),
                child: Container(
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
                  child: Padding(
                    padding:  EdgeInsets.symmetric(vertical: 10.h, horizontal: 20.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            city.name,
                            style: GoogleFonts.poppins(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryColor,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blueAccent, size: 24.sp),
                              onPressed: () {
                                _showEditCityDialog(city);
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: AppColors.errorColor, size: 24.sp),
                              onPressed: () => _deleteCity(city.id),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Dialog for Editing District ---
  void _showEditDistrictDialog(District district) {
    final TextEditingController editController = TextEditingController(text: district.name);
    final _editFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
          title: Text("Edit City", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Form(
            key: _editFormKey,
            child: TextFormField(
              controller: editController,
              decoration: InputDecoration(
                hintText: "Enter new city name",
                hintStyle: GoogleFonts.poppins(color: AppColors.hintTextColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return "City name cannot be empty";
                }
                return null;
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Cancel", style: GoogleFonts.poppins(color: AppColors.primaryColor)),
            ),
            ElevatedButton(
              onPressed: () {
                if (_editFormKey.currentState!.validate()) {
                  Navigator.of(context).pop(); // Close dialog
                  _updateDistrict(district.id, editController.text);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
              ),
              child: Text("Update", style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // --- Dialog for Editing City ---
  void _showEditCityDialog(City city) {
    final TextEditingController editController = TextEditingController(text: city.name);
    final _editFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
          title: Text("Edit Area", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Form(
            key: _editFormKey,
            child: TextFormField(
              controller: editController,
              decoration: InputDecoration(
                hintText: "Enter new area name",
                hintStyle: GoogleFonts.poppins(color: AppColors.hintTextColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return "Area name cannot be empty";
                }
                return null;
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Cancel", style: GoogleFonts.poppins(color: AppColors.primaryColor)),
            ),
            ElevatedButton(
              onPressed: () {
                if (_editFormKey.currentState!.validate()) {
                  Navigator.of(context).pop(); // Close dialog
                  _updateCity(city.id, editController.text);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
              ),
              child: Text("Update", style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
