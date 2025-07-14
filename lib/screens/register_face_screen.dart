import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../services/face_recognition_service.dart';
import '../database/database_helper.dart';
import 'dart:io';
import 'dart:async';

class RegisterFaceScreen extends StatefulWidget {
  const RegisterFaceScreen({super.key});

  @override
  State<RegisterFaceScreen> createState() => _RegisterFaceScreenState();
}

class _RegisterFaceScreenState extends State<RegisterFaceScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;

  final List<File> _capturedImages = [];
  final List<List<Face>> _allDetectedFaces = [];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _providerController = TextEditingController();
  final FaceRecognitionService _faceService = FaceRecognitionService();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final List<String> _faceEncodings = [];
  bool _isCapturing = false;
  String _statusMessage =
      'Captura múltiples fotos para un mejor reconocimiento';

  // Estados para la captura de poses
  int _currentPoseIndex = 0;
  final List<String> _poseInstructions = [
    'Mira hacia el frente',
    'Gira la cabeza hacia la IZQUIERDA',
    'Gira la cabeza hacia la DERECHA',
    'Inclina la cabeza hacia ARRIBA',
    'Inclina la cabeza hacia ABAJO'
  ];

  bool _allPosesCompleted = false;
  Timer? _captureTimer;
  final int _photosPerPose = 3; // Número de fotos por pose
  int _currentPhotoInPose = 0;

  @override
  void initState() {
    super.initState();
    _faceService.initialize();
    _initializeCamera();

    _statusMessage =
        'Pose 1/${_poseInstructions.length}: ${_poseInstructions[0]}';
    _nameController.addListener(() {
      setState(() {});
    });
    _providerController.addListener(() {
      setState(() {});
    });
  }

  Future<void> _initializeCamera() async {
    try {
      final status = await Permission.camera.request();
      if (status != PermissionStatus.granted) {
        _showSnackBar('Permiso de cámara denegado');
        return;
      }

      _cameras = await availableCameras();
      if (_cameras!.isNotEmpty) {
        // Buscar la cámara frontal
        CameraDescription frontCamera = _cameras!.first;
        for (CameraDescription camera in _cameras!) {
          if (camera.lensDirection == CameraLensDirection.front) {
            frontCamera = camera;
            break;
          }
        }

        _cameraController = CameraController(
          frontCamera,
          ResolutionPreset.medium,
          enableAudio: false,
        );

        await _cameraController!.initialize();

        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      _showSnackBar('Error inicializando cámara: $e');
    }
  }

  Future<void> _startContinuousCapture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _showSnackBar('Cámara no inicializada');
      return;
    }

    setState(() {
      _isCapturing = true;
      _currentPhotoInPose = 0;
      _statusMessage =
          'Capturando pose ${_currentPoseIndex + 1}: ${_poseInstructions[_currentPoseIndex]}...';
    });

    // Capturar múltiples fotos con intervalos
    _captureTimer =
        Timer.periodic(const Duration(milliseconds: 800), (timer) async {
      if (_currentPhotoInPose < _photosPerPose) {
        await _capturePhoto();
        _currentPhotoInPose++;
      } else {
        timer.cancel();
        _moveToNextPose();
      }
    });
  }

  Future<void> _capturePhoto() async {
    try {
      final image = await _cameraController!.takePicture();
      await _processImage(image.path);
    } catch (e) {
      _showSnackBar('Error capturando foto: $e');
    }
  }

  void _moveToNextPose() {
    _currentPoseIndex++;
    _currentPhotoInPose = 0;

    setState(() {
      _isCapturing = false;
      if (_currentPoseIndex < _poseInstructions.length) {
        _statusMessage =
            'Pose ${_currentPoseIndex + 1}/${_poseInstructions.length}: ${_poseInstructions[_currentPoseIndex]}';
      } else {
        _allPosesCompleted = true;
        _statusMessage =
            'Todas las poses completadas. Ingresa tu nombre y registra.';

        _showSnackBar(
            'Todas las poses completadas. Ingresa el nombre para registrar.');
      }
    });
  }

  void _stopCapture() {
    _captureTimer?.cancel();
    setState(() {
      _isCapturing = false;
    });
  }

  Future<void> _processImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await _faceService.detectFaces(inputImage);

      if (faces.isNotEmpty && faces.length == 1) {
        _capturedImages.add(File(imagePath));
        _allDetectedFaces.add(faces);

        final faceEncoding = _faceService.createFaceEncoding(faces.first);
        _faceEncodings.add(faceEncoding);

        setState(() {});
      } else {
        _showSnackBar(
            '❌ Foto descartada: ${faces.length} rostros detectados (necesario: 1)');
        if (faces.isEmpty) {
          _showSnackBar('❌ No se detectó ningún rostro');
        } else {
          _showSnackBar(
              '❌  Más de un rostro detectado. Por favor, asegúrate de que solo haya un rostro visible.');
        }
      }
    } catch (e) {
      _showSnackBar("message: 'Error procesando imagen: $e'");
    }
  }

  void _resetCapture() {
    setState(() {
      _capturedImages.clear();
      _allDetectedFaces.clear();
      _faceEncodings.clear();
      _currentPoseIndex = 0;
      _allPosesCompleted = false;
      _statusMessage =
          'Pose 1/${_poseInstructions.length}: ${_poseInstructions[0]}';
    });
  }

  Future<void> _registerUser() async {
    if (_faceEncodings.isEmpty) {
      _showSnackBar('Primero debes completar todas las poses.');
      // print('❌ No hay encodings de rostros');
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('❌  Nombre vacío. \nPor favor, ingresa tu nombre.');
      return;
    }

    if (_providerController.text.trim().isEmpty) {
      _showSnackBar('❌  Campo proveedor vacío. \nPor favor, ingresa de qué eres proveedor.');
      return;
    }

    if (!_allPosesCompleted) {
      _showSnackBar('❌  Debes completar todas las poses primero.');
      // print('Poses no completadas');
      return;
    }

    try {
      final userName = _nameController.text.trim();
      final provider = _providerController.text.trim();
      final fullUserName = '$userName - $provider';

      // print('💾 Guardando fotos permanentemente...');

      // Guardar todas las fotos en el directorio permanente del usuario
      List<String> permanentPaths = [];
      for (int i = 0; i < _capturedImages.length; i++) {
        final permanentPath = await _savePhotoToUserDirectory(
            _capturedImages[i].path, fullUserName, i);
        permanentPaths.add(permanentPath);
        // print('   • Foto ${i + 1} guardada: ${permanentPath.split('/').last}');
      }

      // print('📝 Registrando en base de datos...');

      await _dbHelper.registerUserWithMultiplePoses(fullUserName, _faceEncodings);

      // print('✅ REGISTRO EXITOSO');
      _showSnackBar(
          '✅  Usuario $userName ($provider) registrado exitosamente con ${_faceEncodings.length} fotos guardadas!');

      // Limpiar formulario
      _nameController.clear();
      _providerController.clear();
      _capturedImages.clear();
      _allDetectedFaces.clear();
      _faceEncodings.clear();
      _currentPoseIndex = 0;
      _allPosesCompleted = false;

      setState(() {
        _statusMessage =
            'Pose 1/${_poseInstructions.length}: ${_poseInstructions[0]}';
      });

      // Opcional: navegar de vuelta
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('Error registrando usuario: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<String> _savePhotoToUserDirectory(
      String originalPath, String userName, int photoIndex) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final userDir = Directory('${appDir.path}/user_photos/$userName');

      // Crear directorio si no existe
      if (!await userDir.exists()) {
        await userDir.create(recursive: true);
      }

      // Copiar foto al directorio permanente
      final originalFile = File(originalPath);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newPath = '${userDir.path}/photo_${photoIndex}_$timestamp.jpg';

      await originalFile.copy(newPath);
      return newPath;
    } catch (e) {
      _showSnackBar('Error guardando foto: $e');
      return originalPath; // Retornar path original si falla
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _providerController.dispose();
    _faceService.dispose();
    _cameraController?.dispose();
    _captureTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Rostro'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: !_isCameraInitialized
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        if (_isCapturing)
                          const CircularProgressIndicator()
                        else if (!_allPosesCompleted)
                          ElevatedButton.icon(
                            onPressed: _startContinuousCapture,
                            icon: const Icon(Icons.camera_alt),
                            label: Text('Capturar Pose ${_currentPoseIndex + 1}'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: _resetCapture,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reiniciar Captura'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Cámara y galería
                  Container(
                    height: MediaQuery.of(context).size.height - 200, // Altura específica
                    child: Column(
                      children: [
                        // Vista de la cámara
                        Expanded(
                          flex: 2,
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.blue, width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: CameraPreview(_cameraController!),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.all(8),
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  TextField(
                                    controller: _nameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Nombre',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _providerController,
                                    decoration: const InputDecoration(
                                      labelText: 'proveedor: ',
                                      hintText: 'Ej: Agua, Gas, Internet, etc.',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (_allPosesCompleted)
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: (_nameController.text
                                                    .trim()
                                                    .isNotEmpty &&
                                                _providerController.text
                                                    .trim()
                                                    .isNotEmpty &&
                                                _faceEncodings.isNotEmpty)
                                            ? _registerUser
                                            : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: Text(
                                            'Registrar (${_faceEncodings.length} fotos)'),
                                      ),
                                    )
                                  else
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed:
                                            _isCapturing ? _stopCapture : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Detener'),
                                      ),
                                    ),
                                  if (_allPosesCompleted &&
                                      _nameController.text.trim().isNotEmpty &&
                                      _providerController.text.trim().isNotEmpty &&
                                      _faceEncodings.isNotEmpty)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        '✅ Listo para registrar',
                                        style: TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12),
                                      ),
                                    )
                                  else if (_allPosesCompleted &&
                                      _faceEncodings.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        '⚠️ No hay fotos válidas',
                                        style: TextStyle(
                                            color: Colors.orange,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12),
                                      ),
                                    )
                                  else if (_allPosesCompleted &&
                                      (_nameController.text.trim().isEmpty ||
                                          _providerController.text.trim().isEmpty))
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        '⚠️ Completa todos los campos',
                                        style: TextStyle(
                                            color: Colors.orange,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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
      ..color = Colors.green
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
