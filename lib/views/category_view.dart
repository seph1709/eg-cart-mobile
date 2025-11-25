import 'package:auto_route/auto_route.dart';
import 'package:egcart_mobile/models/product_model.dart';
import 'package:egcart_mobile/route/route.gr.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controller/supabase_controller.dart';
import 'widgets/product_card_widget.dart';

@RoutePage()
class CategoryView extends StatefulWidget {
  final String categoryName;

  const CategoryView({super.key, required this.categoryName});

  @override
  State<CategoryView> createState() => _CategoryViewState();
}

class _CategoryViewState extends State<CategoryView> {
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SupabaseController>();
    ProductsByCategory.products.clear();
    controller.getProductsByCategory(widget.categoryName);
    return MaterialApp(
      home: GetBuilder<SupabaseController>(
        builder: (c) {
          if (ProductsByCategory.products.isEmpty) {
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
                    statusBarIconBrightness: Brightness.dark,
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
            backgroundColor: Colors.grey[50],
            appBar: AppBar(
              systemOverlayStyle: SystemUiOverlayStyle(
                statusBarColor: Colors.grey[50],
                systemNavigationBarColor: Colors.grey[50],
              ),
              leadingWidth: 100,
              leading: GestureDetector(
                onTap: () {
                  context.back();
                },
                child: Row(
                  children: [
                    SizedBox(width: 8),
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
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(15),
                child: Column(
                  children: [
                    Text(
                      widget.categoryName,
                      style: TextStyle(fontSize: 19, color: Colors.grey[800]),
                    ),
                    SizedBox(height: 12),
                  ],
                ),
              ),
              backgroundColor: Colors.grey[50],
              scrolledUnderElevation: 0.0,
            ),
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 25,
                        mainAxisSpacing: 30,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: ProductsByCategory.products.length > 10
                          ? 10
                          : ProductsByCategory.products.length,
                      itemBuilder: (context, index) {
                        // return Text("");
                        final currenProduct =
                            ProductsByCategory.products[index];
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
                    SizedBox(height: 40),
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
