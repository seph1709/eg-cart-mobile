import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class AboutView extends StatefulWidget {
  const AboutView({super.key});

  @override
  State<AboutView> createState() => _AboutViewState();
}

class _AboutViewState extends State<AboutView> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text('About EG-Cart'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Image.asset('assets/images/logo.png', width: 200, height: 150),
              Text(
                'EG-Cart Mobile Application',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              // SizedBox(height: 16),
              Text('Version 1.0.0', style: TextStyle(fontSize: 14)),
              SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'This application was developed as a capstone project for the course Research and Design.',
                  textAlign: TextAlign.justify,
                  style: TextStyle(fontSize: 14),
                ),
              ),
              SizedBox(height: 16),
              Text('Developer and Designer:', style: TextStyle(fontSize: 15)),
              Text('Joseph Maynite', style: TextStyle(fontSize: 15)),
              SizedBox(height: 16),
              Text("Other members:", style: TextStyle(fontSize: 15)),
              Text("Jethrick Guareno", style: TextStyle(fontSize: 15)),
              Text("Ferdinand Cabanlit", style: TextStyle(fontSize: 15)),
              Text("Nathaniel Valencia", style: TextStyle(fontSize: 15)),
              SizedBox(height: 32),
              Text(
                "You can contact us by this email address:",
                style: TextStyle(fontSize: 15),
              ),
              Text("egcartmobile@gmail.com", style: TextStyle(fontSize: 15)),
              SizedBox(height: 32),
              Text(
                '© 2025 EG-Cart. All rights reserved.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
