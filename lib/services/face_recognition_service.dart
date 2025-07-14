import 'dart:convert';
import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceRecognitionService {
  static final FaceRecognitionService _instance = FaceRecognitionService._internal();
  factory FaceRecognitionService() => _instance;
  FaceRecognitionService._internal();

  late FaceDetector _faceDetector;

  void initialize() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: false,
        enableLandmarks: true,
        enableClassification: false,
        enableTracking: false,
        minFaceSize: 0.1,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
  }

  Future<List<Face>> detectFaces(InputImage inputImage) async {
    try {
      final faces = await _faceDetector.processImage(inputImage);
      return faces;
    } catch (e) {
      print('Error detectando rostros: $e');
      return [];
    }
  }

  // Método mejorado para crear una "huella" del rostro con más características
  String createFaceEncoding(Face face) {
    final boundingBox = face.boundingBox;
    final landmarks = face.landmarks;
    
    Map<String, dynamic> encoding = {
      'boundingBox': {
        'left': boundingBox.left.toDouble(),
        'top': boundingBox.top.toDouble(),
        'width': boundingBox.width.toDouble(),
        'height': boundingBox.height.toDouble(),
        'centerX': (boundingBox.left + boundingBox.width / 2).toDouble(),
        'centerY': (boundingBox.top + boundingBox.height / 2).toDouble(),
        'area': (boundingBox.width * boundingBox.height).toDouble(),
      },
      'faceRatios': {
        'aspectRatio': (boundingBox.width / boundingBox.height).toDouble(),
        'normalized': true,
      },
    };

    // Añadir landmarks con análisis geométrico mejorado
    if (landmarks.isNotEmpty) {
      Map<String, dynamic> landmarkData = {};
      Map<String, double> geometricFeatures = {};
      
      // Extraer posiciones de landmarks
      for (var landmark in landmarks.entries) {
        final point = landmark.value;
        if (point != null) {
          landmarkData[landmark.key.name] = {
            'x': point.position.x.toDouble(),
            'y': point.position.y.toDouble(),
            // Normalizar relativamente al bounding box
            'relativeX': ((point.position.x - boundingBox.left) / boundingBox.width).toDouble(),
            'relativeY': ((point.position.y - boundingBox.top) / boundingBox.height).toDouble(),
          };
        }
      }
      
      // Calcular características geométricas del rostro
      if (landmarkData.containsKey('leftEye') && landmarkData.containsKey('rightEye')) {
        final leftEye = landmarkData['leftEye'];
        final rightEye = landmarkData['rightEye'];
        geometricFeatures['eyeDistance'] = _calculateDistance(
          leftEye['x'] as double, leftEye['y'] as double, rightEye['x'] as double, rightEye['y'] as double
        );
        geometricFeatures['eyeCenterY'] = ((leftEye['y'] as double) + (rightEye['y'] as double)) / 2;
      }
      
      if (landmarkData.containsKey('nose') && landmarkData.containsKey('mouth')) {
        final nose = landmarkData['nose'];
        final mouth = landmarkData['mouth'];
        geometricFeatures['noseToMouthDistance'] = _calculateDistance(
          nose['x'] as double, nose['y'] as double, mouth['x'] as double, mouth['y'] as double
        );
      }
      
      if (landmarkData.containsKey('leftCheek') && landmarkData.containsKey('rightCheek')) {
        final leftCheek = landmarkData['leftCheek'];
        final rightCheek = landmarkData['rightCheek'];
        geometricFeatures['cheekDistance'] = _calculateDistance(
          leftCheek['x'] as double, leftCheek['y'] as double, rightCheek['x'] as double, rightCheek['y'] as double
        );
      }
      
      encoding['landmarks'] = landmarkData;
      encoding['geometricFeatures'] = geometricFeatures;
    }

    // Añadir timestamp y metadata
    encoding['metadata'] = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'version': '2.0',
      'landmarkCount': landmarks.length,
    };

    return jsonEncode(encoding);
  }

  // Algoritmo de comparación mejorado con múltiples métricas
  double compareFaces(String encoding1, String encoding2) {
    try {
      final face1 = jsonDecode(encoding1);
      final face2 = jsonDecode(encoding2);

      double totalSimilarity = 0.0;
      int metrics = 0;

      // 1. Comparación de proporciones faciales (peso: 20%)
      final similarity1 = _compareBoundingBoxes(face1['boundingBox'], face2['boundingBox']);
      totalSimilarity += similarity1 * 0.20;
      metrics++;

      // 2. Comparación de landmarks (peso: 50%)
      if (face1['landmarks'] != null && face2['landmarks'] != null) {
        final similarity2 = _compareLandmarks(face1['landmarks'], face2['landmarks']);
        totalSimilarity += similarity2 * 0.50;
        metrics++;
      }

      // 3. Comparación de características geométricas (peso: 30%)
      if (face1['geometricFeatures'] != null && face2['geometricFeatures'] != null) {
        final similarity3 = _compareGeometricFeatures(face1['geometricFeatures'], face2['geometricFeatures']);
        totalSimilarity += similarity3 * 0.30;
        metrics++;
      }

      // Ajustar por número de métricas disponibles
      return metrics > 0 ? totalSimilarity : 0.0;
      
    } catch (e) {
      print('Error comparando rostros: $e');
      return 0.0;
    }
  }

  // Comparación mejorada de bounding boxes
  double _compareBoundingBoxes(Map<String, dynamic> bbox1, Map<String, dynamic> bbox2) {
    try {
      // Comparar proporciones y tamaños relativos con conversiones seguras
      final width1 = (bbox1['width'] as num).toDouble();
      final height1 = (bbox1['height'] as num).toDouble();
      final width2 = (bbox2['width'] as num).toDouble();
      final height2 = (bbox2['height'] as num).toDouble();
      
      final ratio1 = width1 / height1;
      final ratio2 = width2 / height2;
      
      final ratioSimilarity = 1.0 - (ratio1 - ratio2).abs() / max(ratio1, ratio2);
      
      // Comparar áreas relativas con conversiones seguras
      final area1 = (bbox1['area'] as num?)?.toDouble() ?? (width1 * height1);
      final area2 = (bbox2['area'] as num?)?.toDouble() ?? (width2 * height2);
      final areaSimilarity = 1.0 - (area1 - area2).abs() / max(area1, area2);
      
      return (ratioSimilarity * 0.7 + areaSimilarity * 0.3).clamp(0.0, 1.0);
    } catch (e) {
      print('Error comparando bounding boxes: $e');
      return 0.0;
    }
  }

  // Comparación avanzada de landmarks
  double _compareLandmarks(Map<String, dynamic> landmarks1, Map<String, dynamic> landmarks2) {
    double totalSimilarity = 0.0;
    int comparisons = 0;
    
    // Pesos diferentes para landmarks más importantes
    Map<String, double> landmarkWeights = {
      'leftEye': 1.5,
      'rightEye': 1.5,
      'nose': 1.3,
      'mouth': 1.2,
      'leftCheek': 1.0,
      'rightCheek': 1.0,
    };
    
    double totalWeight = 0.0;
    
    try {
      for (String key in landmarks1.keys) {
        if (landmarks2.containsKey(key)) {
          final point1 = landmarks1[key] as Map<String, dynamic>;
          final point2 = landmarks2[key] as Map<String, dynamic>;
          
          // Usar coordenadas relativas para mejor comparación con conversiones seguras
          final x1 = (point1['relativeX'] as num?)?.toDouble() ?? (point1['x'] as num).toDouble();
          final y1 = (point1['relativeY'] as num?)?.toDouble() ?? (point1['y'] as num).toDouble();
          final x2 = (point2['relativeX'] as num?)?.toDouble() ?? (point2['x'] as num).toDouble();
          final y2 = (point2['relativeY'] as num?)?.toDouble() ?? (point2['y'] as num).toDouble();
          
          final relativeDistance = _calculateDistance(x1, y1, x2, y2);
          
          // Convertir distancia a similitud con función exponencial
          final similarity = exp(-relativeDistance * 10); // Función exponencial para mejor discriminación
          
          final weight = landmarkWeights[key] ?? 1.0;
          totalSimilarity += similarity * weight;
          totalWeight += weight;
          comparisons++;
        }
      }
    } catch (e) {
      print('Error comparando landmarks: $e');
      return 0.0;
    }
    
    return comparisons > 0 ? (totalSimilarity / totalWeight).clamp(0.0, 1.0) : 0.0;
  }

  // Comparación de características geométricas
  double _compareGeometricFeatures(Map<String, dynamic> features1, Map<String, dynamic> features2) {
    double totalSimilarity = 0.0;
    int comparisons = 0;
    
    // Comparar distancias importantes
    final importantFeatures = ['eyeDistance', 'noseToMouthDistance', 'cheekDistance'];
    
    try {
      for (String feature in importantFeatures) {
        if (features1.containsKey(feature) && features2.containsKey(feature)) {
          final value1 = (features1[feature] as num).toDouble();
          final value2 = (features2[feature] as num).toDouble();
          
          // Similitud basada en diferencia relativa
          final similarity = 1.0 - (value1 - value2).abs() / max(value1, value2);
          totalSimilarity += similarity;
          comparisons++;
        }
      }
    } catch (e) {
      print('Error comparando características geométricas: $e');
      return 0.0;
    }
    
    return comparisons > 0 ? (totalSimilarity / comparisons).clamp(0.0, 1.0) : 0.0;
  }

  // Comparar un rostro con múltiples poses almacenadas
  double compareFaceWithMultiplePoses(String singleEncoding, String multipleEncodingsJson) {
    try {
      final data = jsonDecode(multipleEncodingsJson);
      if (data['poses'] != null) {
        final poses = data['poses'] as List<dynamic>;
        double bestMatch = 0.0;
        
        for (String poseEncoding in poses) {
          final similarity = compareFaces(singleEncoding, poseEncoding);
          if (similarity > bestMatch) {
            bestMatch = similarity;
          }
        }
        
        return bestMatch;
      } else {
        // Formato antiguo, comparar directamente
        return compareFaces(singleEncoding, multipleEncodingsJson);
      }
    } catch (e) {
      print('Error comparando con múltiples poses: $e');
      // Intentar comparación directa como fallback
      return compareFaces(singleEncoding, multipleEncodingsJson);
    }
  }

  // Comparación avanzada con todas las fotos individuales de múltiples usuarios
  Future<Map<String, dynamic>> compareWithAllUserPhotos(String singleEncoding, List<Map<String, dynamic>> users) async {
    double bestSimilarity = 0.0;
    Map<String, dynamic>? bestMatch;
    String? bestPhotoInfo;
    int totalComparisons = 0;
    List<Map<String, dynamic>> allMatches = [];
    
    print('=== ANÁLISIS AVANZADO DE RECONOCIMIENTO FACIAL ===');
    print('Iniciando comparación con algoritmo mejorado...');
    
    for (final user in users) {
      final userName = user['name'] as String;
      print('=== Analizando usuario: $userName ===');
      
      List<double> userSimilarities = [];
      
      try {
        final encodingsData = jsonDecode(user['face_encodings'] as String);
        
        if (encodingsData['poses'] != null) {
          // Usuario con múltiples poses
          final poses = encodingsData['poses'] as List<dynamic>;
          
          for (int i = 0; i < poses.length; i++) {
            final poseEncoding = poses[i] as String;
            final similarity = compareFaces(singleEncoding, poseEncoding);
            userSimilarities.add(similarity);
            totalComparisons++;
            
            print('  📷 Foto ${i + 1}/${poses.length}: ${(similarity * 100).toStringAsFixed(2)}% similitud');
            
            // Guardar información detallada de esta comparación
            allMatches.add({
              'user': userName,
              'similarity': similarity,
              'photoIndex': i + 1,
              'totalPhotos': poses.length,
              'photoInfo': 'Foto ${i + 1} de ${poses.length}',
            });
            
            if (similarity > bestSimilarity) {
              bestSimilarity = similarity;
              bestMatch = user;
              bestPhotoInfo = 'Foto ${i + 1} de ${poses.length}';
            }
          }
          
          // Análisis estadístico del usuario
          if (userSimilarities.isNotEmpty) {
            final avgSimilarity = userSimilarities.reduce((a, b) => a + b) / userSimilarities.length;
            final maxSimilarity = userSimilarities.reduce(max);
            final minSimilarity = userSimilarities.reduce(min);
            
            print('  📊 Estadísticas de $userName:');
            print('     • Promedio: ${(avgSimilarity * 100).toStringAsFixed(2)}%');
            print('     • Máximo: ${(maxSimilarity * 100).toStringAsFixed(2)}%');
            print('     • Mínimo: ${(minSimilarity * 100).toStringAsFixed(2)}%');
            print('     • Consistencia: ${(100 - (maxSimilarity - minSimilarity) * 100).toStringAsFixed(2)}%');
          }
          
        } else {
          // Usuario con formato antiguo (una sola foto)
          final similarity = compareFaces(singleEncoding, user['face_encodings'] as String);
          userSimilarities.add(similarity);
          totalComparisons++;
          
          print('  📷 Foto única: ${(similarity * 100).toStringAsFixed(2)}% similitud');
          
          allMatches.add({
            'user': userName,
            'similarity': similarity,
            'photoIndex': 1,
            'totalPhotos': 1,
            'photoInfo': 'Foto única',
          });
          
          if (similarity > bestSimilarity) {
            bestSimilarity = similarity;
            bestMatch = user;
            bestPhotoInfo = 'Foto única';
          }
        }
      } catch (e) {
        print('  ❌ Error procesando usuario $userName: $e');
      }
    }
    
    // Ordenar todas las coincidencias por similitud
    allMatches.sort((a, b) => b['similarity'].compareTo(a['similarity']));
    
    // Análisis final
    print('\n=== RESULTADO FINAL DEL ANÁLISIS ===');
    print('Total de fotos analizadas: $totalComparisons');
    print('Total de usuarios: ${users.length}');
    
    if (bestMatch != null) {
      print('🎯 Mejor coincidencia: ${bestMatch['name']} con ${(bestSimilarity * 100).toStringAsFixed(2)}%');
      print('📍 Foto específica: $bestPhotoInfo');
      
      // Mostrar top 3 coincidencias
      print('\n📈 Top 3 coincidencias:');
      for (int i = 0; i < min(3, allMatches.length); i++) {
        final match = allMatches[i];
        print('   ${i + 1}. ${match['user']}: ${(match['similarity'] * 100).toStringAsFixed(2)}% (${match['photoInfo']})');
      }
    } else {
      print('❌ No se encontraron coincidencias válidas');
    }
    
    // Calcular confianza del resultado
    double confidence = bestSimilarity;
    if (allMatches.length > 1) {
      final secondBest = allMatches[1]['similarity'] as double;
      final gap = bestSimilarity - secondBest;
      confidence = bestSimilarity * (1 + gap); // Incrementar confianza si hay una clara diferencia
    }
    
    return {
      'similarity': bestSimilarity,
      'user': bestMatch,
      'photo_info': bestPhotoInfo,
      'total_comparisons': totalComparisons,
      'confidence': confidence.clamp(0.0, 1.0),
      'all_matches': allMatches.take(5).toList(), // Top 5 coincidencias
      'analysis_complete': true,
    };
  }

  double _calculateDistance(double x1, double y1, double x2, double y2) {
    return sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2));
  }

  void dispose() {
    _faceDetector.close();
  }
}
