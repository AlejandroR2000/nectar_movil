# Configuración de Google Maps API Key

## Para que Google Maps funcione correctamente, necesitas configurar una API Key de Google Maps:

### 1. Obtener API Key
1. Ve a [Google Cloud Console](https://console.cloud.google.com/)
2. Crea un nuevo proyecto o selecciona uno existente
3. Habilita la API de Maps SDK for Android
4. Ve a "Credenciales" y crea una nueva API Key
5. Restringe la API Key para que solo funcione con tu aplicación Android

### 2. Configurar en Android
Edita el archivo `android/app/src/main/AndroidManifest.xml` y reemplaza `YOUR_GOOGLE_MAPS_API_KEY` con tu API key real:

```xml
<meta-data android:name="com.google.android.geo.API_KEY"
           android:value="TU_API_KEY_AQUI"/>
```

### 3. Para iOS (opcional)
Si planeas usar iOS, también necesitas configurar la API key en `ios/Runner/AppDelegate.swift`.

## Características implementadas:

✅ **Selector de ubicación con Google Maps integrado**
- Interfaz intuitiva con mapa interactivo
- Marcador arrastrable para selección precisa
- Botón "Mi Ubicación" para obtener ubicación actual
- Coordenadas mostradas en tiempo real
- Diseño moderno con panel inferior

✅ **Integración completa con el formulario**
- Reemplaza la funcionalidad anterior de url_launcher
- Navegación fluida entre pantallas
- Validación y confirmación de ubicación
- Manejo de errores robusto

✅ **Mejoras de UX**
- Instrucciones claras para el usuario
- Feedback visual inmediato
- Fallback a ubicación por defecto (Valladolid, Yucatán)
- Manejo de permisos de ubicación

## Para probar sin API Key:
La aplicación funcionará pero mostrará un mapa en gris. Las coordenadas y la funcionalidad seguirán funcionando normalmente.
