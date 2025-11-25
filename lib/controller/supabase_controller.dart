import 'package:egcart_mobile/models/product_model.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseController extends GetxController {
  late final SupabaseClient supabaseClient;
  int indexNavigationBar = 0;

  @override
  void onInit() {
    super.onInit();
    supabaseClient = Supabase.instance.client;
  }

  @override
  void onReady() {
    super.onReady();
    getFeaturedProducts();
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
}
