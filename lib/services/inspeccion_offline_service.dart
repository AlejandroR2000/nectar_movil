import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/inspeccion_offline.dart';

class InspeccionOfflineService {
  static const String _keyInspecciones = 'inspecciones_offline';

  static Future<void> guardarInspeccion(InspeccionOffline inspeccion) async {
    final prefs = await SharedPreferences.getInstance();
    
    List<InspeccionOffline> inspecciones = await obtenerInspecciones();
    
    // Verificar si ya existe una inspección con el mismo ID
    final index = inspecciones.indexWhere((i) => i.id == inspeccion.id);
    if (index != -1) {
      inspecciones[index] = inspeccion;
    } else {
      inspecciones.add(inspeccion);
    }
    
    // Convertir a JSON y guardar
    final jsonList = inspecciones.map((i) => i.toJson()).toList();
    await prefs.setString(_keyInspecciones, jsonEncode(jsonList));
  }

  static Future<List<InspeccionOffline>> obtenerInspecciones() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyInspecciones);
    
    if (jsonString == null) {
      return [];
    }
    
    try {
      final jsonList = jsonDecode(jsonString) as List;
      return jsonList.map((json) => InspeccionOffline.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<List<InspeccionOffline>> obtenerInspeccionesPendientes() async {
    final inspecciones = await obtenerInspecciones();
    return inspecciones.where((i) => !i.isCompleta).toList();
  }

  static Future<void> eliminarInspeccion(String id) async {
    final prefs = await SharedPreferences.getInstance();
    
    List<InspeccionOffline> inspecciones = await obtenerInspecciones();
    inspecciones.removeWhere((i) => i.id == id);
    
    final jsonList = inspecciones.map((i) => i.toJson()).toList();
    await prefs.setString(_keyInspecciones, jsonEncode(jsonList));
  }

  static Future<void> marcarComoCompleta(String id) async {
    final prefs = await SharedPreferences.getInstance();
    
    List<InspeccionOffline> inspecciones = await obtenerInspecciones();
    final index = inspecciones.indexWhere((i) => i.id == id);
    
    if (index != -1) {
      inspecciones[index] = inspecciones[index].copyWith(isCompleta: true);
      final jsonList = inspecciones.map((i) => i.toJson()).toList();
      await prefs.setString(_keyInspecciones, jsonEncode(jsonList));
    }
  }

  static Future<void> limpiarInspeccionesCompletas() async {
    final prefs = await SharedPreferences.getInstance();
    
    List<InspeccionOffline> inspecciones = await obtenerInspecciones();
    inspecciones.removeWhere((i) => i.isCompleta);
    
    final jsonList = inspecciones.map((i) => i.toJson()).toList();
    await prefs.setString(_keyInspecciones, jsonEncode(jsonList));
  }

  static Future<InspeccionOffline?> obtenerInspeccionPorId(String id) async {
    final inspecciones = await obtenerInspecciones();
    try {
      return inspecciones.firstWhere((i) => i.id == id);
    } catch (e) {
      return null;
    }
  }
}
