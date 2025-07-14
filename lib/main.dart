import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/register_face_screen.dart';
import 'screens/login_face_screen.dart';
import 'screens/view_photos_screen.dart';

void main() {
  runApp(const FaceRecognitionApp());
}

class FaceRecognitionApp extends StatelessWidget {
  const FaceRecognitionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowMaterialGrid: false,
      title: 'Reconocimiento Facial',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 146, 33, 33)),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/register': (context) => const RegisterFaceScreen(),
        '/login': (context) => const LoginFaceScreen(),
        '/view_photos': (context) => const ViewPhotosScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
