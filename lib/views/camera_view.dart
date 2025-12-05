import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:egcart_mobile/controller/supabase_controller.dart';
import 'package:egcart_mobile/route/route.gr.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

@RoutePage()
class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  var showLoading = false;

  var note = "verifying..";

  @override
  Widget build(BuildContext context) {
    final c = Get.find<SupabaseController>();
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.black,
            systemNavigationBarColor: Colors.grey.shade50,
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              MobileScanner(
                onDetect: (result) async {
                  try {
                    if (showLoading == false) {
                      setState(() {
                        showLoading = true;
                      });
                    }

                    //ZWdjYXJ0MDAx
                    final base64Decoder = base64.decoder;
                    final base64Bytes = result.barcodes.first.rawValue ?? "";
                    final decodedBytes = base64Decoder.convert(base64Bytes);
                    if (kDebugMode) {
                      print(utf8.decode(decodedBytes));
                    }

                    var isValid = await c.verifyQRcode("cart001");

                    if (isValid) {
                      setState(() {
                        showLoading = false;
                      });
                      // ignore: use_build_context_synchronously
                      context.replaceRoute(HomeView());
                    } else {
                      setState(() {
                        note = "failed to verify :(";
                      });
                    }
                  } catch (e) {
                    setState(() {
                      note = "failed to verify :(";
                    });
                  }
                },
              ),
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    "Scan QR code",
                    style: TextStyle(color: Colors.grey.shade50, fontSize: 20),
                  ),
                ),
              ),
              if (showLoading)
                Align(
                  alignment: Alignment.center,
                  child: IntrinsicWidth(
                    child: IntrinsicHeight(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.all(Radius.circular(25)),
                        ),
                        padding: EdgeInsets.all(30),
                        child: Column(
                          children: [
                            CircularProgressIndicator(
                              color: Colors.green.shade800,
                            ),
                            SizedBox(height: 10),
                            Text("verifying.."),
                          ],
                        ),
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
