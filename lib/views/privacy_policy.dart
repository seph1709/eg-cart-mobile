import 'package:auto_route/auto_route.dart';
import 'package:egcart_mobile/controller/supabase_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:markdown_widget/config/all.dart';
import 'package:markdown_widget/widget/blocks/leaf/heading.dart';
import 'package:markdown_widget/widget/blocks/leaf/paragraph.dart';
import 'package:markdown_widget/widget/markdown.dart';

@RoutePage()
class PrivacyPolicy extends StatelessWidget {
  const PrivacyPolicy({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<SupabaseController>();
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          toolbarHeight: 40,
          backgroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.white,
            systemNavigationBarColor: Colors.white,
            statusBarIconBrightness: Brightness.dark,
          ),
          title: IntrinsicWidth(
            child: InkWell(
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
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Container(
                padding: EdgeInsets.only(left: 20, right: 20),
                decoration: BoxDecoration(color: Colors.white),
                child: MarkdownWidget(
                  config: MarkdownConfig(
                    configs: [
                      PConfig(textStyle: TextStyle(fontSize: 13)),
                      H2Config(
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      H3Config(
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  data: c.privacyPolicy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
