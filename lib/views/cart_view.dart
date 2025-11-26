import 'package:auto_route/auto_route.dart';
import 'package:egcart_mobile/controller/supabase_controller.dart';
import 'package:egcart_mobile/models/product_model.dart';
import 'package:egcart_mobile/route/route.gr.dart';
import 'package:egcart_mobile/views/widgets/bottom_navbar.dart';
import 'package:egcart_mobile/views/widgets/product_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

@RoutePage()
class CartView extends StatefulWidget {
  const CartView({super.key});

  @override
  State<CartView> createState() => _CartViewState();
}

class _CartViewState extends State<CartView> {
  var select = false;

  var selectedProduct = [];

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

      print("count: $count for $id");

      productsPricesFromCart.add(getRealPrice(discount, price) * count);
    }
    print("prices $productsPricesFromCart");

    final reduced = productsPricesFromCart.reduce(
      (value, element) => value + element,
    );
    return formatDoubleWithCommas(reduced);
  }

  @override
  Widget build(BuildContext context) {
    print("countProd: ${CartProducts.countPerProduct}");
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.grey[50],
        bottomNavigationBar: BottomNavBar(),
        appBar: AppBar(
          scrolledUnderElevation: 0.0,
          leading: Container(
            margin: EdgeInsets.symmetric(horizontal: 25),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "My Cart",
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                if (CartProducts.products.isNotEmpty)
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            select = !select;
                            if (select == false) {
                              selectedProduct.clear();
                            }
                          });
                        },
                        child: Text(
                          select ? "cancel" : "select",
                          style: TextStyle(
                            fontSize: 17,
                            color: Colors.green[600],
                          ),
                        ),
                      ),
                      if (select)
                        Padding(
                          padding: const EdgeInsets.only(left: 15),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedProduct = List.generate(
                                  CartProducts.products.length,
                                  (index) => index,
                                );
                              });
                            },
                            child: Text(
                              "select all",
                              style: TextStyle(
                                fontSize: 17,
                                color: Colors.green[600],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          leadingWidth: double.infinity,
          backgroundColor: Colors.grey[50],

          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.grey[50],
            systemNavigationBarColor: Colors.grey[50],
            statusBarIconBrightness: Brightness.dark,
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              GetBuilder<SupabaseController>(
                builder: (c) {
                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        if (CartProducts.products.isEmpty)
                          Center(
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: MediaQuery.of(context).size.height / 2.6,
                              ),
                              child: Text(
                                "No products found :(",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        if (CartProducts.products.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 20,
                            ),
                            child: Column(
                              children: [
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: 25,
                                        mainAxisSpacing: 30,
                                        childAspectRatio: 0.8,
                                      ),
                                  itemCount: CartProducts.products.length > 10
                                      ? 10
                                      : CartProducts.products.length,
                                  itemBuilder: (context, index) {
                                    // return Text("");
                                    final currenProduct =
                                        CartProducts.products[index];
                                    return Builder(
                                      builder: (context) {
                                        return GestureDetector(
                                          onTap: () {
                                            if (select) {
                                              setState(() {
                                                if (selectedProduct.contains(
                                                  index,
                                                )) {
                                                  selectedProduct.removeWhere(
                                                    (itemIndex) =>
                                                        itemIndex == index,
                                                  );
                                                } else {
                                                  selectedProduct.add(index);
                                                }
                                              });
                                            } else {
                                              context.pushRoute(
                                                ProductDetailsView(
                                                  selectedProduct:
                                                      currenProduct,
                                                ),
                                              );
                                            }
                                          },
                                          child: buildProductCard(
                                            currenProduct,
                                            isFromCart: true,
                                            isSelected:
                                                selectedProduct.isNotEmpty &&
                                                    select
                                                ? selectedProduct.contains(
                                                    index,
                                                  )
                                                : false,
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                                SizedBox(height: 100),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              if (CartProducts.products.isNotEmpty)
                Align(
                  alignment: AlignmentGeometry.bottomCenter,
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        if (CartProducts.products.isNotEmpty)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Container(
                                width: 150,
                                margin: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 2,
                                ),
                                padding: EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.4),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.green[500]!,
                                      Colors.green[700]!,
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
                                    return GestureDetector(
                                      onTap: () {
                                        context.pushRoute(MapView());
                                      },
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.search,
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            selectedProduct.isNotEmpty
                                                ? "Find"
                                                : "Find All",
                                            style: TextStyle(
                                              fontSize: 18,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              if (select && selectedProduct.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      final tempCart = [
                                        ...CartProducts.products,
                                      ];
                                      final tempCount = [
                                        ...CartProducts.countPerProduct,
                                      ];
                                      for (var index in selectedProduct) {
                                        final currProductID =
                                            CartProducts.products[index].id;
                                        tempCart.removeWhere(
                                          (prod) => prod.id == currProductID,
                                        );
                                        tempCount.removeWhere(
                                          (prod) =>
                                              prod.keys.first.id ==
                                              currProductID,
                                        );
                                      }
                                      selectedProduct.clear();
                                      CartProducts.products = tempCart;
                                      CartProducts.countPerProduct = tempCount;
                                      select = false;
                                    });
                                    Get.find<SupabaseController>().update();
                                  },
                                  child: Container(
                                    width: 150,
                                    margin: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 2,
                                    ),
                                    padding: EdgeInsets.symmetric(vertical: 9),
                                    decoration: BoxDecoration(
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.4),
                                          blurRadius: 6,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.red[500]!,
                                          Colors.red[700]!,
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
                                        return Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons
                                                  .remove_shopping_cart_outlined,
                                              color: Colors.white,
                                              size: 22,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              "Remove ",
                                              style: TextStyle(
                                                fontSize: 18,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        Container(
                          width: MediaQuery.of(context).size.width,
                          height: 40,
                          color: Colors.grey.shade50,
                          padding: EdgeInsets.symmetric(horizontal: 30),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Total", style: TextStyle(fontSize: 16)),
                              GetBuilder<SupabaseController>(
                                builder: (c) {
                                  return Text(
                                    "₱${getTotal()}",
                                    style: TextStyle(fontSize: 16),
                                  );
                                },
                              ),
                            ],
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
