class Products {
  static List<Product> products = [];
}

class ProductsByCategory {
  static List<Product> products = [];
}

class SearchResults {
  static List<Product> products = [];
}

class CartProducts {
  static List<Product> products = [];
  static List<Map<Product, int>> countPerProduct = [];
}

class Product {
  final String id;
  final String name;
  final String classification;
  final int quantity;
  final bool available;
  final String supplier;
  final Map<String, double> coordinates;
  final double price;
  final String description;
  final String dateAdded;
  final int discount;
  final String image;
  final String expirationDate;
  final String weight;
  final String brand;
  final String category;
  final String barcode;
  final int minStockLevel;
  final int maxStockLevel;
  final int currentStockLevel;

  Product({
    required this.id,
    required this.name,
    required this.classification,
    required this.quantity,
    required this.available,
    required this.supplier,
    required this.coordinates,
    required this.price,
    required this.description,
    required this.dateAdded,
    required this.discount,
    required this.image,
    required this.expirationDate,
    required this.weight,
    required this.brand,
    required this.category,
    required this.barcode,
    required this.minStockLevel,
    required this.maxStockLevel,
    required this.currentStockLevel,
  });
  Product.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      name = json['name'],
      classification = json['classification'],
      quantity = json['quantity'],
      available = json['available'],
      supplier = json['supplier'],
      coordinates = Map<String, double>.from(json['coordinates']),
      price = json['price'].toDouble(),
      description = json['description'],
      dateAdded = json['dateAdded'],
      discount = json['discount'],
      image = json['image'],
      expirationDate = json['expirationDate'],
      weight = json['weight'],
      brand = json['brand'],
      category = json['category'],
      barcode = json['barcode'],
      minStockLevel = json['minStockLevel'],
      maxStockLevel = json['maxStockLevel'],
      currentStockLevel = json['currentStockLevel'];
}
