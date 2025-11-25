import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:collection';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

double metersToPixels(double meters, {int baseConvertion = 100}) {
  return (meters * baseConvertion).toDouble();
}

double pixelsToMeters(double pixels, {double baseConvertion = 100.0}) {
  return pixels / baseConvertion;
}

@RoutePage()
class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ✅ Initial configuration values
  final String _esp32IpAddress = "192.168.1.100";
  final String _targetCartId = "cart001";
  num baseConvertion = 100;
  double roomWidth = 7.5;
  double roomHeight = 7.0;

  // ✅ Product locations list (in meters, independent of GeoJSON)
  List<Map<String, dynamic>> listOfProductsLocation = [
    {"id": "P001", "position": const Offset(1.0, 1.0)},
    {"id": "P002", "position": const Offset(2.0, 3.0)},
    {"id": "P003", "position": const Offset(4.0, 5.0)},
  ];

  // ✅ GeoJSON map data
  Map<String, dynamic>? geoJsonData;
  String? _loadedFileName;

  // ✅ Computed paths (updated when tag position changes)
  Map<String, List<Offset>> _computedPaths = {};
  Offset? _lastPathComputePosition;

  // ✅ Hidden product IDs (paths not shown when tapped)
  Set<String> _hiddenProductPaths = {};

  // ✅ Nearest product ID (dynamically updated)
  String? _nearestProductId;

  // ✅ Follow/focus mode
  bool _isFollowingTag = false;

  String get _wsUrl => 'ws://$_esp32IpAddress/ws';
  var links =
      "{\"links\":[{\"A\":\"A0084\",\"R\":\"6.10\"},{\"A\":\"A0085\",\"R\":\"4.30\"},{\"A\":\"A0086\",\"R\":\"6.10\"},{\"A\":\"A0087\",\"R\":\"4.30\"}]}";

  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isConnecting = false;
  int _reconnectAttempts = 0;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  DateTime? _lastMessageTime;
  StreamSubscription? _streamSubscription;

  static const List<int> _backoffDelays = [3, 6, 12, 30, 60];
  static const Duration _pingInterval = Duration(seconds: 30);
  static const Duration _heartbeatTimeout = Duration(seconds: 90);
  static const Duration _connectionTimeout = Duration(seconds: 10);

  Offset? _currentTagPosition;
  double _currentAccuracy = 0.0;
  late AnimationController _animationController;
  late Animation<Offset> _positionAnimation;

  late AnimationController _arrowAnimationController;

  final TransformationController _transformationController =
      TransformationController();

  Map<String, Offset> get anchorPositions => {
    "A0084": const Offset(0, 0),
    "A0085": Offset(roomWidth, 0),
    "A0086": Offset(0, roomHeight),
    "A0087": Offset(roomWidth, roomHeight),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _arrowAnimationController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat();

    _loadDefaultGeoJsonData();
    _connectWebSocket();
    _startHeartbeatMonitor();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _processPositionUpdate(links);
        _setInitialZoom();
      }
    });
  }

  // ✅ Request storage permission
  Future<bool> _requestStoragePermission() async {
    if (kIsWeb) {
      return true;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidInfo = await _getAndroidVersion();
      if (androidInfo >= 33) {
        return true;
      }

      var status = await Permission.storage.status;

      if (status.isDenied) {
        status = await Permission.storage.request();
      }

      if (status.isPermanentlyDenied) {
        if (mounted) {
          _showPermissionDialog();
        }
        return false;
      }

      return status.isGranted;
    }

    return true;
  }

  Future<int> _getAndroidVersion() async {
    return 33;
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Storage Permission Required'),
        content: const Text(
          'This app needs storage permission to access files. Please grant the permission in app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _loadDefaultGeoJsonData() {
    const String geoJsonString = '''
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "featureType": "metadata",
        "roomName": "Untitled Map",
        "roomWidth": 7.5,
        "roomHeight": 7.0,
        "roomArea": 52.5,
        "baseLatitude": 43.60666618464,
        "baseLongitude": 3.92162187466,
        "currentLevel": 0,
        "origin": "bottom-left",
        "layers": [
          {
            "name": "Default Layer",
            "isVisible": true
          }
        ],
        "globalSettings": {
          "strokeThickness": 2.0,
          "labelFontSize": 12.0,
          "showGrid": true,
          "snapToGrid": true,
          "gridSize": 1.0
        },
        "timestamp": "2025-11-25T19:02:25.988584",
        "createdWith": "Indoor Map Creator v1.0"
      },
      "geometry": null
    },
    {
      "type": "Feature",
      "properties": {
        "indoor": "yes",
        "level": "0",
        "name": "Bottom Wall",
        "amenity": "wall"
      },
      "geometry": {
        "type": "LineString",
        "coordinates": [
          [3.92162187466, 43.60666618464],
          [3.9217149199820662, 43.60666618464]
        ]
      }
    },
    {
      "type": "Feature",
      "properties": {
        "indoor": "yes",
        "level": "0",
        "name": "Right Wall",
        "amenity": "wall"
      },
      "geometry": {
        "type": "LineString",
        "coordinates": [
          [3.9217149199820662, 43.60666618464],
          [3.9217149199820662, 43.60672906642225]
        ]
      }
    },
    {
      "type": "Feature",
      "properties": {
        "indoor": "yes",
        "level": "0",
        "name": "Top Wall",
        "amenity": "wall"
      },
      "geometry": {
        "type": "LineString",
        "coordinates": [
          [3.9217149199820662, 43.60672906642225],
          [3.92162187466, 43.60672906642225]
        ]
      }
    },
    {
      "type": "Feature",
      "properties": {
        "indoor": "yes",
        "level": "0",
        "name": "Left Wall",
        "amenity": "wall"
      },
      "geometry": {
        "type": "LineString",
        "coordinates": [
          [3.92162187466, 43.60672906642225],
          [3.92162187466, 43.60666618464]
        ]
      }
    },
    {
      "type": "Feature",
      "properties": {
        "indoor": "yes",
        "level": "0",
        "name": "Room 5",
        "amenity": "room",
        "building:part": "room"
      },
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          [
            [3.9216321387220905, 43.60671291085721],
            [3.9216569508079746, 43.60671291085721],
            [3.9216569508079746, 43.60672189396896],
            [3.9216321387220905, 43.60672189396896],
            [3.9216321387220905, 43.60671291085721]
          ]
        ]
      }
    },
    {
      "type": "Feature",
      "properties": {
        "indoor": "yes",
        "level": "0",
        "name": "Circle 6",
        "amenity": "area",
        "radius": "0.5"
      },
      "geometry": {
        "type": "Point",
        "coordinates": [3.9216714988317687, 43.6067200833105]
      }
    },
    {
      "type": "Feature",
      "properties": {
        "indoor": "yes",
        "level": "0",
        "name": "Room 7",
        "amenity": "room",
        "building:part": "room"
      },
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          [
            [3.9216466867458846, 43.606702117086996],
            [3.9216466867458846, 43.60669313397525],
            [3.9216590927888264, 43.60669313397525],
            [3.9216590927888264, 43.606702117086996],
            [3.9216466867458846, 43.606702117086996],
            [3.9216466867458846, 43.606702117086996]
          ]
        ]
      }
    },
    {
      "type": "Feature",
      "properties": {
        "indoor": "yes",
        "level": "0",
        "name": "Door 8",
        "amenity": "entrance",
        "door": "yes"
      },
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          [
            [3.921628077681471, 43.60666573548441],
            [3.9216404837244134, 43.60666573548441],
            [3.9216404837244134, 43.606666633795584],
            [3.921628077681471, 43.606666633795584],
            [3.921628077681471, 43.60666573548441]
          ]
        ]
      }
    },
    {
      "type": "Feature",
      "properties": {
        "indoor": "yes",
        "level": "0",
        "name": "Window 9",
        "amenity": "window",
        "building:part": "window"
      },
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          [
            [3.921662194299562, 43.60666573548441],
            [3.921680803363975, 43.60666573548441],
            [3.921680803363975, 43.606666633795584],
            [3.921662194299562, 43.606666633795584],
            [3.921662194299562, 43.60666573548441]
          ]
        ]
      }
    },
    {
      "type": "Feature",
      "properties": {
        "indoor": "yes",
        "level": "0",
        "name": "Stairs 10",
        "amenity": "stairs"
      },
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          [
            [3.9216882082208566, 43.60666633903723],
            [3.9217130203067407, 43.60666633903723],
            [3.9217130203067407, 43.60667981370486],
            [3.9216882082208566, 43.60667981370486],
            [3.9216882082208566, 43.60666633903723]
          ]
        ]
      }
    },
    {
      "type": "Feature",
      "properties": {
        "indoor": "yes",
        "level": "0",
        "name": "Label 11",
        "description": "Label"
      },
      "geometry": {
        "type": "Point",
        "coordinates": [3.921683904874711, 43.606702117086996]
      }
    },
    {
      "type": "Feature",
      "properties": {
        "indoor": "yes",
        "level": "0",
        "name": "Path 12",
        "highway": "footway"
      },
      "geometry": {
        "type": "LineString",
        "coordinates": [
          [3.9216714988317687, 43.606675167751746],
          [3.9216714988317687, 43.606711100198744],
          [3.9216342807029423, 43.606711100198744],
          [3.921708716960595, 43.606711100198744],
          [3.921708716960595, 43.6066841508635],
          [3.9216342807029423, 43.6066841508635],
          [3.9216342807029423, 43.606711100198744]
        ]
      }
    }
  ]
}
''';

    _parseGeoJsonString(geoJsonString);
    _loadedFileName = 'Default Map';
  }

  void _parseGeoJsonString(String geoJsonString) {
    try {
      final data = jsonDecode(geoJsonString) as Map<String, dynamic>;

      final features = data['features'] as List?;
      if (features != null) {
        for (var feature in features) {
          final properties = feature['properties'] as Map<String, dynamic>?;
          if (properties?['featureType'] == 'metadata') {
            setState(() {
              roomWidth = (properties?['roomWidth'] ?? 7.5).toDouble();
              roomHeight = (properties?['roomHeight'] ?? 7.0).toDouble();
              geoJsonData = data;
            });
            if (kDebugMode) {
              print('✅ Loaded GeoJSON: ${roomWidth}m x ${roomHeight}m');
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _setInitialZoom();
              }
            });
            return;
          }
        }
      }

      setState(() {
        geoJsonData = data;
      });
    } catch (e) {
      if (kDebugMode) print('❌ Failed to parse GeoJSON: $e');
      _showSnackBar('Failed to parse GeoJSON file', isError: true);
    }
  }

  Future<void> _pickGeoJsonFile() async {
    try {
      final hasPermission = await _requestStoragePermission();

      if (!hasPermission) {
        _showSnackBar('Storage permission denied', isError: true);
        if (kDebugMode) print('⚠️ Storage permission denied');
        return;
      }

      if (kDebugMode) print('✅ Storage permission granted');

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'geojson'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        final geoJsonString = utf8.decode(bytes);

        _parseGeoJsonString(geoJsonString);

        setState(() {
          _loadedFileName = result.files.single.name;
        });

        _showSnackBar('✅ Loaded: ${result.files.single.name}');

        if (kDebugMode) {
          print('✅ GeoJSON file loaded: ${result.files.single.name}');
        }
      } else {
        if (kDebugMode) print('⚠️ File picker cancelled');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error picking file: $e');
      _showSnackBar('Failed to load file', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _setInitialZoom() {
    final screenWidth = MediaQuery.of(context).size.width;
    final canvasWidth =
        metersToPixels(roomWidth, baseConvertion: baseConvertion.toInt()) + 100;

    final scale = (screenWidth - 40) / canvasWidth;
    final scaledWidth = canvasWidth * scale;
    final offsetX = (screenWidth - scaledWidth) / 2;

    final matrix = Matrix4.identity()
      ..translate(offsetX, 20.0)
      ..scale(scale);

    _transformationController.value = matrix;

    if (kDebugMode) {
      print(
        '🔍 Zoom set: scale=${scale.toStringAsFixed(3)}, screenWidth=$screenWidth, canvasWidth=$canvasWidth',
      );
    }
  }

  // ✅ Center view on tag position with smooth animation
  void _centerOnTag() {
    if (_currentTagPosition == null) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Convert tag position to canvas pixels
    final tagCanvasX =
        metersToPixels(
          _currentTagPosition!.dx,
          baseConvertion: baseConvertion.toInt(),
        ) +
        50;
    final tagCanvasY =
        metersToPixels(
          roomHeight - _currentTagPosition!.dy,
          baseConvertion: baseConvertion.toInt(),
        ) +
        50;

    // Get current scale
    final currentMatrix = _transformationController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();

    // Use zoom level of 1.5x for good visibility
    final targetScale = 1.5;

    // Calculate offset to center tag on screen
    final offsetX = screenWidth / 2 - (tagCanvasX * targetScale);
    final offsetY = screenHeight / 2 - (tagCanvasY * targetScale);

    // Create new matrix
    final newMatrix = Matrix4.identity()
      ..translate(offsetX, offsetY)
      ..scale(targetScale);

    // Animate to new position
    _transformationController.value = newMatrix;

    if (kDebugMode) {
      print(
        '📍 Centered on tag at (${_currentTagPosition!.dx.toStringAsFixed(2)}, ${_currentTagPosition!.dy.toStringAsFixed(2)})',
      );
    }
  }

  // ✅ Toggle follow mode
  void _toggleFollowMode() {
    setState(() {
      _isFollowingTag = !_isFollowingTag;
    });

    if (_isFollowingTag) {
      _centerOnTag();
      if (kDebugMode) print('✅ Follow mode enabled');
    } else {
      if (kDebugMode) print('❌ Follow mode disabled');
    }
  }

  // ✅ Compute paths for all products from current tag position
  void _computePathsFromTag() {
    if (_currentTagPosition == null || geoJsonData == null) return;

    if (_lastPathComputePosition != null) {
      final distance = math.sqrt(
        math.pow(_currentTagPosition!.dx - _lastPathComputePosition!.dx, 2) +
            math.pow(_currentTagPosition!.dy - _lastPathComputePosition!.dy, 2),
      );
      if (distance < 0.2) {
        return;
      }
    }

    if (kDebugMode) {
      print(
        '🔄 Recomputing paths from tag position: (${_currentTagPosition!.dx.toStringAsFixed(2)}, ${_currentTagPosition!.dy.toStringAsFixed(2)})',
      );
    }

    final pathfinder = Pathfinder(
      roomWidth: roomWidth,
      roomHeight: roomHeight,
      geoJsonData: geoJsonData,
      gridResolution: 0.08,
      obstacleBuffer: 0.15,
      goalTolerance: 0.25,
    );

    final newPaths = <String, List<Offset>>{};

    for (var product in listOfProductsLocation) {
      final productId = product['id'] as String;
      final productPosition = product['position'] as Offset;

      final path = pathfinder.findPath(_currentTagPosition!, productPosition);

      if (path != null && path.length > 1) {
        newPaths[productId] = path;
      }
    }

    _updateNearestProduct();

    setState(() {
      _computedPaths = newPaths;
      _lastPathComputePosition = _currentTagPosition;
    });

    if (kDebugMode) {
      print('✅ Computed ${newPaths.length} paths');
      print('🎯 Nearest product: $_nearestProductId');
    }
  }

  // ✅ Update which product is nearest (excluding hidden products)
  void _updateNearestProduct() {
    if (_currentTagPosition == null) return;

    String? nearestId;
    double nearestDistance = double.infinity;

    for (var product in listOfProductsLocation) {
      final productId = product['id'] as String;

      if (_hiddenProductPaths.contains(productId)) {
        continue;
      }

      final productPosition = product['position'] as Offset;
      final distance = math.sqrt(
        math.pow(_currentTagPosition!.dx - productPosition.dx, 2) +
            math.pow(_currentTagPosition!.dy - productPosition.dy, 2),
      );

      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestId = productId;
      }
    }

    setState(() {
      _nearestProductId = nearestId;
    });
  }

  // ✅ Handle tap on product pinpoint
  void _handleProductTap(Offset tapPosition) {
    final matrix = _transformationController.value;

    final inverseMatrix = Matrix4.inverted(matrix);
    final transformedPoint = MatrixUtils.transformPoint(
      inverseMatrix,
      tapPosition,
    );

    final metersX = pixelsToMeters(
      transformedPoint.dx - 50,
      baseConvertion: baseConvertion.toDouble(),
    );
    final metersY =
        roomHeight -
        pixelsToMeters(
          transformedPoint.dy - 50,
          baseConvertion: baseConvertion.toDouble(),
        );

    if (kDebugMode) {
      print(
        '👆 Tap at canvas: (${metersX.toStringAsFixed(2)}, ${metersY.toStringAsFixed(2)})',
      );
    }

    for (var product in listOfProductsLocation) {
      final productId = product['id'] as String;
      final productPos = product['position'] as Offset;

      final distance = math.sqrt(
        math.pow(metersX - productPos.dx, 2) +
            math.pow(metersY - productPos.dy, 2),
      );

      if (distance < 0.3) {
        setState(() {
          if (_hiddenProductPaths.contains(productId)) {
            _hiddenProductPaths.remove(productId);
            if (kDebugMode) print('✅ Showing path to $productId');
          } else {
            _hiddenProductPaths.add(productId);
            if (kDebugMode) print('❌ Hiding path to $productId');
          }
          _updateNearestProduct();
        });
        return;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanup();
    _animationController.dispose();
    _arrowAnimationController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kDebugMode) print('📱 App lifecycle: $state');
    if (state == AppLifecycleState.paused) {
      if (kDebugMode) print('⏸️ App paused - maintaining connection');
    } else if (state == AppLifecycleState.resumed) {
      if (kDebugMode) print('▶️ App resumed - checking connection');
      _checkConnectionHealth();
    }
  }

  void _cleanup() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _streamSubscription?.cancel();
    _channel?.sink.close(status.goingAway);
    _isConnected = false;
    _isConnecting = false;
  }

  void _startHeartbeatMonitor() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_lastMessageTime != null) {
        final timeSinceLastMessage = DateTime.now().difference(
          _lastMessageTime!,
        );
        if (timeSinceLastMessage > _heartbeatTimeout && _isConnected) {
          if (kDebugMode) {
            print(
              '💔 Heartbeat timeout: ${timeSinceLastMessage.inSeconds}s since last message',
            );
          }
          _handleSilentDisconnection();
        }
      }
    });
  }

  void _handleSilentDisconnection() {
    if (kDebugMode) print('🔌 Detected silent disconnection');
    _isConnected = false;
    _reconnectWithBackoff();
  }

  void _checkConnectionHealth() {
    if (!_isConnected && !_isConnecting) {
      if (kDebugMode) print('🔍 Connection unhealthy, attempting reconnect');
      _reconnectWithBackoff();
    } else if (_lastMessageTime != null) {
      final timeSince = DateTime.now().difference(_lastMessageTime!);
      if (timeSince > _heartbeatTimeout) {
        _handleSilentDisconnection();
      }
    }
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (timer) {
      if (_isConnected && _channel != null) {
        try {
          _channel!.sink.add('ping');
          if (kDebugMode) print('🏓 Ping sent');
        } catch (e) {
          if (kDebugMode) print('❌ Ping failed: $e');
          _handleSilentDisconnection();
        }
      }
    });
  }

  Future<void> _connectWebSocket() async {
    if (_isConnecting) {
      if (kDebugMode) print('⏳ Already connecting...');
      return;
    }

    _isConnecting = true;
    _cleanup();

    try {
      if (kDebugMode) print('🔌 Connecting to WebSocket: $_wsUrl');
      try {
        _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
        final timeoutFuture = Future.delayed(_connectionTimeout, () => false);
        final connectionFuture = _channel!.stream.first.then((_) => true);
        final connected = await Future.any([connectionFuture, timeoutFuture]);

        if (!connected) {
          throw TimeoutException('WebSocket connection timeout');
        }

        _streamSubscription = _channel!.stream.listen(
          _onWebSocketMessage,
          onError: _onWebSocketError,
          onDone: _onWebSocketDone,
          cancelOnError: false,
        );

        setState(() {
          _isConnected = true;
          _isConnecting = false;
          _reconnectAttempts = 0;
        });
        _lastMessageTime = DateTime.now();
        _startPingTimer();
        if (kDebugMode) print('✅ WebSocket connected successfully');
      } catch (e) {
        _channel?.sink.close(status.goingAway);
        _channel = null;
        rethrow;
      }
    } catch (e) {
      if (kDebugMode) print('❌ WebSocket Connection Error: $e');
      setState(() {
        _isConnected = false;
        _isConnecting = false;
      });
      _reconnectWithBackoff();
    }
  }

  void _reconnectWithBackoff() {
    _reconnectTimer?.cancel();
    final delayIndex = math.min(_reconnectAttempts, _backoffDelays.length - 1);
    final delay = Duration(seconds: _backoffDelays[delayIndex]);
    if (kDebugMode) {
      print(
        '🔄 Reconnect attempt ${_reconnectAttempts + 1} in ${delay.inSeconds}s',
      );
    }

    _reconnectTimer = Timer(delay, () {
      if (mounted && !_isConnected) {
        _reconnectAttempts++;
        _connectWebSocket();
      }
    });
  }

  void _onWebSocketMessage(dynamic message) {
    try {
      _lastMessageTime = DateTime.now();
      if (kDebugMode) print('📡 WebSocket message received: $message');
      if (message == 'pong') {
        if (kDebugMode) print('🏓 Pong received');
        return;
      }

      final Map<String, dynamic> data = jsonDecode(message);
      if (data['cart_id'] == _targetCartId) {
        final List<dynamic> anchors = data['anchors'] ?? [];
        final List<Map<String, String>> transformedLinks = anchors.map((
          anchor,
        ) {
          return {
            'A': anchor['anchor_id'].toString(),
            'R': anchor['range_m'].toString(),
          };
        }).toList();

        final newLinks = jsonEncode({'links': transformedLinks});
        if (kDebugMode) print('✅ Transformed data: $newLinks');
        _processPositionUpdate(newLinks);
      } else {
        if (kDebugMode) {
          print(
            '⚠️ Ignoring data from cart_id: ${data['cart_id']} (expected: $_targetCartId)',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Parse Error: $e');
        print('Raw message: $message');
      }
    }
  }

  void _onWebSocketError(dynamic error) {
    if (kDebugMode) print('❌ WebSocket Error: $error');
    setState(() {
      _isConnected = false;
    });
    _reconnectWithBackoff();
  }

  void _onWebSocketDone() {
    if (kDebugMode) print('⚠️ WebSocket connection closed');
    setState(() {
      _isConnected = false;
    });
    _reconnectWithBackoff();
  }

  void _processPositionUpdate(String newLinks) {
    try {
      final decodedData = jsonDecode(newLinks);
      final linksArray = decodedData["links"] as List;

      List<Anchor> listOfAnchors = linksArray.map((link) {
        final anchorId = link["A"].toString();
        final position = anchorPositions[anchorId] ?? const Offset(0, 0);
        return Anchor(
          link["R"].toString(),
          id: anchorId,
          position: position,
          size: const Size(1000, 1000),
          baseConvertion: baseConvertion,
        );
      }).toList();

      final activeAnchors = listOfAnchors.where((a) => a.distance > 0).toList();
      if (activeAnchors.length < 3) {
        if (kDebugMode) print('⚠️ Not enough anchors: ${activeAnchors.length}');
        return;
      }

      Trilateration trilateration = Trilateration(activeAnchors);
      final result = trilateration.calcUserLocation();

      if (result != null) {
        final position = result['position'] as Offset;
        final accuracy = result['accuracy'] as double;
        final constrainedPosition = Offset(
          position.dx.clamp(0.0, roomWidth),
          position.dy.clamp(0.0, roomHeight),
        );

        if (kDebugMode) {
          print(
            '✅ Tag position: (${constrainedPosition.dx.toStringAsFixed(2)}, ${constrainedPosition.dy.toStringAsFixed(2)})m, accuracy: ±${accuracy.toStringAsFixed(2)}m',
          );
        }

        _updateTagPosition(constrainedPosition, accuracy);
      }

      setState(() {
        links = newLinks;
      });
    } catch (e) {
      if (kDebugMode) print('❌ Position calculation error: $e');
    }
  }

  void _updateTagPosition(Offset newPosition, double accuracy) {
    if (_currentTagPosition == null) {
      setState(() {
        _currentTagPosition = newPosition;
        _currentAccuracy = accuracy;
      });
      _computePathsFromTag();

      // ✅ Center on tag if follow mode is enabled
      if (_isFollowingTag) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _centerOnTag();
        });
      }
      return;
    }

    _currentAccuracy = accuracy;
    _positionAnimation =
        Tween<Offset>(begin: _currentTagPosition!, end: newPosition).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );
    _animationController.forward(from: 0.0).then((_) {
      setState(() {
        _currentTagPosition = newPosition;
      });
      _computePathsFromTag();

      // ✅ Keep tag centered if follow mode is enabled
      if (_isFollowingTag) {
        _centerOnTag();
      }
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final canvasWidth =
        metersToPixels(roomWidth, baseConvertion: baseConvertion.toInt()) + 100;
    final canvasHeight =
        metersToPixels(roomHeight, baseConvertion: baseConvertion.toInt()) +
        100;

    final displayPosition =
        _currentTagPosition != null && _animationController.isAnimating
        ? _positionAnimation.value
        : _currentTagPosition;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          GestureDetector(
            onTapDown: (details) {
              _handleProductTap(details.localPosition);
            },
            // ✅ Disable InteractiveViewer gestures when following tag
            child: AnimatedBuilder(
              animation: _arrowAnimationController,
              builder: (context, child) {
                return InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.3,
                  maxScale: 4.0,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  constrained: false,
                  // ✅ Disable panning when in follow mode
                  panEnabled: !_isFollowingTag,
                  scaleEnabled: !_isFollowingTag,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: StaticMapCanvas(
                        roomWidth: roomWidth,
                        roomHeight: roomHeight,
                        baseConvertion: baseConvertion,
                        tagPosition: displayPosition,
                        tagAccuracy: _currentAccuracy,
                        productsLocation: listOfProductsLocation,
                        geoJsonData: geoJsonData,
                        computedPaths: _computedPaths,
                        hiddenProductPaths: _hiddenProductPaths,
                        nearestProductId: _nearestProductId,
                        animationValue: _arrowAnimationController.value,
                      ),
                      size: Size(canvasWidth, canvasHeight),
                    ),
                  ),
                );
              },
            ),
          ),

          // ✅ Load Map button (top right)
          Positioned(
            top: 16,
            right: 16,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              shadowColor: Colors.black26,
              child: InkWell(
                onTap: _pickGeoJsonFile,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.map, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        _loadedFileName ?? 'Load Map',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ✅ Follow/Focus button (bottom right)
          Positioned(
            bottom: 24,
            right: 24,
            child: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(56),
              shadowColor: Colors.black38,
              child: InkWell(
                onTap: _toggleFollowMode,
                borderRadius: BorderRadius.circular(56),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isFollowingTag
                          ? [const Color(0xFF10b981), const Color(0xFF059669)]
                          : [const Color(0xFF6366f1), const Color(0xFF4f46e5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(56),
                  ),
                  child: Icon(
                    _isFollowingTag ? Icons.gps_fixed : Icons.gps_not_fixed,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),

          // ✅ Follow mode indicator (top center)
          if (_isFollowingTag)
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(24),
                  color: const Color(0xFF10b981),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.my_location,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Following Cart',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ... (Rest of the code remains exactly the same: PathNode, Pathfinder, ObstacleGeometry, PriorityQueue, StaticMapCanvas, Anchor, Trilateration classes)

class PathNode {
  final Offset position;
  final PathNode? parent;
  final double g;
  final double h;
  double get f => g + h;

  PathNode(this.position, this.parent, this.g, this.h);

  @override
  bool operator ==(Object other) =>
      other is PathNode && position == other.position;

  @override
  int get hashCode => position.hashCode;
}

class Pathfinder {
  final double roomWidth;
  final double roomHeight;
  final Map<String, dynamic>? geoJsonData;
  final double gridResolution;
  final double obstacleBuffer;
  final double goalTolerance;
  double baseLat = 43.60666618464;
  double baseLon = 3.92162187466;

  final List<ObstacleGeometry> _obstacles = [];

  Pathfinder({
    required this.roomWidth,
    required this.roomHeight,
    this.geoJsonData,
    this.gridResolution = 0.08,
    this.obstacleBuffer = 0.15,
    this.goalTolerance = 0.25,
  }) {
    _extractBaseCoordinates();
    _buildObstacleCache();
  }

  void _extractBaseCoordinates() {
    if (geoJsonData == null) return;

    final features = geoJsonData!['features'] as List?;
    if (features == null) return;

    for (var feature in features) {
      final properties = feature['properties'] as Map<String, dynamic>?;
      if (properties?['featureType'] == 'metadata') {
        baseLat = (properties?['baseLatitude'] ?? baseLat).toDouble();
        baseLon = (properties?['baseLongitude'] ?? baseLon).toDouble();
        break;
      }
    }
  }

  void _buildObstacleCache() {
    _obstacles.clear();
    if (geoJsonData == null) return;

    final features = geoJsonData!['features'] as List?;
    if (features == null) return;

    for (var feature in features) {
      final geometry = feature['geometry'];
      final properties = feature['properties'] as Map<String, dynamic>?;
      final amenity = properties?['amenity'] as String?;

      if (geometry == null) continue;

      final geometryType = geometry['type'] as String?;

      if (amenity == 'wall' || amenity == 'room' || amenity == 'stairs') {
        if (geometryType == 'Polygon') {
          _obstacles.add(
            ObstacleGeometry(
              type: ObstacleType.polygon,
              points: _extractPolygonPoints(geometry),
            ),
          );
        } else if (geometryType == 'LineString' && amenity == 'wall') {
          _obstacles.add(
            ObstacleGeometry(
              type: ObstacleType.line,
              points: _extractLinePoints(geometry),
            ),
          );
        }
      }

      if (geometryType == 'Point' &&
          amenity == 'area' &&
          properties?['radius'] != null) {
        final coordinates = geometry['coordinates'] as List?;
        if (coordinates != null && coordinates.length >= 2) {
          final lon = (coordinates[0] as num).toDouble();
          final lat = (coordinates[1] as num).toDouble();
          final center = _latLonToMeters(lon, lat);
          final radiusMeters =
              double.tryParse(properties!['radius'] as String) ?? 0.5;

          _obstacles.add(
            ObstacleGeometry(
              type: ObstacleType.circle,
              points: [center],
              radius: radiusMeters,
            ),
          );
        }
      }
    }
  }

  List<Offset> _extractPolygonPoints(Map<String, dynamic> geometry) {
    final coordinates = geometry['coordinates'] as List?;
    if (coordinates == null || coordinates.isEmpty) return [];

    final ring = coordinates[0] as List;
    final points = <Offset>[];

    for (var coord in ring) {
      final lon = (coord[0] as num).toDouble();
      final lat = (coord[1] as num).toDouble();
      points.add(_latLonToMeters(lon, lat));
    }

    return points;
  }

  List<Offset> _extractLinePoints(Map<String, dynamic> geometry) {
    final coordinates = geometry['coordinates'] as List?;
    if (coordinates == null) return [];

    final points = <Offset>[];

    for (var coord in coordinates) {
      final lon = (coord[0] as num).toDouble();
      final lat = (coord[1] as num).toDouble();
      points.add(_latLonToMeters(lon, lat));
    }

    return points;
  }

  Offset _latLonToMeters(double lon, double lat) {
    const double metersPerDegreeLat = 111320.0;
    const double metersPerDegreeLon = 111320.0;

    final dx =
        (lon - baseLon) *
        metersPerDegreeLon *
        math.cos(baseLat * math.pi / 180);
    final dy = (lat - baseLat) * metersPerDegreeLat;

    return Offset(dx, dy);
  }

  bool _isObstacle(Offset point, {bool isGoal = false}) {
    final buffer = isGoal ? obstacleBuffer * 0.3 : obstacleBuffer;

    for (var obstacle in _obstacles) {
      if (obstacle.type == ObstacleType.polygon) {
        if (_isPointInOrNearPolygon(point, obstacle.points, buffer)) {
          return true;
        }
      } else if (obstacle.type == ObstacleType.line) {
        if (_isPointNearPolyline(point, obstacle.points, buffer)) {
          return true;
        }
      } else if (obstacle.type == ObstacleType.circle) {
        final center = obstacle.points.first;
        final distance = math.sqrt(
          math.pow(point.dx - center.dx, 2) + math.pow(point.dy - center.dy, 2),
        );
        if (distance < obstacle.radius! + buffer) {
          return true;
        }
      }
    }

    return false;
  }

  bool _isPointInOrNearPolygon(
    Offset point,
    List<Offset> polygon,
    double buffer,
  ) {
    if (polygon.length < 3) return false;

    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      if (((polygon[i].dy > point.dy) != (polygon[j].dy > point.dy)) &&
          (point.dx <
              (polygon[j].dx - polygon[i].dx) *
                      (point.dy - polygon[i].dy) /
                      (polygon[j].dy - polygon[i].dy) +
                  polygon[i].dx)) {
        inside = !inside;
      }
    }

    if (inside) return true;

    for (int i = 0; i < polygon.length; i++) {
      final j = (i + 1) % polygon.length;
      final distance = _distanceToLineSegment(point, polygon[i], polygon[j]);
      if (distance < buffer) {
        return true;
      }
    }

    return false;
  }

  bool _isPointNearPolyline(
    Offset point,
    List<Offset> polyline,
    double threshold,
  ) {
    if (polyline.length < 2) return false;

    for (int i = 0; i < polyline.length - 1; i++) {
      final distance = _distanceToLineSegment(
        point,
        polyline[i],
        polyline[i + 1],
      );
      if (distance < threshold) {
        return true;
      }
    }

    return false;
  }

  double _distanceToLineSegment(
    Offset point,
    Offset lineStart,
    Offset lineEnd,
  ) {
    final dx = lineEnd.dx - lineStart.dx;
    final dy = lineEnd.dy - lineStart.dy;
    final lengthSquared = dx * dx + dy * dy;

    if (lengthSquared == 0) {
      return math.sqrt(
        math.pow(point.dx - lineStart.dx, 2) +
            math.pow(point.dy - lineStart.dy, 2),
      );
    }

    final t =
        ((point.dx - lineStart.dx) * dx + (point.dy - lineStart.dy) * dy) /
        lengthSquared;
    final clampedT = t.clamp(0.0, 1.0);

    final projectionX = lineStart.dx + clampedT * dx;
    final projectionY = lineStart.dy + clampedT * dy;

    return math.sqrt(
      math.pow(point.dx - projectionX, 2) + math.pow(point.dy - projectionY, 2),
    );
  }

  List<Offset>? findPath(Offset start, Offset goal) {
    Offset effectiveGoal = goal;
    if (_isObstacle(goal, isGoal: true)) {
      effectiveGoal = _findBestAccessiblePoint(goal) ?? goal;
    }

    if (_isObstacle(start)) {
      return null;
    }

    final openSet = PriorityQueue<PathNode>((a, b) => a.f.compareTo(b.f));
    final closedSet = <Offset>{};
    final gScores = <Offset, double>{};

    final startNode = PathNode(
      start,
      null,
      0,
      _heuristic(start, effectiveGoal),
    );

    openSet.add(startNode);
    gScores[start] = 0;

    int iterations = 0;
    const maxIterations = 15000;

    while (openSet.isNotEmpty && iterations < maxIterations) {
      iterations++;

      final current = openSet.removeFirst();

      if (_distance(current.position, effectiveGoal) < goalTolerance) {
        final path = _reconstructPath(current);
        if (_distance(path.last, goal) > 0.05) {
          path.add(goal);
        }
        return _aggressiveSmoothing(path);
      }

      closedSet.add(current.position);

      for (var neighbor in _getNeighbors(current.position)) {
        if (closedSet.contains(neighbor) || _isObstacle(neighbor)) {
          continue;
        }

        final tentativeG = current.g + _distance(current.position, neighbor);

        if (!gScores.containsKey(neighbor) || tentativeG < gScores[neighbor]!) {
          gScores[neighbor] = tentativeG;

          final neighborNode = PathNode(
            neighbor,
            current,
            tentativeG,
            _heuristic(neighbor, effectiveGoal),
          );

          openSet.add(neighborNode);
        }
      }
    }

    return null;
  }

  Offset? _findBestAccessiblePoint(Offset goal) {
    const searchRadius = 0.6;
    const angleSteps = 32;

    for (double radius = 0.05; radius <= searchRadius; radius += 0.05) {
      for (int i = 0; i < angleSteps; i++) {
        final angle = (2 * math.pi * i) / angleSteps;
        final candidate = Offset(
          (goal.dx + radius * math.cos(angle)).clamp(0.0, roomWidth),
          (goal.dy + radius * math.sin(angle)).clamp(0.0, roomHeight),
        );

        if (!_isObstacle(candidate, isGoal: true)) {
          return candidate;
        }
      }
    }

    return goal;
  }

  List<Offset> _getNeighbors(Offset position) {
    final neighbors = <Offset>[];

    for (var dx = -gridResolution; dx <= gridResolution; dx += gridResolution) {
      for (
        var dy = -gridResolution;
        dy <= gridResolution;
        dy += gridResolution
      ) {
        if (dx == 0 && dy == 0) continue;

        final neighbor = Offset(
          (position.dx + dx).clamp(0.0, roomWidth),
          (position.dy + dy).clamp(0.0, roomHeight),
        );

        neighbors.add(neighbor);
      }
    }

    return neighbors;
  }

  double _heuristic(Offset a, Offset b) {
    return math.sqrt(math.pow(a.dx - b.dx, 2) + math.pow(a.dy - b.dy, 2));
  }

  double _distance(Offset a, Offset b) {
    return math.sqrt(math.pow(a.dx - b.dx, 2) + math.pow(a.dy - b.dy, 2));
  }

  List<Offset> _reconstructPath(PathNode node) {
    final path = <Offset>[];
    PathNode? current = node;

    while (current != null) {
      path.add(current.position);
      current = current.parent;
    }

    return path.reversed.toList();
  }

  List<Offset> _aggressiveSmoothing(List<Offset> path) {
    if (path.length <= 2) return path;

    final smoothed = <Offset>[path.first];
    int i = 0;

    while (i < path.length - 1) {
      int farthest = i + 1;

      for (int j = path.length - 1; j > i + 1; j--) {
        if (_hasLineOfSight(path[i], path[j])) {
          farthest = j;
          break;
        }
      }

      smoothed.add(path[farthest]);
      i = farthest;
    }

    return smoothed;
  }

  bool _hasLineOfSight(Offset start, Offset end) {
    final distance = _distance(start, end);
    final steps = (distance / (gridResolution * 0.5)).ceil();

    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final point = Offset(
        start.dx + (end.dx - start.dx) * t,
        start.dy + (end.dy - start.dy) * t,
      );

      if (_isObstacle(point)) {
        return false;
      }
    }

    return true;
  }
}

enum ObstacleType { polygon, line, circle }

class ObstacleGeometry {
  final ObstacleType type;
  final List<Offset> points;
  final double? radius;

  ObstacleGeometry({required this.type, required this.points, this.radius});
}

class PriorityQueue<E> {
  final List<E> _elements = [];
  final Comparator<E> _comparator;

  PriorityQueue(this._comparator);

  void add(E element) {
    _elements.add(element);
    _elements.sort(_comparator);
  }

  E removeFirst() {
    return _elements.removeAt(0);
  }

  bool get isNotEmpty => _elements.isNotEmpty;
  bool get isEmpty => _elements.isEmpty;
}

class StaticMapCanvas extends CustomPainter {
  StaticMapCanvas({
    required this.roomWidth,
    required this.roomHeight,
    required this.baseConvertion,
    this.tagPosition,
    this.tagAccuracy = 0.0,
    required this.productsLocation,
    this.geoJsonData,
    required this.computedPaths,
    required this.hiddenProductPaths,
    required this.nearestProductId,
    required this.animationValue,
  });

  final double roomWidth;
  final double roomHeight;
  final num baseConvertion;
  final Offset? tagPosition;
  final double tagAccuracy;
  final List<Map<String, dynamic>> productsLocation;
  final Map<String, dynamic>? geoJsonData;
  final Map<String, List<Offset>> computedPaths;
  final Set<String> hiddenProductPaths;
  final String? nearestProductId;
  final double animationValue;

  double baseLat = 43.60666618464;
  double baseLon = 3.92162187466;

  Color _getAccuracyColor(double error) {
    if (error < 0.3) return const Color(0xFF10b981);
    if (error < 0.7) return const Color(0xFF84cc16);
    if (error < 1.2) return const Color(0xFFf59e0b);
    return const Color(0xFFef4444);
  }

  Offset _metersToCanvasOffset(double x, double y) {
    return Offset(
      metersToPixels(x, baseConvertion: baseConvertion.toInt()) + 50,
      metersToPixels(roomHeight - y, baseConvertion: baseConvertion.toInt()) +
          50,
    );
  }

  Offset _latLonToMeters(double lon, double lat) {
    const double metersPerDegreeLat = 111320.0;
    const double metersPerDegreeLon = 111320.0;

    final dx =
        (lon - baseLon) *
        metersPerDegreeLon *
        math.cos(baseLat * math.pi / 180);
    final dy = (lat - baseLat) * metersPerDegreeLat;

    return Offset(dx, dy);
  }

  void _drawTag(Canvas canvas, Offset position, double accuracy) {
    final pixelPosition = _metersToCanvasOffset(position.dx, position.dy);
    final color = _getAccuracyColor(accuracy);

    if (accuracy > 0 && accuracy < 10) {
      final accuracyCirclePaint = Paint()
        ..color = color.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pixelPosition, 35, accuracyCirclePaint);
    }

    final middleCirclePaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pixelPosition, 16, middleCirclePaint);

    final innerCirclePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pixelPosition, 8, innerCirclePaint);

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(pixelPosition, 8, borderPaint);

    final textSpan = TextSpan(
      text:
          'Cart\n${position.dx.toStringAsFixed(2)}, ${position.dy.toStringAsFixed(2)}m',
      style: TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        backgroundColor: color.withValues(alpha: 0.9),
        height: 1.4,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(minWidth: 0, maxWidth: 110);
    textPainter.paint(
      canvas,
      Offset(pixelPosition.dx - textPainter.width / 2, pixelPosition.dy + 20),
    );
  }

  void _drawPinpoint(Canvas canvas, String id, Offset position) {
    final pixelPosition = _metersToCanvasOffset(position.dx, position.dy);

    final path = Path();
    path.moveTo(pixelPosition.dx, pixelPosition.dy);
    path.quadraticBezierTo(
      pixelPosition.dx - 10,
      pixelPosition.dy - 10,
      pixelPosition.dx - 10,
      pixelPosition.dy - 20,
    );
    path.arcToPoint(
      Offset(pixelPosition.dx + 10, pixelPosition.dy - 20),
      radius: const Radius.circular(10),
    );
    path.quadraticBezierTo(
      pixelPosition.dx + 10,
      pixelPosition.dy - 10,
      pixelPosition.dx,
      pixelPosition.dy,
    );
    path.close();

    final rect = Rect.fromLTWH(
      pixelPosition.dx - 10,
      pixelPosition.dy - 20,
      20,
      20,
    );

    final gradient = LinearGradient(
      colors: [const Color(0xFFf43f5e), const Color(0xFFe11d48)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    final pinPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    final pinBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawPath(path, pinPaint);
    canvas.drawPath(path, pinBorderPaint);

    final circlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(pixelPosition.dx, pixelPosition.dy - 20),
      5,
      circlePaint,
    );

    final textSpan = TextSpan(
      text: id,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        backgroundColor: Color(0xFF1f2937),
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(minWidth: 0, maxWidth: 80);
    textPainter.paint(
      canvas,
      Offset(pixelPosition.dx - textPainter.width / 2, pixelPosition.dy + 6),
    );
  }

  void _drawPath(
    Canvas canvas,
    List<Offset> path,
    Color color,
    bool isNearest,
  ) {
    if (path.length < 2) return;

    final pathColor = isNearest
        ? color
        : const Color(0xFF9ca3af).withValues(alpha: 0.4);
    final strokeWidth = isNearest ? 5.0 : 3.0;

    final paint = Paint()
      ..color = pathColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pathToDraw = Path();
    bool first = true;

    for (var point in path) {
      final pixel = _metersToCanvasOffset(point.dx, point.dy);

      if (first) {
        pathToDraw.moveTo(pixel.dx, pixel.dy);
        first = false;
      } else {
        pathToDraw.lineTo(pixel.dx, pixel.dy);
      }
    }

    if (isNearest) {
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.2)
        ..strokeWidth = 7.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawPath(pathToDraw, shadowPaint);
    }

    canvas.drawPath(pathToDraw, paint);

    if (isNearest) {
      final numArrows = 6;
      final arrowSpacing = 1.0 / numArrows;

      for (int i = 0; i < numArrows; i++) {
        final baseProgress = i * arrowSpacing;
        final animatedProgress = (baseProgress + animationValue) % 1.0;

        _drawFlowingArrow(canvas, path, animatedProgress, color);
      }
    }
  }

  void _drawFlowingArrow(
    Canvas canvas,
    List<Offset> path,
    double progress,
    Color color,
  ) {
    if (path.length < 2) return;

    final totalLength = _calculatePathLength(path);
    final targetLength = totalLength * progress;

    double currentLength = 0.0;
    Offset arrowPos = path.first;
    Offset nextPos = path[1];

    for (int i = 0; i < path.length - 1; i++) {
      final segStart = path[i];
      final segEnd = path[i + 1];
      final segLength = math.sqrt(
        math.pow(segEnd.dx - segStart.dx, 2) +
            math.pow(segEnd.dy - segStart.dy, 2),
      );

      if (currentLength + segLength >= targetLength) {
        final segProgress = (targetLength - currentLength) / segLength;
        arrowPos = Offset(
          segStart.dx + (segEnd.dx - segStart.dx) * segProgress,
          segStart.dy + (segEnd.dy - segStart.dy) * segProgress,
        );
        nextPos = segEnd;
        break;
      }

      currentLength += segLength;
    }

    final canvasPos = _metersToCanvasOffset(arrowPos.dx, arrowPos.dy);
    final canvasNext = _metersToCanvasOffset(nextPos.dx, nextPos.dy);

    final dx = canvasNext.dx - canvasPos.dx;
    final dy = canvasNext.dy - canvasPos.dy;
    final angle = math.atan2(dy, dx);

    final arrowSize = 12.0;
    final arrowWidth = math.pi / 6;

    final arrowPath = Path();

    arrowPath.moveTo(canvasPos.dx, canvasPos.dy);
    arrowPath.lineTo(
      canvasPos.dx - arrowSize * math.cos(angle - arrowWidth),
      canvasPos.dy - arrowSize * math.sin(angle - arrowWidth),
    );
    arrowPath.moveTo(canvasPos.dx, canvasPos.dy);
    arrowPath.lineTo(
      canvasPos.dx - arrowSize * math.cos(angle + arrowWidth),
      canvasPos.dy - arrowSize * math.sin(angle + arrowWidth),
    );

    final arrowPaint = Paint()
      ..color = color.withValues(alpha: 0.95)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(arrowPath, arrowPaint);
  }

  double _calculatePathLength(List<Offset> path) {
    double length = 0.0;
    for (int i = 0; i < path.length - 1; i++) {
      length += math.sqrt(
        math.pow(path[i + 1].dx - path[i].dx, 2) +
            math.pow(path[i + 1].dy - path[i].dy, 2),
      );
    }
    return length;
  }

  void _renderGeoJsonFeatures(Canvas canvas) {
    if (geoJsonData == null) return;

    final features = geoJsonData!['features'] as List?;
    if (features == null) return;

    for (var feature in features) {
      final properties = feature['properties'] as Map<String, dynamic>?;
      if (properties?['featureType'] == 'metadata') {
        baseLat = (properties?['baseLatitude'] ?? baseLat).toDouble();
        baseLon = (properties?['baseLongitude'] ?? baseLon).toDouble();
        break;
      }
    }

    for (var feature in features) {
      final geometry = feature['geometry'];
      final properties = feature['properties'] as Map<String, dynamic>?;

      if (geometry == null) continue;

      final geometryType = geometry['type'] as String?;
      final amenity = properties?['amenity'] as String?;

      switch (geometryType) {
        case 'LineString':
          _drawLineString(canvas, geometry, amenity);
          break;
        case 'Polygon':
          _drawPolygon(canvas, geometry, amenity, properties);
          break;
        case 'Point':
          _drawPoint(canvas, geometry, amenity, properties);
          break;
      }
    }
  }

  void _drawLineString(
    Canvas canvas,
    Map<String, dynamic> geometry,
    String? amenity,
  ) {
    final coordinates = geometry['coordinates'] as List?;
    if (coordinates == null || coordinates.length < 2) return;

    final paint = Paint()
      ..color = amenity == 'wall'
          ? const Color(0xFF1f2937)
          : const Color(0xFF3b82f6)
      ..strokeWidth = amenity == 'wall' ? 4.0 : 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    bool first = true;

    for (var coord in coordinates) {
      final lon = (coord[0] as num).toDouble();
      final lat = (coord[1] as num).toDouble();
      final meters = _latLonToMeters(lon, lat);
      final pixel = _metersToCanvasOffset(meters.dx, meters.dy);

      if (first) {
        path.moveTo(pixel.dx, pixel.dy);
        first = false;
      } else {
        path.lineTo(pixel.dx, pixel.dy);
      }
    }

    canvas.drawPath(path, paint);
  }

  void _drawPolygon(
    Canvas canvas,
    Map<String, dynamic> geometry,
    String? amenity,
    Map<String, dynamic>? properties,
  ) {
    final coordinates = geometry['coordinates'] as List?;
    if (coordinates == null || coordinates.isEmpty) return;

    final ring = coordinates[0] as List;
    if (ring.length < 3) return;

    Color fillColor = const Color(0xFFe5e7eb);
    Color strokeColor = const Color(0xFF9ca3af);

    if (amenity == 'room') {
      fillColor = const Color(0xFFdbeafe);
      strokeColor = const Color(0xFF3b82f6);
    } else if (amenity == 'entrance' || properties?['door'] == 'yes') {
      fillColor = const Color(0xFFfef3c7);
      strokeColor = const Color(0xFFf59e0b);
    } else if (amenity == 'window') {
      fillColor = const Color(0xFFe0f2fe);
      strokeColor = const Color(0xFF0ea5e9);
    } else if (amenity == 'stairs') {
      fillColor = const Color(0xFFfed7aa);
      strokeColor = const Color(0xFFea580c);
    }

    final path = Path();
    bool first = true;

    for (var coord in ring) {
      final lon = (coord[0] as num).toDouble();
      final lat = (coord[1] as num).toDouble();
      final meters = _latLonToMeters(lon, lat);
      final pixel = _metersToCanvasOffset(meters.dx, meters.dy);

      if (first) {
        path.moveTo(pixel.dx, pixel.dy);
        first = false;
      } else {
        path.lineTo(pixel.dx, pixel.dy);
      }
    }
    path.close();

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = strokeColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  void _drawPoint(
    Canvas canvas,
    Map<String, dynamic> geometry,
    String? amenity,
    Map<String, dynamic>? properties,
  ) {
    final coordinates = geometry['coordinates'] as List?;
    if (coordinates == null || coordinates.length < 2) return;

    final lon = (coordinates[0] as num).toDouble();
    final lat = (coordinates[1] as num).toDouble();
    final meters = _latLonToMeters(lon, lat);
    final pixel = _metersToCanvasOffset(meters.dx, meters.dy);

    if (amenity == 'area' && properties?['radius'] != null) {
      final radiusMeters =
          double.tryParse(properties!['radius'] as String) ?? 0.5;
      final radiusPixels = metersToPixels(
        radiusMeters,
        baseConvertion: baseConvertion.toInt(),
      );

      final circlePaint = Paint()
        ..color = const Color(0xFFc084fc).withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;

      final borderPaint = Paint()
        ..color = const Color(0xFFa855f7)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(pixel, radiusPixels, circlePaint);
      canvas.drawCircle(pixel, radiusPixels, borderPaint);
    } else {
      final labelPaint = Paint()
        ..color = const Color(0xFF1f2937)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(pixel, 6, labelPaint);

      if (properties?['name'] != null) {
        final textSpan = TextSpan(
          text: properties!['name'] as String,
          style: const TextStyle(
            color: Color(0xFF1f2937),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            backgroundColor: Color(0xFFffffff),
          ),
        );

        final textPainter = TextPainter(
          text: textSpan,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        );

        textPainter.layout(minWidth: 0, maxWidth: 100);
        textPainter.paint(
          canvas,
          Offset(pixel.dx - textPainter.width / 2, pixel.dy + 10),
        );
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    final gridGap = (baseConvertion / 2).toInt();
    final paint = Paint()
      ..color = const Color(0xFFe5e7eb)
      ..strokeWidth = 1;

    final roomPixelWidth = metersToPixels(
      roomWidth,
      baseConvertion: baseConvertion.toInt(),
    );
    final roomPixelHeight = metersToPixels(
      roomHeight,
      baseConvertion: baseConvertion.toInt(),
    );

    for (double i = 0; i <= roomPixelWidth; i += gridGap) {
      canvas.drawLine(
        Offset(i + 50, 50),
        Offset(i + 50, roomPixelHeight + 50),
        paint,
      );
    }

    for (double i = 0; i <= roomPixelHeight; i += gridGap) {
      canvas.drawLine(
        Offset(50, i + 50),
        Offset(roomPixelWidth + 50, i + 50),
        paint,
      );
    }

    final boundaryPaint = Paint()
      ..color = const Color(0xFF1f2937)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    canvas.drawRect(
      Rect.fromLTWH(50, 50, roomPixelWidth, roomPixelHeight),
      boundaryPaint,
    );

    _renderGeoJsonFeatures(canvas);

    final colors = [
      const Color(0xFF06b6d4),
      const Color(0xFF8b5cf6),
      const Color(0xFFf59e0b),
      const Color(0xFFec4899),
      const Color(0xFF14b8a6),
    ];

    int colorIndex = 0;
    for (var entry in computedPaths.entries) {
      if (!hiddenProductPaths.contains(entry.key)) {
        final isNearest = entry.key == nearestProductId;
        _drawPath(
          canvas,
          entry.value,
          colors[colorIndex % colors.length],
          isNearest,
        );
      }
      colorIndex++;
    }

    for (var product in productsLocation) {
      final id = product['id'] as String;
      final position = product['position'] as Offset;
      _drawPinpoint(canvas, id, position);
    }

    if (tagPosition != null) {
      _drawTag(canvas, tagPosition!, tagAccuracy);
    }
  }

  @override
  bool shouldRepaint(covariant StaticMapCanvas oldDelegate) {
    return true;
  }
}

class Anchor {
  String id;
  Size size;
  num baseConvertion;
  late double x;
  late double y;
  late double distance;

  Anchor(
    String range, {
    required this.id,
    required Offset position,
    required this.size,
    required this.baseConvertion,
  }) {
    x = position.dx;
    y = position.dy;
    final parsedDistance = double.tryParse(range);
    distance = (parsedDistance != null && parsedDistance >= 0)
        ? parsedDistance
        : 0.0;
  }
}

class Trilateration {
  List<Anchor> anchors;

  Trilateration(this.anchors);

  Map<String, dynamic>? calcUserLocation() {
    if (anchors.length < 3) return null;

    try {
      Offset? position;
      if (anchors.length == 3) {
        position = _linearTrilateration();
      } else {
        position = _nonlinearLeastSquares();
      }

      position ??= _fallbackCircleIntersection();

      if (position == null || !position.dx.isFinite || !position.dy.isFinite) {
        return null;
      }

      double rmsError = _calculateRMSError(position);
      return {'position': position, 'accuracy': rmsError};
    } catch (e) {
      if (kDebugMode) print('❌ Trilateration error: $e');
      return null;
    }
  }

  Offset? _linearTrilateration() {
    final a1 = anchors[0];
    final a2 = anchors[1];
    final a3 = anchors[2];

    double x1 = a1.x, y1 = a1.y, r1 = a1.distance;
    double x2 = a2.x, y2 = a2.y, r2 = a2.distance;
    double x3 = a3.x, y3 = a3.y, r3 = a3.distance;

    if (r1 <= 0 || r2 <= 0 || r3 <= 0) return null;

    double A = 2 * (x2 - x1);
    double B = 2 * (y2 - y1);
    double C = r1 * r1 - r2 * r2 - x1 * x1 + x2 * x2 - y1 * y1 + y2 * y2;
    double D = 2 * (x3 - x2);
    double E = 2 * (y3 - y2);
    double F = r2 * r2 - r3 * r3 - x2 * x2 + x3 * x3 - y2 * y2 + y3 * y3;

    double denominator = A * E - B * D;
    if (denominator.abs() < 0.0001) {
      return null;
    }

    double x = (C * E - F * B) / denominator;
    double y = (A * F - D * C) / denominator;

    return Offset(x, y);
  }

  Offset? _nonlinearLeastSquares() {
    double initialX = 0, initialY = 0;
    int count = 0;
    for (var anchor in anchors) {
      if (anchor.distance > 0) {
        initialX += anchor.x;
        initialY += anchor.y;
        count++;
      }
    }
    if (count == 0) return null;

    double x = initialX / count;
    double y = initialY / count;

    const int maxIterations = 100;
    const double convergenceThreshold = 1e-6;

    for (int iteration = 0; iteration < maxIterations; iteration++) {
      List<List<double>> J = [];
      List<double> r = [];

      for (var anchor in anchors) {
        if (anchor.distance <= 0) continue;

        double dx = x - anchor.x;
        double dy = y - anchor.y;
        double dist = math.sqrt(dx * dx + dy * dy);

        if (dist < 0.001) dist = 0.001;

        double residual = dist - anchor.distance;
        r.add(residual);
        J.add([dx / dist, dy / dist]);
      }

      if (J.isEmpty) return null;

      double jtJ00 = 0, jtJ01 = 0, jtJ11 = 0;
      for (var row in J) {
        jtJ00 += row[0] * row[0];
        jtJ01 += row[0] * row[1];
        jtJ11 += row[1] * row[1];
      }

      double jtr0 = 0, jtr1 = 0;
      for (int i = 0; i < J.length; i++) {
        jtr0 += J[i][0] * r[i];
        jtr1 += J[i][1] * r[i];
      }

      double det = jtJ00 * jtJ11 - jtJ01 * jtJ01;
      if (det.abs() < 1e-10) {
        break;
      }

      double inv00 = jtJ11 / det;
      double inv01 = -jtJ01 / det;
      double inv11 = jtJ00 / det;

      double deltaX = -(inv00 * jtr0 + inv01 * jtr1);
      double deltaY = -(inv01 * jtr0 + inv11 * jtr1);

      x += deltaX;
      y += deltaY;

      double stepSize = math.sqrt(deltaX * deltaX + deltaY * deltaY);
      if (stepSize < convergenceThreshold) {
        break;
      }
    }

    return Offset(x, y);
  }

  Offset? _fallbackCircleIntersection() {
    if (anchors.length < 2) return null;

    try {
      double x1 = anchors[0].x, y1 = anchors[0].y, r1 = anchors[0].distance;
      double x2 = anchors[1].x, y2 = anchors[1].y, r2 = anchors[1].distance;

      double d = math.sqrt(math.pow(x2 - x1, 2) + math.pow(y2 - y1, 2));

      if (d > r1 + r2 || d < (r1 - r2).abs() || d == 0) {
        return Offset((x1 + x2) / 2, (y1 + y2) / 2);
      }

      double a = (r1 * r1 - r2 * r2 + d * d) / (2 * d);
      double h = math.sqrt((r1 * r1 - a * a).abs());

      double x0 = x1 + a * (x2 - x1) / d;
      double y0 = y1 + a * (y2 - y1) / d;

      double intersectionX1 = x0 + h * (y2 - y1) / d;
      double intersectionY1 = y0 - h * (x2 - x1) / d;

      return Offset(intersectionX1, intersectionY1);
    } catch (e) {
      return null;
    }
  }

  double _calculateRMSError(Offset position) {
    double sumSquaredError = 0;
    int count = 0;

    for (var anchor in anchors) {
      if (anchor.distance <= 0) continue;

      double dx = position.dx - anchor.x;
      double dy = position.dy - anchor.y;
      double calculatedDist = math.sqrt(dx * dx + dy * dy);
      double error = calculatedDist - anchor.distance;

      sumSquaredError += error * error;
      count++;
    }

    if (count == 0) return 0;
    return math.sqrt(sumSquaredError / count);
  }
}
