import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/face_recognition_service.dart';
import '../database/database_helper.dart';
import 'dart:io';
import 'dart:math';

class LoginFaceScreen extends StatefulWidget {
  const LoginFaceScreen({super.key});

  @override
  State<LoginFaceScreen> createState() => _LoginFaceScreenState();
}

class _LoginFaceScreenState extends State<LoginFaceScreen> {
  File? _selectedImage;
  List<Face> _detectedFaces = [];
  final FaceRecognitionService _faceService = FaceRecognitionService();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isProcessing = false;
  bool _isAuthenticating = false;
  String _statusMessage = 'Toma una foto para iniciar sesión';

  @override
  void initState() {
    super.initState();
    _faceService.initialize();
  }

  @override
  void dispose() {
    _faceService.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) {
      _showSnackBar('Permisos de cámara denegados');
      return;
    }

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _statusMessage = 'Procesando imagen...';
        _isProcessing = true;
      });
      
      await _processImage(image.path);
    }
  }

  Future<void> _processImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await _faceService.detectFaces(inputImage);
      
      setState(() {
        _detectedFaces = faces;
        _isProcessing = false;
        if (faces.isNotEmpty) {
          _statusMessage = 'Rostros detectados: ${faces.length}. Toca "Iniciar Sesión" para continuar.';
        } else {
          _statusMessage = 'No se detectaron rostros. Toma otra foto.';
        }
      });
      
      print('Rostros encontrados: ${faces.length}');
      for (int i = 0; i < faces.length; i++) {
        print('Rostro $i: ${faces[i].boundingBox}');
      }
    } catch (e) {
      print('Error procesando imagen: $e');
      setState(() {
        _statusMessage = 'Error procesando imagen: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _authenticateWithFace() async {
    if (_detectedFaces.isEmpty) {
      _showSnackBar('No se detectó ningún rostro. Toma otra foto.');
      return;
    }

    if (_detectedFaces.length > 1) {
      _showSnackBar('Se detectaron múltiples rostros. Asegúrate de que solo aparezca una persona en la foto.');
      return;
    }

    setState(() {
      _isAuthenticating = true;
      _statusMessage = 'Comparando con todas las fotos registradas...';
    });

    try {
      // Usar el primer rostro detectado
      final detectedFace = _detectedFaces.first;
      final detectedEncoding = _faceService.createFaceEncoding(detectedFace);
      
      // Obtener todos los usuarios registrados
      final users = await _dbHelper.getAllUsers();
      
      if (users.isEmpty) {
        _showSnackBar('No hay usuarios registrados en el sistema.');
        setState(() {
          _isAuthenticating = false;
          _statusMessage = 'No hay usuarios registrados.';
        });
        return;
      }

      // Contar total de fotos para mostrar progreso
      // ignore: unused_local_variable
      int totalPhotosToCompare = 0;
      for (var user in users) {
        final userPhotos = await _dbHelper.getUserPhotos(user['name']);
        totalPhotosToCompare += userPhotos.length;
      }

      setState(() {
        _statusMessage = 'Ejecutando análisis avanzado de reconocimiento facial...';
      });

      const double threshold = 0.6; // Umbral de similitud

      // Comparar con todas las fotos individuales usando algoritmo mejorado

      
      final comparisonResult = await _faceService.compareWithAllUserPhotos(detectedEncoding, users);
      
      final bestMatch = comparisonResult['similarity'] as double;
      final matchedUser = comparisonResult['user'] as Map<String, dynamic>?;
      final photoInfo = comparisonResult['photo_info'] as String?;
      final totalComparisons = comparisonResult['total_comparisons'] as int;
      final confidence = comparisonResult['confidence'] as double? ?? bestMatch;
      final allMatches = comparisonResult['all_matches'] as List<dynamic>? ?? [];
      

      setState(() {
        _isAuthenticating = false;
      });

      if (bestMatch >= threshold && matchedUser != null) {
        setState(() {
          _statusMessage = '¡Usuario identificado! ${matchedUser['name']} (${(bestMatch * 100).toStringAsFixed(1)}% similitud, ${(confidence * 100).toStringAsFixed(1)}% confianza)';
        });
        
        String successMessage = '¡Usuario identificado con análisis avanzado! ${matchedUser['name']} con ${(bestMatch * 100).toStringAsFixed(1)}% de similitud';
        if (confidence > bestMatch) {
          successMessage += ' y ${(confidence * 100).toStringAsFixed(1)}% de confianza';
        }
        successMessage += ' después de analizar $totalComparisons fotos';
        
        _showSnackBar(successMessage);
        
        // Mostrar información adicional de las mejores coincidencias
        if (allMatches.isNotEmpty && allMatches.length > 1) {
          print('=== TOP COINCIDENCIAS ===');
          for (int i = 0; i < min(3, allMatches.length); i++) {
            final match = allMatches[i];
            print('${i + 1}. ${match['user']}: ${(match['similarity'] * 100).toStringAsFixed(1)}% (${match['photo_info']})');
          }
        }
        
        // Mostrar diálogo de éxito
        _showSuccessDialog(matchedUser['name'], bestMatch, photoInfo, confidence);
      } else {
        setState(() {
          _statusMessage = 'Sin coincidencias suficientes después de análisis avanzado de $totalComparisons fotos';
        });
        
        String detailMessage = 'Ningún usuario reconocido después del análisis avanzado de $totalComparisons fotos de ${users.length} usuarios.';
        if (matchedUser != null) {
          detailMessage = 'Mejor resultado del análisis: ${matchedUser['name']} con ${(bestMatch * 100).toStringAsFixed(1)}% (necesario: ${(threshold * 100).toStringAsFixed(1)}%) - $photoInfo';
          if (confidence != bestMatch) {
            detailMessage += ' (confianza: ${(confidence * 100).toStringAsFixed(1)}%)';
          }
        }
        
        _showSnackBar(detailMessage);
      }
    } catch (e) {
      setState(() {
        _isAuthenticating = false;
        _statusMessage = 'Error durante la autenticación: $e';
      });
      _showSnackBar('Error durante la autenticación: $e');
    }
  }

  void _showSuccessDialog(String userName, [double? similarity, String? photoInfo, double? confidence]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('¡Acceso Concedido!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                '¡Bienvenido, $userName',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              if (photoInfo != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Coincidencia con: $photoInfo',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar diálogo
                Navigator.of(context).pop(); // Volver a pantalla anterior
              },
              child: const Text('Continuar'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio de Sesión Facial'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Estado
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.grey[200],
              child: Column(
                children: [
                  Text(
                    _statusMessage,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  if (_isProcessing)
                    const CircularProgressIndicator()
                  else
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Tomar Foto'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
            
            // Imagen y formulario
            Container(
              height: MediaQuery.of(context).size.height - 200, // Altura específica para el contenido
              child: _selectedImage != null
                  ? Column(
                      children: [
                        // Imagen con rostros detectados
                        Expanded(
                          flex: 3,
                          child: Stack(
                            children: [
                              Container(
                                width: double.infinity,
                                child: Image.file(
                                  _selectedImage!,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              if (_detectedFaces.isNotEmpty)
                                CustomPaint(
                                  painter: FacePainter(_detectedFaces),
                                  child: Container(),
                                ),
                            ],
                          ),
                        ),
                        
                        // Botones de control
                        Expanded(
                          flex: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Rostros detectados: ${_detectedFaces.length}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: (_detectedFaces.length == 1 && !_isAuthenticating) 
                                        ? _authenticateWithFace 
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: _isAuthenticating
                                        ? const CircularProgressIndicator(color: Colors.white)
                                        : const Text('Iniciar Sesión'),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (_detectedFaces.length == 1 && !_isAuthenticating)
                                  const Text(
                                    '✅ Listo para verificar',
                                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      height: MediaQuery.of(context).size.height - 300,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Presiona el botón para tomar una foto\ny iniciar sesión con tu rostro',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class FacePainter extends CustomPainter {
  final List<Face> faces;

  FacePainter(this.faces);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    for (Face face in faces) {
      canvas.drawRect(face.boundingBox, paint);
    }
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) {
    return oldDelegate.faces != faces;
  }
}
