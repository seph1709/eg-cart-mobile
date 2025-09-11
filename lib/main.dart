import 'package:egcart_mobile/views/home_view.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(EGCartApp());
}

class EGCartApp extends StatelessWidget {
  const EGCartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return HomePage();
  }
}
