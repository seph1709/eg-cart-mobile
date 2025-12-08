import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// A top-level widget that shows a modal overlay when the device is NOT
/// connected to Wi‑Fi. Place this above your `MaterialApp` (or wrap it
/// around the app) so it appears regardless of the current route.
class ConnectivityGate extends StatefulWidget {
  final Widget child;

  const ConnectivityGate({super.key, required this.child});

  @override
  State<ConnectivityGate> createState() => _ConnectivityGateState();
}

class _ConnectivityGateState extends State<ConnectivityGate> {
  late StreamSubscription<ConnectivityResult> _sub;
  bool _isWifi = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _sub = Connectivity().onConnectivityChanged.listen(_update);
    // Some platforms may not reliably emit connectivity changes for
    // Wi‑Fi toggles. Poll periodically as a fallback.
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final res = await Connectivity().checkConnectivity();
        _update(res);
      } catch (_) {}
    });
  }

  Future<void> _initConnectivity() async {
    final res = await Connectivity().checkConnectivity();
    _update(res);
  }

  void _update(ConnectivityResult r) {
    final isWifi = r == ConnectivityResult.wifi;
    if (!mounted) return;
    if (isWifi != _isWifi) {
      setState(() {
        _isWifi = isWifi;
      });
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (!_isWifi)
          Positioned.fill(
            child: Material(
              color: Colors.black45,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: _NoWifiModal(onRetry: _initConnectivity),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NoWifiModal extends StatelessWidget {
  final VoidCallback onRetry;

  const _NoWifiModal({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final green = Colors.green[600]!;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(Icons.wifi_off_rounded, color: green, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No Wi‑Fi connection',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[900],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'You are not connected to a Wi-Fi network. This app is designed to work only with an active Wi-Fi connection because it uses IPS. In order for it to work, the app needs to listen for incoming websocket data from the UWB. Please connect to the Wi-Fi network where the UWB is connected.',
              style: TextStyle(color: Colors.grey[800]),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onRetry,
                  child: Text('Retry', style: TextStyle(color: green)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: onRetry,
                  child: const Text(
                    'Check Again',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
