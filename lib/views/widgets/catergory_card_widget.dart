import 'package:flutter/material.dart';

Widget buildCategoryCard(String title, IconData icon, Color color) {
  return Container(
    width: 100,
    margin: EdgeInsets.only(right: 16),
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
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        SizedBox(height: 8),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ),
      ],
    ),
  );
}
