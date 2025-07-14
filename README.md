# Aplicación de Reconocimiento Facial con Flutter

Esta aplicación permite registrar rostros en una base de datos SQLite local y posteriormente utilizarlos para iniciar sesión mediante reconocimiento facial.

## Características

- **Registro de Rostros**: Permite capturar y almacenar características faciales de usuarios
- **Inicio de Sesión Facial**: Autentica usuarios comparando rostros con la base de datos
- **Base de Datos Local**: Utiliza SQLite para almacenar información de usuarios
- **Interfaz Intuitiva**: Diseño Material 3 con navegación simple

## Tecnologías Utilizadas

- **Flutter**: Framework de desarrollo multiplataforma
- **Google ML Kit**: Para detección de rostros
- **SQLite**: Base de datos local
- **Camera**: Acceso a la cámara del dispositivo
- **Permission Handler**: Manejo de permisos

## Instalación

1. **Clona el repositorio**:
   ```bash
   git clone <url-del-repositorio>
   cd flutter_reconocimiento_facial
   ```

2. **Instala las dependencias**:
   ```bash
   flutter pub get
   ```

3. **Ejecuta la aplicación**:
   ```bash
   flutter run
   ```

## Uso de la Aplicación

### 1. Pantalla Principal
- Muestra el número de usuarios registrados
- Botón para registrar nuevo rostro
- Botón para iniciar sesión (habilitado solo si hay usuarios registrados)
- Lista de usuarios registrados con opción de eliminar

### 2. Registro de Rostro
- Activa la cámara frontal
- Detecta rostros automáticamente (marcados con rectángulo rojo)
- Permite ingresar el nombre del usuario
- Botón "Capturar Rostro" para tomar la muestra
- Botón "Registrar" para guardar en la base de datos

### 3. Inicio de Sesión Facial
- Activa la cámara frontal
- Detecta rostros automáticamente
- Compara el rostro detectado con los registrados
- Muestra mensaje de bienvenida si encuentra coincidencia
- Opción de verificación manual

## Permisos Necesarios

### Android
Los siguientes permisos se añaden automáticamente en `android/app/src/main/AndroidManifest.xml`:
- `CAMERA`: Para acceso a la cámara
- `WRITE_EXTERNAL_STORAGE`: Para almacenar datos
- `READ_EXTERNAL_STORAGE`: Para leer datos

### iOS
En `ios/Runner/Info.plist` se debe añadir:
```xml
<key>NSCameraUsageDescription</key>
<string>Esta aplicación necesita acceso a la cámara para el reconocimiento facial.</string>
```

## Estructura del Proyecto

```
lib/
├── main.dart                          # Punto de entrada de la app
├── database/
│   └── database_helper.dart          # Gestión de base de datos SQLite
├── services/
│   └── face_recognition_service.dart # Servicio de reconocimiento facial
└── screens/
    ├── home_screen.dart              # Pantalla principal
    ├── register_face_screen.dart     # Pantalla de registro
    └── login_face_screen.dart        # Pantalla de login
```

## Funcionalidades Técnicas

### Detección de Rostros
- Utiliza Google ML Kit Face Detection
- Detecta múltiples rostros en tiempo real
- Extrae características faciales (landmarks, contornos)

### Almacenamiento
- Base de datos SQLite local
- Tabla `users` con campos: id, name, face_encodings, created_at
- Encodings faciales almacenados como JSON

### Comparación de Rostros
- Algoritmo simplificado de comparación
- Basado en proporciones faciales y landmarks
- Umbral de similitud configurable (actualmente 0.6)

## Limitaciones

1. **Algoritmo Simplificado**: El método de comparación es básico. Para producción se recomienda usar algoritmos más sofisticados como FaceNet.

2. **Condiciones de Iluminación**: La detección puede verse afectada por condiciones de luz pobres.

3. **Múltiples Rostros**: Solo se procesa el primer rostro detectado.

4. **Seguridad**: Los datos se almacenan localmente sin encriptación.

## Mejoras Futuras

1. **Algoritmos Avanzados**: Implementar FaceNet o similar para mejor precisión
2. **Encriptación**: Encriptar datos faciales almacenados
3. **Configuración**: Permitir ajustar el umbral de similitud
4. **Múltiples Rostros**: Soportar registro de múltiples rostros por usuario
5. **Exportar/Importar**: Funcionalidad para backup de datos

## Resolución de Problemas

### Error de Permisos
- Asegúrate de que los permisos de cámara estén habilitados en la configuración del dispositivo

### Rostro No Detectado
- Verifica que haya suficiente iluminación
- Asegúrate de estar mirando directamente a la cámara
- Mantén el rostro centrado en la pantalla

### Error de Base de Datos
- Reinicia la aplicación
- Si persiste, desinstala y reinstala la app

