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
        backgroundColor: Colors.green[600],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('About', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                children: [
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 6,
                    color: Colors.white,
                    child: Padding(
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
                            'Version 1.0.0',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'A friendly grocery shopping app — built as a capstone project for Research and Design.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Divider(color: Colors.grey[200]),
                          const SizedBox(height: 8),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.person,
                              color: Colors.green[600],
                            ),
                            title: const Text('Developer & Designer'),
                            subtitle: const Text('Joseph Maynite'),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.group,
                              color: Colors.green[600],
                            ),
                            title: const Text('Team Members'),
                            subtitle: const Text(
                              'Jethrick Guareno, Ferdinand Cabanlit, Nathaniel Valencia',
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Contact block: improved layout with clear actions
                          Padding(
                            padding: EdgeInsets.zero,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.email_outlined,
                                  color: Colors.green[600],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Contact',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[50],
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
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
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                OutlinedButton.icon(
                                                  onPressed: () async {
                                                    await Clipboard.setData(
                                                      const ClipboardData(
                                                        text:
                                                            'egcartmobile@gmail.com',
                                                      ),
                                                    );
                                                    final messenger =
                                                        ScaffoldMessenger.maybeOf(
                                                          context,
                                                        );
                                                    if (messenger != null) {
                                                      messenger.showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            'Email copied to clipboard',
                                                          ),
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
                                                const SizedBox(width: 12),
                                                ElevatedButton.icon(
                                                  onPressed: () async {
                                                    final uri = Uri.parse(
                                                      'mailto:egcartmobile@gmail.com?subject=Support',
                                                    );
                                                    try {
                                                      if (await canLaunchUrl(
                                                        uri,
                                                      ))
                                                        await launchUrl(uri);
                                                    } catch (_) {}
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.green[600],
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 10,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                  ),
                                                  icon: const Icon(
                                                    Icons.open_in_new_rounded,
                                                    size: 16,
                                                    color: Colors.white,
                                                  ),
                                                  label: Text(
                                                    'Mail',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.white,
                                                    ),
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
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () {
                                try {
                                  context.pushRoute(PrivacyPolicy());
                                } catch (_) {}
                              },
                              icon: Icon(
                                Icons.privacy_tip_outlined,
                                color: Colors.green[600],
                              ),
                              label: const Text('Privacy Policy',style: TextStyle(color: Colors.black),),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '© 2025 EG-Cart. All rights reserved.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
