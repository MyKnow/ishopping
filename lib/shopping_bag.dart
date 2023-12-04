import 'package:flutter/material.dart';
// import 'cart_items.dart'; // 상품 데이터를 가져오는 파일

class ShoppingBagScreen extends StatefulWidget {
  final Map<String, int>? shoppingbag;
  const ShoppingBagScreen({super.key, this.shoppingbag});

  @override
  _ShoppingBagScreenState createState() => _ShoppingBagScreenState();
}

class _ShoppingBagScreenState extends State<ShoppingBagScreen> {
  List<CartItem> cartItems = [];
  int totalPrice = 0;

  @override
  void initState() {
    super.initState();
    // shoppingbag 맵으로부터 데이터를 가져옵니다.
    widget.shoppingbag?.forEach((name, quantity) {
      cartItems.add(CartItem(
          name: name,
          quantity: quantity,
          price: 1000)); // 가격을 1000원으로 고정, 나중에 DB걸로 바꿀 거임.
    });
  }

  @override
  Widget build(BuildContext context) {
    totalPrice = 0;
    for (var item in cartItems) {
      totalPrice += item.price * item.quantity;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('장바구니',
            style: TextStyle(
                fontFamily: 'CustomFont', color: Colors.red, fontSize: 24)),
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: cartItems.length,
              itemBuilder: (context, index) {
                final item = cartItems[index];
                if (item.quantity > 0) {
                  return Column(
                    children: [
                      ListTile(
                        title: Text('${item.name} ${item.quantity}개',
                            style: TextStyle(
                                fontFamily: 'CustomFont',
                                color: Colors.red,
                                fontSize: 20)),
                        trailing: Text('${item.price * item.quantity}원',
                            style: TextStyle(
                                fontFamily: 'CustomFont',
                                color: Colors.red,
                                fontSize: 20)),
                        leading: IconButton(
                          icon: Icon(Icons.cancel, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              item.quantity = 0;
                            });
                          },
                        ),
                      ),
                      Divider(color: Colors.grey),
                    ],
                  );
                } else {
                  return Container();
                }
              },
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('총 금액: ${totalPrice}원',
                    style: TextStyle(
                        fontFamily: 'CustomFont',
                        color: Colors.red,
                        fontSize: 24)),
                SizedBox(height: 10),
                ElevatedButton(
                  child: Text('구매하기',
                      style: TextStyle(
                          fontFamily: 'CustomFont',
                          color: Colors.white,
                          fontSize: 20)),
                  style: ElevatedButton.styleFrom(primary: Colors.red),
                  onPressed: () {
                    // 구매 로직
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CartItem {
  final String name;
  int quantity;
  final int price;

  CartItem({required this.name, required this.quantity, required this.price});
}
