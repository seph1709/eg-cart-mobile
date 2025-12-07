import 'package:egcart_mobile/route/route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'controller/supabase_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: "assets/.env");

  final String supabaseKey = dotenv.env['SUPABASE_KEY']!;

  final String supabaseUrl = dotenv.env['SUPABASE_URL']!;

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);

  Get.put(SupabaseController());

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final _appRouter = AppRouter();

  MyApp({super.key}); // Initialize your AutoRouter

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: _appRouter.config(), // Use the delegate from your router
    );
  }
}
