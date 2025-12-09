import 'package:auto_route/auto_route.dart';
import 'package:egcart_mobile/route/route.gr.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

@RoutePage()
class AboutView extends StatefulWidget {
  const AboutView({super.key});

  @override
  State<AboutView> createState() => _AboutViewState();
}

class _AboutViewState extends State<AboutView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        toolbarHeight: 40,
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          systemNavigationBarColor: Colors.grey[50],
          statusBarIconBrightness: Brightness.dark,
        ),

        leading: InkWell(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: EdgeInsetsGeometry.only(left: 15),
            child: Row(
              children: [
                Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: Colors.grey[800],
                ),
                const SizedBox(width: 8),
                Text(
                  'Back',
                  style: TextStyle(fontSize: 17, color: Colors.grey[800]),
                ),
              ],
            ),
          ),
        ),
        leadingWidth: 150,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Center(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        width: 140,
                        height: 120,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'EG-Cart Mobile',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[900],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Version 1.3.7',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'A friendly grocery shopping app — built as a capstone project.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 16),
                      Divider(color: Colors.grey[200]),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.person, color: Colors.grey[600]),
                        title: const Text(
                          'Developer & Designer',
                          style: TextStyle(fontSize: 15),
                        ),
                        subtitle: const Text('Joseph Maynite'),
                      ),
                      const SizedBox(height: 10),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.group, color: Colors.grey[600]),
                        title: const Text(
                          'Team Members',
                          style: TextStyle(fontSize: 15),
                        ),
                        subtitle: const Text(
                          'Jethrick Guareno, Ferdinand Cabanlit, Nathaniel Valencia',
                        ),
                      ),
                      const SizedBox(height: 15),
                      // Contact block: improved layout with clear actions
                      Padding(
                        padding: EdgeInsets.zero,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.email_outlined, color: Colors.grey[600]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Contact',
                                    style: TextStyle(fontSize: 15),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    ),
                                    margin: EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(35),
                                      border: Border.all(
                                        color: Colors.grey[200]!,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SelectableText(
                                          'egcartmobile@gmail.com',
                                          style: TextStyle(
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              await Clipboard.setData(
                                const ClipboardData(
                                  text: 'egcartmobile@gmail.com',
                                ),
                              );
                              final messenger = ScaffoldMessenger.maybeOf(
                                context,
                              );
                              if (messenger != null) {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Email copied to clipboard'),
                                  ),
                                );
                              }
                            },
                            icon: Icon(
                              Icons.copy,
                              size: 18,
                              color: Colors.grey[700],
                            ),
                            label: Text(
                              'Copy',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 50),

                      Text(
                        '© 2025 EG-Cart. All rights reserved.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
