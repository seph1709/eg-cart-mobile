import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:egcart_mobile/route/route.gr.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

@RoutePage()
class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  var showLoading = false;

  @override
  Widget build(BuildContext context) {
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
                  //ZWdjYXJ0MDAx
                  if (showLoading == false) {
                    setState(() {
                      showLoading = true;
                    });
                  }
                  final base64Decoder = base64.decoder;
                  final base64Bytes = result.barcodes.first.rawValue ?? "";
                  final decodedBytes = base64Decoder.convert(base64Bytes);
                  await Future.delayed(Duration(seconds: 2));
                  print(utf8.decode(decodedBytes));
                  if (utf8.decode(decodedBytes) == "egcart001") {
                    setState(() {
                      showLoading = false;
                    });
                    context.replaceRoute(HomeView());
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
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.all(Radius.circular(25)),
                    ),
                    padding: EdgeInsets.all(30),
                    child: CircularProgressIndicator(
                      color: Colors.green.shade800,
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
