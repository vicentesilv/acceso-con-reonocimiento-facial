import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'dart:io';

// Clase para manejar la base de datos SQLite
class DatabaseHelper {
  // Instancia singleton de DatabaseHelper
  static DatabaseHelper? _instance;
  // Instancia de la base de datos
  static Database? _database;

  DatabaseHelper._internal();

  // Factory para obtener la instancia singleton
  factory DatabaseHelper() {
    _instance ??= DatabaseHelper._internal();
    return _instance!;
  }

  // Getter para obtener la base de datos, inicializándola si es necesario
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  // Inicializa la base de datos y la abre
  Future<Database> _initDatabase() async {
    final documentsDirectory = await getDatabasesPath();
    final path = join(documentsDirectory, 'face_recognition.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  // Crea la tabla 'users' en la base de datos
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        face_encodings TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  // Registra un nuevo usuario con un solo encoding facial
  Future<int> registerUser(String name, String faceEncodings) async {
    final db = await database;
    return await db.insert('users', {
      'name': name,
      'face_encodings': faceEncodings,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // Registra un nuevo usuario con múltiples encodings (poses)
  Future<int> registerUserWithMultiplePoses(String name, List<String> faceEncodings) async {
    final db = await database;
    // Convierte la lista de encodings a JSON
    final encodingsJson = jsonEncode({"poses": faceEncodings});
    return await db.insert('users', {
      'name': name,
      'face_encodings': encodingsJson,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // Obtiene todos los usuarios registrados en la base de datos
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await database;
    return await db.query('users');
  }

  // Busca un usuario por su ID
  Future<Map<String, dynamic>?> getUserById(int id) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? result.first : null;
  }

  // Elimina un usuario por su ID
  Future<int> deleteUser(int id) async {
    final db = await database;
    return await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Cierra la base de datos
  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  // Obtiene todas las fotos temporales de un usuario específico
  Future<List<File>> getUserPhotos(String userName) async {
    // Nota: Las fotos se almacenan temporalmente y pueden ser eliminadas
    // por el sistema operativo. Para un almacenamiento permanente,
    // deberías copiar las fotos a un directorio permanente.

    List<File> userPhotos = [];

    // Busca archivos en el directorio temporal que contengan el nombre del usuario
    final Directory tempDir = Directory.systemTemp;
    final List<FileSystemEntity> files = tempDir.listSync();

    for (FileSystemEntity file in files) {
      if (file is File && file.path.contains(userName)) {
        userPhotos.add(file);
      }
    }

    return userPhotos;
  }

  // Obtiene la información completa de un usuario junto con sus fotos
  Future<Map<String, dynamic>?> getUserWithPhotos(String userName) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'users',
      where: 'name = ?',
      whereArgs: [userName],
    );

    if (results.isNotEmpty) {
      final user = results.first;
      final photos = await getUserPhotos(userName);

      return {
        'user': user,
        'photos': photos,
        'photo_count': photos.length,
      };
    }

    return null;
  }
}
