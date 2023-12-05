class ProductModel {
  final String id;
  final String product;
  final int price;
  final String barcodeNum;
  final String category;
  ProductModel(
      {required this.id,
      required this.product,
      required this.price,
      required this.barcodeNum,
      required this.category});
  factory ProductModel.fromJson(Map<String, dynamic> data) => ProductModel(
        id: data['id'],
        product: data['product'],
        price: data['price'],
        barcodeNum: data['barcodeNum'],
        category: data['category'],
      );
  Map<String, dynamic> toMap() => {
        'id': id,
        'product': product,
        'price': price,
        'barcodeNum': barcodeNum,
        'category': category
      };
}
