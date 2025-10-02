class ApiConfig {
  // 🌍 URL base de la API - CAMBIAR AQUÍ PARA TODAS LAS APIS
  static const String baseUrl =
      'http://10.0.2.2:5028'; //http://148.113.190.163:88

  // 🔗 Ruta base de la API
  static const String apiPath = '/api';

  // 📋 URLs completas para cada endpoint
  static String get tiposApoyoUrl => '$baseUrl$apiPath/Apoyos/ObtenerTipoApoyo';
  static String get obtenerTipoApoyoUrl =>
      '$baseUrl$apiPath/Apoyos/ObtenerTipoApoyo';
  static String get beneficiariosUrl =>
      '$baseUrl$apiPath/Apoyos/ObtenerBeneficiariosPaginado';
  static String get obtenerBeneficiariosUrl =>
      '$baseUrl$apiPath/Apoyos/ObtenerBeneficiariosPaginado';
  static String get obtenerApoyosPaginadoUrl =>
      '$baseUrl$apiPath/Apoyos/ObtenerApoyosPaginado';
  static String get obtenerSaldoApoyoUrl =>
      '$baseUrl$apiPath/Apoyos/ObtenerSaldoApoyo';
  static String get obtenerSectorHabitacionalApoyosUrl =>
      '$baseUrl$apiPath/Apoyos/ObtenerSectorHabitacionalApoyos';
  static String get obtenerColoniasApoyoUrl =>
      '$baseUrl$apiPath/Apoyos/ObtenerColoniasApoyo';
  static String get agregarBeneficiarioUrl =>
      '$baseUrl$apiPath/Apoyos/AgregarBeneficiario';
  static String get agregarApoyoUrl => '$baseUrl$apiPath/Apoyos/AgregarApoyo';

  // Endpoints de autenticación
  static String get loginUrl => '$baseUrl$apiPath/Login';
  static String get validarTokenUrl => '$baseUrl$apiPath/Login/ValidarToken';
  static String get registerUrl => '$baseUrl$apiPath/auth/register';

  // Endpoints de revisiones
  static String get obtenerTiposVerificacionUrl =>
      '$baseUrl$apiPath/Revisiones/ObtenerTiposVerificacion';
  static String get agregarRevisionUrl =>
      '$baseUrl$apiPath/Revisiones/AgregarRevision';
  static String get obtenerRevisionesPorInspectorUrl =>
      '$baseUrl$apiPath/Revisiones/ObtenerRevisionesPorInspectorPaginado';

  // Endpoints de contribuyentes
  static String get obtenerContribuyentesPaginadoUrl =>
      '$baseUrl$apiPath/Contribuyente/ObtenerContribuyentesPaginado';
  static String get obtenerContribuyenteUrl =>
      '$baseUrl$apiPath/Contribuyente/ObtenerContribuyente';
  static String get modificarContribuyenteUrl =>
      '$baseUrl$apiPath/Contribuyente/ModificarContribuyente';
  static String get agregarContribuyenteUrl =>
      '$baseUrl$apiPath/Contribuyente/AgregarContribuyente';

  // Endpoints de predios
  static String get obtenerPrediosPaginadoUrl =>
      '$baseUrl$apiPath/Predio/ObtenerPrediosPaginado';

  // Endpoints de información direcciones
  static String get obtenerSectoresHabitacionalesUrl =>
      '$baseUrl$apiPath/InfoDirec/ObtenerSectoresHabitacionales';
  static String get obtenerColoniasUrl =>
      '$baseUrl$apiPath/InfoDirec/ObtenerColonias';
      
  // Endpoints de licencias de funcionamiento
  static String get obtenerLicenciaQRUrl =>
      '$baseUrl$apiPath/LicenciaFuncionamiento/ObtenerLicenciaQR';

  static String get obtenerLicenciasFuncionamientoPaginadoUrl =>
      '$baseUrl$apiPath/LicenciaFuncionamiento/ObtenerLicenciasPaginado';

  // Endpoints de giros comerciales
  static String get obtenerGirosComercialesUrl =>
      '$baseUrl$apiPath/GiroComercial/ObtenerGiros';

  // 🔧 Método para construir URLs dinámicamente
  static String buildUrl(String endpoint) {
    return '$baseUrl$apiPath$endpoint';
  }

  // 🌟 URLs para diferentes ambientes (comentar/descomentar según necesites)
  static const Map<String, String> environments = {
    'local': 'http://10.0.2.2:5028',
    'development': 'https://dev-api.tuservidor.com',
    'staging': 'https://staging-api.tuservidor.com',
    'production': 'https://api.tuservidor.com',
  };

  // 📱 Para cambiar rápidamente el ambiente
  static String getEnvironmentUrl(String environment) {
    return environments[environment] ?? baseUrl;
  }
}
