import 'package:auto_route/auto_route.dart';
import 'package:egcart_mobile/route/route.gr.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';

import '../controller/supabase_controller.dart';

@RoutePage()
class ScanView extends StatefulWidget {
  const ScanView({super.key});

  @override
  State<ScanView> createState() => _ScanViewState();
}

class _ScanViewState extends State<ScanView> {
  final textEditingController = TextEditingController();
  var showFloatingPrivacyPolicy = false;
  @override
  Widget build(BuildContext context) {
    final c = Get.find<SupabaseController>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
          backgroundColor: Colors.green.shade600,
          systemOverlayStyle: SystemUiOverlayStyle(
            systemNavigationBarColor: Colors.grey[50],
            statusBarIconBrightness: Brightness.light,
            statusBarColor: Colors.green.shade600,
          ),
        ),
        backgroundColor: Colors.grey[50],
        body: SafeArea(
          child: Stack(
            children: [
              Container(
                height: double.infinity,
                width: double.infinity,
                color: Colors.green.shade600,
                alignment: Alignment.topCenter,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: SvgPicture.asset("assets/images/QR-Code-bro.svg"),
                    ),
                  ],
                ),
              ),
              Align(
                alignment: AlignmentGeometry.bottomCenter,
                child: IntrinsicHeight(
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.only(bottom: 30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(25),
                        topRight: Radius.circular(25),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 35,
                            vertical: 30,
                          ),
                          child: Text(
                            "Please scan the QR code displayed in the cart or input the pin code to proceed.",
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          width: 250,
                          child: TextField(
                            onSubmitted: (value) async {
                              var val = int.tryParse(value);
                              if (val != null) {
                                var isValid = await c.verifyPinCode(val);
                                if (isValid) {
                                  // ignore: use_build_context_synchronously
                                  context.replaceRoute(HomeView());
                                }
                              }
                            },
                            controller: textEditingController,
                            autofocus: false,
                            style: TextStyle(fontSize: 19),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              border: InputBorder.none,
                              hint: Center(
                                child: Text(
                                  "INPUT PIN CODE",
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          margin: EdgeInsets.symmetric(vertical: 10),
                          child: Text("OR"),
                        ),
                        IntrinsicHeight(
                          child: GestureDetector(
                            onTap: () {
                              context.pushRoute(CameraView());
                            },
                            child: Container(
                              width: 250,
                              margin: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 2,
                              ),
                              padding: EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.4),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.green[500]!,
                                    Colors.green[700]!,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.all(
                                  Radius.circular(10),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: GetBuilder<SupabaseController>(
                                builder: (c) {
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.qr_code,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        "Scan QR code",
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            text: "By using this app, you agree to our\n",
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 13,
                            ),
                            children: [
                              WidgetSpan(
                                child: Container(
                                  padding: EdgeInsets.only(top: 5),
                                  child: RichText(
                                    text: TextSpan(
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () {
                                          context.pushRoute(PrivacyPolicy());
                                        },
                                      text: "Privacy Policy.",
                                      style: TextStyle(
                                        color: Colors.green[800],
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
