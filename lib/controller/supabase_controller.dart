import 'package:egcart_mobile/models/product_model.dart';
import 'package:egcart_mobile/models/uwb_model.dart';
import 'package:egcart_mobile/views/widgets/product_card_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseController extends GetxController {
  late final SupabaseClient supabaseClient;
  int indexNavigationBar = 0;

  String? prioritizedProductId;
  final Set<String> hiddenProductPaths = {};

  String username = 'User';

  @override
  void onInit() {
    super.onInit();
    supabaseClient = Supabase.instance.client;
  }

  @override
  void onReady() {
    super.onReady();
    getFeaturedProducts();
    getUwbIP();
    getGeoJson();
  }

  String getTotal() {
    late List<double> productsPricesFromCart = [];
    for (var currProduct in CartProducts.products) {
      final id = currProduct.id;
      final price = currProduct.price;
      final discount = currProduct.discount;
      var count = CartProducts.countPerProduct
          .lastWhere((curr) {
            return curr.keys.first.id == id;
          })
          .values
          .first;

      if (kDebugMode) {
        print("count: $count for $id");
      }

      productsPricesFromCart.add(getRealPrice(discount, price) * count);
    }
    if (kDebugMode) {
      print("prices $productsPricesFromCart");
    }

    final reduced = productsPricesFromCart.reduce(
      (value, element) => value + element,
    );
    return formatDoubleWithCommas(reduced);
  }

  Future<void> getFeaturedProducts() async {
    try {
      final response = await supabaseClient.from('products').select("*");
      for (var product in response) {
        Products.products.add(Product.fromJson(product));
      }
      if (kDebugMode) {
        print(response);
      }
      update();
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  Future<void> getProductsFromSearch(String name) async {
    try {
      final response = await supabaseClient
          .from('products')
          .select("*")
          .ilike('name', '%$name%');
      List<Product> searchResults = [];
      for (var product in response) {
        searchResults.add(Product.fromJson(product));
      }
      SearchResults.products = searchResults;
      update();
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  Future<void> getProductsByCategory(String category) async {
    try {
      final response = await supabaseClient
          .from('products')
          .select("*")
          .eq('category', category);
      List<Product> categoryResults = [];
      for (var product in response) {
        categoryResults.add(Product.fromJson(product));
      }
      if (kDebugMode) {
        print(categoryResults);
      }

      ProductsByCategory.products = categoryResults;
      update();
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  Future<void> getUwbIP() async {
    try {
      final response = await supabaseClient
          .from('uwb_ip')
          .select("*")
          .eq('id', "01");

      UwbContent.ipAdress = response.first["ip_address"] ?? "";
      UwbContent.id = response.first["id"] ?? "";

      update();
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  Future<void> getGeoJson() async {
    try {
      final response = await supabaseClient
          .from('geojson')
          .select("*")
          .eq('id', "01");

      UwbContent.geoJson = response.first["content"] ?? "";
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  Future<bool> verifyQRcode(String cardId) async {
    try {
      final response = await supabaseClient
          .from('uwb_ip')
          .select("*")
          .eq('card_id', cardId);

      final isIpAdressExist = response.first["ip_address"] != null;
      final ipIdExist = response.first["id"] != null;

      print("validdd $response");

      return isIpAdressExist && ipIdExist;
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }

      print("returning from error $e");

      return false;
    }
  }

  Future<bool> verifyPinCode(int pinCode) async {
    try {
      final response = await supabaseClient
          .from('uwb_ip')
          .select("*")
          .eq('pin_code', pinCode);

      final isIpAdressExist = response.first["ip_address"] != null;
      final ipIdExist = response.first["id"] != null;

      return isIpAdressExist && ipIdExist;
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }

      return false;
    }
  }
}
