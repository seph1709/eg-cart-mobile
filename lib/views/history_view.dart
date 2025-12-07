import 'package:auto_route/auto_route.dart';
import 'package:egcart_mobile/models/product_model.dart';
import 'package:egcart_mobile/route/route.gr.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

@RoutePage()
class HistoryView extends StatefulWidget {
  const HistoryView({super.key});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      print(Products.historyProducts);
    }
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: GestureDetector(
            onTap: () {
              context.back();
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
          backgroundColor: Colors.white,
        ),
        body: ListView.builder(
          itemCount: Products.historyProducts.length,
          itemBuilder: (context, index) {
            final product = Products.historyProducts[index];
            return GestureDetector(
              onTap: () {
                context.pushRoute(ProductDetailsView(selectedProduct: product));
              },
              child: ListTile(
                leading: SizedBox(
                  width: 100,
                  child: Image.network(product.image),
                ),
                title: Text(product.name),
                subtitle: Text('₱${product.price.toStringAsFixed(2)}'),
              ),
            );
          },
        ),
      ),
    );
  }
}
