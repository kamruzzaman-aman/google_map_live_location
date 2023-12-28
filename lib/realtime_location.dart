import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class RealTimeLocationTracker extends StatefulWidget {
  const RealTimeLocationTracker({super.key});

  @override
  State<RealTimeLocationTracker> createState() =>
      _RealTimeLocationTrackerState();
}

class _RealTimeLocationTrackerState extends State<RealTimeLocationTracker> {
  late GoogleMapController _controller;
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  LocationData? currentLocation;
  Location location = Location();
  List<LatLng> routePoints = [];
  bool isGetLocation = false;

  PermissionStatus? permissionStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      getPermissionAndLocation();
    });
  }

  Future<void> getPermissionAndLocation() async {
    await getPermission();
    if (permissionStatus == PermissionStatus.granted) {
      await getInitialCurrentLocation();
      isGetLocation = false;
      setState(() {});
      updateLocationPeriodically();
    }
  }

  Future<void> getPermission() async {
    try {
      permissionStatus = await location.hasPermission();
      isGetLocation = true;
      setState(() {});
      if (permissionStatus == PermissionStatus.denied ||
          permissionStatus == PermissionStatus.deniedForever) {
        permissionStatus = await location.requestPermission();
        log(permissionStatus.toString());
        setState(() {});
      }
    } catch (e) {
      log(e.toString());
    }
  }

  animateCamera() {
    try {
      _controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: routePoints[0],
            zoom: 15.0,
          ),
        ),
      );
    } catch (e) {
      log(e.toString());
    }
  }

  Future<void> getInitialCurrentLocation() async {
    try {
      currentLocation = await location.getLocation();
      LatLng initialLatLng = LatLng(
        currentLocation!.latitude!,
        currentLocation!.longitude!,
      );
      routePoints.add(initialLatLng);
      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: initialLatLng,
          infoWindow: InfoWindow(
              title: 'My Current Location',
              snippet:
                  '${currentLocation!.latitude!}, ${currentLocation!.longitude!}'),
        ),
      );

      // Animate to the current location if _controller is not null
      // if (_controller != null) {
      //   _controller.animateCamera(
      //     CameraUpdate.newCameraPosition(
      //       CameraPosition(
      //         target: initialLatLng,
      //         zoom: 15.0,
      //       ),
      //     ),
      //   );
    } catch (e) {
      log('Error fetching initial location: $e');
    }
  }

  Future<void> updateLocationPeriodically() async {
    // Set up Timer.periodic for a 10-second interval
    Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        LocationData locationData = await location.getLocation();
        LatLng updateLatLng = LatLng(
          locationData.latitude!,
          locationData.longitude!,
        );

        // Only add new point if there's a significant change in location
        if (routePoints.isEmpty || routePoints.last != updateLatLng) {
          routePoints.add(updateLatLng);
        }

        // Update polyline
        polylines.clear();
        polylines.add(
          Polyline(
            polylineId: const PolylineId('route'),
            color: Colors.blue,
            width: 5,
            points: routePoints,
          ),
        );

        // Update marker position
        markers.clear();
        markers.add(
          Marker(
            markerId: const MarkerId('current_location'),
            position: updateLatLng,
            infoWindow: InfoWindow(
              title: 'My Current Location',
              snippet: '${locationData.latitude!}, ${locationData.longitude!}',
            ),
          ),
        );

        // Move camera to updated location
        _controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: updateLatLng,
              zoom: 15.0,
            ),
          ),
        );

        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        log('Error fetching location: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-Time Location Tracker'),
      ),
      body: Visibility(
        visible: isGetLocation == false,
        replacement: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text((permissionStatus == PermissionStatus.denied) ||
                      (permissionStatus == PermissionStatus.deniedForever)
                  ? "Give location permission and wait for the map..."
                  : "Please wait..."),
            ],
          ),
        ),
        child: routePoints.isNotEmpty
            ? GoogleMap(
                onMapCreated: (controller) {
                  _controller = controller;

                  Future.delayed(const Duration(seconds: 3))
                      .then((value) => animateCamera());
                  //  animateCamera();
                },
                initialCameraPosition: CameraPosition(
                  target: routePoints.isNotEmpty
                      ? routePoints[0]
                      : const LatLng(0, 0),
                  zoom: 5.0,
                ),
                markers: markers,
                polylines: polylines,
              )
            : const Center(
                child: CircularProgressIndicator(),
              ),
      ),
    );
  }
}
