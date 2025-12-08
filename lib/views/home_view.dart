import 'package:auto_route/auto_route.dart';
import 'package:egcart_mobile/controller/supabase_controller.dart';
import 'package:egcart_mobile/models/announcement_model.dart';
import 'package:egcart_mobile/models/product_model.dart';
import 'package:egcart_mobile/route/route.gr.dart';
import 'package:egcart_mobile/views/widgets/announcement_widget.dart';
import 'package:egcart_mobile/views/widgets/bottom_navbar.dart';
import 'package:egcart_mobile/views/widgets/catergory_card_widget.dart';
import 'package:egcart_mobile/views/widgets/product_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

@RoutePage()
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  List<Announcement> announcements = [];

  @override
  void initState() {
    super.initState();

    // Apply persisted read states (if any) by asking controller to load local data
    final controller = Get.find<SupabaseController>();

    controller.getLocalData().then((_) {
      final map = controller.announcementsRead;
      if (map.isNotEmpty) {
        setState(() {
          announcements = announcements
              .map((a) => a.copyWith(isRead: map[a.id] ?? a.isRead))
              .toList();
        });
      }
    });
    controller.getAnnouncements().then(
      (val) => setState(() {
        if (val.isNotEmpty) {
          // Add new announcements and apply persisted read states
          final newAnnouncements = val
              .map(
                (a) => a.copyWith(
                  isRead: controller.announcementsRead[a.id] ?? false,
                ),
              )
              .toList();
          announcements = [...newAnnouncements];
        }
      }),
    );
  }

  void _handleAnnouncementTap(Announcement announcement) {
    final index = announcements.indexOf(announcement);
    if (index != -1) {
      setState(() {
        announcements[index] = announcement.copyWith(isRead: true);
      });
      // persist read state
      Get.find<SupabaseController>().markAnnouncementRead(
        announcement.id,
        true,
      );
    }
  }

  void _showAnnouncements(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AnnouncementBottomSheet(
        announcements: announcements,
        onAnnouncementRead: _handleAnnouncementTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'E-G Cart',

      home: GetBuilder<SupabaseController>(
        builder: (c) {
          if (Products.products.isEmpty) {
            c.getFeaturedProducts();
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
              scrolledUnderElevation: 0,
              systemOverlayStyle: SystemUiOverlayStyle(
                statusBarColor: Colors.green[600],
                statusBarIconBrightness: Brightness.light,
                systemNavigationBarColor: Colors.grey[50],
              ),
              backgroundColor: Colors.green[600],
              centerTitle: false,
              title: Row(
                children: [
                  Icon(
                    Icons.shopping_cart_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'E-G Cart',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              actions: [
                Stack(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                        size: 26,
                      ),
                      onPressed: () {
                        _showAnnouncements(context);
                      },
                    ),
                    if (announcements.where((a) => !a.isRead).isNotEmpty)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            announcements
                                .where((a) => !a.isRead)
                                .length
                                .toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
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
                        vertical: 32,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(color: Colors.green[600]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Find Fresh Groceries',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Browse our wide selection of grocery items and quickly locate them in-store.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          SizedBox(height: 24),
                          // Search Bar
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
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
                                  hintText: 'Search products...',
                                  hintStyle: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 15,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    color: Colors.green[600],
                                    size: 22,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 14,
                                    horizontal: 4,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 28),

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
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[900],
                              letterSpacing: 0.3,
                            ),
                          ),
                          SizedBox(height: 14),
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

                    SizedBox(height: 28),

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
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey[900],
                                  letterSpacing: 0.3,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  context.pushRoute(
                                    CategoryView(
                                      categoryName: "Featured Products",
                                      isGetAll: true,
                                    ),
                                  );
                                },
                                child: Text(
                                  'See All',
                                  style: TextStyle(
                                    color: Colors.green[600],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 14),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 20,
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

                    SizedBox(height: 60), // Bottom padding for navigation bar
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
