import 'package:flutter/material.dart';

Widget buildProductCard(String name, String price, String unit, IconData icon) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 110,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Icon(icon, size: 48, color: Colors.green[600]),
        ),
        Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
              // Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        price,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green[600],
                        ),
                      ),
                      Text(
                        unit,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
  );
}
