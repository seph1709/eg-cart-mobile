import 'package:auto_route/auto_route.dart';
import 'package:egcart_mobile/controller/supabase_controller.dart';
import 'package:egcart_mobile/models/product_model.dart';
import 'package:egcart_mobile/route/route.gr.dart';
import 'package:egcart_mobile/views/widgets/product_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

@RoutePage()
class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  var isProductFound = true;

  @override
  void dispose() {
    super.dispose();
    SearchResults.products.clear();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SupabaseController>();

    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.grey[50],
          toolbarHeight: 90,
          leadingWidth: MediaQuery.of(context).size.width,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.grey[50],
            systemNavigationBarColor: Colors.grey[50],
            statusBarIconBrightness: Brightness.dark,
          ),
          leading: Container(
            margin: EdgeInsets.all(16),
            width: double.infinity,
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
            child: TextField(
              autofocus: true,
              onChanged: (value) {
                if (value.isEmpty || value.length < 3) {
                  setState(() {
                    SearchResults.products.clear();
                  });
                } else {
                  controller.getProductsFromSearch(value).then((_) {
                    setState(() {
                      SearchResults.products;

                      if (SearchResults.products.isEmpty) {
                        isProductFound = false;
                      } else {
                        isProductFound = true;
                      }
                    });
                  });
                }
              },
              decoration: InputDecoration(
                hintText: 'Search for products...',
                prefixIcon: Icon(Icons.search, color: Colors.green[600]),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: GetBuilder<SupabaseController>(
            builder: (c) {
              return SingleChildScrollView(
                child: Column(
                  children: [
                    if (isProductFound == false)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 50),
                          child: Column(
                            children: [
                              Text(
                                "No products found",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (SearchResults.products.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
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
                              itemCount: SearchResults.products.length > 10
                                  ? 10
                                  : SearchResults.products.length,
                              itemBuilder: (context, index) {
                                // return Text("");
                                final currenProduct =
                                    SearchResults.products[index];
                                return Builder(
                                  builder: (context) {
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
                                );
                              },
                            ),
                            SizedBox(height: 40),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
