import 'dart:developer';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'product_model.dart';

class DatabaseService {
  static final DatabaseService _databaseService = DatabaseService._internal();
  factory DatabaseService() => _databaseService;
  DatabaseService._internal();
  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDatabase();
    return _database!;
  }

  Future<Database> initDatabase() async {
    final getDirectory = await getApplicationDocumentsDirectory();
    String path = getDirectory.path + '/products.db';
    log(path);
    return await openDatabase(path, onCreate: _onCreate, version: 1);
  }

  void _onCreate(Database db, int version) async {
    await db.execute(
        'CREATE TABLE Products(id TEXT PRIMARY KEY, product TEXT, price INTEGER, barcodeNum TEXT, category TEXT)');
    log('TABLE CREATED');
  }

  Future<List<ProductModel>> getProducts() async {
    final db = await _databaseService.database;
    var data = await db.rawQuery('SELECT * FROM Products');
    List<ProductModel> products = List.generate(
        data.length, (index) => ProductModel.fromJson(data[index]));
    print(products.length);
    return products;
  }

  Future<void> insertProduct(ProductModel product) async {
    final db = await _databaseService.database;
    var data = await db.rawInsert(
        'INSERT INTO Products(id, product, price, barcodeNum, category ) VALUES(?,?,?,?,?)',
        [
          product.id,
          product.product,
          product.price,
          product.barcodeNum,
          product.category
        ]);
    log('inserted $data');
  }

  Future<void> editProduct(ProductModel product) async {
    final db = await _databaseService.database;
    var data = await db.rawUpdate(
        'UPDATE Products SET product=?,price=?,barcodeNum=?,category=? WHERE ID=?',
        [
          product.id,
          product.product,
          product.price,
          product.barcodeNum,
          product.category
        ]);
    log('updated $data');
  }

  Future<void> deleteProduct(String id) async {
    final db = await _databaseService.database;
    var data = await db.rawDelete('DELETE from Products WHERE id=?', [id]);
    log('deleted $data');
  }
}
