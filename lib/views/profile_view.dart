import 'package:auto_route/auto_route.dart';
import 'package:egcart_mobile/controller/supabase_controller.dart';
import 'package:egcart_mobile/route/route.gr.dart' hide WishlistView;
import 'package:egcart_mobile/views/widgets/bottom_navbar.dart';
import 'package:egcart_mobile/views/wishlist_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

@RoutePage()
class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  var isEditing = false;

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: isDestructive ? Colors.red[50] : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDestructive ? Colors.red[200]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.red[600] : Colors.green[600],
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDestructive ? Colors.red[600] : Colors.grey[800],
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: isDestructive ? Colors.red[400] : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEmail() async {
    final email = 'egcartmobile@gmail.com';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.support_agent_rounded,
                      color: Colors.green[600],
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contact Support',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[900],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'We typically respond within 24 hours.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'You can reach us at',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        email,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[900],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: email));
                        final messenger = ScaffoldMessenger.maybeOf(context);
                        if (messenger != null) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: const Text('Email copied to clipboard'),
                              backgroundColor: Colors.green[600],
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      icon: Icon(Icons.copy, color: Colors.grey[600], size: 20),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Or compose a message directly:',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        final subject = Uri.encodeComponent('Support Request');
                        final body = Uri.encodeComponent(
                          'Hi, I need help with...',
                        );
                        final uri = Uri.parse(
                          'mailto:$email?subject=$subject&body=$body',
                        );
                        try {
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          }
                        } catch (_) {
                          // ignore per user preference
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.open_in_new_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Open Mail App'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      'Close',
                      style: TextStyle(color: Colors.grey[800]),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<SupabaseController>();
    return MaterialApp(
      home: Scaffold(
        bottomNavigationBar: BottomNavBar(),
        appBar: AppBar(
          title: Text(
            "Profile",
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          backgroundColor: Colors.grey[50],
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.grey[50],
            systemNavigationBarColor: Colors.grey[50],
            statusBarIconBrightness: Brightness.dark,
          ),
          elevation: 0,
        ),
        body: Scaffold(
          backgroundColor: Colors.grey[50],
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    if (isEditing)
                                      SizedBox(
                                        height: 30,
                                        width: 200,
                                        child: TextField(
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade800,
                                          ),
                                          onSubmitted: (value) {
                                            setState(() {
                                              c.username = value;
                                              isEditing = false;
                                              c.saveLocalData();
                                            });
                                          },
                                          autofocus: true,
                                          decoration: InputDecoration(
                                            isCollapsed: true,
                                            hintStyle: TextStyle(
                                              color: Colors.grey.shade400,
                                              fontSize: 18,
                                            ),
                                            focusedBorder: UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                color: Colors.transparent,
                                              ),
                                            ),
                                            enabledBorder: InputBorder.none,
                                            hintText: "user name",
                                            isDense: false,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  vertical: 5,
                                                ),
                                            border: UnderlineInputBorder(),
                                          ),
                                        ),
                                      )
                                    else
                                      Row(
                                        children: [
                                          SizedBox(
                                            height: 30,
                                            child: Text(
                                              c.username,
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                isEditing = true;
                                              });
                                            },
                                            child: Icon(
                                              Icons.edit,
                                              size: 18,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
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
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Menu',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                    _buildMenuItem(
                      icon: Icons.history,
                      label: 'Order History',
                      onTap: () {
                        context.pushRoute(OrderedHistoryView());
                      },
                    ),
                    _buildMenuItem(
                      icon: Icons.favorite_outline,
                      label: 'Wishlist',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WishlistView(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      icon: Icons.help_outline,
                      label: 'Help & Support',
                      onTap: () {
                        _openEmail();
                      },
                    ),
                    _buildMenuItem(
                      icon: Icons.privacy_tip_outlined,
                      label: 'Privacy Policy',
                      onTap: () {
                        context.pushRoute(PrivacyPolicy());
                      },
                    ),
                    _buildMenuItem(
                      icon: Icons.info_outline,
                      label: 'About',
                      onTap: () {
                        context.pushRoute(AboutView());
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
