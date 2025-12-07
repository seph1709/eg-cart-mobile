class WishlistItem {
  final String id;
  final String productId;
  final String productName;
  final double price;
  final String image;
  final String supplier;
  final int discount;
  final DateTime dateAdded;

  WishlistItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.price,
    required this.image,
    required this.supplier,
    required this.discount,
    required this.dateAdded,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'price': price,
      'image': image,
      'supplier': supplier,
      'discount': discount,
      'dateAdded': dateAdded.toIso8601String(),
    };
  }

  factory WishlistItem.fromJson(Map<String, dynamic> json) {
    return WishlistItem(
      id: json['id'] as String,
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      price: (json['price'] as num).toDouble(),
      image: json['image'] as String,
      supplier: json['supplier'] as String,
      discount: json['discount'] as int,
      dateAdded: DateTime.parse(json['dateAdded'] as String),
    );
  }
}

class Wishlist {
  static List<WishlistItem> items = [];

  static void addItem(WishlistItem item) {
    if (!items.any((i) => i.productId == item.productId)) {
      items.add(item);
    }
  }

  static void removeItem(String productId) {
    items.removeWhere((item) => item.productId == productId);
  }

  static bool isInWishlist(String productId) {
    return items.any((item) => item.productId == productId);
  }

  static void clear() {
    items.clear();
  }
}
