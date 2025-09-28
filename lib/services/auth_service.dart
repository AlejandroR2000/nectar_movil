import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userNameKey = 'user_name';
  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';
  static const String _userRoleKey = 'user_role';
  static const String _userDataKey = 'user_data';
  static const String _userPermissionsKey = 'user_permissions';

  // Login con la API
  static Future<Map<String, dynamic>> login(String userName, String password) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.loginUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userName': userName,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        // Verificar si la respuesta contiene un token (login exitoso)
        if (responseData is Map<String, dynamic> && responseData.containsKey('token')) {
          // Guardar todos los datos de autenticación
          await _saveAuthData(responseData);
          
          return {
            'success': true,
            'data': responseData,
            'message': 'Login exitoso'
          };
        } else {
          // La respuesta es "Usuario no Encontrado" u otro mensaje de error
          return {
            'success': false,
            'message': response.body.replaceAll('"', '')
          };
        }
      } else if (response.statusCode == 404) {
        // Específicamente para error 404, personalizar el mensaje
        String responseMessage = response.body.replaceAll('"', '').trim();
        
        // Si el mensaje es "Usuario no Encontrado", cambiar por "Credenciales Incorrectas"
        if (responseMessage.toLowerCase().contains('usuario no encontrado') || 
            responseMessage.toLowerCase().contains('user not found')) {
          return {
            'success': false,
            'message': 'Credenciales Incorrectas'
          };
        } else {
          // Para otros mensajes 404, mostrar el mensaje original o uno genérico
          return {
            'success': false,
            'message': responseMessage.isNotEmpty ? responseMessage : 'Credenciales Incorrectas'
          };
        }
    } else if (response.statusCode == 401) {
      return {
        'success': false,
        'message': 'Credenciales Incorrectas'
      };
    } else {
        return {
          'success': false,
          'message': 'Error de conexión: ${response.statusCode}'
        };
      }
    } catch (e) {

      return {
        'success': false,
        'message': 'Error de red: $e'
      };
    }
  }

  // Guardar todos los datos de autenticación
  static Future<void> _saveAuthData(Map<String, dynamic> responseData) async {
    final prefs = await SharedPreferences.getInstance();
    final usuario = responseData['usuario'];
    
    await prefs.setString(_tokenKey, responseData['token']);
    await prefs.setString(_userNameKey, usuario['userName']);
    await prefs.setString(_userIdKey, usuario['idUsuario'].toString());
    await prefs.setString(_userEmailKey, usuario['email'] ?? '');
    await prefs.setString(_userRoleKey, usuario['rol'] ?? '');
    await prefs.setString(_userDataKey, jsonEncode(responseData));
    // Guardar las páginas (permisos) del usuario
    await prefs.setString(_userPermissionsKey, jsonEncode(responseData['paginas'] ?? []));
  }

  // Obtener token guardado
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Obtener nombre de usuario guardado
  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey);
  }

  // Obtener ID de usuario guardado
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  // Obtener email de usuario guardado
  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  // Obtener rol de usuario guardado
  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userRoleKey);
  }

  // Obtener permisos de usuario guardados
  static Future<List<String>> getUserPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final permissionsString = prefs.getString(_userPermissionsKey);
    
    if (permissionsString != null && permissionsString.isNotEmpty) {
      try {
        // Intentar decodificar la lista de permisos
        final List<dynamic> permissionsList = jsonDecode(permissionsString);
        
        // Asegurarse de que sea una lista de strings
        return permissionsList.map((e) => e.toString()).toList();
      } catch (e) {
        print('Error al decodificar permisos: $e');
      }
    }
    
    // Retornar lista vacía si no hay permisos o ocurrió un error
    return [];
  }

  // Verificar si el usuario está logueado
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // Logout completo - Limpiar TODOS los SharedPreferences
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Limpiar todas las claves específicas de autenticación
    await prefs.remove(_tokenKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userRoleKey);
    await prefs.remove(_userDataKey);
    await prefs.remove(_userPermissionsKey);
    
    // También limpiar cualquier otra clave que pueda existir
    // Obtener todas las claves y limpiar las que empiecen con prefijos conocidos
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('auth_') || 
          key.startsWith('user_') || 
          key.startsWith('session_') ||
          key.startsWith('token_')) {
        await prefs.remove(key);
      }
    }
  }

  // Manejar token expirado - Llamar cuando una API responda con error de token
  static Future<void> handleTokenExpired() async {
    await logout(); // Limpiar todo
  }

  // Obtener headers para peticiones autenticadas
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Método genérico para hacer peticiones autenticadas con manejo de token expirado
  static Future<Map<String, dynamic>> makeAuthenticatedRequest({
    required String endpoint,
    required String method,
    Map<String, dynamic>? body,
  }) async {
    try {
      final headers = await getAuthHeaders();
      final uri = Uri.parse(ApiConfig.buildUrl(endpoint));
      
      http.Response response;
      
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(uri, headers: headers);
          break;
        case 'POST':
          response = await http.post(
            uri, 
            headers: headers, 
            body: body != null ? jsonEncode(body) : null
          );
          break;
        case 'PUT':
          response = await http.put(
            uri, 
            headers: headers, 
            body: body != null ? jsonEncode(body) : null
          );
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers);
          break;
        default:
          throw Exception('Método HTTP no soportado: $method');
      }

      // Verificar si el token expiró
      if (response.statusCode == 401) {
        await handleTokenExpired();
        return {
          'success': false,
          'tokenExpired': true,
          'message': 'Sesión expirada. Por favor, inicia sesión nuevamente.'
        };
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'data': responseData,
          'statusCode': response.statusCode
        };
      } else {
        return {
          'success': false,
          'message': 'Error: ${response.statusCode} - ${response.body}',
          'statusCode': response.statusCode
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de red: $e'
      };
    }
  }

  // Método para verificar si el token sigue siendo válido
  static Future<bool> isTokenValid() async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        return false;
      }

      // Usar el endpoint de validación de token
      final response = await http.post(
        Uri.parse(ApiConfig.validarTokenUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': '*/*',
        },
        body: jsonEncode(token), // Enviar el token como string en el body
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        // Verificar la respuesta
        if (responseData is Map && responseData.containsKey('valido')) {
          bool isValid = responseData['valido'] == true;
          
          if (!isValid) {
            // Si el token no es válido, limpiar la sesión
            await handleTokenExpired();
          }
          
          return isValid;
        }
      }
      
      // Si hay error en la validación, considerar el token como inválido
      return false;
      
    } catch (e) {
      print('Error validando token: $e');
      // En caso de error de red, asumir que el token sigue siendo válido
      // para no cerrar sesión por problemas de conectividad
      return true;
    }
  }

  // Obtener páginas/permisos del usuario
  static Future<List<Map<String, dynamic>>> getUserPages() async {
    final prefs = await SharedPreferences.getInstance();
    final permissionsJson = prefs.getString(_userPermissionsKey);
    if (permissionsJson != null) {
      try {
        final decoded = jsonDecode(permissionsJson);
        return List<Map<String, dynamic>>.from(decoded);
      } catch (e) {
        print('Error al decodificar permisos: $e');
        return [];
      }
    }
    return [];
  }

  // Verificar si el usuario tiene permiso para una URL específica
  static Future<bool> hasPermission(String url) async {
    final permissions = await getUserPages();
    return permissions.any((permission) => 
      permission['url'].toString() == url && permission['activo'] == true
    );
  }

  // Verificar si el usuario tiene alguno de los permisos de una lista
  static Future<bool> hasAnyPermission(List<String> urls) async {
    final permissions = await getUserPages();
    for (String url in urls) {
      if (permissions.any((permission) => 
          permission['url'].toString() == url && permission['activo'] == true)) {
        return true;
      }
    }
    return false;
  }

  // Verificar permisos específicos para Apoyos
  static Future<Map<String, bool>> getApoyosPermissions() async {
    final permissions = await getUserPages();
    
    final beneficiarios = permissions.any((p) => 
      p['url'].toString() == '/beneficiarios' && p['activo'] == true);
    final crearBeneficiario = permissions.any((p) => 
      p['url'].toString() == '/beneficiarios/create' && p['activo'] == true);
    final apoyos = permissions.any((p) => 
      p['url'].toString() == '/apoyos' && p['activo'] == true);
    final crearApoyo = permissions.any((p) => 
      p['url'].toString() == '/apoyos/create' && p['activo'] == true);

    return {
      'beneficiarios': beneficiarios,
      'crearBeneficiario': crearBeneficiario,
      'apoyos': apoyos,
      'crearApoyo': crearApoyo,
      'mostrarApoyos': beneficiarios || apoyos, // Mostrar sección si tiene cualquiera
      'mostrarReportes': crearApoyo, // Mostrar reportes solo si puede crear apoyos
    };
  }

  // Verificar permisos específicos para Revisiones
  static Future<Map<String, bool>> getRevisionesPermissions() async {
    final permissions = await getUserPages();
    
    final revisiones = permissions.any((p) => 
      p['url'].toString() == '/revisiones' && p['activo'] == true);
    final crearRevision = permissions.any((p) => 
      p['url'].toString() == '/revisiones/create' && p['activo'] == true);

    return {
      'revisiones': revisiones,
      'crearRevision': crearRevision,
      'mostrarRevisiones': revisiones || crearRevision, // Mostrar sección si tiene cualquiera
    };
  }
}
