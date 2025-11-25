import 'package:auto_route/auto_route.dart';
import 'package:egcart_mobile/controller/supabase_controller.dart';
import 'package:egcart_mobile/models/product_model.dart';
import 'package:egcart_mobile/route/route.gr.dart';

import 'package:egcart_mobile/views/widgets/bottom_navbar.dart';
import 'package:egcart_mobile/views/widgets/catergory_card_widget.dart';
import 'package:egcart_mobile/views/widgets/product_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

@RoutePage()
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'E-G Cart',
      home: GetBuilder<SupabaseController>(
        builder: (c) {
          if (Products.products.isEmpty) {
            return Center(
              child: Scaffold(
                backgroundColor: Colors.grey[50],
                appBar: AppBar(
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  backgroundColor: Colors.transparent,
                  scrolledUnderElevation: 0,

                  systemOverlayStyle: SystemUiOverlayStyle(
                    statusBarColor: Colors.grey[50],
                    systemNavigationBarColor: Colors.grey[50],
                  ),
                ),
                body: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.green.shade600,
                    ),
                  ),
                ),
              ),
            );
          }
          return Scaffold(
            bottomNavigationBar: BottomNavBar(),
            backgroundColor: Colors.grey[50],
            appBar: AppBar(
              elevation: 0,
              shadowColor: Colors.transparent,
              toolbarHeight: 0.0,
              scrolledUnderElevation: 0,
              systemOverlayStyle: SystemUiOverlayStyle(
                statusBarColor: Colors.green[600],
                statusBarIconBrightness: Brightness.light,
                systemNavigationBarColor: Colors.grey[50],
              ),
              backgroundColor: Colors.green[600],

              // title: Row(
              //   children: [
              //     SizedBox(width: 8),
              //     Text(
              //       'E-G Cart',
              //       style: TextStyle(
              //         color: Colors.white,
              //         fontSize: 20,
              //         // fontWeight: FontWeight.bold,
              //       ),
              //     ),
              //   ],
              // ),
              // actions: [
              //   IconButton(
              //     icon: Icon(Icons.notifications_outlined, color: Colors.white),
              //     onPressed: () {
              //       //
              //     },
              //   ),
              //   IconButton(
              //     icon: Icon(
              //       Icons.account_circle_outlined,
              //       color: Colors.white,
              //     ),
              //     onPressed: () {
              //       //
              //     },
              //   ),
              // ],
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Banner
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        vertical: 50,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green[600]!, Colors.green[300]!],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Find fresh groceries today!',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 20),
                          // Search Bar
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: GestureDetector(
                              onTap: () {
                                context.pushRoute(SearchView());
                              },
                              child: TextField(
                                enabled: false,
                                decoration: InputDecoration(
                                  hintText: 'Search for products...',
                                  prefixIcon: Icon(
                                    Icons.search,
                                    color: Colors.green[600],
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.all(16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    // Categories Section
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Shop by Category',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: 16),
                          SizedBox(
                            height: 160,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    context.pushRoute(
                                      CategoryView(
                                        categoryName: 'Fruits & Vegetables',
                                      ),
                                    );
                                  },
                                  child: buildCategoryCard(
                                    'Fruits & Vegetables',
                                    Icons.apple,
                                    Colors.orange,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    context.pushRoute(
                                      CategoryView(
                                        categoryName: 'Dairy and Eggs',
                                      ),
                                    );
                                  },
                                  child: buildCategoryCard(
                                    'Dairy & Eggs',
                                    Icons.local_drink,
                                    Colors.blue,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    context.pushRoute(
                                      CategoryView(categoryName: 'Meat & Fish'),
                                    );
                                  },
                                  child: buildCategoryCard(
                                    'Meat & Fish',
                                    Icons.restaurant,
                                    Colors.red,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    context.pushRoute(
                                      CategoryView(categoryName: 'Bakery'),
                                    );
                                  },
                                  child: buildCategoryCard(
                                    'Bakery',
                                    Icons.cake,
                                    Colors.amber,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    context.pushRoute(
                                      CategoryView(categoryName: 'Beverages'),
                                    );
                                  },
                                  child: buildCategoryCard(
                                    'Beverages',
                                    Icons.local_cafe,
                                    Colors.purple,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 10),

                    // Featured Products
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Featured Products',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              TextButton(
                                onPressed: () {},
                                child: Text(
                                  'See All',
                                  style: TextStyle(
                                    color: Colors.green[600],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
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
                            itemCount: 4,
                            itemBuilder: (context, index) {
                              // return Text("");
                              final currenProduct = Products.products[index];
                              return GestureDetector(
                                onTap: () {
                                  context.pushRoute(
                                    ProductDetailsView(
                                      selectedProduct: currenProduct,
                                    ),
                                  );
                                },
                                child: buildProductCard(currenProduct),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    SizedBox(
                      height: 50,
                    ), // Bottom padding for floating action button
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
