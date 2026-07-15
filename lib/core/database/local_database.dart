import 'package:sqflite/sqflite.dart';

abstract class LocalDatabase {
  Future<Database> get database;

  Future<void> initialize();
  Future<void> close();

  // Punto de extension para SQLite. La implementacion futura debe garantizar
  // transacciones atomicas y consultas paginadas para soportar alto volumen.
  Future<T> transaction<T>(Future<T> Function() action);
}
