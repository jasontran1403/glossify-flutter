import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/utils/local_images/local_images.dart';

class ExploreMapScreen extends StatefulWidget {
  const ExploreMapScreen({super.key});

  @override
  State<ExploreMapScreen> createState() => _ExploreMapScreenState();
}

class _ExploreMapScreenState extends State<ExploreMapScreen> {
  bool isLoading = true;
  bool isNavigating = false;
  bool isFollowingUser = true; // Theo dõi vị trí user
  LatLng? userLocation;
  double? _heading;
  String selectedSalonName = ''; // Tên salon được chọn
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<CompassEvent>? _compassStream;
  List<LatLng> routePoints = [];
  List<String> routeInstructions = [];

  final MapController _mapController = MapController();

  final List<Map<String, dynamic>> markers = [
    {"img": AppImages.salon, "lat": 41.433462159926265, "lng": -87.36355931218331},
    {"img": AppImages.salon1, "lat": 41.43065949429464, "lng": -87.36220714958915},
  ];

  @override
  void initState() {
    super.initState();
    _initMap();
    _listenCompass();
    _listenLocation();
  }

  void _listenCompass() async {
    final hasSensor = await FlutterCompass.events?.isBroadcast ?? false;
    if (!hasSensor) {
      debugPrint('⚠️ Compass not available on this device.');
      return;
    }

    _compassStream = FlutterCompass.events?.listen((event) {
      if (event.heading != null && mounted) {
        setState(() => _heading = event.heading);

        // Tự động xoay bản đồ theo hướng nếu đang follow user
        if (isFollowingUser && userLocation != null) {
          _mapController.rotate(-event.heading!);
        }
      }
    });
  }

  void _listenLocation() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 2,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position pos) {
      if (!mounted) return;

      setState(() {
        userLocation = LatLng(pos.latitude, pos.longitude);
      });

      if (isFollowingUser && mounted) {
        _mapController.move(userLocation!, _mapController.camera.zoom);
      }
    });
  }

  Future<void> _initMap() async {
    try {
      final pos = await _getUserLocation();
      if (!mounted) return;

      setState(() {
        userLocation = pos;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error getting location: $e");
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<LatLng> _getUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('Location service disabled');
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) throw Exception('Permission denied');
    }
    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    return LatLng(pos.latitude, pos.longitude);
  }

  // Toggle theo dõi vị trí và xoay bản đồ
  void _toggleFollowUser() {
    setState(() {
      isFollowingUser = !isFollowingUser;
      if (isFollowingUser) {
        // Xoay bản đồ theo hướng hiện tại
        if (_heading != null) {
          _mapController.rotate(-_heading!);
        }
        // Di chuyển đến vị trí user
        if (userLocation != null) {
          _mapController.move(userLocation!, _mapController.camera.zoom);
        }
      } else {
        // Reset rotation về 0 (bắc ở trên)
        _mapController.rotate(0);
      }
    });
  }

  Future<void> _showRoute(LatLng salonLatLng) async {
    if (userLocation == null || !mounted) return;

    setState(() {
      isLoading = true;
      isNavigating = true;
      isFollowingUser = false; // Tắt follow khi xem route
    });

    final result = await getRouteData(userLocation!, salonLatLng);

    if (!mounted) return;

    setState(() {
      routePoints = result.$1;
      routeInstructions = result.$2;
      isLoading = false;
    });

    // Reset rotation để nhìn route rõ hơn
    _mapController.rotate(0);

    final bounds = LatLngBounds.fromPoints([...routePoints, userLocation!, salonLatLng]);
    _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)));
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      polyline.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return polyline;
  }

  Future<(List<LatLng>, List<String>)> getRouteData(LatLng start, LatLng end) async {
    const apiKey =
        'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjY2NTA3NGQ0MzJhODQzMTM4MzhiZWFiOWNiOWZlMjY5IiwiaCI6Im11cm11cjY0In0=';

    final url = 'https://api.openrouteservice.org/v2/directions/driving-car';
    final dio = Dio();
    final body = {
      "coordinates": [
        [start.longitude, start.latitude],
        [end.longitude, end.latitude],
      ]
    };

    try {
      final response = await dio.post(
        url,
        options: Options(headers: {
          'Authorization': apiKey,
          'Content-Type': 'application/json',
        }),
        data: jsonEncode(body),
      );

      final geometry = response.data['routes'][0]['geometry'];
      final decoded = _decodePolyline(geometry);

      final steps = response.data['routes'][0]['segments'][0]['steps'] as List;
      final instructions = steps.map((s) {
        final dist = (s['distance'] / 1000).toStringAsFixed(2);
        return '${s['instruction']} (${dist} km)';
      }).toList();

      return (decoded, instructions);
    } catch (e) {
      debugPrint('Error fetching route: $e');
      return (<LatLng>[], <String>[]);
    }
  }


  @override
  void dispose() {
    _positionStream?.cancel();
    _compassStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading ? _buildShimmer() : _buildMapContent(context),
    );
  }

  Widget _buildShimmer() {
    return Center(child: CircularProgressIndicator(color: AppColors.primaryColor));
  }

  Widget _buildMapContent(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: userLocation ?? LatLng(10.78, 106.68),
            initialZoom: 15,
            minZoom: 5,  // Giới hạn zoom out (không zoom ra quá xa)
            maxZoom: 19, // Giới hạn zoom in (không zoom vào quá gần)
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
            onPositionChanged: (position, hasGesture) {
              // Tắt follow mode khi user drag bản đồ
              if (hasGesture && isFollowingUser) {
                setState(() => isFollowingUser = false);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
              userAgentPackageName: 'com.hair_sallon.app',
              retinaMode: false,
              tileProvider: NetworkTileProvider(),
              maxNativeZoom: 19,
              maxZoom: 19,
            ),

            if (routePoints.isNotEmpty)
              PolylineLayer(polylines: [
                Polyline(
                  points: routePoints,
                  color: const Color(0xFF007AFF),
                  strokeWidth: 6,
                ),
              ]),

            MarkerLayer(
              markers: [
                // User location marker (dấu chấm xanh giống iOS)
                if (userLocation != null)
                  Marker(
                    point: userLocation!,
                    width: 50,
                    height: 50,
                    child: _buildUserLocationMarker(),
                  ),

                // Salon markers (chấm đỏ giống iOS)
                ...markers.map((m) => Marker(
                  point: LatLng(m['lat'], m['lng']),
                  width: 60,
                  height: 60,
                  child: GestureDetector(
                    onTap: () => _showRoute(LatLng(m['lat'], m['lng'])),
                    child: _buildSalonMarker(m['img']),
                  ),
                )),
              ],
            ),
          ],
        ),

        // Compass và nút follow ở góc phải
        _buildCompassAndFollowButton(),

        if (!isNavigating) _buildBottomCards(context),
        if (isNavigating) _buildNavigationPanel(),
      ],
    );
  }

  // Marker vị trí user giống iOS (chấm xanh với đuôi chỉ hướng dạng cung)
  Widget _buildUserLocationMarker() {
    return Transform.rotate(
      angle: (_heading ?? 0) * (math.pi / 180),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Đuôi hình quạt chỉ hướng (dài hơn)
          CustomPaint(
            size: const Size(80, 80),
            painter: _DirectionTailPainter(),
          ),
          // Chấm xanh ở giữa
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF007AFF),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Marker salon giống iOS (chấm đỏ + hình ảnh)
  Widget _buildSalonMarker(String imagePath) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Chấm đỏ với shadow
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              imagePath,
              fit: BoxFit.cover,
            ),
          ),
        ),
        // Đuôi marker
        CustomPaint(
          size: const Size(12, 8),
          painter: _MarkerTailPainter(),
        ),
      ],
    );
  }

  // La bàn và nút follow user
  Widget _buildCompassAndFollowButton() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      right: 16,
      child: Column(
        children: [
          // Nút xoay bản đồ / follow user
          Material(
            elevation: 4,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: _toggleFollowUser,
              customBorder: const CircleBorder(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFollowingUser
                      ? const Color(0xFF007AFF)
                      : Colors.white,
                ),
                child: Icon(
                  Icons.navigation,
                  color: isFollowingUser ? Colors.white : Colors.grey[700],
                  size: 24,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // La bàn
          Material(
            elevation: 4,
            shape: const CircleBorder(),
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: Transform.rotate(
                angle: (_heading ?? 0) * (math.pi / 180),
                child: const Icon(
                  Icons.explore,
                  color: Colors.red,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCards(BuildContext context) {
    final format = NumberFormat("#,##0.00", "en_US");

    final List<Map<String, dynamic>> salonInfo = [
      {
        "name": "CP Nails Spa",
        "address": "1302 N Main St #6, Crown Point, IN 46307, USA",
        "img": AppImages.salon,
      },
      {
        "name": "Deluxe Nails Salon",
        "address": "1176 N Main St, Crown Point, IN 46307, USA",
        "img": AppImages.salon1,
      },
    ];

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.27,
        child: PageView.builder(
          itemCount: markers.length,
          controller: PageController(viewportFraction: 0.88),
          itemBuilder: (context, index) {
            final marker = markers[index];
            final info = salonInfo[index];
            final salonLatLng = LatLng(marker['lat'], marker['lng']);

            final km = userLocation == null
                ? null
                : Distance().as(LengthUnit.Kilometer, userLocation!, salonLatLng);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: InkWell(
                onTap: () => _showRoute(salonLatLng),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.whiteColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 100,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            fit: BoxFit.cover,
                            image: AssetImage(info['img']),
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(info['name'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_pin,
                                    size: 16, color: AppColors.primaryColor),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(info['address'],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: AppColors.mistBlueColor)),
                                ),
                              ],
                            ),
                            if (km != null)
                              Text("${format.format(km)} km away",
                                  style: const TextStyle(color: AppColors.mistBlueColor)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNavigationPanel() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  if (mounted) {
                    setState(() => isNavigating = false);
                  }
                },
                child: const Icon(Icons.keyboard_arrow_down, size: 30),
              ),
              const SizedBox(height: 8),
              if (routeInstructions.isNotEmpty)
                Text(
                  routeInstructions.first,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              if (routeInstructions.length > 1)
                Text(
                  "Sau đó: ${routeInstructions[1]}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom painter cho đuôi chỉ hướng dạng cung/sector (giống iOS Maps)
class _DirectionTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Tạo gradient từ tâm ra ngoài (đậm -> nhạt)
    final gradient = ui.Gradient.radial(
      center,
      radius,
      [
        const Color(0xFF007AFF).withOpacity(0.4), // Đậm ở gần
        const Color(0xFF007AFF).withOpacity(0.15), // Nhạt ở giữa
        const Color(0xFF007AFF).withOpacity(0.0), // Trong suốt ở xa
      ],
      [0.0, 0.5, 1.0], // Vị trí các màu trong gradient
    );

    final paint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.fill;

    // Vẽ hình quạt hẹp (45°)
    final path = ui.Path()
      ..moveTo(center.dx, center.dy) // Bắt đầu từ tâm
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2 - math.pi / 8, // Bắt đầu từ -112.5° (22.5° bên trái)
        math.pi / 4, // Quét 45° (22.5° mỗi bên)
        false,
      )
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom painter cho đuôi marker salon
class _MarkerTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    final path = ui.Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}