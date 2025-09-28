import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineMapService {
  static const String _cacheKey = 'map_tiles_downloaded';
  static const String _tileCacheFolder = 'map_tiles';
  
  // Coordenadas de Valladolid, Yucatán
  static const double _valladolidLat = 20.6896;
  static const double _valladolidLng = -88.2028;
  static const double _radiusKm = 10.0;
  
  // Niveles de zoom optimizados
  static const List<int> _zoomLevels = [12, 13, 14, 15];
  
  static Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    final mapCacheDir = Directory('${directory.path}/$_tileCacheFolder');
    if (!await mapCacheDir.exists()) {
      await mapCacheDir.create(recursive: true);
    }
    return mapCacheDir.path;
  }
  
  static Future<bool> areMapTilesDownloaded() async {
    final prefs = await SharedPreferences.getInstance();
    final flagDownloaded = prefs.getBool(_cacheKey) ?? false;
    
    // Si el flag dice que no están descargados, no verificar archivos
    if (!flagDownloaded) {
      return false;
    }
    
    // Verificar si realmente existen archivos de tiles
    try {
      final cachePath = await _localPath;
      final cacheDir = Directory(cachePath);
      
      if (!await cacheDir.exists()) {
        // Resetear flag si no existe el directorio
        await prefs.setBool(_cacheKey, false);
        return false;
      }
      
      // Contar archivos PNG en el directorio
      final files = await cacheDir.list(recursive: true)
          .where((entity) => entity is File && entity.path.endsWith('.png'))
          .length;
      
      if (files < 10) { // Si hay menos de 10 tiles, probablemente no se descargó correctamente
        // Resetear flag si no hay suficientes tiles
        await prefs.setBool(_cacheKey, false);
        return false;
      }
      
      return true;
    } catch (e) {
      // En caso de error, resetear flag
      await prefs.setBool(_cacheKey, false);
      return false;
    }
  }
  
  static Future<void> markMapTilesAsDownloaded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cacheKey, true);
  }
  
  static Future<void> clearMapCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cacheKey, false);
    
    final cachePath = await _localPath;
    final cacheDir = Directory(cachePath);
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }
  }
  
  // Convertir coordenadas geográficas a coordenadas de tile
  static Point<int> latLngToTileCoords(double lat, double lng, int zoom) {
    final latRad = lat * pi / 180;
    final n = pow(2, zoom);
    final x = ((lng + 180) / 360 * n).floor();
    final y = ((1 - log(tan(latRad) + 1 / cos(latRad)) / pi) / 2 * n).floor();
    return Point(x, y);
  }
  
  // Calcular los bounds de tiles para Valladolid
  static List<Point<int>> getTileBoundsForValladolid(int zoom) {
    final radiusLat = _radiusKm / 111.32; // Aproximadamente 111.32 km por grado de latitud
    final radiusLng = _radiusKm / (111.32 * cos(_valladolidLat * pi / 180));
    
    final northWest = latLngToTileCoords(
      _valladolidLat + radiusLat,
      _valladolidLng - radiusLng,
      zoom,
    );
    
    final southEast = latLngToTileCoords(
      _valladolidLat - radiusLat,
      _valladolidLng + radiusLng,
      zoom,
    );
    
    // Corregir el orden: asegurar que min < max para X e Y
    final minX = min(northWest.x, southEast.x);
    final maxX = max(northWest.x, southEast.x);
    final minY = min(northWest.y, southEast.y);
    final maxY = max(northWest.y, southEast.y);
    
    return [Point(minX, minY), Point(maxX, maxY)];
  }
  
  static Future<void> downloadMapTilesForValladolid({
    required Function(int current, int total) onProgress,
    required Function(String message) onStatusUpdate,
  }) async {
    try {
      onStatusUpdate('Iniciando descarga optimizada de mapas...');
      
      final cachePath = await _localPath;
      
      // Recopilar todos los tiles a descargar
      List<Map<String, int>> allTiles = [];
      
      for (int zoom in _zoomLevels) {
        final bounds = getTileBoundsForValladolid(zoom);
        final minX = bounds[0].x;
        final minY = bounds[0].y;
        final maxX = bounds[1].x;
        final maxY = bounds[1].y;
        
        for (int x = minX; x <= maxX; x++) {
          for (int y = minY; y <= maxY; y++) {
            allTiles.add({'zoom': zoom, 'x': x, 'y': y});
          }
        }
      }
      
      final totalTiles = allTiles.length;
      onStatusUpdate('Descargando $totalTiles tiles (optimizado)...');
      
      int downloadedTiles = 0;
      const int batchSize = 6; // Descargar 6 tiles en paralelo
      
      // Procesar en batches para descarga paralela
      for (int i = 0; i < allTiles.length; i += batchSize) {
        final batch = allTiles.skip(i).take(batchSize).toList();
        
        // Descargar el batch en paralelo
        final futures = batch.map((tile) async {
          try {
            await _downloadTile(tile['zoom']!, tile['x']!, tile['y']!, cachePath);
            return true;
          } catch (e) {
            return false;
          }
        });
        
        final results = await Future.wait(futures);
        downloadedTiles += results.length;
        
        // Actualizar progreso
        onProgress(downloadedTiles, totalTiles);
        
        // Mostrar progreso cada 30 tiles
        if (downloadedTiles % 30 == 0 || downloadedTiles == totalTiles) {
          onStatusUpdate('Descargados: $downloadedTiles/$totalTiles tiles (${(downloadedTiles/totalTiles*100).toStringAsFixed(1)}%)');
        }
        
        // Pequeña pausa para no saturar el servidor
        if (i + batchSize < allTiles.length) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
      
      await markMapTilesAsDownloaded();
      onStatusUpdate('¡$downloadedTiles mapas descargados exitosamente!');
      
    } catch (e) {
      onStatusUpdate('Error durante la descarga: $e');
      throw e;
    }
  }
  
  static Future<void> _downloadTile(int zoom, int x, int y, String cachePath) async {
    final tileDir = Directory('$cachePath/$zoom/$x');
    if (!await tileDir.exists()) {
      await tileDir.create(recursive: true);
    }
    
    final filePath = '${tileDir.path}/$y.png';
    final file = File(filePath);
    
    // Si el tile ya existe, no descargarlo de nuevo
    if (await file.exists()) {
      return;
    }
    
    // URL de OpenStreetMap tiles
    final url = 'https://tile.openstreetmap.org/$zoom/$x/$y.png';
    
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'NectarMovil/1.0 (offline maps cache)',
        },
      ).timeout(const Duration(seconds: 10)); // Timeout de 10 segundos
      
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      // Re-lanzar excepción para manejo en nivel superior
      throw Exception('Tile $zoom/$x/$y failed: $e');
    }
  }
  
  static Future<File?> getCachedTile(int zoom, int x, int y) async {
    final cachePath = await _localPath;
    final filePath = '$cachePath/$zoom/$x/$y.png';
    final file = File(filePath);
    
    if (await file.exists()) {
      return file;
    } else {
      return null;
    }
  }
  
  static Future<double> getCacheSize() async {
    final cachePath = await _localPath;
    final cacheDir = Directory(cachePath);
    
    if (!await cacheDir.exists()) {
      return 0.0;
    }
    
    double totalSize = 0.0;
    await for (final entity in cacheDir.list(recursive: true)) {
      if (entity is File) {
        final stat = await entity.stat();
        totalSize += stat.size;
      }
    }
    
    return totalSize / (1024 * 1024); // Retornar en MB
  }
}
