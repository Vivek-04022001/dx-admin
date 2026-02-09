import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;


import '../utils/api_constants.dart';
import '../utils/colors.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  String deliveryTime = 'Loading...';
  bool isLoading = false;
  String deliveryCharge = 'Loading...!';
  String callingNumber = 'Loading...!';
  String whatsapp_Number = 'Loading...!';
  String support_email = 'Loading...!';
  String handling_charge = 'Loading...!';
  String minium_amount = 'Loading...!';
  String freeDelivery = 'Loading...!';

  @override
  void initState() {
    super.initState();
    fetchDeliveryTime();
    fetchDeliveryCharge();
    fetchCallingNumber();
    fetchWhatsappNumber();
    fetchEmail();
    fetchHandlingCharge();
    fetchMinOrderAmount();
    fetchFreeDelivery();
  }

  // DELIVERY_TIME FETCH UPDATE
  Future<void> fetchDeliveryTime() async {
    try {
      final response = await http.get(Uri.parse(ApiConstants.FETCH_DELIVERY_TIME));
      final data = json.decode(response.body);

      if (data['success']) {
        setState(() {
          deliveryTime = data['data']['time'];
        });
      } else {
        setState(() {
          deliveryTime = 'Not found';
        });
      }
    } catch (e) {
      setState(() {
        deliveryTime = 'Error';
      });
    }
  }
  void showEditDialog() {
    final TextEditingController controller = TextEditingController(text: deliveryTime);
    showDialog(
      context: context,
      builder: (context) {
        return _buildEditDialog(
          title: 'Edit Delivery Time',
          controller: controller,
          onSave: () {
            String newTime = controller.text.trim();
            if (newTime.isNotEmpty) {
              updateDeliveryTime(newTime);
              Navigator.pop(context);
            }
          },
        );
      },
    );
  }
  Future<void> updateDeliveryTime(String newTime) async {
    setState(() => isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.UPDATE_DELIVERY_TIME),
        body: {
          'id': '1',
          'time': newTime,
        },
      );
      final data = json.decode(response.body);

      if (data['success']) {
        setState(() {
          deliveryTime = newTime;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'])),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating time')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }


  // DELIVERY_CHARGE FETCH UPDATE
  Future<void> fetchDeliveryCharge() async {
    try {
      final response = await http.get(Uri.parse(ApiConstants.FETCH_DELIVERY_AMOUNT));
      final data = json.decode(response.body);

      if (data['success']) {
        setState(() {
          deliveryCharge = data['data']['amount'];
        });
      } else {
        setState(() {
          deliveryCharge = 'Not found';
        });
      }
    } catch (e) {
      setState(() {
        deliveryCharge = 'Error';
      });
    }
  }
  void showEditDialogDeliveryCharge() {
    final TextEditingController controller = TextEditingController(text: deliveryCharge);

    showDialog(
      context: context,
      builder: (context) {
        return _buildEditDialog(
          title: 'Edit Delivery Amount',
          controller: controller,
          onSave: () {
            String newAmount = controller.text.trim();
            if (newAmount.isNotEmpty) {
              updateDeliveryCharge(newAmount);
              Navigator.pop(context);
            }
          },
        );
      },
    );
  }
  Future<void> updateDeliveryCharge(String newAmount) async {
    setState(() => isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.UPDATE_DELIVERY_AMOUNT),
        body: {
          'id': '1',
          'amount': newAmount,
        },
      );
      final data = json.decode(response.body);

      if (data['success']) {
        setState(() {
          deliveryCharge = newAmount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'])),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating time')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }


  // Minimum order value
  Future<void> fetchMinOrderAmount() async {
    try {
      final response = await http.get(Uri.parse(ApiConstants.GET_MINIMUM_ORDER_AMOUT));
      final data = json.decode(response.body);

      if (data['success']) {
        setState(() {
          minium_amount = data['data']['amount'];
        });
      } else {
        setState(() {
          minium_amount = 'Not found';
        });
      }
    } catch (e) {
      setState(() {
        minium_amount = 'Error';
      });
    }
  }
  void showEditDialogMinOrderAmount() {
    final TextEditingController controller = TextEditingController(text: minium_amount);

    showDialog(
      context: context,
      builder: (context) {
        return _buildEditDialog(
          title: 'Edit Min Order Amount',
          controller: controller,
          onSave: () {
            String minOrder = controller.text.trim();
            if (minOrder.isNotEmpty) {
              updateMinOrderAmount(minOrder);
              Navigator.pop(context);
            }
          },
        );
      },
    );
  }
  Future<void> updateMinOrderAmount(String minOrder) async {
    setState(() => isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.UPDATE_MINIMUM_ORDER_AMOUT),
        body: {
          'id': '1',
          'amount': minOrder,
        },
      );
      final data = json.decode(response.body);

      if (data['success']) {
        setState(() {
          minium_amount = minOrder;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'])),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating time')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }


  // Free Order  value
  Future<void> fetchFreeDelivery() async {
    try {
      final response = await http.get(Uri.parse(ApiConstants.GET_FREE_DELIVERY_AMOUNT));
      final data = json.decode(response.body);

      if (data['success']) {
        setState(() {
          freeDelivery = data['data']['amount'];
        });
      } else {
        setState(() {
          freeDelivery = 'Not found';
        });
      }
    } catch (e) {
      setState(() {
        freeDelivery = 'Error';
      });
    }
  }
  void showEditFreeDeliveryAmount() {
    final TextEditingController controller = TextEditingController(text: freeDelivery);

    showDialog(
      context: context,
      builder: (context) {
        return _buildEditDialog(
          title: 'Edit Free Delivery Amount',
          controller: controller,
          onSave: () {
            String freeDeliveryAmount = controller.text.trim();
            if (freeDeliveryAmount.isNotEmpty) {
              updateFreeDeliveryAmount(freeDeliveryAmount);
              Navigator.pop(context);
            }
          },
        );
      },
    );
  }
  Future<void> updateFreeDeliveryAmount(String freeDeliveryAmount) async {
    setState(() => isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.UPDATE_FREE_DELIVERY_AMOUNT),
        body: {
          'id': '1',
          'amount': freeDeliveryAmount,
        },
      );
      final data = json.decode(response.body);

      if (data['success']) {
        setState(() {
          freeDelivery = freeDeliveryAmount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'])),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating time')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }


  // FETCH CALLING NUMBER
  Future<void> fetchCallingNumber() async {
    try {
      final response = await http.get(Uri.parse(ApiConstants.GET_CALLING_NUMBER));
      final data = json.decode(response.body);

      if (data['success']) {
        setState(() {
          callingNumber = data['data']['call_help'];
        });
      } else {
        setState(() {
          callingNumber = 'Not found';
        });
      }
    } catch (e) {
      setState(() {
        callingNumber = 'Error';
      });
    }
  }
  void showEditDialogCallingNumber() {
    final TextEditingController controller = TextEditingController(text: callingNumber);

    showDialog(
      context: context,
      builder: (context) {
        return _buildEditDialog(
          title: 'Edit Calling Number',
          controller: controller,
          onSave: () {
            String newNumber = controller.text.trim();
            if (newNumber.isNotEmpty) {
              updateCallingNumber(newNumber);
              Navigator.pop(context);
            }
          },
        );
      },
    );
  }
  Future<void> updateCallingNumber(String newNumber) async {
    setState(() => isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.UPDATE_CALLING_NUMBER),
        body: {
          'id': '1',
          'call': newNumber.toString(),
        },
      );
      final data = json.decode(response.body);

      if (data['success']) {
        setState(() {
          callingNumber = newNumber;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'])),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating calling number')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }



  // FETCH WHATSAPP NUMBER
  Future<void> fetchWhatsappNumber() async {
    try {
      final response = await http.get(Uri.parse(ApiConstants.GET_WHATSAPP_NUMBER));
      final data = json.decode(response.body);

      if (data['success']) {
        setState(() {
          whatsapp_Number = data['data']['whatsapp_no'];
        });
      } else {
        setState(() {
          whatsapp_Number = 'Not found';
        });
      }
    } catch (e) {
      setState(() {
        whatsapp_Number = 'Error';
      });
    }
  }
  void showEditDialogWhatsappNumber() {
    final TextEditingController controller = TextEditingController(text: whatsapp_Number);

    showDialog(
      context: context,
      builder: (context) {
        return _buildEditDialog(
          title: 'Edit Whatsapp Number',
          controller: controller,
          onSave: () {
            String whatsappNumber = controller.text.trim();
            if (whatsappNumber.isNotEmpty) {
              updateWhatsappNumber(whatsappNumber);
              Navigator.pop(context);
            }
          },
        );
      },
    );
  }
  Future<void> updateWhatsappNumber(String whatsappNumber) async {
    setState(() => isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.UPDATE_WHATSAPP_NUMBER),
        body: {
          'id': '1',
          'number': whatsappNumber.toString(),
        },
      );
      final data = json.decode(response.body);

      if (data['success']) {
        setState(() {
          whatsapp_Number = whatsappNumber;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'])),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating whatsapp number')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  // FETCH EMAIL ID
  Future<void> fetchEmail() async {
    try {
      final response = await http.get(Uri.parse(ApiConstants.GET_EMAIL));
      final data = json.decode(response.body);

      if (data['success']) {
        setState(() {
          support_email = data['data']['email'];
        });
      } else {
        setState(() {
          support_email = 'Not found';
        });
      }
    } catch (e) {
      setState(() {
        support_email = 'Error';
      });
    }
  }
  void showEditDialogEmail() {
    final TextEditingController controller = TextEditingController(text: support_email);

    showDialog(
      context: context,
      builder: (context) {
        return _buildEditDialog(
          title: 'Edit Email',
          controller: controller,
          onSave: () {
            String email_id = controller.text.trim();
            if (email_id.isNotEmpty) {
              updateEmail(email_id);
              Navigator.pop(context);
            }
          },
        );
      },
    );
  }
  Future<void> updateEmail(String newEmail) async {
    setState(() => isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.UPDATE_EMAIL),
        body: {
          'id': '1',
          'email': newEmail.toString(),
        },
      );
      final data = json.decode(response.body);

      if (data['success']) {
        setState(() {
          support_email = newEmail;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'])),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating email')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }


  // FETCH EMAIL ID
  Future<void> fetchHandlingCharge() async {
    try {
      final response = await http.get(Uri.parse(ApiConstants.GET_HANDLING_CHARGE));
      final data = json.decode(response.body);

      if (data['success']) {
        setState(() {
          handling_charge = data['data']['amount'];
        });
      } else {
        setState(() {
          handling_charge = 'Not found';
        });
      }
    } catch (e) {
      setState(() {
        handling_charge = 'Error';
      });
    }
  }
  void showEditHandlingCharge() {
    final TextEditingController controller = TextEditingController(text: handling_charge);

    showDialog(
      context: context,
      builder: (context) {
        return _buildEditDialog(
          title: 'Edit Email',
          controller: controller,
          onSave: () {
            String handlingCharge = controller.text.trim();
            if (handlingCharge.isNotEmpty) {
              updateHandlingCharge(handlingCharge);
              Navigator.pop(context);
            }
          },
        );
      },
    );
  }
  Future<void> updateHandlingCharge(String newHandling) async {
    setState(() => isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.UPDATE_HANDLING_CHARGE),
        body: {
          'id': '1',
          'amount': newHandling.toString(),
        },
      );
      final data = json.decode(response.body);

      if (data['success']) {
        setState(() {
          handling_charge = newHandling;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'])),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating email')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }




  // Helper method to build edit dialogs
  Widget _buildEditDialog({
    required String title,
    required TextEditingController controller,
    required VoidCallback onSave,
  }) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        title,
        style: TextStyle(
          color: AppColors.primaryTextColor,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.backgroundColor,
          hintText: 'Enter new value',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: AppColors.secondaryTextColor),
          ),
        ),
        ElevatedButton(
          onPressed: onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            'Save',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  // Helper method to build setting items
  Widget _buildSettingItem({
    required String title,
    required String value,
    required VoidCallback onEdit,
    required IconData icon,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primaryColor),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.secondaryTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          value,
          style: TextStyle(
            fontSize: 16,
            color: AppColors.primaryTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: IconButton(
          icon: Icon(Icons.edit, color: AppColors.secondaryColor),
          onPressed: onEdit,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            color: AppColors.primaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.surfaceColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.primaryTextColor),
      ),
      backgroundColor: AppColors.backgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Application Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryTextColor,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Manage your application configuration',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.secondaryTextColor,
              ),
            ),
            SizedBox(height: 24),
            Expanded(
              child: isLoading
                  ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                ),
              )
                  : ListView(
                children: [
                  _buildSettingItem(
                    title: 'Delivery Time',
                    value: deliveryTime,
                    onEdit: showEditDialog,
                    icon: Icons.access_time,
                  ),
                  _buildSettingItem(
                    title: 'Delivery Charge',
                    value: "₹"+deliveryCharge,
                    onEdit: showEditDialogDeliveryCharge,
                    icon: Icons.local_shipping,
                  ),

                  _buildSettingItem(
                    title: 'Minimum order value',
                    value: "₹" + minium_amount,
                    onEdit: showEditDialogMinOrderAmount,
                    icon: Icons.shopping_cart, // पहला icon
                  ),

                  _buildSettingItem(
                    title: 'Free Delivery Amount value',
                    value: "₹" + freeDelivery,
                    onEdit: showEditFreeDeliveryAmount,
                    icon: Icons.local_shipping_outlined, // दूसरा icon
                  ),



                  _buildSettingItem(
                    title: 'Handling Charge',
                    value: "₹"+handling_charge,
                    onEdit: showEditHandlingCharge,
                    icon: Icons.shopping_bag,
                  ),


                  _buildSettingItem(
                    title: 'Calling Number',
                    value: callingNumber,
                    onEdit: showEditDialogCallingNumber,
                    icon: Icons.phone,
                  ),
                  _buildSettingItem(
                    title: 'WhatsApp Number',
                    value: whatsapp_Number,
                    onEdit: showEditDialogWhatsappNumber,
                    icon: Icons.chat,
                  ),
                  _buildSettingItem(
                    title: 'Support Email',
                    value: support_email,
                    onEdit: showEditDialogEmail,
                    icon: Icons.email,
                  ),


                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

