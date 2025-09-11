import 'package:egcart_mobile/views/widgets/catergory_card_widget.dart';
import 'package:egcart_mobile/views/widgets/product_card_widget.dart';
import 'package:egcart_mobile/views/widgets/quicaction_card_widget.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'E-G Cart',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.green[600],
          elevation: 0,
          title: Row(
            children: [
              Icon(Icons.shopping_cart, color: Colors.white, size: 28),
              SizedBox(width: 8),
              Text(
                'E-G Cart',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.notifications_outlined, color: Colors.white),
              onPressed: () {},
            ),
            IconButton(
              icon: Icon(Icons.account_circle_outlined, color: Colors.white),
              onPressed: () {},
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Banner
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green[600]!, Colors.green[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Find fresh groceries delivered to your door',
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
                      child: TextField(
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
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      height: 120,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          buildCategoryCard(
                            'Fruits & Vegetables',
                            Icons.apple,
                            Colors.orange,
                          ),
                          buildCategoryCard(
                            'Dairy & Eggs',
                            Icons.local_drink,
                            Colors.blue,
                          ),
                          buildCategoryCard(
                            'Meat & Fish',
                            Icons.restaurant,
                            Colors.red,
                          ),
                          buildCategoryCard('Bakery', Icons.cake, Colors.amber),
                          buildCategoryCard(
                            'Beverages',
                            Icons.local_cafe,
                            Colors.purple,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 32),

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
                            fontSize: 22,
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
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: 4,
                      itemBuilder: (context, index) {
                        return buildProductCard(
                          'Fresh Bananas',
                          '\$2.99',
                          '/kg',
                          Icons.border_clear,
                        );
                      },
                    ),
                  ],
                ),
              ),

              SizedBox(height: 32),

              // Quick Actions
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: buildQuickActionCard(
                            'Reorder',
                            Icons.refresh,
                            'Order your favorites again',
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: buildQuickActionCard(
                            'Deals',
                            Icons.local_offer,
                            'Check today\'s special offers',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(
                height: 100,
              ), // Bottom padding for floating action button
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {},
          backgroundColor: Colors.green[600],
          icon: Icon(Icons.shopping_cart, color: Colors.white),
          label: Text(
            'View Cart',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
