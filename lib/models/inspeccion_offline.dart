import 'dart:convert';

class InspeccionOffline {
  final String id;
  final String? contribuyenteId;
  final String? contribuyenteNombre;
  final String? predioId;
  final String? predioDireccion;
  final String fechaInspeccion;
  final String observaciones;
  final String? fotoFachadaPath;
  final String? fotoPermisoPath;
  final double? latitud;
  final double? longitud;
  final DateTime fechaCreacion;
  final bool isCompleta;
  // Nuevos campos
  final String? tipoVerificacionId;
  final String? tipoVerificacionDescripcion;
  final String? fechaVigencia;
  final String? licenciaId;
  final String? licenciaDescripcion;

  InspeccionOffline({
    required this.id,
    this.contribuyenteId,
    this.contribuyenteNombre,
    this.predioId,
    this.predioDireccion,
    required this.fechaInspeccion,
    required this.observaciones,
    this.fotoFachadaPath,
    this.fotoPermisoPath,
    this.latitud,
    this.longitud,
    required this.fechaCreacion,
    this.isCompleta = false,
    // Nuevos campos
    this.tipoVerificacionId,
    this.tipoVerificacionDescripcion,
    this.fechaVigencia,
    this.licenciaId,
    this.licenciaDescripcion,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contribuyenteId': contribuyenteId,
      'contribuyenteNombre': contribuyenteNombre,
      'predioId': predioId,
      'predioDireccion': predioDireccion,
      'fechaInspeccion': fechaInspeccion,
      'observaciones': observaciones,
      'fotoFachadaPath': fotoFachadaPath,
      'fotoPermisoPath': fotoPermisoPath,
      'latitud': latitud,
      'longitud': longitud,
      'fechaCreacion': fechaCreacion.toIso8601String(),
      'isCompleta': isCompleta,
      'tipoVerificacionId': tipoVerificacionId,
      'tipoVerificacionDescripcion': tipoVerificacionDescripcion,
      'fechaVigencia': fechaVigencia,
      'licenciaId': licenciaId,
      'licenciaDescripcion': licenciaDescripcion,
    };
  }

  factory InspeccionOffline.fromJson(Map<String, dynamic> json) {
    return InspeccionOffline(
      id: json['id'],
      contribuyenteId: json['contribuyenteId'],
      contribuyenteNombre: json['contribuyenteNombre'],
      predioId: json['predioId'],
      predioDireccion: json['predioDireccion'],
      fechaInspeccion: json['fechaInspeccion'],
      observaciones: json['observaciones'],
      fotoFachadaPath: json['fotoFachadaPath'],
      fotoPermisoPath: json['fotoPermisoPath'],
      latitud: json['latitud']?.toDouble(),
      longitud: json['longitud']?.toDouble(),
      fechaCreacion: DateTime.parse(json['fechaCreacion']),
      isCompleta: json['isCompleta'] ?? false,
      tipoVerificacionId: json['tipoVerificacionId'],
      tipoVerificacionDescripcion: json['tipoVerificacionDescripcion'],
      fechaVigencia: json['fechaVigencia'],
      licenciaId: json['licenciaId'],
      licenciaDescripcion: json['licenciaDescripcion'],
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory InspeccionOffline.fromJsonString(String jsonString) {
    return InspeccionOffline.fromJson(jsonDecode(jsonString));
  }

  InspeccionOffline copyWith({
    String? id,
    String? contribuyenteId,
    String? contribuyenteNombre,
    String? predioId,
    String? predioDireccion,
    String? fechaInspeccion,
    String? observaciones,
    String? fotoFachadaPath,
    String? fotoPermisoPath,
    double? latitud,
    double? longitud,
    DateTime? fechaCreacion,
    bool? isCompleta,
  }) {
    return InspeccionOffline(
      id: id ?? this.id,
      contribuyenteId: contribuyenteId ?? this.contribuyenteId,
      contribuyenteNombre: contribuyenteNombre ?? this.contribuyenteNombre,
      predioId: predioId ?? this.predioId,
      predioDireccion: predioDireccion ?? this.predioDireccion,
      fechaInspeccion: fechaInspeccion ?? this.fechaInspeccion,
      observaciones: observaciones ?? this.observaciones,
      fotoFachadaPath: fotoFachadaPath ?? this.fotoFachadaPath,
      fotoPermisoPath: fotoPermisoPath ?? this.fotoPermisoPath,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      isCompleta: isCompleta ?? this.isCompleta,
    );
  }
}
