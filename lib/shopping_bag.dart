import 'package:flutter/material.dart';
// import 'cart_items.dart'; // 상품 데이터를 가져오는 파일

class ShoppingBagScreen extends StatefulWidget {
  @override
  _ShoppingBagScreenState createState() => _ShoppingBagScreenState();
}

class _ShoppingBagScreenState extends State<ShoppingBagScreen> {
  int totalPrice = 0; // 전체 클래스에 totalPrice 선언

  @override
  Widget build(BuildContext context) {
    totalPrice = 0; // 매번 빌드할 때 totalPrice 초기화
    for (var item in cartItems) {
      if (item.quantity > 0) {
        totalPrice +=
            item.price * item.quantity; // 각 항목의 가격 * 수량을 totalPrice에 더하기
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('장바구니',
            style: TextStyle(
                fontFamily: 'CustomFont',
                color: Colors.red,
                fontSize: 24)), // 글씨 크기 증가
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
                  totalPrice += (item.price * item.quantity).toInt();
                  return Column(
                    children: [
                      ListTile(
                        title: Text('${item.name} ${item.quantity}개',
                            style: TextStyle(
                                fontFamily: 'CustomFont',
                                color: Colors.red,
                                fontSize: 20)),
                        trailing: Text('${item.price.toInt() * item.quantity}원',
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
                Text('총 금액: ${totalPrice.toInt()}원',
                    style: TextStyle(
                        fontFamily: 'CustomFont',
                        color: Colors.red,
                        fontSize: 24)), // 소수점 제거 및 글씨 크기 증가
                SizedBox(height: 10),
                ElevatedButton(
                  child: Text('구매하기',
                      style: TextStyle(
                          fontFamily: 'CustomFont',
                          color: Colors.white,
                          fontSize: 20)), // 글씨 크기 증가
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

// 장바구니 상품 항목 예시 (cart_items.dart 파일에 정의)
class CartItem {
  final String name;
  final int price;
  int quantity;

  CartItem({required this.name, this.quantity = 0, required this.price});
}

// 장바구니에 담긴 상품 목록 (예시 데이터)
List<CartItem> cartItems = [
  CartItem(name: '까르보불닭', quantity: 2, price: 1500),
  CartItem(name: '짜파게티', quantity: 1, price: 1200),
  // ... 추가 상품
  CartItem(name: '까르보불닭', price: 1500),
  CartItem(name: '짜파게티', price: 1200),
  CartItem(name: '진라면매운맛', price: 3500),
  CartItem(name: '불닭볶음면', price: 5000),
  CartItem(name: '김치사발면', price: 3000),
  CartItem(name: '육개장', price: 4000),
  CartItem(name: '신라면', price: 4500),
  CartItem(name: '튀김우동', price: 4300),
  CartItem(name: '너구리', price: 4500),
];
