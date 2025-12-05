// ignore_for_file: unused_field
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:auto_route/auto_route.dart';
import 'package:bottom_bar_with_sheet/bottom_bar_with_sheet.dart';
import 'package:egcart_mobile/controller/supabase_controller.dart';
import 'package:egcart_mobile/models/product_model.dart';
import 'package:egcart_mobile/models/uwb_model.dart';
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

// ✅ Position quality state for prediction mode
enum PositionQuality { good, degraded, lost }

@RoutePage()
class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final String _esp32IpAddress = UwbContent.ipAdress;
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

  // ✅ Kalman filter state
  Offset? _kalmanPosition;
  Offset? _kalmanVelocity;
  DateTime? _lastKalmanUpdate;

  // ✅ Position quality tracking
  PositionQuality _positionQuality = PositionQuality.lost;
  DateTime? _lastGoodMeasurementTime;
  static const Duration _maxPredictionDuration = Duration(seconds: 2);

  // ✅ Enhanced thresholds
  DateTime? _lastStateUpdateTime;
  Timer? _stateUpdateThrottleTimer;
  static const Duration _minUpdateInterval = Duration(milliseconds: 100);
  bool _hasPendingUpdate = false;

  DateTime? _lastValidPositionTime;
  int _consecutiveBadReadings = 0;
  static const int _maxBadReadings = 5;
  static const Duration _positionTimeout = Duration(seconds: 5);
  static const double _maxAccuracyThreshold = 1.5;
  static const double _minMovementThreshold = 0.05;

  // ✅ Innovation and speed gates
  static const double _maxSpeedMps = 1.8; // m/s max cart speed
  static const double _spatialJumpLimit = 1.0; // hard jump limit per update

  // ✅ Adaptive path update threshold
  double _pathUpdateThreshold = 0.20;
  static const double _pathUpdateThresholdMin = 0.10;
  static const double _pathUpdateThresholdMax = 0.40;

  Offset? _pendingTargetPosition;
  double? _pendingAccuracy;

  // ✅ Dynamic segment for continuous path
  Offset? _dynamicPathSegmentStart;
  Offset? _dynamicPathSegmentEnd;

  final List<Offset> _positionHistory = [];
  final List<DateTime> _positionTimeHistory = [];
  static const int _historySize = 5;

  // ✅ NEW: Per-anchor spike detection
  final Map<String, double> _previousAnchorRanges = {};
  final Map<String, DateTime> _lastAnchorUpdateTime = {};
  final Map<String, int> _anchorSpikeCount = {};
  final Map<String, int> _anchorHealthScore = {};

  Map<String, Offset> get anchorPositions => {
    "A0084": const Offset(0, 0),
    "A0085": Offset(roomWidth, 0),
    "A0086": Offset(0, roomHeight),
    "A0087": Offset(roomWidth, roomHeight),
  };

  String? get _displayedProductId {
    final c = Get.find<SupabaseController>();
    if (c.prioritizedProductId != null &&
        !c.hiddenProductPaths.contains(c.prioritizedProductId)) {
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
    _startThrottledStateUpdates();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _processPositionUpdate(links);
        _setInitialZoom();
        _toggleFollowMode();
      }
    });
  }

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

          if (estimatedVelocity > 0.5) {
            speed = 0.30;
          } else if (distance > 0.3) {
            speed = 0.25;
          } else if (distance > 0.15) {
            speed = 0.18;
          } else if (distance > 0.05) {
            speed = 0.12;
          } else {
            speed = 0.08;
          }

          _currentTagPosition = Offset(
            _currentTagPosition!.dx +
                (_targetTagPosition!.dx - _currentTagPosition!.dx) * speed,
            _currentTagPosition!.dy +
                (_targetTagPosition!.dy - _currentTagPosition!.dy) * speed,
          );

          // ✅ Update dynamic path segment continuously
          _updateDynamicPathSegment();

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

  // ✅ Update dynamic segment from tag to nearest path point
  void _updateDynamicPathSegment() {
    if (_currentTagPosition == null || _displayedProductId == null) {
      _dynamicPathSegmentStart = null;
      _dynamicPathSegmentEnd = null;
      return;
    }

    final path = _computedPaths[_displayedProductId];
    if (path == null || path.isEmpty) {
      _dynamicPathSegmentStart = null;
      _dynamicPathSegmentEnd = null;
      return;
    }

    // Find nearest point on path
    double minDistance = double.infinity;
    Offset? nearestPoint;

    for (var pathPoint in path) {
      final distance = math.sqrt(
        math.pow(_currentTagPosition!.dx - pathPoint.dx, 2) +
            math.pow(_currentTagPosition!.dy - pathPoint.dy, 2),
      );
      if (distance < minDistance) {
        minDistance = distance;
        nearestPoint = pathPoint;
      }
    }

    // Only show dynamic segment if tag is far from path
    if (nearestPoint != null && minDistance > 0.1) {
      _dynamicPathSegmentStart = _currentTagPosition;
      _dynamicPathSegmentEnd = nearestPoint;
    } else {
      _dynamicPathSegmentStart = null;
      _dynamicPathSegmentEnd = null;
    }
  }

  void _loadDefaultGeoJsonData() {
    String geoJsonString = UwbContent.geoJson;

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
      if (c.hiddenProductPaths.contains(targetProductId)) {
        c.hiddenProductPaths.remove(targetProductId);
        if (kDebugMode) {
          debugPrint('✅ Whitelisted path to $targetProductId');
        }
      } else {
        c.hiddenProductPaths.add(targetProductId);
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

  // ✅ Adaptive path update threshold based on velocity
  void _computePathsFromTag() {
    if (_currentTagPosition == null || geoJsonData == null) {
      return;
    }

    // Adaptive threshold based on velocity
    final velocity = _estimateVelocity();
    if (velocity > 0.5) {
      _pathUpdateThreshold = _pathUpdateThresholdMin;
    } else if (velocity < 0.1) {
      _pathUpdateThreshold = _pathUpdateThresholdMax;
    } else {
      _pathUpdateThreshold = 0.20;
    }

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

    final c = Get.find<SupabaseController>();
    String? nearestId;
    double nearestDistance = double.infinity;

    for (var product in CartProducts.products) {
      final productId = product.id;
      final x = product.coordinates['x'] ?? 0.0;
      final y = product.coordinates['y'] ?? 0.0;
      final productPosition = Offset(x, y);

      if (c.hiddenProductPaths.contains(productId)) {
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

    _nearestProductId = nearestId;
    Get.find<SupabaseController>().update();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionUpdateTimer?.cancel();
    _transformCheckTimer?.cancel();
    _stateUpdateThrottleTimer?.cancel();
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

      try {
        _channel = WebSocketChannel.connect(
          Uri.parse(_wsUrl),
          protocols: ['websocket'],
        );
      } catch (connectionError) {
        if (kDebugMode) {
          debugPrint(
            '❌ WebSocket connection creation failed: $connectionError',
          );
        }
        rethrow;
      }

      final timeoutFuture = Future.delayed(_connectionTimeout, () => false);

      final connectionFuture = _channel!.ready
          .then((_) {
            if (kDebugMode) {
              debugPrint('✅ WebSocket ready signal received');
            }
            return true;
          })
          .catchError((e) {
            if (kDebugMode) {
              debugPrint('❌ WebSocket ready error: $e');
            }
            return false;
          });

      final connected = await Future.any([connectionFuture, timeoutFuture]);

      if (!connected) {
        if (kDebugMode) {
          debugPrint('❌ WebSocket connection failed or timed out');
        }
        throw TimeoutException('WebSocket connection timeout or failed');
      }

      if (!mounted) {
        if (kDebugMode) {
          debugPrint('⚠️ Widget unmounted during connection');
        }
        return;
      }

      _streamSubscription = _channel!.stream.listen(
        _onWebSocketMessage,
        onError: (error, stackTrace) {
          if (kDebugMode) {
            debugPrint('❌ WebSocket stream error: $error');
            debugPrint('Stack trace: $stackTrace');
          }
        },
        onDone: () {
          if (kDebugMode) {
            debugPrint('⚠️ WebSocket stream done');
          }
          _onWebSocketDone();
        },
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
        debugPrint('✅ WebSocket connected successfully');
      }
    } on SocketException catch (e) {
      if (kDebugMode) {
        debugPrint('❌ SocketException: ${e.message}');
        debugPrint('   Address: ${e.address}, Port: ${e.port}');
        debugPrint('   Make sure ESP32 server is running on $_wsUrl');
      }

      if (_channel != null) {
        try {
          await _channel!.sink.close();
        } catch (closeError) {
          // Ignore - socket already closed
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
    } on TimeoutException catch (e) {
      if (kDebugMode) {
        debugPrint('❌ TimeoutException: $e');
      }

      if (_channel != null) {
        try {
          await _channel!.sink.close();
        } catch (closeError) {
          // Ignore - cleanup during error recovery
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
    } on WebSocketChannelException catch (e) {
      if (kDebugMode) {
        debugPrint('❌ WebSocketChannelException: $e');
        if (e.inner != null) {
          debugPrint('   Inner exception: ${e.inner}');
        }
      }

      if (_channel != null) {
        try {
          await _channel!.sink.close();
        } catch (closeError) {
          // Ignore - connection failed, cleanup only
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
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ Unexpected WebSocket error: $e');
        debugPrint('Stack trace: $stackTrace');
      }

      if (_channel != null) {
        try {
          await _channel!.sink.close();
        } catch (closeError) {
          // Ignore - final cleanup before reconnect
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

  // ✅ NEW: Pre-filter anchor spikes BEFORE multilateration
  List<Anchor> _preFilterAnchorSpikes(List<Anchor> anchors) {
    const maxAnchorJumpPerSecond = 5.0; // meters/second max anchor range change
    const spikeThreshold = 3; // Reject after 3 consecutive spikes

    final cleanAnchors = <Anchor>[];
    final now = DateTime.now();

    for (var anchor in anchors) {
      final anchorId = anchor.id;
      final currentRange = anchor.distance;

      // Check if we have previous data
      if (_previousAnchorRanges.containsKey(anchorId) &&
          _lastAnchorUpdateTime.containsKey(anchorId)) {
        final previousRange = _previousAnchorRanges[anchorId]!;
        final previousTime = _lastAnchorUpdateTime[anchorId]!;
        final dt = now.difference(previousTime).inMilliseconds / 1000.0;

        if (dt > 0 && dt < 2.0) {
          // Only check if time diff is reasonable
          final rangeDiff = (currentRange - previousRange).abs();
          final impliedSpeed = rangeDiff / dt;

          // SPIKE DETECTION
          if (impliedSpeed > maxAnchorJumpPerSecond) {
            final spikeCount = _anchorSpikeCount[anchorId] ?? 0;
            _anchorSpikeCount[anchorId] = spikeCount + 1;

            if (kDebugMode) {
              debugPrint(
                '⚠️ Anchor $anchorId spike: ${rangeDiff.toStringAsFixed(2)}m '
                'in ${(dt * 1000).toStringAsFixed(0)}ms '
                '(${impliedSpeed.toStringAsFixed(1)}m/s) - count: ${spikeCount + 1}',
              );
            }

            // Reject after multiple consecutive spikes
            if (spikeCount >= spikeThreshold) {
              if (kDebugMode) {
                debugPrint('❌ Anchor $anchorId rejected - too many spikes');
              }
              continue; // Skip this anchor
            }
          } else {
            // Reset spike count on good reading
            _anchorSpikeCount[anchorId] = 0;
          }
        }
      }

      // Update history
      _previousAnchorRanges[anchorId] = currentRange;
      _lastAnchorUpdateTime[anchorId] = now;
      cleanAnchors.add(anchor);
    }

    return cleanAnchors;
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

      // ✅ NEW: Pre-filter anchor spikes BEFORE multilateration
      final cleanAnchors = _preFilterAnchorSpikes(activeAnchors);

      if (cleanAnchors.length < 3) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ Not enough clean anchors after spike filtering: ${cleanAnchors.length}',
          );
        }
        return;
      }

      // ✅ Enhanced multilateration with anchor residual filtering
      Multilateration multilateration = Multilateration(
        cleanAnchors, // ← Use cleaned anchors
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

      links = newLinks;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Position calculation error: $e');
      }
    }
  }

  // ✅ Production-grade position update with prediction mode & innovation gates
  void _updateTagPosition(Offset newPosition, double accuracy) {
    final now = DateTime.now();

    // 1) Handle bad accuracy with prediction mode instead of freeze
    if (accuracy > _maxAccuracyThreshold) {
      _consecutiveBadReadings++;

      if (_kalmanPosition != null && _lastKalmanUpdate != null) {
        // Use pure prediction from Kalman state (no measurement update)
        final timeSinceLastGood = _lastGoodMeasurementTime != null
            ? now.difference(_lastGoodMeasurementTime!)
            : Duration.zero;

        if (timeSinceLastGood < _maxPredictionDuration) {
          final predicted = _predictFromKalman(now, decayVelocity: true);
          _positionQuality = PositionQuality.degraded;

          _schedulePositionUpdate(predicted, _currentAccuracy);
          _currentTagPosition ??= predicted;

          if (kDebugMode) {
            debugPrint(
              '⚠️ DEGRADED: Poor accuracy ${accuracy.toStringAsFixed(2)}m - using prediction (${timeSinceLastGood.inMilliseconds}ms since good)',
            );
          }
        } else {
          _positionQuality = PositionQuality.lost;
          if (kDebugMode) {
            debugPrint('❌ LOST: Extended poor accuracy, stopped prediction');
          }
        }
      } else {
        _positionQuality = PositionQuality.lost;
      }
      return;
    }

    // 2) We have nominal accuracy → apply Kalman with innovation/speed gate
    final fused = _applyKalmanFilterWithGates(newPosition, accuracy, now);

    if (fused == null) {
      // Innovation gate rejected this measurement as outlier
      _consecutiveBadReadings++;
      if (kDebugMode) {
        debugPrint('❌ Innovation gate rejected measurement as outlier');
      }
      return;
    }

    // 3) Good measurement accepted
    _consecutiveBadReadings = 0;
    _lastGoodMeasurementTime = now;
    _positionQuality = PositionQuality.good;

    // 4) First valid position
    if (_currentTagPosition == null) {
      _schedulePositionUpdate(fused, accuracy);
      _currentTagPosition = fused;
      _lastValidPositionTime = now;

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

    // 5) Calculate movement distance
    final distance = math.sqrt(
      math.pow(fused.dx - _currentTagPosition!.dx, 2) +
          math.pow(fused.dy - _currentTagPosition!.dy, 2),
    );

    // 6) Ignore micro-movements
    if (distance < _minMovementThreshold) {
      if (kDebugMode) {
        debugPrint(
          '🔇 Ignored micro-movement: ${(distance * 100).toStringAsFixed(1)}cm',
        );
      }
      _currentAccuracy = accuracy;
      _lastValidPositionTime = now;
      return;
    }

    // 7) Valid position update
    _currentAccuracy = accuracy;
    _lastValidPositionTime = now;

    _schedulePositionUpdate(fused, accuracy);

    _positionHistory.add(fused);
    _positionTimeHistory.add(now);
    if (_positionHistory.length > _historySize) {
      _positionHistory.removeAt(0);
      _positionTimeHistory.removeAt(0);
    }

    if (kDebugMode) {
      debugPrint(
        '✅ Valid position update: ${(distance * 100).toStringAsFixed(1)}cm movement, quality: $_positionQuality',
      );
    }

    // 8) Update paths with adaptive threshold
    final velocity = _estimateVelocity();
    if (distance > _pathUpdateThreshold || velocity > 0.5) {
      _computePathsFromTag();
    }
  }

  // ✅ Kalman prediction only (for degraded mode)
  Offset _predictFromKalman(DateTime now, {bool decayVelocity = false}) {
    if (_kalmanPosition == null ||
        _kalmanVelocity == null ||
        _lastKalmanUpdate == null) {
      return _currentTagPosition ?? const Offset(0, 0);
    }

    final dt = now.difference(_lastKalmanUpdate!).inMilliseconds / 1000.0;
    if (dt <= 0 || dt > 1.0) {
      return _kalmanPosition!;
    }

    // Predict position
    var predictedPosition = Offset(
      _kalmanPosition!.dx + _kalmanVelocity!.dx * dt,
      _kalmanPosition!.dy + _kalmanVelocity!.dy * dt,
    );

    // Constrain to room
    predictedPosition = Offset(
      predictedPosition.dx.clamp(0.0, roomWidth),
      predictedPosition.dy.clamp(0.0, roomHeight),
    );

    // Decay velocity to prevent unbounded drift
    if (decayVelocity) {
      const decayFactor = 0.85; // Decay 15% per prediction
      _kalmanVelocity = Offset(
        _kalmanVelocity!.dx * decayFactor,
        _kalmanVelocity!.dy * decayFactor,
      );
    }

    _kalmanPosition = predictedPosition;
    _lastKalmanUpdate = now;

    return predictedPosition;
  }

  // ✅ Kalman filter with innovation & speed gates
  Offset? _applyKalmanFilterWithGates(
    Offset measurement,
    double accuracy,
    DateTime now,
  ) {
    // Initialize on first measurement
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

    // 1) Predict step
    final predictedPosition = Offset(
      _kalmanPosition!.dx + _kalmanVelocity!.dx * dt,
      _kalmanPosition!.dy + _kalmanVelocity!.dy * dt,
    );

    // 2) Innovation gate: check if measurement is physically plausible
    final innovation = math.sqrt(
      math.pow(measurement.dx - predictedPosition.dx, 2) +
          math.pow(measurement.dy - predictedPosition.dy, 2),
    );

    final impliedSpeed = innovation / dt;

    // Hard spatial jump limit
    if (innovation > _spatialJumpLimit) {
      if (kDebugMode) {
        debugPrint(
          '❌ Spatial jump rejected: ${innovation.toStringAsFixed(2)}m (max: $_spatialJumpLimit)',
        );
      }
      return null; // Reject outlier
    }

    // Speed gate
    if (impliedSpeed > _maxSpeedMps) {
      if (kDebugMode) {
        debugPrint(
          '❌ Speed gate rejected: ${impliedSpeed.toStringAsFixed(2)}m/s (max: $_maxSpeedMps)',
        );
      }
      // Clamp to max speed instead of full reject
      final direction = Offset(
        (measurement.dx - predictedPosition.dx) / innovation,
        (measurement.dy - predictedPosition.dy) / innovation,
      );
      final clampedMeasurement = Offset(
        predictedPosition.dx + direction.dx * _maxSpeedMps * dt,
        predictedPosition.dy + direction.dy * _maxSpeedMps * dt,
      );
      return _applyKalmanUpdate(
        clampedMeasurement,
        accuracy,
        predictedPosition,
        dt,
        now,
      );
    }

    // 3) Measurement passed gates, apply Kalman update
    return _applyKalmanUpdate(
      measurement,
      accuracy,
      predictedPosition,
      dt,
      now,
    );
  }

  // ✅ Kalman update step
  Offset _applyKalmanUpdate(
    Offset measurement,
    double accuracy,
    Offset predictedPosition,
    double dt,
    DateTime now,
  ) {
    // Adaptive noise based on accuracy
    const processNoise = 0.08;
    final measurementNoise =
        0.15 + (accuracy * 0.1); // Worse accuracy = more noise

    final kalmanGain = processNoise / (processNoise + measurementNoise);

    final updatedPosition = Offset(
      predictedPosition.dx +
          kalmanGain * (measurement.dx - predictedPosition.dx),
      predictedPosition.dy +
          kalmanGain * (measurement.dy - predictedPosition.dy),
    );

    // Update velocity estimate
    final newVelocity = Offset(
      (updatedPosition.dx - _kalmanPosition!.dx) / dt,
      (updatedPosition.dy - _kalmanPosition!.dy) / dt,
    );

    // Smooth velocity with EMA
    _kalmanVelocity = Offset(
      _kalmanVelocity!.dx * 0.75 + newVelocity.dx * 0.25,
      _kalmanVelocity!.dy * 0.75 + newVelocity.dy * 0.25,
    );

    _kalmanPosition = updatedPosition;
    _lastKalmanUpdate = now;

    return updatedPosition;
  }

  void checkIfProdExist() {
    final prioritizeProductId =
        Get.find<SupabaseController>().prioritizedProductId;
    final isProductExistPrio = CartProducts.products
        .where((product) => product.id == prioritizeProductId)
        .isNotEmpty;
    final isProductExistNear = CartProducts.products
        .where((product) => product.id == _nearestProductId)
        .isNotEmpty;

    if (isProductExistNear == false) {
      _nearestProductId = null;
    }

    if (isProductExistPrio == false) {
      Get.find<SupabaseController>().prioritizedProductId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    checkIfProdExist();
    final canvasWidth =
        metersToPixels(roomWidth, baseConvertion: baseConvertion.toInt()) + 100;
    final canvasHeight =
        metersToPixels(roomHeight, baseConvertion: baseConvertion.toInt()) +
        100;

    if (CartProducts.products.isEmpty) {
      context.replaceRoute(CartView());
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Your cart is empty',
                style: TextStyle(fontSize: 18, color: Colors.grey[700]),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.replaceRoute(CartView()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: Text(
                  'Back to Cart',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GetBuilder<SupabaseController>(
      builder: (c) {
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
                                context.pushRoute(
                                  ProductDetailsView(
                                    selectedProduct:
                                        CartProducts.products[index],
                                  ),
                                );
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
                              positionQuality: _positionQuality,
                              productsLocation: CartProducts.products,
                              geoJsonData: geoJsonData,
                              computedPaths: _computedPaths,
                              hiddenProductPaths: c.hiddenProductPaths,
                              nearestProductId: _displayedProductId,
                              animationValue: _arrowAnimationController.value,
                              dynamicSegmentStart: _dynamicPathSegmentStart,
                              dynamicSegmentEnd: _dynamicPathSegmentEnd,
                            ),
                            size: Size(canvasWidth, canvasHeight),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Stack(
                  children: [
                    GestureDetector(
                      onTap: () {
                        context.replaceRoute(CartView());
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        margin: EdgeInsets.only(left: 10),
                        child: Icon(Icons.arrow_back, color: Colors.white),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 10,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _isConnected
                              ? Colors.green.withOpacity(0.9)
                              : Colors.orange.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _isConnected ? Colors.white : Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              _isConnected ? 'Connected' : 'Reconnecting...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // ✅ NEW: Anchor health status indicator (debug mode)
                if (kDebugMode)
                  Positioned(
                    bottom: 100,
                    left: 10,
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Anchor Status:',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          ...anchorPositions.keys.map((anchorId) {
                            final spikeCount = _anchorSpikeCount[anchorId] ?? 0;
                            final color = spikeCount == 0
                                ? Colors.green
                                : spikeCount < 3
                                ? Colors.orange
                                : Colors.red;

                            return Padding(
                              padding: EdgeInsets.only(bottom: 2),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '$anchorId: ${spikeCount == 0 ? "Good" : "Spike x$spikeCount"}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                if (_displayedProductId != null &&
                    !c.hiddenProductPaths.contains(_displayedProductId))
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
                                      !c.hiddenProductPaths.contains(
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
                                        !c.hiddenProductPaths.contains(
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

// ✅ ProductCallout Widget (unchanged)
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
                Text(
                  'category: ${CartProducts.products.where((p) => p.id == productId).first.category}',
                  style: TextStyle(
                    color: Color(0xFF6b7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'rack level: ${CartProducts.products.where((p) => p.id == productId).first.rackLevel}',
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

// ✅ PathNode (unchanged)
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

// ✅ Pathfinder class (unchanged - preserving all existing logic)
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

// ✅ ENHANCED: Canvas with position quality visualization & dynamic segments
class StaticMapCanvas extends CustomPainter {
  StaticMapCanvas({
    required this.roomWidth,
    required this.roomHeight,
    required this.baseConvertion,
    this.tagPosition,
    this.tagAccuracy = 0.0,
    required this.positionQuality,
    required this.productsLocation,
    this.geoJsonData,
    required this.computedPaths,
    required this.hiddenProductPaths,
    required this.nearestProductId,
    required this.animationValue,
    this.dynamicSegmentStart,
    this.dynamicSegmentEnd,
  });

  final double roomWidth;
  final double roomHeight;
  final num baseConvertion;
  final Offset? tagPosition;
  final double tagAccuracy;
  final PositionQuality positionQuality;
  final List<Product> productsLocation;
  final Map<String, dynamic>? geoJsonData;
  final Map<String, List<Offset>> computedPaths;
  final Set<String> hiddenProductPaths;
  final String? nearestProductId;
  final double animationValue;
  final Offset? dynamicSegmentStart;
  final Offset? dynamicSegmentEnd;

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

  // ✅ ENHANCED: Tag rendering with quality state visualization
  void _drawTag(Canvas canvas, Offset position, double accuracy) {
    final pixelPosition = _metersToCanvasOffset(position.dx, position.dy);
    final color = _getAccuracyColor(accuracy);

    // Visual hint based on quality
    final opacity = positionQuality == PositionQuality.good
        ? 1.0
        : positionQuality == PositionQuality.degraded
        ? 0.6
        : 0.3;

    if (accuracy > 0 && accuracy < 10) {
      final accuracyCirclePaint = Paint()
        ..color = color.withValues(alpha: 0.15 * opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pixelPosition, 35, accuracyCirclePaint);

      // Dashed circle for degraded quality
      if (positionQuality != PositionQuality.good) {
        final dashedPaint = Paint()
          ..color = color.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        _drawDashedCircle(canvas, pixelPosition, 35, dashedPaint);
      }
    }

    final middleCirclePaint = Paint()
      ..color = color.withValues(alpha: 0.35 * opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pixelPosition, 16, middleCirclePaint);

    final innerCirclePaint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(pixelPosition, 8, innerCirclePaint);

    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(pixelPosition, 8, borderPaint);

    // Quality indicator text
    final qualityText = positionQuality == PositionQuality.good
        ? 'Cart'
        : positionQuality == PositionQuality.degraded
        ? 'Cart (Est.)'
        : 'Cart (Lost)';

    final textSpan = TextSpan(
      text:
          '$qualityText\n${position.dx.toStringAsFixed(2)}, ${position.dy.toStringAsFixed(2)}m',
      style: TextStyle(
        color: Colors.white.withValues(alpha: opacity),
        fontSize: 10,
        fontWeight: FontWeight.w600,
        backgroundColor: color.withValues(alpha: 0.9 * opacity),
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

  // ✅ Draw dashed circle for degraded quality
  void _drawDashedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
  ) {
    const dashLength = 5.0;
    const gapLength = 3.0;
    final circumference = 2 * math.pi * radius;
    final dashCount = (circumference / (dashLength + gapLength)).floor();

    for (int i = 0; i < dashCount; i++) {
      final startAngle = (2 * math.pi / dashCount) * i;
      final endAngle = startAngle + (dashLength / radius);

      final path = Path()
        ..addArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          endAngle - startAngle,
        );
      canvas.drawPath(path, paint);
    }
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
  }

  // ✅ Draw dynamic segment from tag to path
  void _drawDynamicSegment(Canvas canvas, Offset start, Offset end) {
    final startPixel = _metersToCanvasOffset(start.dx, start.dy);
    final endPixel = _metersToCanvasOffset(end.dx, end.dy);

    final paint = Paint()
      ..color = const Color(0xFF06b6d4).withValues(alpha: 0.6)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Dashed line
    const dashLength = 8.0;
    const gapLength = 4.0;
    final distance = math.sqrt(
      math.pow(endPixel.dx - startPixel.dx, 2) +
          math.pow(endPixel.dy - startPixel.dy, 2),
    );

    if (distance > 0) {
      final dashCount = (distance / (dashLength + gapLength)).floor();
      for (int i = 0; i < dashCount; i++) {
        final t1 = (i * (dashLength + gapLength)) / distance;
        final t2 = ((i * (dashLength + gapLength)) + dashLength) / distance;
        if (t2 > 1.0) break;

        final x1 = startPixel.dx + (endPixel.dx - startPixel.dx) * t1;
        final y1 = startPixel.dy + (endPixel.dy - startPixel.dy) * t1;
        final x2 = startPixel.dx + (endPixel.dx - startPixel.dx) * t2;
        final y2 = startPixel.dy + (endPixel.dy - startPixel.dy) * t2;

        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
      }
    }
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

    // ✅ Draw dynamic segment if exists
    if (dynamicSegmentStart != null && dynamicSegmentEnd != null) {
      _drawDynamicSegment(canvas, dynamicSegmentStart!, dynamicSegmentEnd!);
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

// ✅ Anchor class (unchanged)
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

// ✅ ENHANCED: Multilateration with anchor residual filtering (unchanged - already optimal)
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
      final cleanedAnchors = _removeOutlierAnchors(anchors);
      if (cleanedAnchors.length < 3) {
        if (kDebugMode) {
          debugPrint('⚠️ Not enough valid anchors after outlier removal');
        }
        return null;
      }

      Offset? position = _weightedLeastSquares(cleanedAnchors);

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

  List<Anchor> _removeOutlierAnchors(List<Anchor> allAnchors) {
    if (allAnchors.length <= 3) return allAnchors;

    final initialPos = _weightedLeastSquares(allAnchors);
    if (initialPos == null) return allAnchors;

    final residuals = <double>[];
    for (var anchor in allAnchors) {
      final dx = initialPos.dx - anchor.x;
      final dy = initialPos.dy - anchor.y;
      final calculatedDist = math.sqrt(dx * dx + dy * dy);
      final residual = (calculatedDist - anchor.distance).abs();
      residuals.add(residual);
    }

    final sortedResiduals = List<double>.from(residuals)..sort();
    final medianResidual = sortedResiduals[sortedResiduals.length ~/ 2];

    final filtered = <Anchor>[];
    for (int i = 0; i < allAnchors.length; i++) {
      if (residuals[i] < medianResidual * 3.0) {
        filtered.add(allAnchors[i]);
      } else {
        if (kDebugMode) {
          debugPrint(
            '🗑️ Filtered outlier anchor: ${allAnchors[i].id} (residual=${residuals[i].toStringAsFixed(2)}m, median=${medianResidual.toStringAsFixed(2)}m)',
          );
        }
      }
    }

    return filtered.length >= 3 ? filtered : allAnchors;
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

  Offset _applyEnhancedSmoothing(Offset newPos, Offset prevPos) {
    final distance = math.sqrt(
      math.pow(newPos.dx - prevPos.dx, 2) + math.pow(newPos.dy - prevPos.dy, 2),
    );

    if (distance < 0.02) {
      return prevPos;
    }

    double alpha;
    if (distance < 0.06) {
      alpha = 0.20;
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
