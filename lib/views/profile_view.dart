import 'package:auto_route/auto_route.dart';
import 'package:egcart_mobile/controller/supabase_controller.dart';
import 'package:egcart_mobile/route/route.gr.dart';
import 'package:egcart_mobile/views/widgets/bottom_navbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

@RoutePage()
class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  var isEditing = false;
  @override
  Widget build(BuildContext context) {
    final c = Get.find<SupabaseController>();
    return MaterialApp(
      home: Scaffold(
        bottomNavigationBar: BottomNavBar(),
        appBar: AppBar(
          leading: Container(
            alignment: Alignment.centerLeft,
            margin: EdgeInsets.only(left: 25),
            child: Text(
              "Profile",
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          leadingWidth: double.infinity,
          backgroundColor: Colors.grey[50],
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.grey[50],
            systemNavigationBarColor: Colors.grey[50],
            statusBarIconBrightness: Brightness.dark,
          ),
        ),
        body: Scaffold(
          backgroundColor: Colors.grey[50],
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 27),
                    child: Row(
                      children: [
                        IntrinsicWidth(
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(25),
                                  ),
                                ),
                                child: Icon(
                                  Icons.person,
                                  color: Colors.green.shade500,
                                  size: 35,
                                ),
                              ),
                              SizedBox(width: 10),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Welcome",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if (isEditing)
                                    SizedBox(
                                      height: 30,
                                      width: 200,
                                      child: TextField(
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade800,
                                        ),
                                        onSubmitted: (value) {
                                          setState(() {
                                            c.username = value;
                                            isEditing = false;
                                            c.saveLocalData();
                                          });
                                        },
                                        autofocus: true,
                                        decoration: InputDecoration(
                                          isCollapsed: true,

                                          hintStyle: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 18,
                                          ),
                                          focusedBorder: UnderlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Colors.transparent,
                                            ),
                                          ),
                                          enabledBorder: InputBorder.none,
                                          hintText: "user name",
                                          isDense: false,
                                          contentPadding: EdgeInsets.symmetric(
                                            vertical: 5,
                                          ),
                                          border: UnderlineInputBorder(),
                                        ),
                                      ),
                                    )
                                  else
                                    Row(
                                      children: [
                                        SizedBox(
                                          height: 30,
                                          child: Text(
                                            c.username,
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade800,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              isEditing = true;
                                            });
                                          },
                                          child: Icon(
                                            Icons.edit,
                                            size: 18,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: Colors.grey.shade300, height: 2),
                  InkWell(
                    onTap: () {
                      context.pushRoute(HistoryView());
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IntrinsicWidth(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.history,
                                  size: 30,
                                  color: Colors.grey.shade500,
                                ),
                                SizedBox(width: 15),
                                Text(
                                  "History",
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    fontSize: 17,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_sharp,
                            color: Colors.green.shade600,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(color: Colors.grey.shade300, height: 2),
                  InkWell(
                    onTap: () {
                      context.pushRoute(AboutView());
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IntrinsicWidth(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 30,
                                  color: Colors.grey.shade500,
                                ),
                                SizedBox(width: 15),
                                Text(
                                  "About",
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    fontSize: 17,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_sharp,
                            color: Colors.green.shade600,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(color: Colors.grey.shade300, height: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
