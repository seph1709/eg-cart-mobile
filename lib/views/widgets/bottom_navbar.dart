import 'package:auto_route/auto_route.dart';
import 'package:egcart_mobile/controller/supabase_controller.dart';
import 'package:egcart_mobile/route/route.gr.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({super.key});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  @override
  Widget build(BuildContext context) {
    return GetBuilder<SupabaseController>(
      builder: (c) {
        return IntrinsicHeight(
          child: Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Container(
                    padding: EdgeInsets.symmetric(horizontal: 15, vertical: 6),
                    decoration: BoxDecoration(
                      color: c.indexNavigationBar == 0
                          ? Colors.green[50]
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.home,
                          color: c.indexNavigationBar == 0
                              ? Colors.green[600]
                              : Colors.grey[400],
                          size: 25,
                        ),
                        SizedBox(width: 4),
                        Text(
                          "Home",
                          style: TextStyle(
                            color: c.indexNavigationBar == 0
                                ? Colors.green[600]
                                : Colors.grey[400],
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  onPressed: () {
                    //
                    c.indexNavigationBar = 0;
                    c.update();
                    context.replaceRoute(HomeView());
                  },
                ),

                IconButton(
                  icon: Container(
                    padding: EdgeInsets.symmetric(horizontal: 15, vertical: 6),
                    decoration: BoxDecoration(
                      color: c.indexNavigationBar == 1
                          ? Colors.green[50]
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shopping_cart,
                          color: c.indexNavigationBar == 1
                              ? Colors.green[600]
                              : Colors.grey[400],
                          size: 25,
                        ),
                        SizedBox(width: 4),
                        Text(
                          "Cart",
                          style: TextStyle(
                            color: c.indexNavigationBar == 1
                                ? Colors.green[600]
                                : Colors.grey[400],
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  onPressed: () {
                    //
                    c.indexNavigationBar = 1;
                    c.update();
                    context.replaceRoute(CartView());
                  },
                ),
                IconButton(
                  icon: Container(
                    padding: EdgeInsets.symmetric(horizontal: 15, vertical: 6),
                    decoration: BoxDecoration(
                      color: c.indexNavigationBar == 2
                          ? Colors.green[50]
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_3_sharp,
                          color: c.indexNavigationBar == 2
                              ? Colors.green[600]
                              : Colors.grey[400],
                          size: 25,
                        ),
                        SizedBox(width: 4),
                        Text(
                          "Profile",
                          style: TextStyle(
                            color: c.indexNavigationBar == 2
                                ? Colors.green[600]
                                : Colors.grey[400],
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  onPressed: () {
                    //
                    c.indexNavigationBar = 2;
                    c.update();
                    context.replaceRoute(ProfileView());
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
