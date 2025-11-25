import 'package:auto_route/annotations.dart';
import 'package:auto_route/auto_route.dart';
import 'package:egcart_mobile/views/widgets/bottom_navbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

@RoutePage()
class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  @override
  Widget build(BuildContext context) {
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
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                  Text(
                                    "Joseph C. Maynite",
                                    style: TextStyle(
                                      color: Colors.grey.shade800,
                                      fontSize: 16,
                                    ),
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
                  Padding(
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
                  Divider(color: Colors.grey.shade300, height: 2),
                  Padding(
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
