import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'
    show
        LatLng,
        GoogleMapController,
        MarkerId,
        Marker,
        Polyline,
        InfoWindow,
        PolylineId,
        BitmapDescriptor,
        LatLngBounds,
        CameraUpdate,
        JointType,
        Cap,
        CameraPosition,
        GoogleMap;
//import 'package:Maps_flutter/Maps_flutter.dart'; // This is the LatLng for the map
import 'package:http/http.dart' as http;
// Alias for latlong2's LatLng (if you use it for other calculations)
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart'; // Import for kDebugMode

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    runApp(const GoHatodDriverApp());
  } catch (e, st) {
    print('Firebase init error: $e\n$st');
  }
}

class GoHatodDriverApp extends StatelessWidget {
  const GoHatodDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GoHatod Driver',
      theme: ThemeData(
        primarySwatch: Colors.pink,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.pink,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.pinkAccent,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.pink,
          foregroundColor: Colors.white,
        ),
      ),
      home: const DriverHomeScreen(),
    );
  }
}

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  String? driverId;
  Key _streamKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _promptForDriverName();
    });
  }

  Future<void> _promptForDriverName() async {
    final name = await _askDriverName(context);
    setState(() {
      driverId = name;
    });
  }

  Future<String> _askDriverName(BuildContext context) async {
    final controller = TextEditingController();
    String? name;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Enter Driver Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Your name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                name = controller.text.trim();
                Navigator.of(context).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Driver name cannot be empty!')),
                );
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return name ?? 'Driver';
  }

  @override
  Widget build(BuildContext context) {
    if (driverId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('GoHatod Driver - Available Bookings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload Available Bookings',
            onPressed: () {
              setState(() {
                _streamKey = UniqueKey();
              });
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        key: _streamKey,
        stream: FirebaseFirestore.instance.collection('bookings').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading bookings: ${snapshot.error}',
                  textAlign: TextAlign.center),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text('No active bookings available at the moment.'));
          }

          final bookings = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.only(
                bottom: 80.0), // Added padding to avoid FAB overlap
            itemCount: bookings.length,
            itemBuilder: (context, i) {
              final data = bookings[i].data() as Map<String, dynamic>;
              final id = bookings[i].id;
              final canAccept =
                  (data['status'] == 'active' && data['driver'] == null);

              final serviceType = data['serviceType'] ?? 'N/A';
              final status = data['status'] ?? 'N/A';
              final pickupAddress = data['pickup']?['address'] ?? 'N/A';
              final destinationAddress =
                  data['destination']?['address'] ?? 'N/A';

              if (kDebugMode) {
                debugPrint(
                    'DEBUG (DriverHomeScreen): raw fare value: ${data['fare']} (Type: ${data['fare'].runtimeType})');
              }
              String fare = _formatFare(data['fare']);

              final driverName = data['driver']?['name'] ?? 'none';

              return Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$serviceType Booking',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.pink,
                            ),
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(context, 'Status', status),
                      _buildDetailRow(context, 'Pickup', pickupAddress),
                      _buildDetailRow(
                          context, 'Destination', destinationAddress),
                      _buildDetailRow(context, 'Fare', fare),
                      _buildDetailRow(context, 'Assigned Driver', driverName),
                      if (canAccept)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Accept Booking'),
                              onPressed: () async {
                                try {
                                  await FirebaseFirestore.instance
                                      .collection('bookings')
                                      .doc(id)
                                      .update({
                                    'driver': {
                                      'name': driverId,
                                      'vehicle': 'Motorcycle',
                                      'plate': 'ABC-123',
                                    },
                                    'status':
                                        'active', // STATUS CHANGED TO 'active'
                                    'driverAcceptedAt':
                                        FieldValue.serverTimestamp(),
                                  });

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Booking accepted!')),
                                    );
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      if (context.mounted) {
                                        Navigator.of(context)
                                            .push(MaterialPageRoute(
                                          builder: (_) => BookingDetailScreen(
                                            bookingId: id,
                                            driverName: driverId!,
                                          ),
                                        ));
                                      }
                                    });
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'Failed to accept booking: $e')),
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                        ),
                      if (!canAccept)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.info_outline),
                              label: const Text('View Details'),
                              onPressed: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => BookingDetailScreen(
                                    bookingId: id,
                                    driverName: driverId!,
                                  ),
                                ));
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.assignment_turned_in),
        label: const Text('My Accepted Bookings'),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  DriverAcceptedBookingsScreen(driverName: driverId!),
            ),
          );
        },
        tooltip: 'View your currently accepted bookings',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  String _formatFare(dynamic fareValue) {
    if (fareValue == null) return 'N/A';
    if (fareValue is num) {
      return '₱${fareValue.toStringAsFixed(2)}';
    } else if (fareValue is String && fareValue.isNotEmpty) {
      final parsedFare = double.tryParse(fareValue);
      if (parsedFare != null) {
        return '₱${parsedFare.toStringAsFixed(2)}';
      } else {
        return '₱$fareValue';
      }
    }
    return 'N/A';
  }
}

class DriverAcceptedBookingsScreen extends StatelessWidget {
  final String driverName;
  const DriverAcceptedBookingsScreen({super.key, required this.driverName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Bookings for $driverName')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('driver.name', isEqualTo: driverName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading accepted bookings: ${snapshot.error}',
                  textAlign: TextAlign.center),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text('You have no accepted bookings yet.'));
          }

          final bookings = snapshot.data!.docs;
          return ListView.builder(
            itemCount: bookings.length,
            itemBuilder: (context, i) {
              final data = bookings[i].data() as Map<String, dynamic>;
              final id = bookings[i].id;

              final serviceType = data['serviceType'] ?? 'N/A';
              final status = data['status'] ?? 'N/A';
              final pickupAddress = data['pickup']?['address'] ?? 'N/A';
              final destinationAddress =
                  data['destination']?['address'] ?? 'N/A';

              if (kDebugMode) {
                debugPrint(
                    'DEBUG (DriverAcceptedBookingsScreen): raw fare value: ${data['fare']} (Type: ${data['fare'].runtimeType})');
              }
              String fare = _formatFare(data['fare']);

              return Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$serviceType Booking',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.pink,
                            ),
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(context, 'Pickup', pickupAddress),
                      _buildDetailRow(
                          context, 'Destination', destinationAddress),
                      _buildDetailRow(context, 'Fare', fare),
                      _buildDetailRow(context, 'Status', status),
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.remove_red_eye_outlined),
                            label: const Text('View Details'),
                            onPressed: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => BookingDetailScreen(
                                  bookingId: id,
                                  driverName: driverName,
                                ),
                              ));
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  String _formatFare(dynamic fareValue) {
    if (fareValue == null) return 'N/A';
    if (fareValue is num) {
      return '₱${fareValue.toStringAsFixed(2)}';
    } else if (fareValue is String && fareValue.isNotEmpty) {
      final parsedFare = double.tryParse(fareValue);
      if (parsedFare != null) {
        return '₱${parsedFare.toStringAsFixed(2)}';
      } else {
        return '₱$fareValue';
      }
    }
    return 'N/A';
  }
}

class BookingDetailScreen extends StatefulWidget {
  final String bookingId;
  final String driverName;
  const BookingDetailScreen(
      {super.key, required this.bookingId, required this.driverName});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  StreamSubscription<Position>? _locationSub;
  // Explicitly use Maps_flutter's LatLng for map-related coordinates
  LatLng? _driverLatLng;
  GoogleMapController? _mapController;
  Map<MarkerId, Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _isLoadingRoute = false;
  bool _hasInitialCameraAnimationRun = false;
  // Store the last known pickup and destination LatLngs to avoid re-calculating route unnecessarily
  LatLng? _lastPickupLatLng;
  LatLng? _lastDestLatLng;

  // IMPORTANT: Securely store your API key (e.g., using flutter_dotenv or environment variables)
  // DO NOT hardcode it directly in your production code.
  final String _googleMapsApiKey =
      'AIzaSyAY2ateXTWXgThNsfZQkqIi6ZzWWcwNazE'; // Replace with your actual key

  // Stream for Firestore booking data to avoid directly passing snapshot.data to other methods
  Stream<DocumentSnapshot>? _bookingStream;

  @override
  void initState() {
    super.initState();
    _bookingStream = FirebaseFirestore.instance
        .collection('bookings')
        .doc(widget.bookingId)
        .snapshots();
    _startLocationUpdates();
  }

  @override
  void didUpdateWidget(covariant BookingDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bookingId != oldWidget.bookingId) {
      _bookingStream = FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .snapshots();
      _hasInitialCameraAnimationRun = false;
      _polylines.clear();
      _markers.clear();
      _lastPickupLatLng = null;
      _lastDestLatLng = null;
    }
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _updateMapMarkers(LatLng? driverLocation, LatLng? pickupLocation,
      LatLng? destinationLocation) {
    final Map<MarkerId, Marker> newMarkers = {};

    if (driverLocation != null) {
      newMarkers[const MarkerId('driver')] = Marker(
          markerId: const MarkerId('driver'),
          position: driverLocation,
          infoWindow: const InfoWindow(title: 'Your Current Location'),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose));
    }
    if (pickupLocation != null) {
      newMarkers[const MarkerId('pickup')] = Marker(
          markerId: const MarkerId('pickup'),
          position: pickupLocation,
          infoWindow: const InfoWindow(title: 'Pickup Location'),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen));
    }
    if (destinationLocation != null) {
      newMarkers[const MarkerId('destination')] = Marker(
          markerId: const MarkerId('destination'),
          position: destinationLocation,
          infoWindow: const InfoWindow(title: 'Destination Location'),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue));
    }

    if (!mapEquals(_markers, newMarkers)) {
      setState(() {
        _markers = newMarkers;
      });
    }
  }

  void _animateCameraToFitMarkers(
      LatLng? driverLoc, LatLng? pickupLoc, LatLng? destLoc) {
    if (_mapController == null || _hasInitialCameraAnimationRun) return;

    final List<LatLng> points = [];
    if (driverLoc != null) points.add(driverLoc);
    if (pickupLoc != null) points.add(pickupLoc);
    if (destLoc != null) points.add(destLoc);

    if (points.length < 2) return;

    double minLat =
        points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
    double maxLat =
        points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
    double minLng =
        points.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
    double maxLng =
        points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!
        .animateCamera(CameraUpdate.newLatLngBounds(bounds, 100))
        .then((_) {
      if (mounted) {
        setState(() {
          _hasInitialCameraAnimationRun = true;
        });
      }
    });
  }

  void _startLocationUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Location services are disabled. Please enable them.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Location permissions are denied. Cannot track driver.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar(
          'Location permissions are permanently denied. Please enable from settings.');
      return;
    }

    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position pos) {
      if (mounted) {
        _driverLatLng =
            LatLng(pos.latitude, pos.longitude); // Uses Maps_flutter.LatLng

        FirebaseFirestore.instance
            .collection('bookings')
            .doc(widget.bookingId)
            .update({
          'driverLocation': {'lat': pos.latitude, 'lng': pos.longitude}
        }).catchError((e) => debugPrint("Error updating driver location: $e"));
      }
    }, onError: (e) {
      _showSnackBar('Error getting location updates: $e');
      if (kDebugMode) {
        debugPrint("Location stream error: $e");
      }
    });
  }

  Future<void> _getRoute(LatLng from, LatLng to) async {
    // Uses Maps_flutter.LatLng
    if (_isLoadingRoute ||
        (_lastPickupLatLng == from && _lastDestLatLng == to)) {
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingRoute = true;
        _polylines.clear();
      });
    }

    try {
      final url =
          'https://maps.googleapis.com/maps/api/directions/json?origin=${from.latitude},${from.longitude}&destination=${to.latitude},${to.longitude}&key=$_googleMapsApiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final points = data['routes'][0]['overview_polyline']['points'];
          final polyline = _decodePolyline(points);

          if (mounted) {
            setState(() {
              _polylines = {
                Polyline(
                  polylineId: const PolylineId('route'),
                  color: Colors.blueAccent,
                  width: 6,
                  points: polyline,
                  jointType: JointType.round,
                  startCap: Cap.roundCap,
                  endCap: Cap.roundCap,
                ),
              };
              _lastPickupLatLng = from;
              _lastDestLatLng = to;
            });
          }
        } else {
          _showSnackBar('No route found between locations.');
        }
      } else {
        _showSnackBar(
            'Failed to get route: ${response.statusCode} - ${response.body}');
        if (kDebugMode) {
          debugPrint(
              'Directions API Error: Status ${response.statusCode}, Body: ${response.body}');
        }
      }
    } catch (e) {
      _showSnackBar('Error fetching route: $e');
      if (kDebugMode) {
        debugPrint('Error in _getRoute: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRoute = false;
        });
      }
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    // Uses Maps_flutter.LatLng
    List<LatLng> polyline = []; // Uses Maps_flutter.LatLng
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

      polyline.add(LatLng(lat / 1E5, lng / 1E5)); // Uses Maps_flutter.LatLng
    }
    return polyline;
  }

  void _showSnackBar(String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      _showSnackBar('Could not launch $phoneNumber');
    }
  }

  // ... (imports and class declaration stay the same)

  @override
  Widget build(BuildContext context) {
    debugPrint('BookingDetailScreen build called'); // Debug print
    return Scaffold(
      appBar: AppBar(title: const Text('Booking Details')),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: _bookingStream, // Use the stream from state
          builder: (context, snapshot) {
            debugPrint('StreamBuilder builder called'); // Debug print

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            final pickup = data['pickup'];
            final destination = data['destination'];
            final currentStatus = data['status'] ?? 'N/A';
            final customerPhone = data['customerPhone'] ?? 'N/A';

            final LatLng? pickupLatLng = (pickup != null &&
                    pickup['lat'] != null &&
                    pickup['lng'] != null)
                ? LatLng(pickup['lat'], pickup['lng'])
                : null;
            final LatLng? destLatLng = (destination != null &&
                    destination['lat'] != null &&
                    destination['lng'] != null)
                ? LatLng(destination['lat'], destination['lng'])
                : null;

            // Map marker/route logic as before
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _updateMapMarkers(_driverLatLng, pickupLatLng, destLatLng);
              }
            });
            if (_driverLatLng != null && destLatLng != null) {
              if (_lastPickupLatLng != _driverLatLng ||
                  _lastDestLatLng != destLatLng) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _getRoute(_driverLatLng!, destLatLng);
                  }
                });
              }
            }
            if (_mapController != null &&
                !_hasInitialCameraAnimationRun &&
                _driverLatLng != null &&
                pickupLatLng != null &&
                destLatLng != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _animateCameraToFitMarkers(
                      _driverLatLng, pickupLatLng, destLatLng);
                }
              });
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- MAP AT THE TOP ---
                SizedBox(
                  height: 260,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GoogleMap(
                        key: ValueKey(widget.bookingId),
                        initialCameraPosition: CameraPosition(
                          target: _driverLatLng ??
                              LatLng(pickupLatLng?.latitude ?? 0,
                                  pickupLatLng?.longitude ?? 0),
                          zoom: 14,
                        ),
                        markers: Set<Marker>.of(_markers.values),
                        polylines: _polylines,
                        onMapCreated: (controller) {
                          _mapController = controller;
                        },
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        padding: EdgeInsets.only(
                            bottom: _driverLatLng != null ? 0 : 40),
                      ),
                    ),
                  ),
                ),

                // --- CUSTOMER DETAILS BELOW MAP ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${data['serviceType'] ?? 'Service'} Booking Overview',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.pink[700],
                                ),
                          ),
                          const Divider(height: 20, thickness: 1),
                          _buildDetailRow(
                              context, 'Status', currentStatus.toUpperCase()),
                          _buildDetailRow(
                              context, 'Pickup', pickup?['address'] ?? 'N/A'),
                          _buildDetailRow(context, 'Destination',
                              destination?['address'] ?? 'N/A'),
                          _buildDetailRow(
                              context, 'Fare', _formatFare(data['fare'])),
                          if (data['driver']?['name'] != null)
                            _buildDetailRow(
                                context, 'Driver', data['driver']['name']),
                          // --- CUSTOMER PHONE WITH CALL ICON ---
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 100,
                                  child: Text(
                                    'Customer:',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    customerPhone,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                                if (customerPhone != 'N/A' &&
                                    customerPhone.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.phone,
                                        color: Colors.green),
                                    onPressed: () =>
                                        _makePhoneCall(customerPhone),
                                    tooltip: 'Call Customer',
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // --- COMPLETE BOOKING BUTTON ---
                Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                    top: 8,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.task_alt),
                      label: const Text('Complete Booking'),
                      onPressed: currentStatus == 'completed'
                          ? null
                          : () async {
                              try {
                                await FirebaseFirestore.instance
                                    .collection('bookings')
                                    .doc(widget.bookingId)
                                    .update({
                                  'status': 'completed',
                                  'completedAt': FieldValue.serverTimestamp(),
                                });
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Booking marked as completed!')),
                                  );
                                  Navigator.of(context).pop();
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'Failed to complete booking: $e')),
                                  );
                                }
                              }
                            },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      // Floating Action Button for Chat (unchanged)
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.chat),
        label: const Text('Chat with Customer'),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                bookingId: widget.bookingId,
                senderName: widget.driverName,
              ),
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  String _formatFare(dynamic fareValue) {
    if (fareValue == null) return 'N/A';
    if (fareValue is num) {
      return '₱${fareValue.toStringAsFixed(2)}';
    } else if (fareValue is String && fareValue.isNotEmpty) {
      final parsedFare = double.tryParse(fareValue);
      if (parsedFare != null) {
        return '₱${parsedFare.toStringAsFixed(2)}';
      } else {
        return '₱$fareValue';
      }
    }
    return 'N/A';
  }
}

// NEW WIDGET FOR THE CHAT SCREEN
class ChatScreen extends StatelessWidget {
  final String bookingId;
  final String senderName;
  const ChatScreen({
    super.key,
    required this.bookingId,
    required this.senderName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Chat'),
      ),
      // Ensure resizeToAvoidBottomInset is true (default for Scaffold)
      resizeToAvoidBottomInset: true,
      body: BookingChatWidget(
        bookingId: bookingId,
        senderName: senderName,
      ),
    );
  }
}

class BookingChatWidget extends StatefulWidget {
  final String bookingId;
  final String senderName;
  const BookingChatWidget(
      {super.key, required this.bookingId, required this.senderName});

  @override
  State<BookingChatWidget> createState() => _BookingChatWidgetState();
}

class _BookingChatWidgetState extends State<BookingChatWidget> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .collection('messages')
          .add({
        'sender': widget.senderName,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _controller.clear();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
      if (kDebugMode) {
        debugPrint("Error sending message: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('bookings')
                .doc(widget.bookingId)
                .collection('messages')
                .orderBy('timestamp')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                    child: Text('Error loading chat: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                    child: Text('No messages yet. Start the conversation!'));
              }

              final messages = snapshot.data!.docs;
              return ListView.builder(
                controller: _scrollController,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final data = messages[index].data() as Map<String, dynamic>;
                  final isMe = data['sender'] == widget.senderName;
                  return Align(
                    alignment:
                        isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: EdgeInsets.fromLTRB(
                        isMe ? 60 : 8,
                        4,
                        isMe ? 8 : 60,
                        4,
                      ),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.pink[100] : Colors.blueGrey[50],
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isMe ? 'You' : data['sender'] ?? 'Unknown',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isMe
                                  ? Colors.pink[700]
                                  : Colors.blueGrey[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data['text'] ?? '',
                            style: const TextStyle(fontSize: 14),
                          ),
                          if (data['timestamp'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                _formatTimestamp(data['timestamp']),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
            left: 8.0,
            right: 8.0,
            bottom: MediaQuery.of(context).viewInsets.bottom +
                8.0, // Modified padding
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25.0),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: Colors.pinkAccent,
                radius: 24,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
