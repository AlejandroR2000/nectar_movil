import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/offline_map_service.dart';
import 'dart:ui' as ui;

class OfflineMapLocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const OfflineMapLocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<OfflineMapLocationPickerScreen> createState() => _OfflineMapLocationPickerScreenState();
}

class _OfflineMapLocationPickerScreenState extends State<OfflineMapLocationPickerScreen> {
  final MapController _mapController = MapController();
  LatLng? _selectedLocation;
  bool _isLoading = true;
  bool _isDownloadingMaps = false;
  String _downloadStatus = '';
  int _downloadProgress = 0;
  int _totalTiles = 0;
  
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
    });

    // Verificar si hay mapas descargados, si no, descargarlos automáticamente
    await _checkAndDownloadMaps();

    setState(() {
      _isLoading = false;
    });

    // Mover el mapa a la ubicación inicial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(initialLocation, 15.0);
    });
  }

  Future<void> _checkAndDownloadMaps() async {
    bool mapsExist = await OfflineMapService.areMapTilesDownloaded();
    
    if (!mapsExist) {
      setState(() {
        _isDownloadingMaps = true;
        _downloadStatus = 'Descargando mapas automáticamente...';
      });

      try {
        await OfflineMapService.downloadMapTilesForValladolid(
          onProgress: (current, total) {
            setState(() {
              _downloadProgress = current;
              _totalTiles = total;
            });
          },
          onStatusUpdate: (status) {
            setState(() {
              _downloadStatus = status;
            });
          },
        );
      } catch (e) {
        setState(() {
          _downloadStatus = 'Error descargando mapas: $e';
        });
      } finally {
        setState(() {
          _isDownloadingMaps = false;
        });
      }
    }
  }

  void _onMapTapped(TapPosition tapPosition, LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Seleccionar Ubicación',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          if (_selectedLocation != null)
            IconButton(
              icon: const Icon(Icons.check, color: Colors.white),
              onPressed: () {
                Navigator.pop(context, {
                  'latitude': _selectedLocation!.latitude,
                  'longitude': _selectedLocation!.longitude,
                });
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isDownloadingMaps
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _downloadStatus,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      if (_totalTiles > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Progreso: $_downloadProgress / $_totalTiles tiles',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: LinearProgressIndicator(
                            value: _downloadProgress / _totalTiles,
                            backgroundColor: Colors.grey[300],
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedLocation ?? _defaultLocation,
                    initialZoom: 15.0,
                    maxZoom: 18.0,
                    minZoom: 8.0,
                    onTap: _onMapTapped,
                    // Limitar el mapa a la región de Valladolid
                    cameraConstraint: CameraConstraint.contain(
                      bounds: LatLngBounds(
                        LatLng(20.63, -88.27), // Suroeste
                        LatLng(20.75, -88.13), // Noreste
                      ),
                    ),
                  ),
                  children: [
                    TileLayer(
                      tileProvider: _OfflineTileProvider(),
                      userAgentPackageName: 'com.devgap.nectar_movil',
                      maxZoom: 18,
                    ),
                    if (_selectedLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedLocation!,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                // Positioned(
                //   bottom: 100,
                //   right: 16,
                //   child: FloatingActionButton(
                //     heroTag: "location_btn",
                //     backgroundColor: const Color(0xFF2E7D32),
                //     foregroundColor: Colors.white,
                //     onPressed: _onCurrentLocationPressed,
                //     child: const Icon(Icons.my_location),
                //   ),
                // ),
                // Banner para indicar que está usando mapas offline
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.9),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.offline_bolt,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'MAPA OFFLINE - Sin conexión requerida',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_selectedLocation != null)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Ubicación seleccionada:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}',
                            ),
                            Text(
                              'Lng: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context, {
                                    'latitude': _selectedLocation!.latitude,
                                    'longitude': _selectedLocation!.longitude,
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2E7D32),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Confirmar Ubicación'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _OfflineTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return _OfflineFileImage(coordinates);
  }
}

class _OfflineFileImage extends ImageProvider<_OfflineFileImage> {
  final TileCoordinates coordinates;
  
  const _OfflineFileImage(this.coordinates);
  
  @override
  Future<_OfflineFileImage> obtainKey(ImageConfiguration configuration) {
    return Future.value(this);
  }
  
  @override
  ImageStreamCompleter loadImage(_OfflineFileImage key, ImageDecoderCallback decode) {
    return OneFrameImageStreamCompleter(_loadTile(key, decode));
  }
  
  Future<ImageInfo> _loadTile(_OfflineFileImage key, ImageDecoderCallback decode) async {
    try {
      // Usar OfflineMapService para obtener el tile descargado
      final cachedFile = await OfflineMapService.getCachedTile(
        key.coordinates.z,
        key.coordinates.x,
        key.coordinates.y,
      );
      
      if (cachedFile != null && await cachedFile.exists()) {
        final bytes = await cachedFile.readAsBytes();
        
        // Verificar que tenemos datos válidos
        if (bytes.isEmpty) {
          return await _createPlaceholderTile();
        }
        
        // Verificar que sea un PNG válido
        if (bytes.length >= 8 && 
            bytes[0] == 0x89 && bytes[1] == 0x50 && 
            bytes[2] == 0x4E && bytes[3] == 0x47) {
          final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
          final codec = await decode(buffer);
          final frame = await codec.getNextFrame();
          return ImageInfo(image: frame.image);
        } else {
          return await _createPlaceholderTile();
        }
      }
      
      // Si no existe el tile, crear uno placeholder
      return await _createPlaceholderTile();
    } catch (e) {
      // En caso de error, crear tile placeholder
      return await _createPlaceholderTile();
    }
  }
  
  Future<ImageInfo> _createPlaceholderTile() async {
    // Crear un tile gris placeholder de 256x256 usando PictureRecorder
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = Colors.grey[300]!;
    
    // Dibujar el fondo
    canvas.drawRect(const Rect.fromLTWH(0, 0, 256, 256), paint);
    
    // Agregar texto para indicar que es offline
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'OFF',
        style: TextStyle(
          color: Colors.grey,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(110, 120));
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(256, 256);
    return ImageInfo(image: image);
  }
  
  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is _OfflineFileImage &&
           other.coordinates.x == coordinates.x &&
           other.coordinates.y == coordinates.y &&
           other.coordinates.z == coordinates.z;
  }
  
  @override
  int get hashCode => Object.hash(coordinates.x, coordinates.y, coordinates.z);
}
