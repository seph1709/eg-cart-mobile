import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:auto_route/auto_route.dart';
import 'package:bottom_bar_with_sheet/bottom_bar_with_sheet.dart';
import 'package:egcart_mobile/controller/supabase_controller.dart';
import 'package:egcart_mobile/models/product_model.dart';
import 'package:egcart_mobile/route/route.gr.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'widgets/product_card_widget.dart';

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
  final String _esp32IpAddress = "172.16.42.15";
  final String _targetCartId = "cart001";
  final _bottomWithSheelController = BottomBarWithSheetController(
    initialIndex: 0,
  );
  num baseConvertion = 100;
  double roomWidth = 7.5;
  double roomHeight = 7.0;

  Map<String, dynamic>? geoJsonData;
  Map<String, List<Offset>> _computedPaths = {};
  Offset? _lastPathComputePosition;
  final Set<String> _hiddenProductPaths = {};
  String? _nearestProductId;
  bool _isFollowingTag = false;

  String? _selectedProductId;
  Offset? _selectedProductPosition;

  String get _wsUrl => 'ws://$_esp32IpAddress/ws';
  var links =
      "{\"links\":[{\"A\":\"A0084\",\"R\":\"3.50\"},{\"A\":\"A0085\",\"R\":\"4.20\"},{\"A\":\"A0086\",\"R\":\"5.10\"},{\"A\":\"A0087\",\"R\":\"3.80\"}]}";

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
  static const Duration _pingInterval = Duration(seconds: 45);
  static const Duration _heartbeatTimeout = Duration(seconds: 150);
  static const Duration _connectionTimeout = Duration(seconds: 15);

  Offset? _currentTagPosition;
  Offset? _targetTagPosition;
  double _currentAccuracy = 0.0;
  late AnimationController _animationController;
  late AnimationController _arrowAnimationController;
  late AnimationController _continuousAnimationController;
  Timer? _positionUpdateTimer;

  late AnimationController _cameraAnimationController;
  Animation<Matrix4>? _cameraAnimation;

  final TransformationController _transformationController =
      TransformationController();

  Matrix4? _lastTransformValue;
  Timer? _transformCheckTimer;

  // ✅ CRITICAL: Update throttling to prevent freezing
  DateTime? _lastStateUpdateTime;
  Timer? _stateUpdateThrottleTimer;
  static const Duration _minUpdateInterval = Duration(
    milliseconds: 100,
  ); // Max 10 updates/sec
  bool _hasPendingUpdate = false;

  // ✅ NEW: Reduced sensitivity (5cm minimum vs 1.5cm)
  DateTime? _lastValidPositionTime;
  int _consecutiveBadReadings = 0;
  static const int _maxBadReadings = 3;
  static const Duration _positionTimeout = Duration(seconds: 5);
  static const double _maxAccuracyThreshold = 1.5;
  static const double _minMovementThreshold = 0.05; // 5cm minimum (was 1.5cm)

  // ✅ CRITICAL: Path update throttling (only update if moved > 20cm)
  static const double _pathUpdateThreshold =
      0.20; // 20cm for path recalculation

  // Kalman filter state
  Offset? _kalmanPosition;
  Offset? _kalmanVelocity;
  DateTime? _lastKalmanUpdate;

  // Position history
  final List<Offset> _positionHistory = [];
  final List<DateTime> _positionTimeHistory = [];
  static const int _historySize = 5;

  // ✅ NEW: Pending position updates (batching)
  Offset? _pendingTargetPosition;
  double? _pendingAccuracy;

  Map<String, Offset> get anchorPositions => {
    "A0084": const Offset(0, 0),
    "A0085": Offset(roomWidth, 0),
    "A0086": Offset(0, roomHeight),
    "A0087": Offset(roomWidth, roomHeight),
  };

  String? get _displayedProductId {
    final c = Get.find<SupabaseController>();
    if (c.prioritizedProductId != null &&
        !_hiddenProductPaths.contains(c.prioritizedProductId)) {
      return c.prioritizedProductId;
    }
    return _nearestProductId;
  }

  double? get _nearestProductDistance {
    final targetId = _displayedProductId;
    if (targetId == null || _currentTagPosition == null) {
      return null;
    }

    final product = CartProducts.products.firstWhere((p) => p.id == targetId);
    final x = product.coordinates['x'] ?? 0.0;
    final y = product.coordinates['y'] ?? 0.0;
    final productPosition = Offset(x, y);
    return math.sqrt(
      math.pow(_currentTagPosition!.dx - productPosition.dx, 2) +
          math.pow(_currentTagPosition!.dy - productPosition.dy, 2),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _arrowAnimationController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat();

    _continuousAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _cameraAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _transformationController.addListener(_onTransformChanged);
    _startTransformMonitoring();

    _loadDefaultGeoJsonData();
    _connectWebSocket();
    _startHeartbeatMonitor();
    _startContinuousPositionUpdate();
    _startThrottledStateUpdates(); // ✅ NEW: Start throttled updates

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _processPositionUpdate(links);
        _setInitialZoom();
        _toggleFollowMode();
      }
    });
  }

  // ✅ CRITICAL: Throttled setState to prevent freezing
  void _startThrottledStateUpdates() {
    _stateUpdateThrottleTimer?.cancel();
    _stateUpdateThrottleTimer = Timer.periodic(_minUpdateInterval, (timer) {
      if (!mounted) return;

      if (_hasPendingUpdate && _pendingTargetPosition != null) {
        setState(() {
          _targetTagPosition = _pendingTargetPosition;
          _currentAccuracy = _pendingAccuracy ?? _currentAccuracy;
          _hasPendingUpdate = false;
        });
        _lastStateUpdateTime = DateTime.now();
      }
    });
  }

  // ✅ NEW: Schedule update instead of immediate setState
  void _schedulePositionUpdate(Offset position, double accuracy) {
    _pendingTargetPosition = position;
    _pendingAccuracy = accuracy;
    _hasPendingUpdate = true;
  }

  void _startTransformMonitoring() {
    _transformCheckTimer?.cancel();
    _transformCheckTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      if (!mounted) {
        return;
      }
      _checkForUserGesture();
    });
  }

  void _onTransformChanged() {
    if (_selectedProductId != null) {
      setState(() {
        _selectedProductId = null;
        _selectedProductPosition = null;
      });
    }

    if (!_isFollowingTag || _cameraAnimationController.isAnimating) {
      return;
    }

    if (_lastTransformValue != null) {
      final currentTransform = _transformationController.value;
      if (!_areMatricesEqual(currentTransform, _lastTransformValue!)) {
        if (kDebugMode) {
          debugPrint('🔓 Auto-unlocking follow mode - user gesture detected');
        }
      }
    }
  }

  bool _areMatricesEqual(Matrix4 a, Matrix4 b, {double tolerance = 0.01}) {
    for (int i = 0; i < 16; i++) {
      if ((a.storage[i] - b.storage[i]).abs() > tolerance) {
        return false;
      }
    }
    return true;
  }

  void _checkForUserGesture() {
    if (_isFollowingTag && !_cameraAnimationController.isAnimating) {
      _lastTransformValue = _transformationController.value.clone();
    }
  }

  void _handleCanvasTap(Offset screenPosition) {
    final transform = _transformationController.value;
    final inverseTransform = Matrix4.inverted(transform);
    final transformedPosition = MatrixUtils.transformPoint(
      inverseTransform,
      screenPosition,
    );

    if (kDebugMode) {
      debugPrint('🖱️ Screen tap: $screenPosition');
      debugPrint('📍 Canvas position: $transformedPosition');
    }

    for (var product in CartProducts.products) {
      final productId = product.id;
      final x = product.coordinates['x'] ?? 0.0;
      final y = product.coordinates['y'] ?? 0.0;
      final productPosition = Offset(x, y);

      final productCanvasX =
          metersToPixels(
            productPosition.dx,
            baseConvertion: baseConvertion.toInt(),
          ) +
          50;
      final productCanvasY =
          metersToPixels(
            roomHeight - productPosition.dy,
            baseConvertion: baseConvertion.toInt(),
          ) +
          50;

      final distance = math.sqrt(
        math.pow(transformedPosition.dx - productCanvasX, 2) +
            math.pow(transformedPosition.dy - productCanvasY, 2),
      );

      if (kDebugMode) {
        debugPrint(
          '📏 Distance to $productId: ${distance.toStringAsFixed(2)}px',
        );
      }

      if (distance < 30) {
        _handleProductTap(productId, productPosition);
        return;
      }
    }

    if (_selectedProductId != null) {
      setState(() {
        _selectedProductId = null;
        _selectedProductPosition = null;
      });
    }
  }

  void _handleProductTap(String productId, Offset position) {
    setState(() {
      if (_selectedProductId == productId) {
        _selectedProductId = null;
        _selectedProductPosition = null;
      } else {
        _selectedProductId = productId;
        _selectedProductPosition = position;
      }
    });

    if (kDebugMode) {
      debugPrint('✅ Product selected: $productId at $position');
    }
  }

  void _handleProductListTap(String productId) {
    final c = Get.find<SupabaseController>();
    setState(() {
      if (_hiddenProductPaths.contains(productId)) {
        _hiddenProductPaths.remove(productId);
        c.prioritizedProductId = productId;
        if (kDebugMode) {
          debugPrint('🔄 Restored and prioritized: $productId');
        }
      } else {
        if (c.prioritizedProductId == productId) {
          // Do nothing
        } else {
          c.prioritizedProductId = productId;
          if (kDebugMode) {
            debugPrint('🎯 Prioritized product: $productId');
          }
        }
      }
      _updateNearestProduct();
    });
  }

  Offset _getScreenPosition(Offset meterPosition) {
    final canvasX =
        metersToPixels(
          meterPosition.dx,
          baseConvertion: baseConvertion.toInt(),
        ) +
        50;
    final canvasY =
        metersToPixels(
          roomHeight - meterPosition.dy,
          baseConvertion: baseConvertion.toInt(),
        ) +
        50;

    final transform = _transformationController.value;
    final transformedX =
        transform.entry(0, 0) * canvasX + transform.entry(0, 3);
    final transformedY =
        transform.entry(1, 1) * canvasY + transform.entry(1, 3);

    return Offset(transformedX, transformedY);
  }

  // ✅ OPTIMIZED: Smoother, less frequent interpolation
  void _startContinuousPositionUpdate() {
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = Timer.periodic(const Duration(milliseconds: 50), (
      timer,
    ) {
      if (_targetTagPosition != null &&
          _currentTagPosition != null &&
          mounted) {
        final distance = math.sqrt(
          math.pow(_targetTagPosition!.dx - _currentTagPosition!.dx, 2) +
              math.pow(_targetTagPosition!.dy - _currentTagPosition!.dy, 2),
        );

        if (distance > 0.01) {
          double speed;
          double estimatedVelocity = _estimateVelocity();

          // ✅ OPTIMIZED: Slower, smoother interpolation
          if (estimatedVelocity > 0.5) {
            speed = 0.30; // Reduced from 0.45
          } else if (distance > 0.3) {
            speed = 0.25; // Reduced from 0.35
          } else if (distance > 0.15) {
            speed = 0.18; // Reduced from 0.25
          } else if (distance > 0.05) {
            speed = 0.12; // Reduced from 0.18
          } else {
            speed = 0.08; // Reduced from 0.12
          }

          // ✅ CRITICAL: Update without setState (just modify the value)
          _currentTagPosition = Offset(
            _currentTagPosition!.dx +
                (_targetTagPosition!.dx - _currentTagPosition!.dx) * speed,
            _currentTagPosition!.dy +
                (_targetTagPosition!.dy - _currentTagPosition!.dy) * speed,
          );

          if (_isFollowingTag && !_cameraAnimationController.isAnimating) {
            _centerOnTagSmooth(animate: false);
          }
        }
      }
    });
  }

  double _estimateVelocity() {
    if (_positionHistory.length < 2) return 0.0;

    final recentPositions = _positionHistory.length > 3
        ? _positionHistory.sublist(_positionHistory.length - 3)
        : _positionHistory;
    final recentTimes = _positionTimeHistory.length > 3
        ? _positionTimeHistory.sublist(_positionTimeHistory.length - 3)
        : _positionTimeHistory;

    if (recentPositions.length < 2) return 0.0;

    double totalDistance = 0.0;
    for (int i = 1; i < recentPositions.length; i++) {
      totalDistance += math.sqrt(
        math.pow(recentPositions[i].dx - recentPositions[i - 1].dx, 2) +
            math.pow(recentPositions[i].dy - recentPositions[i - 1].dy, 2),
      );
    }

    final totalTime =
        recentTimes.last.difference(recentTimes.first).inMilliseconds / 1000.0;
    return totalTime > 0 ? totalDistance / totalTime : 0.0;
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
        "timestamp": "2025-11-26T20:19:40.602204",
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
        "name": "Room 5 (copy)",
        "amenity": "room",
        "building:part": "room"
      },
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          [
            [3.9216335440941426, 43.60670076962023],
            [3.9216583561800267, 43.60670076962023],
            [3.9216583561800267, 43.606704812020524],
            [3.9216335440941426, 43.606704812020524],
            [3.9216335440941426, 43.60670076962023]
          ]
        ]
      }
    },
    {
      "type": "Feature",
      "properties": {
        "indoor": "yes",
        "level": "0",
        "name": "Room 5 (copy) (copy)",
        "amenity": "room",
        "building:part": "room"
      },
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          [
            [3.9216343291640476, 43.60668763883736],
            [3.9216591412499318, 43.60668763883736],
            [3.9216591412499318, 43.60669168123764],
            [3.9216343291640476, 43.60669168123764],
            [3.9216343291640476, 43.60668763883736]
          ]
        ]
      }
    },
    {
      "type": "Feature",
      "properties": {
        "indoor": "yes",
        "level": "0",
        "name": "Room 5 (copy) (copy) (copy)",
        "amenity": "room",
        "building:part": "room"
      },
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          [
            [3.921634038397416, 43.606675167751746],
            [3.9216588504833005, 43.606675167751746],
            [3.9216588504833005, 43.60667921015204],
            [3.921634038397416, 43.60667921015204],
            [3.921634038397416, 43.606675167751746]
          ]
        ]
      }
    },
    {
      "type": "Feature",
      "properties": {
        "indoor": "yes",
        "level": "0",
        "name": "Room 5 (copy) (copy) (copy) (copy)",
        "amenity": "room",
        "building:part": "room"
      },
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          [
            [3.9216776727765765, 43.60670133106472],
            [3.921702484862461, 43.60670133106472],
            [3.921702484862461, 43.606705373465005],
            [3.9216776727765765, 43.606705373465005],
            [3.9216776727765765, 43.60670133106472]
          ]
        ]
      }
    },
    {
      "type": "Feature",
      "properties": {
        "indoor": "yes",
        "level": "0",
        "name": "Room 5 (copy)",
        "amenity": "room",
        "building:part": "room"
      },
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          [
            [3.9216778860054395, 43.60668768094569],
            [3.921702698091324, 43.60668768094569],
            [3.921702698091324, 43.60669172334598],
            [3.9216778860054395, 43.60669172334598],
            [3.9216778860054395, 43.60668768094569]
          ]
        ]
      }
    },
    {
      "type": "Feature",
      "properties": {
        "indoor": "yes",
        "level": "0",
        "name": "Room 5 (copy) (copy)",
        "amenity": "room",
        "building:part": "room"
      },
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          [
            [3.9216780798498605, 43.60667562392539],
            [3.921702891935745, 43.60667562392539],
            [3.921702891935745, 43.60667966632568],
            [3.9216780798498605, 43.60667966632568],
            [3.9216780798498605, 43.60667562392539]
          ]
        ]
      }
    },
    {
      "type": "Feature",
      "properties": {
        "indoor": "yes",
        "level": "0",
        "name": "Room 5 (copy)",
        "amenity": "room",
        "building:part": "room"
      },
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          [
            [3.9216335344019213, 43.60671475660595],
            [3.921658346487806, 43.60671475660595],
            [3.921658346487806, 43.60671879900624],
            [3.9216335344019213, 43.60671879900624],
            [3.9216335344019213, 43.60671475660595]
          ]
        ]
      }
    },
    {
      "type": "Feature",
      "properties": {
        "indoor": "yes",
        "level": "0",
        "name": "Room 5 (copy) (copy)",
        "amenity": "room",
        "building:part": "room"
      },
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          [
            [3.921677508008819, 43.606715065400415],
            [3.921702320094703, 43.606715065400415],
            [3.921702320094703, 43.60671910780071],
            [3.921677508008819, 43.60671910780071],
            [3.921677508008819, 43.606715065400415]
          ]
        ]
      }
    }
  ]
}
''';

    _parseGeoJsonString(geoJsonString);
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
              debugPrint('✅ Loaded GeoJSON: ${roomWidth}m x ${roomHeight}m');
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
      if (kDebugMode) {
        debugPrint('❌ Failed to parse GeoJSON: $e');
      }
    }
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
      debugPrint(
        '🔍 Zoom set: scale=${scale.toStringAsFixed(3)}, screenWidth=$screenWidth, canvasWidth=$canvasWidth',
      );
    }
  }

  void _centerOnTagSmooth({bool animate = true}) {
    if (_currentTagPosition == null) {
      return;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

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

    final targetScale = 1.0;
    final offsetX = screenWidth / 2 - (tagCanvasX * targetScale);
    final offsetY = screenHeight / 2 - (tagCanvasY * targetScale);

    final targetMatrix = Matrix4.identity()
      ..translate(offsetX, offsetY)
      ..scale(targetScale);

    if (animate) {
      final currentMatrix = _transformationController.value;
      _cameraAnimation = Matrix4Tween(begin: currentMatrix, end: targetMatrix)
          .animate(
            CurvedAnimation(
              parent: _cameraAnimationController,
              curve: Curves.easeInOutCubic,
            ),
          );

      _cameraAnimationController.forward(from: 0.0).then((_) {
        if (mounted) {
          _transformationController.value = targetMatrix;
          _lastTransformValue = targetMatrix.clone();
        }
      });

      _cameraAnimation!.addListener(_updateCameraTransform);
    } else {
      _transformationController.value = targetMatrix;
      _lastTransformValue = targetMatrix.clone();
    }
  }

  void _updateCameraTransform() {
    if (_cameraAnimation != null && mounted) {
      _transformationController.value = _cameraAnimation!.value;
    }
  }

  void _toggleFollowMode() {
    setState(() {
      _isFollowingTag = !_isFollowingTag;
    });

    if (_isFollowingTag) {
      _centerOnTagSmooth(animate: true);
      if (kDebugMode) {
        debugPrint('✅ Follow mode enabled');
      }
    } else {
      if (kDebugMode) {
        debugPrint('❌ Follow mode disabled');
      }
    }
  }

  void _toggleNearestPathVisibility() {
    final c = Get.find<SupabaseController>();
    final targetProductId = c.prioritizedProductId ?? _nearestProductId;

    if (targetProductId == null) {
      if (kDebugMode) {
        debugPrint('⚠️ No product to exclude/whitelist');
      }
      return;
    }

    setState(() {
      if (_hiddenProductPaths.contains(targetProductId)) {
        _hiddenProductPaths.remove(targetProductId);
        if (kDebugMode) {
          debugPrint('✅ Whitelisted path to $targetProductId');
        }
      } else {
        _hiddenProductPaths.add(targetProductId);
        if (kDebugMode) {
          debugPrint('❌ Excluded path to $targetProductId');
        }

        if (targetProductId == c.prioritizedProductId) {
          if (kDebugMode) {
            debugPrint(
              '🎯 Prioritized product excluded, auto-switching to nearest',
            );
          }
        }
      }
      _updateNearestProduct();
    });
  }

  // ✅ CRITICAL: Smart path updates - only if moved > 20cm
  void _computePathsFromTag() {
    if (_currentTagPosition == null || geoJsonData == null) {
      return;
    }

    // ✅ CRITICAL: Check if we've moved enough to warrant path recalculation
    if (_lastPathComputePosition != null) {
      final distance = math.sqrt(
        math.pow(_currentTagPosition!.dx - _lastPathComputePosition!.dx, 2) +
            math.pow(_currentTagPosition!.dy - _lastPathComputePosition!.dy, 2),
      );

      if (distance < _pathUpdateThreshold) {
        if (kDebugMode) {
          debugPrint(
            '⏭️ Skipped path update: ${(distance * 100).toStringAsFixed(1)}cm < ${(_pathUpdateThreshold * 100).toStringAsFixed(0)}cm threshold',
          );
        }
        return;
      }
    }

    if (kDebugMode) {
      debugPrint(
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

    for (var product in CartProducts.products) {
      final productId = product.id;
      final x = product.coordinates['x'] ?? 0.0;
      final y = product.coordinates['y'] ?? 0.0;
      final productPosition = Offset(x, y);

      final path = pathfinder.findPath(_currentTagPosition!, productPosition);

      if (path != null && path.length > 1) {
        newPaths[productId] = path;
      }
    }

    _updateNearestProduct();

    // ✅ CRITICAL: Batch update - single setState
    setState(() {
      _computedPaths = newPaths;
      _lastPathComputePosition = _currentTagPosition;
    });

    if (kDebugMode) {
      debugPrint('✅ Computed ${newPaths.length} paths');
      debugPrint('🎯 Nearest product: $_nearestProductId');
    }
  }

  void _updateNearestProduct() {
    if (_currentTagPosition == null) {
      Get.find<SupabaseController>().update();
      return;
    }

    String? nearestId;
    double nearestDistance = double.infinity;

    for (var product in CartProducts.products) {
      final productId = product.id;
      final x = product.coordinates['x'] ?? 0.0;
      final y = product.coordinates['y'] ?? 0.0;
      final productPosition = Offset(x, y);

      if (_hiddenProductPaths.contains(productId)) {
        continue;
      }

      final distance = math.sqrt(
        math.pow(_currentTagPosition!.dx - productPosition.dx, 2) +
            math.pow(_currentTagPosition!.dy - productPosition.dy, 2),
      );

      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestId = productId;
      }
    }

    // ✅ Don't call setState here - just update the value
    _nearestProductId = nearestId;
    Get.find<SupabaseController>().update();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionUpdateTimer?.cancel();
    _transformCheckTimer?.cancel();
    _stateUpdateThrottleTimer?.cancel(); // ✅ NEW: Cancel throttle timer
    _transformationController.removeListener(_onTransformChanged);
    _cleanup();
    _animationController.dispose();
    _arrowAnimationController.dispose();
    _continuousAnimationController.dispose();
    _cameraAnimationController.dispose();
    _cameraAnimation?.removeListener(_updateCameraTransform);
    _transformationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kDebugMode) {
      debugPrint('📱 App lifecycle: $state');
    }
    if (state == AppLifecycleState.paused) {
      if (kDebugMode) {
        debugPrint('⏸️ App paused - maintaining connection');
      }
    } else if (state == AppLifecycleState.resumed) {
      if (kDebugMode) {
        debugPrint('▶️ App resumed - checking connection');
      }
      _checkConnectionHealth();
    }
  }

  void _cleanup() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _streamSubscription?.cancel();
    _streamSubscription = null;

    if (_channel != null) {
      try {
        _channel!.sink.close();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Channel already closed: $e');
        }
      }
      _channel = null;
    }

    _isConnected = false;
    _isConnecting = false;
  }

  void _startHeartbeatMonitor() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (_lastMessageTime != null) {
        final timeSinceLastMessage = DateTime.now().difference(
          _lastMessageTime!,
        );
        if (timeSinceLastMessage > _heartbeatTimeout && _isConnected) {
          if (kDebugMode) {
            debugPrint(
              '💔 Heartbeat timeout: ${timeSinceLastMessage.inSeconds}s since last message',
            );
          }
          _handleSilentDisconnection();
        }
      }
    });
  }

  void _handleSilentDisconnection() {
    if (kDebugMode) {
      debugPrint('🔌 Detected silent disconnection');
    }
    _isConnected = false;
    _reconnectWithBackoff();
  }

  void _checkConnectionHealth() {
    if (!_isConnected && !_isConnecting) {
      if (kDebugMode) {
        debugPrint('🔍 Connection unhealthy, attempting reconnect');
      }
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
          if (kDebugMode) {
            debugPrint('🏓 Ping sent');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('❌ Ping failed: $e');
          }
          _handleSilentDisconnection();
        }
      }
    });
  }

  Future<void> _connectWebSocket() async {
    if (_isConnecting) {
      if (kDebugMode) {
        debugPrint('⏳ Already connecting...');
      }
      return;
    }

    _isConnecting = true;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _streamSubscription?.cancel();

    if (_channel != null) {
      try {
        await _channel!.sink.close();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Error closing previous channel: $e');
        }
      }
      _channel = null;
    }

    try {
      if (kDebugMode) {
        debugPrint('🔌 Connecting to WebSocket: $_wsUrl');
      }

      _channel = WebSocketChannel.connect(
        Uri.parse(_wsUrl),
        protocols: ['websocket'],
      );

      final timeoutFuture = Future.delayed(_connectionTimeout, () => false);
      final connectionFuture = _channel!.ready.then((_) => true).catchError((
        e,
      ) {
        if (kDebugMode) {
          debugPrint('❌ Connection error: $e');
        }
        return false;
      });

      final connected = await Future.any([connectionFuture, timeoutFuture]);

      if (!connected || !mounted) {
        throw TimeoutException('WebSocket connection timeout');
      }

      _streamSubscription = _channel!.stream.listen(
        _onWebSocketMessage,
        onError: (error) {
          if (kDebugMode) {
            debugPrint('❌ Stream error: $error');
          }
        },
        onDone: _onWebSocketDone,
        cancelOnError: false,
      );

      if (mounted) {
        setState(() {
          _isConnected = true;
          _isConnecting = false;
          _reconnectAttempts = 0;
        });
      }

      _lastMessageTime = DateTime.now();
      _startPingTimer();
      _startHeartbeatMonitor();

      if (kDebugMode) {
        debugPrint('✅ WebSocket connected - Forever mode active');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ WebSocket Connection Error: $e');
      }

      if (_channel != null) {
        try {
          await _channel!.sink.close();
        } catch (closeError) {
          if (kDebugMode) {
            debugPrint('⚠️ Error closing failed channel: $closeError');
          }
        }
        _channel = null;
      }

      if (mounted) {
        setState(() {
          _isConnected = false;
          _isConnecting = false;
        });
      }

      _reconnectWithBackoff();
    }
  }

  void _reconnectWithBackoff() {
    _reconnectTimer?.cancel();
    final delayIndex = math.min(_reconnectAttempts, _backoffDelays.length - 1);
    final delay = Duration(seconds: _backoffDelays[delayIndex]);
    if (kDebugMode) {
      debugPrint(
        '🔄 Reconnect attempt ${_reconnectAttempts + 1} in ${delay.inSeconds}s',
      );
    }

    _reconnectTimer = Timer(delay, () {
      if (mounted && !_isConnected && !_isConnecting) {
        _reconnectAttempts++;
        _connectWebSocket();
      }
    });
  }

  void _onWebSocketMessage(dynamic message) {
    try {
      _lastMessageTime = DateTime.now();

      if (kDebugMode) {
        debugPrint('📡 WebSocket message received: $message');
      }

      if (message == 'pong') {
        if (kDebugMode) {
          debugPrint('🏓 Pong received - connection alive');
        }
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

        if (kDebugMode) {
          debugPrint('✅ Transformed anchor data: $newLinks');
        }

        _processPositionUpdate(newLinks);
      } else {
        if (kDebugMode) {
          debugPrint(
            '⚠️ Ignoring data from cart_id: ${data['cart_id']} (expected: $_targetCartId)',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Parse Error: $e');
        debugPrint('Raw message: $message');
      }
    }
  }

  void _onWebSocketError(dynamic error) {
    if (kDebugMode) {
      debugPrint('❌ WebSocket Error: $error');
    }

    if (mounted) {
      setState(() {
        _isConnected = false;
      });
    }

    _reconnectWithBackoff();
  }

  void _onWebSocketDone() {
    if (kDebugMode) {
      debugPrint('⚠️ WebSocket connection closed');
    }

    if (mounted) {
      setState(() {
        _isConnected = false;
      });
    }

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
          roomWidth: roomWidth,
          roomHeight: roomHeight,
        );
      }).toList();

      final activeAnchors = listOfAnchors
          .where((a) => a.distance > 0 && a.isValid)
          .toList();

      if (activeAnchors.length < 3) {
        if (kDebugMode) {
          debugPrint('⚠️ Not enough valid anchors: ${activeAnchors.length}');
        }
        return;
      }

      Multilateration multilateration = Multilateration(
        activeAnchors,
        roomWidth: roomWidth,
        roomHeight: roomHeight,
        previousPosition: _kalmanPosition ?? _currentTagPosition,
      );

      final result = multilateration.calcUserLocation();

      if (result != null) {
        final position = result['position'] as Offset;
        final accuracy = result['accuracy'] as double;
        final constrainedPosition = Offset(
          position.dx.clamp(0.0, roomWidth),
          position.dy.clamp(0.0, roomHeight),
        );

        if (kDebugMode) {
          debugPrint(
            '✅ Tag position: (${constrainedPosition.dx.toStringAsFixed(2)}, ${constrainedPosition.dy.toStringAsFixed(2)})m, accuracy: ±${accuracy.toStringAsFixed(2)}m',
          );
        }

        _updateTagPosition(constrainedPosition, accuracy);
      }

      // ✅ CRITICAL: Don't update links in setState - just store it
      links = newLinks;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Position calculation error: $e');
      }
    }
  }

  // ✅ ULTIMATE FIX: Kalman-filtered position with throttled updates
  void _updateTagPosition(Offset newPosition, double accuracy) {
    // ✅ FIX 1: Reject poor accuracy
    if (accuracy > _maxAccuracyThreshold) {
      _consecutiveBadReadings++;
      if (kDebugMode) {
        debugPrint(
          '❌ REJECTED: Poor accuracy ${accuracy.toStringAsFixed(2)}m (threshold: $_maxAccuracyThreshold) - Bad readings: $_consecutiveBadReadings',
        );
      }

      if (_consecutiveBadReadings > _maxBadReadings) {
        if (kDebugMode) {
          debugPrint('🔄 Too many bad readings, waiting for good signal...');
        }
      }
      return;
    }

    // ✅ FIX 2: Apply Kalman filter
    final filteredPosition = _applyKalmanFilter(newPosition);

    // ✅ FIX 3: Check timeout
    if (_lastValidPositionTime != null) {
      final timeSinceLastValid = DateTime.now().difference(
        _lastValidPositionTime!,
      );
      if (timeSinceLastValid > _positionTimeout) {
        if (kDebugMode) {
          debugPrint('⏱️ Position timeout, resetting to new position');
        }

        // ✅ CRITICAL: Use scheduled update instead of setState
        _schedulePositionUpdate(filteredPosition, accuracy);
        _currentTagPosition = filteredPosition;
        _lastValidPositionTime = DateTime.now();
        _consecutiveBadReadings = 0;

        _computePathsFromTag();
        return;
      }
    }

    // ✅ FIX 4: First valid position
    if (_currentTagPosition == null) {
      // ✅ CRITICAL: Use scheduled update
      _schedulePositionUpdate(filteredPosition, accuracy);
      _currentTagPosition = filteredPosition;
      _lastValidPositionTime = DateTime.now();
      _consecutiveBadReadings = 0;

      _computePathsFromTag();

      if (_isFollowingTag) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _centerOnTagSmooth(animate: true);
          }
        });
      }
      return;
    }

    // ✅ FIX 5: Calculate movement distance
    final distance = math.sqrt(
      math.pow(filteredPosition.dx - _currentTagPosition!.dx, 2) +
          math.pow(filteredPosition.dy - _currentTagPosition!.dy, 2),
    );

    // ✅ FIX 6: Ignore micro-movements (5cm threshold)
    if (distance < _minMovementThreshold) {
      if (kDebugMode) {
        debugPrint(
          '🔇 Ignored micro-movement: ${(distance * 100).toStringAsFixed(1)}cm (threshold: ${(_minMovementThreshold * 100).toStringAsFixed(1)}cm)',
        );
      }
      _currentAccuracy = accuracy;
      _lastValidPositionTime = DateTime.now();
      _consecutiveBadReadings = 0;
      return;
    }

    // ✅ FIX 7: Valid position update - use throttled update
    _currentAccuracy = accuracy;
    _lastValidPositionTime = DateTime.now();
    _consecutiveBadReadings = 0;

    // ✅ CRITICAL: Schedule update instead of immediate setState
    _schedulePositionUpdate(filteredPosition, accuracy);

    // Add to position history
    _positionHistory.add(filteredPosition);
    _positionTimeHistory.add(DateTime.now());
    if (_positionHistory.length > _historySize) {
      _positionHistory.removeAt(0);
      _positionTimeHistory.removeAt(0);
    }

    if (kDebugMode) {
      debugPrint(
        '✅ Valid position update: ${(distance * 100).toStringAsFixed(1)}cm movement',
      );
    }

    // ✅ CRITICAL: Only update paths if moved > 20cm (throttled)
    if (distance > _pathUpdateThreshold) {
      _computePathsFromTag();
    }
  }

  // ✅ Kalman filter implementation
  Offset _applyKalmanFilter(Offset measurement) {
    final now = DateTime.now();

    if (_kalmanPosition == null) {
      _kalmanPosition = measurement;
      _kalmanVelocity = const Offset(0, 0);
      _lastKalmanUpdate = now;
      return measurement;
    }

    final dt = now.difference(_lastKalmanUpdate!).inMilliseconds / 1000.0;
    if (dt <= 0 || dt > 1.0) {
      _kalmanPosition = measurement;
      _kalmanVelocity = const Offset(0, 0);
      _lastKalmanUpdate = now;
      return measurement;
    }

    // Predict step
    final predictedPosition = Offset(
      _kalmanPosition!.dx + _kalmanVelocity!.dx * dt,
      _kalmanPosition!.dy + _kalmanVelocity!.dy * dt,
    );

    // Update step - ✅ INCREASED process noise for smoother tracking
    const processNoise = 0.08; // Increased from 0.05
    const measurementNoise = 0.20; // Increased from 0.15

    final kalmanGain = processNoise / (processNoise + measurementNoise);

    final updatedPosition = Offset(
      predictedPosition.dx +
          kalmanGain * (measurement.dx - predictedPosition.dx),
      predictedPosition.dy +
          kalmanGain * (measurement.dy - predictedPosition.dy),
    );

    // Update velocity estimate - ✅ MORE smoothing
    final newVelocity = Offset(
      (updatedPosition.dx - _kalmanPosition!.dx) / dt,
      (updatedPosition.dy - _kalmanPosition!.dy) / dt,
    );

    // ✅ INCREASED smoothing for velocity
    _kalmanVelocity = Offset(
      _kalmanVelocity!.dx * 0.80 + newVelocity.dx * 0.20, // Was 0.7/0.3
      _kalmanVelocity!.dy * 0.80 + newVelocity.dy * 0.20,
    );

    _kalmanPosition = updatedPosition;
    _lastKalmanUpdate = now;

    return updatedPosition;
  }

  @override
  Widget build(BuildContext context) {
    final canvasWidth =
        metersToPixels(roomWidth, baseConvertion: baseConvertion.toInt()) + 100;
    final canvasHeight =
        metersToPixels(roomHeight, baseConvertion: baseConvertion.toInt()) +
        100;
    final c = Get.find<SupabaseController>();

    return GetBuilder<SupabaseController>(
      builder: (con) {
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 0.0,
            systemOverlayStyle: SystemUiOverlayStyle(
              systemNavigationBarColor: Colors.green,
            ),
          ),
          backgroundColor: const Color(0xFFF5F5F5),
          bottomNavigationBar: BottomBarWithSheet(
            disableMainActionButton: true,
            onSelectItem: (index) {
              if (index == 1) {
                context.pushRoute(const SearchView());
              } else {
                _bottomWithSheelController.toggleSheet();
              }
            },
            controller: _bottomWithSheelController,
            bottomBarTheme: const BottomBarTheme(
              contentPadding: EdgeInsets.only(top: 10),
              selectedItemIconColor: Colors.white,
              heightClosed: 50,
              itemIconSize: 27,
              selectedItemIconSize: 27,
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
              ),
              itemIconColor: Colors.white,
            ),
            items: const [
              BottomBarWithSheetItem(icon: Icons.menu_open_rounded),
              BottomBarWithSheetItem(icon: Icons.search_rounded),
            ],
            sheetChild: Container(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      const Text(
                        'Products',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        "Total: ₱${c.getTotal()}",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsetsGeometry.symmetric(horizontal: 18),
                      child: SingleChildScrollView(
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 25,
                                mainAxisSpacing: 30,
                                childAspectRatio: 0.8,
                              ),
                          itemCount: CartProducts.products.length,
                          itemBuilder: (context, index) {
                            if (CartProducts.products.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            return GestureDetector(
                              onTap: () {
                                _handleProductListTap(
                                  CartProducts.products[index].id,
                                );
                                _bottomWithSheelController.closeSheet();
                              },
                              child: buildProductCard(
                                CartProducts.products[index],
                                isFromCart: true,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: SafeArea(
            child: Stack(
              children: [
                Listener(
                  onPointerDown: (details) {
                    _handleCanvasTap(details.localPosition);
                  },
                  child: AnimatedBuilder(
                    animation: _arrowAnimationController,
                    builder: (context, child) {
                      return InteractiveViewer(
                        transformationController: _transformationController,
                        minScale: 0.3,
                        maxScale: 4.0,
                        boundaryMargin: const EdgeInsets.all(double.infinity),
                        constrained: false,
                        panEnabled: true,
                        scaleEnabled: true,
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: StaticMapCanvas(
                              roomWidth: roomWidth,
                              roomHeight: roomHeight,
                              baseConvertion: baseConvertion,
                              tagPosition: _currentTagPosition,
                              tagAccuracy: _currentAccuracy,
                              productsLocation: CartProducts.products,
                              geoJsonData: geoJsonData,
                              computedPaths: _computedPaths,
                              hiddenProductPaths: _hiddenProductPaths,
                              nearestProductId: _displayedProductId,
                              animationValue: _arrowAnimationController.value,
                            ),
                            size: Size(canvasWidth, canvasHeight),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    context.replaceRoute(CartView());
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    margin: EdgeInsets.only(left: 10),
                    child: Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
                if (_displayedProductId != null &&
                    !_hiddenProductPaths.contains(_displayedProductId))
                  Positioned(
                    top: 35,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(28),
                        shadowColor: Colors.black26,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors:
                                  c.prioritizedProductId != null &&
                                      !_hiddenProductPaths.contains(
                                        c.prioritizedProductId,
                                      )
                                  ? [
                                      const Color(0xFF10b981),
                                      const Color(0xFF059669),
                                    ]
                                  : [
                                      const Color(0xFF06b6d4),
                                      const Color(0xFF0891b2),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                c.prioritizedProductId != null &&
                                        !_hiddenProductPaths.contains(
                                          c.prioritizedProductId,
                                        )
                                    ? Icons.star
                                    : Icons.navigation,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Heading to',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    CartProducts.products
                                        .where(
                                          (p) => p.id == _displayedProductId,
                                        )
                                        .first
                                        .name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              if (_nearestProductDistance != null) ...[
                                const SizedBox(width: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_nearestProductDistance!.toStringAsFixed(1)}m',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_selectedProductId != null &&
                    _selectedProductPosition != null)
                  Builder(
                    builder: (context) {
                      final screenPos = _getScreenPosition(
                        _selectedProductPosition!,
                      );
                      return ProductCallout(
                        productId: _selectedProductId!,
                        position: screenPos,
                        onClose: () {
                          setState(() {
                            _selectedProductId = null;
                            _selectedProductPosition = null;
                          });
                        },
                      );
                    },
                  ),
                Positioned(
                  bottom: 24,
                  left: 24,
                  child: Material(
                    elevation: 12,
                    borderRadius: BorderRadius.circular(56),
                    shadowColor: Colors.black38,
                    child: InkWell(
                      onTap: _toggleNearestPathVisibility,
                      borderRadius: BorderRadius.circular(56),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(56),
                        ),
                        child: Icon(Icons.route_outlined, color: Colors.white),
                      ),
                    ),
                  ),
                ),
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
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(56),
                        ),
                        child: Icon(
                          _isFollowingTag
                              ? Icons.gps_fixed
                              : Icons.gps_not_fixed,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ProductCallout extends StatelessWidget {
  final String productId;
  final Offset position;
  final VoidCallback onClose;

  const ProductCallout({
    super.key,
    required this.productId,
    required this.position,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx - 75,
      top: position.dy + 35,
      child: GestureDetector(
        onTap: () {},
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          shadowColor: Colors.black26,
          child: Container(
            width: 150,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFe5e7eb), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3b82f6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.inventory_2,
                        color: Color(0xFF3b82f6),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        CartProducts.products
                            .where((p) => p.id == productId)
                            .first
                            .name,
                        style: const TextStyle(
                          color: Color(0xFF1f2937),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Product Details',
                  style: TextStyle(
                    color: Color(0xFF6b7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Text(
                  'Rack: 2',
                  style: TextStyle(
                    color: Color(0xFF6b7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    final c = Get.find<SupabaseController>();
                    c.prioritizedProductId = productId;
                    if (kDebugMode) {
                      debugPrint('🎯 Prioritized product: $productId');
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10b981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_circle_up_rounded,
                          color: Color(0xFF10b981),
                          size: 20,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Navigate',
                          style: TextStyle(
                            color: Color(0xFF10b981),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
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
    );
  }
}

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
        if (_isPointInOrNearPolygon(point, obstacle.points, buffer))
          return true;
      } else if (obstacle.type == ObstacleType.line) {
        if (_isPointNearPolyline(point, obstacle.points, buffer)) return true;
      } else if (obstacle.type == ObstacleType.circle) {
        final center = obstacle.points.first;
        final distance = math.sqrt(
          math.pow(point.dx - center.dx, 2) + math.pow(point.dy - center.dy, 2),
        );
        if (distance < obstacle.radius! + buffer) return true;
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
      if (distance < buffer) return true;
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
      if (distance < threshold) return true;
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
    if (_isObstacle(start)) return null;

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
        if (_distance(path.last, goal) > 0.05) path.add(goal);
        return _aggressiveSmoothing(path);
      }
      closedSet.add(current.position);
      for (var neighbor in _getNeighbors(current.position)) {
        if (closedSet.contains(neighbor) || _isObstacle(neighbor)) continue;
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
        if (!_isObstacle(candidate, isGoal: true)) return candidate;
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

  double _heuristic(Offset a, Offset b) =>
      math.sqrt(math.pow(a.dx - b.dx, 2) + math.pow(a.dy - b.dy, 2));

  double _distance(Offset a, Offset b) =>
      math.sqrt(math.pow(a.dx - b.dx, 2) + math.pow(a.dy - b.dy, 2));

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
      if (_isObstacle(point)) return false;
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

  E removeFirst() => _elements.removeAt(0);
  bool get isNotEmpty => _elements.isNotEmpty;
  bool get isEmpty => _elements.isEmpty;
}

// ✅ StaticMapCanvas - Optimized rendering
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
  final List<Product> productsLocation;
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
      colors: [Colors.green.shade600, Colors.green.shade300],
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
    bool isDisplayed,
  ) {
    if (path.length < 2) return;
    final pathColor = isDisplayed
        ? color
        : const Color(0xFF9CA3AF).withValues(alpha: 0.2);
    final strokeWidth = isDisplayed ? 5.0 : 3.0;

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

    if (isDisplayed) {
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

    if (isDisplayed) {
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
          ? const Color(0xFFe5e7eb)
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
    Color strokeColor = Colors.transparent;

    if (amenity == 'room') {
      fillColor = const Color(0xFFdbeafe);
      strokeColor = Colors.transparent;
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
        final isDisplayed = entry.key == nearestProductId;
        _drawPath(
          canvas,
          entry.value,
          colors[colorIndex % colors.length],
          isDisplayed,
        );
      }
      colorIndex++;
    }

    for (var product in productsLocation) {
      final id = product.id;
      final x = product.coordinates['x'] ?? 0.0;
      final y = product.coordinates['y'] ?? 0.0;
      final position = Offset(x, y);
      _drawPinpoint(canvas, id, position);
    }

    if (tagPosition != null) {
      _drawTag(canvas, tagPosition!, tagAccuracy);
    }
  }

  @override
  bool shouldRepaint(covariant StaticMapCanvas oldDelegate) => true;
}

class Anchor {
  String id;
  Size size;
  num baseConvertion;
  late double x;
  late double y;
  late double distance;
  late bool isValid;
  final double roomWidth;
  final double roomHeight;

  Anchor(
    String range, {
    required this.id,
    required Offset position,
    required this.size,
    required this.baseConvertion,
    required this.roomWidth,
    required this.roomHeight,
  }) {
    x = position.dx;
    y = position.dy;
    final parsedDistance = double.tryParse(range);
    distance = (parsedDistance != null && parsedDistance >= 0)
        ? parsedDistance
        : 0.0;

    final maxPossibleDistance =
        math.sqrt(roomWidth * roomWidth + roomHeight * roomHeight) + 2.0;
    isValid = distance > 0.1 && distance < maxPossibleDistance;

    if (kDebugMode && !isValid) {
      debugPrint(
        '⚠️ Invalid anchor $id: distance=$distance (max=$maxPossibleDistance)',
      );
    }
  }
}

// ✅ FINAL: Freeze-free Multilateration
class Multilateration {
  List<Anchor> anchors;
  final double roomWidth;
  final double roomHeight;
  final Offset? previousPosition;

  Multilateration(
    this.anchors, {
    required this.roomWidth,
    required this.roomHeight,
    this.previousPosition,
  });

  Map<String, dynamic>? calcUserLocation() {
    if (anchors.length < 3) return null;

    try {
      final cleanedAnchors = _removeOutliers(anchors);
      if (cleanedAnchors.length < 3) {
        if (kDebugMode) {
          debugPrint('⚠️ Not enough valid anchors after outlier removal');
        }
        return null;
      }

      Offset? position = _weightedLeastSquares(cleanedAnchors);

      // ✅ Enhanced smoothing
      if (position != null && previousPosition != null) {
        position = _applyEnhancedSmoothing(position, previousPosition!);
      }

      if (position == null || !position.dx.isFinite || !position.dy.isFinite) {
        return null;
      }

      double rmsError = _calculateWeightedRMSE(position, cleanedAnchors);

      return {'position': position, 'accuracy': rmsError};
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Multilateration error: $e');
      }
      return null;
    }
  }

  List<Anchor> _removeOutliers(List<Anchor> allAnchors) {
    if (allAnchors.length <= 3) return allAnchors;

    final List<Anchor> cleaned = [];
    for (var anchor in allAnchors) {
      int consistentCount = 0;
      for (var other in allAnchors) {
        if (anchor.id == other.id) continue;
        final anchorDist = math.sqrt(
          math.pow(anchor.x - other.x, 2) + math.pow(anchor.y - other.y, 2),
        );
        final minDist = (anchor.distance - other.distance).abs();
        final maxDist = anchor.distance + other.distance;
        if (anchorDist >= minDist - 0.5 && anchorDist <= maxDist + 0.5) {
          consistentCount++;
        }
      }
      if (consistentCount >= (allAnchors.length / 2)) {
        cleaned.add(anchor);
      } else {
        if (kDebugMode) {
          debugPrint(
            '🗑️ Removing outlier anchor: ${anchor.id} (dist=${anchor.distance.toStringAsFixed(2)}m)',
          );
        }
      }
    }
    return cleaned.isNotEmpty ? cleaned : allAnchors;
  }

  Offset? _weightedLeastSquares(List<Anchor> validAnchors) {
    double x = _getInitialX(validAnchors);
    double y = _getInitialY(validAnchors);

    const int maxIterations = 80;
    const double convergenceThreshold = 1e-6;

    for (int iteration = 0; iteration < maxIterations; iteration++) {
      List<List<double>> J = [];
      List<double> r = [];
      List<double> weights = [];

      for (var anchor in validAnchors) {
        if (anchor.distance <= 0) continue;
        double dx = x - anchor.x;
        double dy = y - anchor.y;
        double dist = math.sqrt(dx * dx + dy * dy);
        if (dist < 0.01) dist = 0.01;

        double residual = dist - anchor.distance;
        r.add(residual);
        J.add([dx / dist, dy / dist]);
        double weight = 1.0 / (1.0 + anchor.distance);
        weights.add(weight);
      }

      if (J.isEmpty) return null;

      double jtJ00 = 0, jtJ01 = 0, jtJ11 = 0;
      for (int i = 0; i < J.length; i++) {
        final w = weights[i];
        jtJ00 += w * J[i][0] * J[i][0];
        jtJ01 += w * J[i][0] * J[i][1];
        jtJ11 += w * J[i][1] * J[i][1];
      }

      double jtr0 = 0, jtr1 = 0;
      for (int i = 0; i < J.length; i++) {
        final w = weights[i];
        jtr0 += w * J[i][0] * r[i];
        jtr1 += w * J[i][1] * r[i];
      }

      double det = jtJ00 * jtJ11 - jtJ01 * jtJ01;
      if (det.abs() < 1e-10) break;

      double inv00 = jtJ11 / det;
      double inv01 = -jtJ01 / det;
      double inv11 = jtJ00 / det;

      double deltaX = -(inv00 * jtr0 + inv01 * jtr1);
      double deltaY = -(inv01 * jtr0 + inv11 * jtr1);

      x = (x + deltaX).clamp(0.0, roomWidth);
      y = (y + deltaY).clamp(0.0, roomHeight);

      double stepSize = math.sqrt(deltaX * deltaX + deltaY * deltaY);
      if (stepSize < convergenceThreshold) break;
    }

    return Offset(x, y);
  }

  double _getInitialX(List<Anchor> validAnchors) {
    if (previousPosition != null) return previousPosition!.dx;
    double weightedSum = 0;
    double totalWeight = 0;
    for (var anchor in validAnchors) {
      if (anchor.distance > 0) {
        double weight = 1.0 / (1.0 + anchor.distance);
        weightedSum += anchor.x * weight;
        totalWeight += weight;
      }
    }
    return totalWeight > 0
        ? (weightedSum / totalWeight).clamp(0.0, roomWidth)
        : roomWidth / 2;
  }

  double _getInitialY(List<Anchor> validAnchors) {
    if (previousPosition != null) return previousPosition!.dy;
    double weightedSum = 0;
    double totalWeight = 0;
    for (var anchor in validAnchors) {
      if (anchor.distance > 0) {
        double weight = 1.0 / (1.0 + anchor.distance);
        weightedSum += anchor.y * weight;
        totalWeight += weight;
      }
    }
    return totalWeight > 0
        ? (weightedSum / totalWeight).clamp(0.0, roomHeight)
        : roomHeight / 2;
  }

  // ✅ FINAL: Enhanced smoothing - stable movement
  Offset _applyEnhancedSmoothing(Offset newPos, Offset prevPos) {
    final distance = math.sqrt(
      math.pow(newPos.dx - prevPos.dx, 2) + math.pow(newPos.dy - prevPos.dy, 2),
    );

    // ✅ Increased dead zone to 2cm (was 1.5cm)
    if (distance < 0.02) return prevPos;

    // ✅ SMOOTHER graduated alpha
    double alpha;
    if (distance < 0.06) {
      alpha = 0.20; // Very heavy smoothing
    } else if (distance < 0.15) {
      alpha = 0.40;
    } else if (distance < 0.30) {
      alpha = 0.60;
    } else if (distance < 0.50) {
      alpha = 0.75;
    } else {
      alpha = 0.88;
    }

    return Offset(
      prevPos.dx + alpha * (newPos.dx - prevPos.dx),
      prevPos.dy + alpha * (newPos.dy - prevPos.dy),
    );
  }

  double _calculateWeightedRMSE(Offset position, List<Anchor> validAnchors) {
    double sumWeightedSquaredError = 0;
    double totalWeight = 0;

    for (var anchor in validAnchors) {
      if (anchor.distance <= 0) continue;
      double dx = position.dx - anchor.x;
      double dy = position.dy - anchor.y;
      double calculatedDist = math.sqrt(dx * dx + dy * dy);
      double error = calculatedDist - anchor.distance;
      double weight = 1.0 / (1.0 + anchor.distance);
      sumWeightedSquaredError += weight * error * error;
      totalWeight += weight;
    }

    if (totalWeight == 0) return 0;
    return math.sqrt(sumWeightedSquaredError / totalWeight);
  }
}
