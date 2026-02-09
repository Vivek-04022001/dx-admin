class ApiConstants {
  static const String BASE_URL = "https://kritikamart.shop/Backend/api_folder/";
  static const String BASE_IMAGE_URL =
      "https://kritikamart.shop/Backend/api_folder/product_api_project/";

  // Auth
  static const String LOGIN = "$BASE_URL/admin_login.php";

  // Main Category
  static const String MAIN_ADD_CATEGORY = "$BASE_URL/main_category/add.php";
  static const String MAIN_VIEW_CATEGORY = "$BASE_URL/main_category/view.php";
  static const String MAIN_EDIT_CATEGORY = "$BASE_URL/main_category/edit.php";
  static const String MAIN_DELETE_CATEGORY =
      "$BASE_URL/main_category/delete.php";

  // District
  static const String ADD_DISTRICT =
      "$BASE_URL/location/district/add_district.php";
  static const String VIEW_DISTRICT =
      "$BASE_URL/location/district/view_district.php";
  static const String DELETE_DISTRICT =
      "$BASE_URL/location/district/delete_district.php";
  static const String UPDATE_DISTRICT =
      "$BASE_URL/location/district/update_district.php";

  // City
  static const String ADD_CITY = "$BASE_URL/location/city/add_city.php";
  static const String VIEW_CITY = "$BASE_URL/location/city/view_city.php";
  static const String DELETE_CITY = "$BASE_URL/location/city/delete_city.php";
  static const String UPDATE_CITY = "$BASE_URL/location/city/update_city.php";

  // User
  static const String GET_ALL_USER = "$BASE_URL/auth/get_all_user.php";
  static const String USER_STATUS_UPDATE = "$BASE_URL/auth/user_status.php";
  static const String GET_ALL_DELIVERY_BOYS =
      "$BASE_URL/delivery_boy/get_all_user.php";
  static const String ADD_DELIVERY_BOYS = "$BASE_URL/delivery_boy/signup.php";

  // Product
  static const String SUB_CATEGORY =
      "$BASE_URL/sub_category_api/view_sub_category.php";
  static const String SAVE_PRODUCT =
      "$BASE_URL/product_api_project/product/insert_product.php";
  static const String SAVE_VARIANT =
      "$BASE_URL/product_api_project/variant/save_variant.php";
  static const String SAVE_IMAGE =
      "$BASE_URL/product_api_project/product/upload_product_image.php";
  static const String SAVE_PRODUCT_INFO =
      "$BASE_URL/product_api_project/info/save_info.php";
  static const String SAVE_PRODUCT_HIGHLIGHT =
      "$BASE_URL/product_api_project/highlight/save_highlight.php";
  static const String UPDATE_PRODUCT =
      "$BASE_URL/product_api_project/product/update_full_product.php";
  static const String UPDATE_STOCK =
      "$BASE_URL/product_api_project/product/update_stock.php";
  static const String VIEW_ALL_PRODUCTS =
      "$BASE_URL/product_api_project/product/get_all_products.php";
  static const String DELETE_PRODUCTS =
      "$BASE_URL/product_api_project/product/delete_product.php";
  // static const String BASE_IMAGE_URL = "https://iws.flyplus.in/product_api_project/";
  static const String UPDATE_IMAGE =
      "product_api_project/product/upload_product_image.php";
  // Update product type

  static const String UPDATE_PRODUCT_TYPE =
      "$BASE_URL/product_api_project/product/update_type.php";

  // NormalBanner
  static const String ADD_BANNER = "$BASE_URL/banner_api/add_banner.php";
  static const String DELETE_BANNER = "$BASE_URL/banner_api/delete_banner.php";
  static const String VIEW_BANNER = "$BASE_URL/banner_api/view_banner.php";

  // CouponCode
  static const String ADD_COUPON = "$BASE_URL/coupon_code_api/add_coupon.php";
  static const String DELETE_COUPON =
      "$BASE_URL/coupon_code_api/delete_coupon.php";
  static const String VIEW_COUPON = "$BASE_URL/coupon_code_api/view_coupon.php";

  // order
  static const String GET_ALL_ORDER =
      "$BASE_URL/product_api_project/place_order/get_all_order.php";
  static const String GET_ALL_ORDER_DASHBOARD =
      "$BASE_URL/product_api_project/place_order/get_all_order_dashborad.php";
  static const String UPDATE_ORDER_STATUS =
      "$BASE_URL/product_api_project/place_order/update_order_status.php";

  // Calling
  static const String GET_CALLING_NUMBER =
      "$BASE_URL/help_api/call/get_help_call.php";
  static const String UPDATE_CALLING_NUMBER =
      "$BASE_URL/help_api/call/update_hellp_call.php";

  // whatsapp
  static const String GET_WHATSAPP_NUMBER =
      "$BASE_URL/help_api/whatsapp/get_help_whatsapp.php";
  static const String UPDATE_WHATSAPP_NUMBER =
      "$BASE_URL/help_api/whatsapp/update_hellp_whatsapp.php";

  // email
  static const String GET_EMAIL = "$BASE_URL/help_api/email/get_help_email.php";
  static const String UPDATE_EMAIL =
      "$BASE_URL/help_api/email/update_hellp_email.php";

  // Handling Charge
  static const String GET_HANDLING_CHARGE =
      "$BASE_URL/handling_charge/get_delivery_charge.php";
  static const String UPDATE_HANDLING_CHARGE =
      "$BASE_URL/handling_charge/update_handling_charge.php";

  // MINIMUM ORDER AMOUNT
  static const String GET_MINIMUM_ORDER_AMOUT =
      "$BASE_URL/minimum_order_amout/get_ minimum_order_amout.php";
  static const String UPDATE_MINIMUM_ORDER_AMOUT =
      "$BASE_URL/minimum_order_amout/update_ minimum_order_amout.php";

  // DeliveryTime
  static const String FETCH_DELIVERY_TIME =
      "$BASE_URL/deliver_time/get_delivery_time.php";
  static const String UPDATE_DELIVERY_TIME =
      "$BASE_URL/deliver_time/update_delivery_time.php";

  // DeliveryCharge
  static const String FETCH_DELIVERY_AMOUNT =
      "$BASE_URL/delivery_charge/get_delivery_charge.php";
  static const String UPDATE_DELIVERY_AMOUNT =
      "$BASE_URL/delivery_charge/update_delivery_charge.php";

  // Set free delivery amount
  static const String GET_FREE_DELIVERY_AMOUNT =
      "$BASE_URL/free_delivey/get_free_delivery.php";
  static const String UPDATE_FREE_DELIVERY_AMOUNT =
      "$BASE_URL/free_delivey/update_delivery_charge.php";
}
