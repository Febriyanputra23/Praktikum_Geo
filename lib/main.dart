// import yang dibutuhkan
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'catatan_model.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: const MapScreen());
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final List<CatatanModel> _savedNotes = [];
  final MapController _mapController = MapController();

  // memuat data saat aplikasi dimulai
  @override
  void initState() {
    super.initState();
    loadNotes();
  } 

  //Simpan semua catatan ke SharedPreferences
  Future<void> saveNotes() async {
    final prefs = await SharedPreferences.getInstance();

    List<String> encoded = _savedNotes.map((note) {
      return jsonEncode({
        'latitude': note.position.latitude,
        'longitude': note.position.longitude,
        'note': note.note,
        'address': note.address,
        'type': note.type,
      });
    }).toList();

    await prefs.setStringList('catatan', encoded);
  }

  //Muat semua catatan dari SharedPreferences
  Future<void> loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? data = prefs.getStringList('catatan');

    if (data != null) {
      setState(() {
        _savedNotes.clear();
        for (var item in data) {
          var decoded = jsonDecode(item);
          _savedNotes.add(
            CatatanModel(
              position: latlong.LatLng(
                decoded['latitude'],
                decoded['longitude'],
              ),
              note: decoded['note'],
              address: decoded['address'],
              type: decoded['type'],
            ),
          );
        }
      });
    }
  }

  // Ikon Marker
  IconData getMarkerIcon(String type) {
    switch (type) {
      case "Rumah":
        return Icons.home;
      case "Kantor":
        return Icons.business;
      case "Toko":
        return Icons.store;
      default:
        return Icons.location_on;
    }
  }

  //fungsi untuk mendapatkan lokasi saat ini
  Future<void> _findMyLocation() async {
    //Cek layanan dan izin GPS
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    // Ambil posisi
    Position position = await Geolocator.getCurrentPosition();

    // Pindahkan kamera peta
    _mapController.move(
      latlong.LatLng(position.latitude, position.longitude),
      15.0,
    );
  }

  // Fungsi menangani Long Press pada peta
  void _handleLongPress(TapPosition _, latlong.LatLng point) async {
    // Reverse Geocoding (Koordinat -> Alamat)
    List<Placemark> placemark = await placemarkFromCoordinates(
      point.latitude,
      point.longitude,
    );
    String address = placemark.first.street ?? "Alamat tidak dikenal";

    String? selectedType = "Rumah";

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text("Tambah Catatan"),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return DropdownButton<String>(
                value: selectedType,
                items: ["Rumah", "Kantor", "Toko"]
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (value) {
                  setStateDialog(() {
                    selectedType = value; // ✅ Sekarang dropdown berubah
                  });
                },
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Ok"),
            ),
          ],
        );
      },
    );

    // Tampilkan Dialog (Kode UI disederhanakan disini)
    // ... Implementasi Dialog ...
    setState(() {
      _savedNotes.add(
        CatatanModel(
          position: point,
          note: "Catatan Baru",
          address: address,
          type: selectedType!,
        ),
      );
    });

    await saveNotes(); // Simpan catatan setelah ditambahkan
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Geo-Catatan")),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: const latlong.LatLng(-6.2, 106.8),
          initialZoom: 13.0,
          onLongPress: _handleLongPress,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          ),
          MarkerLayer(
            markers: _savedNotes
                .map(
                  (n) => Marker(
                    point: n.position,
                    child: GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text("Hapus Marker?"),
                            content: Text("Hapus Catatan '${n.address}' ?"),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text("Batal"),
                              ),
                              TextButton(
                                onPressed: () async {
                                  setState(() {
                                    _savedNotes.remove(n);
                                  });
                                  await saveNotes();
                                  Navigator.pop(context);
                                },
                                child: Text("Hapus"),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Icon(
                        getMarkerIcon(n.type),
                        color: Colors.red,
                        size: 35,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _findMyLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
