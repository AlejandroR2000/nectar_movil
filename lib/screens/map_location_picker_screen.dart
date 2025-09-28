import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class MapLocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const MapLocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<MapLocationPickerScreen> createState() => _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState extends State<MapLocationPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  bool _isLoading = true;
  
  // Centro de Valladolid, Yucatán como ubicación por defecto
  static const LatLng _defaultLocation = LatLng(20.6896, -88.2028);

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    LatLng initialLocation;

    // Si se proporcionaron coordenadas iniciales, usarlas
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      initialLocation = LatLng(widget.initialLatitude!, widget.initialLongitude!);
      _selectedLocation = initialLocation;
    } else {
      // Intentar obtener la ubicación actual
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          
          if (permission == LocationPermission.whileInUse || 
              permission == LocationPermission.always) {
            Position position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 10),
            );
            initialLocation = LatLng(position.latitude, position.longitude);
            _selectedLocation = initialLocation;
          } else {
            initialLocation = _defaultLocation;
          }
        } else {
          initialLocation = _defaultLocation;
        }
      } catch (e) {
        initialLocation = _defaultLocation;
      }
    }

    setState(() {
      _selectedLocation = initialLocation;
      _isLoading = false;
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _onMapTapped(LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
  }

  void _onCurrentLocationPressed() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage('Los servicios de ubicación están deshabilitados', Colors.orange);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showMessage('Permisos de ubicación denegados', Colors.red);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showMessage('Permisos de ubicación denegados permanentemente', Colors.red);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final currentLocation = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _selectedLocation = currentLocation;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(currentLocation, 16.0),
      );

      _showMessage('Ubicación actual obtenida', Colors.green);

    } catch (e) {
      _showMessage('Error al obtener ubicación actual: $e', Colors.red);
    }
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _confirmLocation() {
    if (_selectedLocation != null) {
      Navigator.of(context).pop({
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
      });
    }
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Seleccionar Ubicación'),
      backgroundColor: Theme.of(context).primaryColor,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: const Icon(Icons.check),
          onPressed: _selectedLocation != null ? _confirmLocation : null,
        ),
      ],
    ),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            children: [
              GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition: CameraPosition(
                  target: _selectedLocation ?? _defaultLocation,
                  zoom: 15.0,
                ),
                onTap: _onMapTapped,
                markers: _selectedLocation != null
                    ? {
                        Marker(
                          markerId: const MarkerId('selected_location'),
                          position: _selectedLocation!,
                          draggable: true,
                          onDragEnd: (LatLng newPosition) {
                            setState(() {
                              _selectedLocation = newPosition;
                            });
                          },
                        ),
                      }
                    : {},
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
              ),
              
              // Panel de información en la parte inferior con SafeArea
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Handle visual para indicar que se puede arrastrar
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Información de ubicación
                          Row(
                            children: [
                              const Icon(Icons.location_on, color: Colors.blue),
                              const SizedBox(width: 8),
                              const Text(
                                'Ubicación seleccionada:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          
                          if (_selectedLocation != null) ...[
                            Text(
                              'Latitud: ${_selectedLocation!.latitude.toStringAsFixed(6)}',
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                            Text(
                              'Longitud: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ] else ...[
                            const Text(
                              'Toca en el mapa para seleccionar una ubicación',
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                          
                          const SizedBox(height: 16),
                          
                          // Botones de acción
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _onCurrentLocationPressed,
                                  icon: const Icon(Icons.my_location, size: 18),
                                  label: const Text('Mi Ubicación'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    side: const BorderSide(color: Colors.blue),
                                    foregroundColor: Colors.blue,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _selectedLocation != null ? _confirmLocation : null,
                                  icon: const Icon(Icons.check, size: 18),
                                  label: const Text('Confirmar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _selectedLocation != null ? Colors.blue : Colors.grey.shade400,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    elevation: _selectedLocation != null ? 2 : 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // Instrucciones en la parte superior
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Toca en el mapa para seleccionar una ubicación o arrastra el marcador',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
  );
}
}
