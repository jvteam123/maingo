import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'firebase_options.dart';

// Minimal ChatScreen implementation for demonstration.
// Replace this with your actual chat UI if you have one.
// Replace your ChatScreen class with this:

class ChatScreen extends StatefulWidget {
  final String bookingId;
  final String driverName;
  final String customerPhone;
  const ChatScreen({
    required this.bookingId,
    required this.driverName,
    required this.customerPhone,
    Key? key,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();

  Stream<QuerySnapshot> get _messagesStream => FirebaseFirestore.instance
      .collection('bookings')
      .doc(widget.bookingId)
      .collection('messages')
      .orderBy('timestamp', descending: true)
      .snapshots();

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(widget.bookingId)
        .collection('messages')
        .add({
      'text': text.trim(),
      'sender': 'driver',
      'timestamp': FieldValue.serverTimestamp(),
      'senderName': widget.driverName,
    });
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with Customer'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text("No messages yet."));
                }
                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final isMe = data['sender'] == 'driver';
                    return Container(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      child: Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.pink[200]
                                  : Colors.grey[300],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              data['text'] ?? '',
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isMe ? "You" : "Customer",
                            style: const TextStyle(
                                fontSize: 11, color: Colors.black54),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: "Type your message...",
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.pink),
                  onPressed: () => _sendMessage(_controller.text),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const GoHatodDriverApp());
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.pinkAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
            padding: const EdgeInsets.only(bottom: 80.0),
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
                      _buildDetailRow(context, 'Destination', destinationAddress),
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
                                await FirebaseFirestore.instance
                                    .collection('bookings')
                                    .doc(id)
                                    .update({
                                  'driver': {
                                    'name': driverId,
                                    'vehicle': 'Motorcycle',
                                    'plate': 'ABC-123',
                                  },
                                  'status': 'active',
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
  const BookingDetailScreen({
    super.key,
    required this.bookingId,
    required this.driverName,
  });

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  StreamSubscription<Position>? _locationSub;
  LatLng? _driverLatLng;
  GoogleMapController? _mapController;
  Map<MarkerId, Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _isLoadingRoute = false;
  bool _hasInitialCameraAnimationRun = false;
  LatLng? _lastPickupLatLng;
  LatLng? _lastDestLatLng;

  final String _googleMapsApiKey = 'AIzaSyAY2ateXTWXgThNsfZQkqIi6ZzWWcwNazE';

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
            LatLng(pos.latitude, pos.longitude);

        FirebaseFirestore.instance
            .collection('bookings')
            .doc(widget.bookingId)
            .update({
          'driverLocation': {'lat': pos.latitude, 'lng': pos.longitude}
        }).catchError((e) => debugPrint("Error updating driver location: $e"));
      }
    }, onError: (e) {
      _showSnackBar('Error getting location updates: $e');
    });
  }

  Future<void> _getRoute(LatLng from, LatLng to) async {
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
      }
    } catch (e) {
      _showSnackBar('Error fetching route: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRoute = false;
        });
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _bookingStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Error: ${snapshot.error}')));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final pickup = data['pickup'];
        final destination = data['destination'];
        final currentStatus = data['status'] ?? 'N/A';
        final customerPhone = data['customerMobile'] ?? data['customerPhone'] ?? 'N/A';
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

        final mapWidget = Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.37,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.pinkAccent.withOpacity(0.09),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: GoogleMap(
                key: ValueKey(widget.bookingId),
                initialCameraPosition: CameraPosition(
                  target: _driverLatLng ??
                      LatLng(pickupLatLng?.latitude ?? 0,
                          pickupLatLng?.longitude ?? 0),
                  zoom: 15.5,
                ),
                markers: Set<Marker>.of(_markers.values),
                polylines: _polylines,
                onMapCreated: (controller) {
                  _mapController = controller;
                },
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                padding: const EdgeInsets.only(bottom: 30),
              ),
            ),
          ),
        );

        final detailsCard = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Card(
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${data['serviceType']?.toString().toUpperCase() ?? 'SERVICE'} BOOKING',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.pink[700],
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: currentStatus == 'completed'
                              ? Colors.green[100]
                              : Colors.orange[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          currentStatus.toUpperCase(),
                          style: TextStyle(
                            color: currentStatus == 'completed'
                                ? Colors.green[800]
                                : Colors.orange[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _bookingDetailRow(
                    context,
                    icon: Icons.place,
                    label: 'Pickup',
                    value: pickup?['address'] ?? 'N/A',
                  ),
                  const SizedBox(height: 8),
                  _bookingDetailRow(
                    context,
                    icon: Icons.flag,
                    label: 'Destination',
                    value: destination?['address'] ?? 'N/A',
                  ),
                  const SizedBox(height: 8),
                  _bookingDetailRow(
                    context,
                    icon: Icons.local_atm,
                    label: 'Fare',
                    value: _formatFare(data['fare']),
                    valueStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Colors.pink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (data['driver']?['name'] != null)
                    _bookingDetailRow(
                      context,
                      icon: Icons.person,
                      label: 'Driver',
                      value: data['driver']['name'],
                    ),
                  const SizedBox(height: 12),
                  // --- CUSTOMER PHONE WITH CALL & CHAT ICON BUTTONS ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.phone_android, color: Colors.pink, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          customerPhone,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (customerPhone != 'N/A' && customerPhone.isNotEmpty) ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.phone, color: Colors.white, size: 18),
                          label: const Text(
                            "Call",
                            style: TextStyle(color: Colors.white),
                          ),
                         onPressed: () => _makePhoneCall(customerPhone),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.chat, color: Colors.white, size: 18),
                          label: const Text(
                            "Chat",
                            style: TextStyle(color: Colors.white),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  bookingId: widget.bookingId,
                                  driverName: widget.driverName,
                                  customerPhone: customerPhone,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );

        final completeBookingButton = Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            bottom: MediaQuery.of(context).padding.bottom + 22,
            top: 6,
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline, size: 22),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  "Complete Booking",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink[600],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 6,
              ),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('bookings')
                    .doc(widget.bookingId)
                    .update({'status': 'completed'});
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ),
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Booking Details'),
            backgroundColor: Colors.pink,
            elevation: 0,
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          mapWidget,
                          const SizedBox(height: 18),
                          detailsCard,
                          const Spacer(),
                          completeBookingButton,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _bookingDetailRow(BuildContext context,
      {required IconData icon,
      required String label,
      required String value,
      TextStyle? valueStyle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.pink, size: 20),
        const SizedBox(width: 10),
        SizedBox(
          width: 96,
          child: Text(
            '$label:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: valueStyle ??
                Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: Colors.black87, fontWeight: FontWeight.w500),
          ),
        ),
      ],
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
