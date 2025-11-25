import 'dart:math';

import 'package:egcart_mobile/models/product_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

double getRealPrice(int discout, double price) {
  if (discout == 0) {
    return price;
  }
  double decimal = (100 - discout) / 100;
  return price * decimal;
}

String formatDoubleWithCommas(double number) {
  final NumberFormat formatter = NumberFormat(
    "#,##0.00",
    "en_US",
  ); // Formats with commas and two decimal places
  return formatter.format(number).replaceAll(".00", ".0");
}

Widget buildProductCard(
  Product product, {
  bool isFromCart = false,
  bool isSelected = false,
}) {
  final name = product.name;
  final price = product.price;
  final image = product.image;
  final discount = product.discount;
  final unit = product.weight;
  var count = 0;

  if (isFromCart) {
    for (var productInCart in CartProducts.countPerProduct) {
      if (productInCart.keys.first == product) {
        count = productInCart.values.first;
      }
    }
  }

  return Container(
    decoration: BoxDecoration(
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.12),
          blurRadius: 10,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            border: isSelected
                ? Border.all(color: Colors.green.shade600, width: 2)
                : null,
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 100,
                width: double.infinity,
                padding: EdgeInsets.only(top: 10, left: 10, right: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Image.network(
                  image,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.broken_image_rounded,
                    size: 70,
                    color: Colors.grey.shade300,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.grey[800],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (isFromCart == false)
                                  Text(
                                    "₱${getRealPrice(discount, price)}",
                                    style: TextStyle(
                                      // fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.green[600],
                                    ),
                                  ),
                                if (isFromCart == true)
                                  Text(
                                    "₱${formatDoubleWithCommas((getRealPrice(discount, price) * count))}",
                                    style: TextStyle(
                                      // fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.green[600],
                                    ),
                                  ),
                                if (isFromCart == true)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 5),
                                    child: Text(
                                      "$count item${count > 1 ? "s" : ""}",
                                      style: TextStyle(
                                        // fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (discount != 0 && isFromCart == false)
                              Text(
                                "₱$price",
                                style: TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  fontSize: 12,
                                  color: Colors.grey[800],
                                ),
                              ),
                            if (isFromCart == true &&
                                count != 0 &&
                                discount != 0)
                              Text(
                                "₱${formatDoubleWithCommas(price * count)}",
                                style: TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  fontSize: 12,
                                  color: Colors.grey[800],
                                ),
                              ),
                            Text(
                              unit,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        // Container(
                        //   width: 32,
                        //   height: 32,
                        //   decoration: BoxDecoration(
                        //     color: Colors.green[600],
                        //     shape: BoxShape.circle,
                        //   ),
                        //   child: Icon(Icons.add, color: Colors.white, size: 18),
                        // ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (discount != 0)
          Positioned(
            bottom: 20, // Distance from the top edge of the card
            right: -40, // Extends slightly past the right edge
            child: Transform.rotate(
              angle: -pi / 4, // Rotates 45 degrees (M_PI_4)
              child: Container(
                width: 150, // Width defines the length of the banner
                height: 20, // Height defines the thickness of the banner
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.green.shade800, // The dark green color
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 20,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Text(
                  "$discount% off",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
