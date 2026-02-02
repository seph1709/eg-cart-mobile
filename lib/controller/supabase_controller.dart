import 'dart:convert';
import 'package:egcart_mobile/models/announcement_model.dart';
import 'package:egcart_mobile/models/product_model.dart';
import 'package:egcart_mobile/models/uwb_model.dart';
import 'package:egcart_mobile/models/wishlist_model.dart';
import 'package:egcart_mobile/views/widgets/product_card_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences_android/shared_preferences_android.dart';

class SupabaseController extends GetxController {
  late final SupabaseClient supabaseClient;
  int indexNavigationBar = 0;

  final SharedPreferencesAsyncAndroidOptions options =
      SharedPreferencesAsyncAndroidOptions(
        backend: SharedPreferencesAndroidBackendLibrary.SharedPreferences,
        originalSharedPreferencesOptions: AndroidSharedPreferencesStoreOptions(
          fileName: 'egcart_sharedpreference',
        ),
      );

  late final SharedPreferences prefs;

  String? prioritizedProductId;
  final Set<String> hiddenProductPaths = {};

  String username = 'User';

  String privacyPolicy = "";

  Offset? selectedProductPosition;

  /// Persisted map of announcement id -> read state
  Map<String, bool> announcementsRead = {};

  @override
  void onInit() {
    super.onInit();
    supabaseClient = Supabase.instance.client;
    SharedPreferences.getInstance().then((val) {
      prefs = val;
      getLocalData().then((_) => update());
    });
  }

  @override
  void onReady() {
    super.onReady();
    getDocumentPolicy("privacy_policy").then((_) => update());
    getFeaturedProducts().then((_) => update());
    getUwbIP().then((_) => update());
    getGeoJson().then((_) => update());
  }

  Future<void> getLocalData() async {
    try {
      username = prefs.getString('username') ?? "user";
      var prodHistory = prefs.getString('products_history');
      var announcementsReadStr = prefs.getString('announcements_read');
      var wishlistID = prefs.getString('wishlistID');
      await getFeaturedProducts();
      print(wishlistID);
      if (wishlistID != null) {
        var listID = jsonDecode(wishlistID);
        print(listID);
        if (listID == null) return;
        List<WishlistItem> tempListWishlist = [];
        var uniqueId = 1;
        for (var id in listID) {
          print(id);
          var prod = Products.products.firstWhere((curr) {
            return curr.id == id.toString();
          });

          print(prod);
          var wishlistItem = WishlistItem(
            id: uniqueId.toString(),
            productId: prod.id,
            productName: prod.name,
            price: prod.price,
            image: prod.image,
            supplier: prod.supplier,
            discount: prod.discount,
            dateAdded: DateTime.parse(prod.dateAdded),
          );
          tempListWishlist.add(wishlistItem);
          uniqueId++;
        }
        Wishlist.items = tempListWishlist;
        print(tempListWishlist);
      }

      if (announcementsReadStr != null) {
        try {
          final decoded =
              jsonDecode(announcementsReadStr) as Map<String, dynamic>;
          announcementsRead = decoded.map((k, v) => MapEntry(k, v == true));
        } catch (e) {
          announcementsRead = {};
        }
      }

      if (prodHistory != null) {
        Products.prodHistfromJson(jsonDecode(prodHistory));
      }
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  Future<void> saveLocalData() async {
    List<String> listWishListId = [];

    for (var item in Wishlist.items) {
      listWishListId.add(item.productId);
    }

    try {
      await prefs.setString('wishlistID', jsonEncode(listWishListId));
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
    try {
      await prefs.setString('username', username);

      // Ensure history is deduplicated before saving
      try {
        Products.deduplicateHistory();
      } catch (_) {}

      await prefs.setString(
        'products_history',
        jsonEncode(Product.toJson(Products.historyProducts)),
      );
      // persist announcement read map
      try {
        await prefs.setString(
          'announcements_read',
          jsonEncode(announcementsRead),
        );
      } catch (e) {
        if (kDebugMode) {
          print('Failed to save announcements_read: $e');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("errrrorr $e");
      }
    }
  }

  /// Mark an announcement as read/unread and persist immediately
  Future<void> markAnnouncementRead(String id, bool isRead) async {
    announcementsRead[id] = isRead;
    await saveLocalData();
    update();
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

      if (kDebugMode) {
        print("validdd $response");
      }

      return isIpAdressExist && ipIdExist;
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }

      if (kDebugMode) {
        print("returning from error $e");
      }

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

  Future<void> getDocumentPolicy(String name) async {
    try {
      final response = await supabaseClient
          .from('document_policy')
          .select("*")
          .eq('name', name);

      final content = response.first["content"] ?? "";
      privacyPolicy = content.toString();
      update();
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  Future<List<Announcement>> getAnnouncements() async {
    try {
      List<Announcement> annoucements = [];
      final response = await supabaseClient.from('announcement').select("*");

      if (response.isNotEmpty) {
        for (var curr in response) {
          annoucements.add(
            Announcement(
              id: curr["id"],
              title: curr["title"],
              description: curr["description"],
              createdAt: DateTime.parse(curr["created_at"]),
            ),
          );
        }
        return annoucements;
      } else {
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      return [];
    }
  }
}

