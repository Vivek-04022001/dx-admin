import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../HomeScreen/home_screen.dart';
import '../utils/api_constants.dart';
import '../utils/colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _errorMessage = '';

  final String _loginUrl = ApiConstants.LOGIN;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _checkLogin();
  }

  _checkLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    if (token != null && token.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    }
  }

  _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _rememberMe = prefs.getBool('rememberMe') ?? false;
        if (_rememberMe) {
          _emailController.text = prefs.getString('savedEmail') ?? '';
          _passwordController.text = prefs.getString('savedPassword') ?? '';
        }
      });
    } catch (e) {
      print("Error loading saved credentials: $e");
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse(_loginUrl),
        body: {
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'success') {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_email', data['user']['email']);

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomeScreen()),
          );
        } else {
          setState(() => _errorMessage = data['message'] ?? "Login failed");
        }
      } else {
        setState(() => _errorMessage = "Server error: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _errorMessage = "Something went wrong: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(left: 40.w, right: 40.w),
          child: Center(
            child: Container(
              width: 600.w,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 80.h),
                  // App Logo/Title
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 80.sp,
                          color: AppColors.primaryColor,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'Welcome Back',
                          style: GoogleFonts.jost(
                            fontSize: 28.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryTextColor,
                          ),
                        ),
                        Text(
                          'Sign in to continue',
                          style: GoogleFonts.jost(
                            fontSize: 16.sp,
                            color: AppColors.secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 40.h),

                  // Login Form
                  Container(
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceColor,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 16.r,
                          offset: Offset(0, 8.h),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Email field
                          TextFormField(
                            controller: _emailController,
                            style: GoogleFonts.jost(
                              color: AppColors.primaryTextColor,
                              fontSize: 14.sp,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Email Address',
                              labelStyle: GoogleFonts.jost(
                                color: AppColors.hintTextColor,
                                fontSize: 14.sp,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: BorderSide(
                                  color: AppColors.borderColor,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: BorderSide(
                                  color: AppColors.borderColor,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: BorderSide(
                                  color: AppColors.primaryColor,
                                  width: 2.w,
                                ),
                              ),
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                color: AppColors.hintTextColor,
                                size: 20.sp,
                              ),
                              filled: true,
                              fillColor: AppColors.backgroundColor,
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                  .hasMatch(value)) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),

                          SizedBox(height: 20.h),

                          // Password field
                          TextFormField(
                            controller: _passwordController,
                            style: GoogleFonts.jost(
                              color: AppColors.primaryTextColor,
                              fontSize: 14.sp,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: GoogleFonts.jost(
                                color: AppColors.hintTextColor,
                                fontSize: 14.sp,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: BorderSide(
                                  color: AppColors.borderColor,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: BorderSide(
                                  color: AppColors.borderColor,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: BorderSide(
                                  color: AppColors.primaryColor,
                                  width: 2.w,
                                ),
                              ),
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: AppColors.hintTextColor,
                                size: 20.sp,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: AppColors.hintTextColor,
                                  size: 20.sp,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: AppColors.backgroundColor,
                            ),
                            obscureText: _obscurePassword,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),

                          SizedBox(height: 16.h),

                          // Remember me
                          Row(
                            children: [
                              Theme(
                                data: ThemeData(
                                  unselectedWidgetColor: AppColors.hintTextColor,
                                ),
                                child: Checkbox(
                                  value: _rememberMe,
                                  onChanged: (value) {
                                    setState(() {
                                      _rememberMe = value!;
                                    });
                                  },
                                  activeColor: AppColors.primaryColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4.r),
                                  ),
                                ),
                              ),
                              Text(
                                'Remember Me',
                                style: GoogleFonts.jost(
                                  color: AppColors.secondaryTextColor,
                                  fontSize: 14.sp,
                                ),
                              ),
                              const Spacer(),
                            ],
                          ),

                          SizedBox(height: 16.h),

                          // Error message
                          if (_errorMessage.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(12.w),
                              decoration: BoxDecoration(
                                color: AppColors.errorColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: AppColors.errorColor,
                                    size: 20.sp,
                                  ),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: Text(
                                      _errorMessage,
                                      style: GoogleFonts.jost(
                                        color: AppColors.errorColor,
                                        fontSize: 14.sp,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          SizedBox(height: 20.h),

                          // Login button
                          SizedBox(
                            width: double.infinity,
                            height: 54.h,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                elevation: 0,
                                padding: EdgeInsets.symmetric(vertical: 16.h),
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                width: 24.w,
                                height: 24.w,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.w,
                                ),
                              )
                                  : Text(
                                'LOGIN',
                                style: GoogleFonts.jost(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 40.h),

                  // Footer text
                  Center(
                    child: Text(
                      '© 2025 Dx Mart. All rights reserved.',
                      style: GoogleFonts.jost(
                        color: AppColors.secondaryTextColor,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
