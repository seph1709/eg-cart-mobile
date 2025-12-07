import 'dart:math';

import 'package:auto_route/auto_route.dart';
import 'package:egcart_mobile/controller/supabase_controller.dart';
import 'package:egcart_mobile/models/product_model.dart';
import 'package:egcart_mobile/models/wishlist_model.dart';
import 'package:egcart_mobile/route/route.gr.dart' as app_routes;
import 'package:egcart_mobile/views/widgets/product_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

@RoutePage()
class ProductDetailsView extends StatefulWidget {
  final Product selectedProduct;

  final bool fromMapView;

  const ProductDetailsView({
    super.key,
    required this.selectedProduct,
    this.fromMapView = false,
  });

  @override
  State<ProductDetailsView> createState() => _ProductDetailsViewState();
}

class _ProductDetailsViewState extends State<ProductDetailsView> {
  int rand = Random().nextInt(3) + 2;

  var counter = 1;
  var isAddedInTheCart = false;
  late bool isInWishlist;

  double getRealPrice(int discout, double price) {
    if (discout == 0) {
      return price;
    }
    double decimal = (100 - discout) / 100;
    return price * decimal;
  }

  void _toggleWishlist() {
    String message;
    Color snackBarColor;

    if (isInWishlist) {
      Wishlist.removeItem(widget.selectedProduct.id);
      message = 'Removed from wishlist';
      snackBarColor = Colors.red[600]!;
    } else {
      final wishlistItem = WishlistItem(
        id: widget.selectedProduct.id,
        productId: widget.selectedProduct.id,
        productName: widget.selectedProduct.name,
        price: widget.selectedProduct.price,
        image: widget.selectedProduct.image,
        supplier: widget.selectedProduct.supplier,
        discount: widget.selectedProduct.discount,
        dateAdded: DateTime.now(),
      );
      Wishlist.addItem(wishlistItem);
      message = 'Added to wishlist';
      snackBarColor = Colors.green[600]!;
    }

    setState(() {
      isInWishlist = !isInWishlist;
      Get.find<SupabaseController>().saveLocalData();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: snackBarColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  var listSameCatProd = [];

  @override
  initState() {
    super.initState();
    isInWishlist = Wishlist.isInWishlist(widget.selectedProduct.id);

    Get.find<SupabaseController>()
        .getProductsByCategory(widget.selectedProduct.category)
        .then(
          (val) => {
            setState(() {
              listSameCatProd = ProductsByCategory.products
                  .where((prod) => prod.id != widget.selectedProduct.id)
                  .toList();
            }),
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedProduct.id ==
        Get.find<SupabaseController>().prioritizedProductId) {
      Get.find<SupabaseController>().prioritizedProductId = null;
      Get.find<SupabaseController>().update();
    }

    if (CartProducts.products.contains(widget.selectedProduct)) {
      isAddedInTheCart = true;
    } else {
      isAddedInTheCart = false;
    }
    for (var product in CartProducts.countPerProduct) {
      if (product.keys.first == widget.selectedProduct) {
        counter = product.values.first;
      }
    }

    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          shadowColor: Colors.transparent,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.grey[50],
            systemNavigationBarColor: Colors.grey[50],
            statusBarIconBrightness: Brightness.dark,
          ),
          backgroundColor: Colors.grey[50],
          title: IntrinsicWidth(
            child: InkWell(
              onTap: () {
                if (CartProducts.products.isEmpty && widget.fromMapView) {
                  context.replaceRoute(app_routes.CartView());
                } else {
                  context.back();
                }
              },
              child: Row(
                children: [
                  Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    weight: 5,
                    color: Colors.grey[800],
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Back",
                    style: TextStyle(fontSize: 17, color: Colors.grey[800]),
                  ),
                ],
              ),
            ),
          ),
        ),

        body: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      height: 250,
                      alignment: Alignment.center,
                      child: Image.network(
                        widget.selectedProduct.image,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.broken_image_rounded,
                          size: 70,
                          color: Colors.grey.shade300,
                        ),
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(left: 18),
                      alignment: Alignment.centerLeft,
                      child: Column(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.selectedProduct.name,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              Text(
                                "Supplier: ${widget.selectedProduct.supplier}",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                              Text(
                                "Stocks: ${widget.selectedProduct.currentStockLevel}",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                              Text(
                                "Product ID: ${widget.selectedProduct.id}",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                              SizedBox(height: 5),
                              Row(
                                children: [
                                  ...List.generate(5, (index) {
                                    if (index <= rand) {
                                      return Icon(
                                        Icons.star,
                                        color: Colors.green[600],
                                        size: 16,
                                      );
                                    } else {
                                      return Icon(
                                        Icons.star,
                                        color: Colors.grey[300],
                                        size: 16,
                                      );
                                    }
                                  }),
                                ],
                              ),
                            ],
                          ),

                          Padding(
                            padding: EdgeInsets.only(top: 30),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  alignment: Alignment.centerLeft,
                                  child: IntrinsicWidth(
                                    child: Container(
                                      height: 40,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(10),
                                        ),
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          IconButton(
                                            onPressed: () {
                                              if (counter > 1) {
                                                setState(() {
                                                  counter--;
                                                  if (CartProducts.products
                                                      .contains(
                                                        widget.selectedProduct,
                                                      )) {
                                                    CartProducts.countPerProduct
                                                        .add({
                                                          widget.selectedProduct:
                                                              counter,
                                                        });
                                                  }
                                                  Get.find<SupabaseController>()
                                                      .update();
                                                });
                                              }
                                            },
                                            icon: Icon(
                                              Icons.remove,
                                              color: const Color.fromARGB(
                                                255,
                                                55,
                                                50,
                                                50,
                                              ),
                                              size: 23,
                                            ),
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            '$counter',
                                            style: TextStyle(
                                              fontSize: 19,
                                              color: Colors.grey[800],
                                            ),
                                          ),
                                          SizedBox(width: 4),
                                          IconButton(
                                            onPressed: () {
                                              setState(() {
                                                if (widget
                                                        .selectedProduct
                                                        .currentStockLevel >
                                                    counter) {
                                                  counter++;
                                                  if (CartProducts.products
                                                      .contains(
                                                        widget.selectedProduct,
                                                      )) {
                                                    CartProducts.countPerProduct
                                                        .add({
                                                          widget.selectedProduct:
                                                              counter,
                                                        });
                                                  }
                                                }
                                                Get.find<SupabaseController>()
                                                    .update();
                                              });
                                            },
                                            icon: Icon(
                                              Icons.add,
                                              color: Colors.grey[800],
                                              size: 23,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  height: widget.selectedProduct.discount != 0
                                      ? 50
                                      : 40,
                                  alignment: Alignment.centerRight,
                                  margin: EdgeInsets.only(right: 18),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "₱${formatDoubleWithCommas(getRealPrice(widget.selectedProduct.discount, widget.selectedProduct.price) * counter)}",
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                      if (widget.selectedProduct.discount != 0)
                                        Row(
                                          children: [
                                            Text(
                                              "₱${formatDoubleWithCommas(widget.selectedProduct.price * counter)}",
                                              style: TextStyle(
                                                fontSize: 13,

                                                color: Colors.grey[800],
                                                decoration:
                                                    TextDecoration.lineThrough,
                                              ),
                                            ),
                                            SizedBox(width: 5),
                                            Text(
                                              "${widget.selectedProduct.discount}% off",
                                              style: TextStyle(
                                                fontSize: 13,

                                                color: Colors.green[800],
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(top: 30, bottom: 10),
                            child: Text(
                              "About the product",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                          ),
                          Container(
                            margin: EdgeInsets.only(right: 18, bottom: 20),
                            child: Text(
                              widget.selectedProduct.description,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.justify,
                            ),
                          ),
                          if (listSameCatProd.isNotEmpty)
                            Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(
                                bottom: 10,
                                top: 20,
                              ),
                              child: Text(
                                "You might also like",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ),
                          if (listSameCatProd.isNotEmpty)
                            SizedBox(
                              height: 200,
                              width: MediaQuery.of(context).size.width,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: listSameCatProd.length,
                                itemBuilder: (context, index) {
                                  return Container(
                                    width: 140,
                                    height: 180,
                                    margin: EdgeInsets.only(
                                      right: 20,
                                      top: 10,
                                      bottom: 10,
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        context.pushRoute(
                                          app_routes.ProductDetailsView(
                                            selectedProduct:
                                                listSameCatProd[index],
                                          ),
                                        );
                                      },
                                      child: buildProductCard(
                                        listSameCatProd[index],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                          SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          final c = Get.find<SupabaseController>();
                          c.indexNavigationBar = 1;
                          c.update();
                          context.pushRoute(app_routes.CartView());
                        },
                        child: Container(
                          width: 55,
                          height: 50,
                          margin: EdgeInsets.only(right: 8, left: 18),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.shopping_cart_outlined,
                            color: Colors.green[600],
                            size: 28,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _toggleWishlist,
                        child: Container(
                          width: 55,
                          height: 50,
                          margin: EdgeInsets.only(right: 18, left: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isInWishlist
                                  ? Colors.red[600]!
                                  : Colors.grey[300]!,
                            ),
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                            color: isInWishlist ? Colors.red[50] : Colors.white,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            isInWishlist
                                ? Icons.favorite
                                : Icons.favorite_outline,
                            color: isInWishlist
                                ? Colors.red[600]
                                : Colors.grey[500],
                            size: 26,
                          ),
                        ),
                      ),
                      Expanded(
                        child: IntrinsicHeight(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                if (CartProducts.products.contains(
                                  widget.selectedProduct,
                                )) {
                                  CartProducts.products.removeWhere(
                                    (product) =>
                                        product == widget.selectedProduct,
                                  );
                                  CartProducts.countPerProduct.removeWhere(
                                    (product) =>
                                        product.keys.first ==
                                        widget.selectedProduct,
                                  );
                                  Get.find<SupabaseController>()
                                      .saveLocalData();
                                  Get.find<SupabaseController>().update();
                                } else {
                                  CartProducts.products.add(
                                    widget.selectedProduct,
                                  );
                                  CartProducts.countPerProduct.add({
                                    widget.selectedProduct: counter,
                                  });

                                  // Only add to history when actually added to cart
                                  // and avoid duplicates (compare by id).
                                  if (!Products.historyProducts.any(
                                    (p) => p.id == widget.selectedProduct.id,
                                  )) {
                                    Products.historyProducts.add(
                                      widget.selectedProduct,
                                    );
                                  }
                                  Get.find<SupabaseController>()
                                      .saveLocalData();
                                  Get.find<SupabaseController>().update();
                                }
                              });
                            },
                            child: Container(
                              margin: EdgeInsets.only(
                                top: 10,
                                bottom: 10,
                                right: 18,
                              ),
                              padding: EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    if (isAddedInTheCart) ...[
                                      Colors.red[500]!,
                                      Colors.red[700]!,
                                    ],
                                    if (!isAddedInTheCart) ...[
                                      Colors.green[500]!,
                                      Colors.green[700]!,
                                    ],
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.all(
                                  Radius.circular(10),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: GetBuilder<SupabaseController>(
                                builder: (c) {
                                  if (!isAddedInTheCart) {
                                    return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.shopping_bag_outlined,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          "Add to cart",
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    );
                                  } else {
                                    return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.remove_shopping_cart_outlined,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          "Remove from cart",
                                          style: TextStyle(
                                            fontSize: 18,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
