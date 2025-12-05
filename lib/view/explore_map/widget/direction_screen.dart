import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/widgets/common_appbar/common_appbar.dart';
import 'package:latlong2/latlong.dart';

class ExploreMapDirection extends StatefulWidget {
  const ExploreMapDirection({super.key});

  @override
  State<ExploreMapDirection> createState() => _ExploreMapDirectionState();
}

class _ExploreMapDirectionState extends State<ExploreMapDirection> {
  final LatLng yourLocation = LatLng(39.4699, -0.3763);
  final LatLng shopLocation = LatLng(39.4710, -0.3735);
  final LatLng mapCenter = LatLng(39.4704, -0.3754);

  LatLng getMidPoint(LatLng a, LatLng b) {
    return LatLng(
      (a.latitude + b.latitude) / 2,
      (a.longitude + b.longitude) / 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: ComAppbar(
        bgColor: AppColors.transparent,
        title: "Get Direction",
        elevation: 0.0,
        centerTitle: true,
        isTitleBold: true,
        iconTheme: IconThemeData(color: AppColors.whiteColor),
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Transform.scale(
            scale: 0.5,
            child: SvgPicture.asset(
              'assets/icon/back-button.svg',
              colorFilter: ColorFilter.mode(
                AppColors.blackColor,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),

      body: FlutterMap(
        options: MapOptions(initialCenter: mapCenter, initialZoom: 16),
        children: [
          TileLayer(
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
            userAgentPackageName: 'com.hair_sallon.app',
            tileProvider: NetworkTileProvider(
              headers: {
                'User-Agent': 'YourAppName/1.0 (your@email.com)',
                'Referer': 'https://yourwebsite.com',
              },
            ),
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: [yourLocation, shopLocation],
                color: Colors.blueAccent,
                strokeWidth: 4,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: yourLocation,
                width: 80,
                height: 80,
                child: Column(
                  children: [
                    const Text(
                      "You",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 4),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.navigation,
                          color: Colors.blue,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // "Salon" marker
              Marker(
                point: shopLocation,
                width: 80,
                height: 80,
                child: Column(
                  children: [
                    const Text(
                      "Salon",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 4),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.store,
                          color: AppColors.primaryColor,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      // Bottom start button
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: () {
            // Add logic here (e.g., start tracking or booking)
          },
          child: const Text(
            "Start",
            style: TextStyle(fontSize: 16, color: AppColors.whiteColor),
          ),
        ),
      ),
    );
  }
}
