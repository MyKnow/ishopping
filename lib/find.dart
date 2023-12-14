import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class FindScreen extends StatefulWidget {
  const FindScreen({super.key});
  @override
  _FindScreenState createState() => _FindScreenState();
}

class _FindScreenState extends State<FindScreen> {
  late FlutterTts flutterTts;
  int activeButtonIndex = 0; // 활성화된 버튼 인덱스

  @override
  void initState() {
    super.initState();
    initializeTts();
  }

  void initializeTts() async {
    flutterTts = FlutterTts();
    await flutterTts.setLanguage("ko-KR");
    await flutterTts.setPitch(1.0);
    await flutterTts.setSpeechRate(0.8);
    await flutterTts.speak("가고자 하는 매대를 선택해주세요.");
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      body: SafeArea(
        child: GestureDetector(
          onVerticalDragEnd: (details) => _VerticalhandleSwipe(details),
          onTap: () => _navigateToCurrentMode(context),
          child: Stack(
            children: [
              _buildBackground(), // 배경 타원 그리기
              Column(
                children: [
                  _buildTitleSection(), // 제목 섹션
                  Expanded(child: buildLayout()), // 버튼 그리드
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _VerticalhandleSwipe(DragEndDetails details) {
    if (details.primaryVelocity != null) {
      if (details.primaryVelocity! > 0 && activeButtonIndex < 7) {
        setState(() {
          activeButtonIndex++;
          speakCurrentMode();
        });
      } else if (details.primaryVelocity! < 0 && activeButtonIndex > 0) {
        setState(() {
          activeButtonIndex--;
          speakCurrentMode();
        });
      }
    }
  }

  void speakCurrentMode() async {
    String modeText = "";
    switch (activeButtonIndex) {
      case 0:
        modeText = "기획 상품.";
        break;
      case 1:
        modeText = "간편 식품.";
        break;
      case 2:
        modeText = "과자.";
        break;
      case 3:
        modeText = "냉동.";
        break;
      case 4:
        modeText = "라면.";
        break;
      case 5:
        modeText = "빵.";
        break;
      case 6:
        modeText = "음료.";
        break;
      case 7:
        modeText = "생필품.";
        break;
    }

    await flutterTts.speak(modeText);
  }

  void _navigateToCurrentMode(BuildContext context) {
    String modeText = "";
    switch (activeButtonIndex) {
      case 0:
        modeText = "기획 상품 클릭됨";
        break;
      case 1:
        modeText = "간편 식품 클릭됨";
        break;
      case 2:
        modeText = "과자 클릭됨";
        break;
      case 3:
        modeText = "냉동 클릭됨";
        break;
      case 4:
        modeText = "라면 클릭됨";
        break;
      case 5:
        modeText = "빵 클릭됨";
        break;
      case 6:
        modeText = "음료 클릭됨";
        break;
      case 7:
        modeText = "생필품 클릭됨";
        break;
    }

    flutterTts.speak(modeText);
  }

  Widget _buildBackground() {
    return CustomPaint(
      painter: BackgroundPainter(),
      size: Size(double.infinity, double.infinity),
    );
  }

  Widget _buildTitleSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Image.asset(
            'assets/images/public/lens.png',
            width: 32, // 적절한 크기로 조절
            height: 32,
          ),
          SizedBox(width: 8),
          // 텍스트 추가
          Text(
            '매대 검색',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 32,
              fontFamily: 'CustomFont',
            ),
          ),
        ],
      ),
    );
  }

  Widget buildLayout() {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    double availableHeight = screenHeight -
        (AppBar().preferredSize.height +
            MediaQuery.of(context).padding.top +
            40);

    // 버튼의 높이를 화면 세로 크기의 1/4로 설정
    double buttonHeight = availableHeight / 4;

    // 버튼의 비율을 가로 크기 대비 세로 크기로 설정
    double childAspectRatio = screenWidth / (buttonHeight * 2);

    return GridView.builder(
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 2열
        childAspectRatio: childAspectRatio,
      ),
      itemCount: 8,
      itemBuilder: (context, index) {
        List<String> buttonNames = [
          '기획',
          '간편식품',
          '과자',
          '냉동',
          '라면',
          '빵',
          '음료',
          '생필품',
        ];
        String buttonName = buttonNames[index];

        return buildModeButton(buttonName, index, buttonHeight);
      },
    );
  }

  Widget buildModeButton(String text, int modeIndex, double buttonHeight) {
    return GestureDetector(
      onTap: () {
        setState(() => activeButtonIndex = modeIndex);
        _navigateToCurrentMode(context);
      },
      child: Container(
        margin: EdgeInsets.all(10),
        child: ElevatedButton(
          onPressed: () {
            _navigateToCurrentMode(context);
          },
          style: ElevatedButton.styleFrom(
            primary:
                activeButtonIndex == modeIndex ? Colors.yellow : Colors.white,
            onPrimary: Colors.black,
            shadowColor: const Color.fromARGB(255, 88, 77, 77),
            elevation: activeButtonIndex == modeIndex ? 10 : 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            padding: EdgeInsets.symmetric(vertical: 20),
            // 버튼의 최소 높이를 설정하지 않습니다.
          ),
          child: Text(
            text,
            style: TextStyle(
              color: activeButtonIndex == modeIndex ? Colors.red : Colors.black,
              fontSize: 24,
              fontFamily: 'CustomFont',
            ),
          ),
        ),
      ),
    );
  }
}

class BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var paintSmall = Paint()..color = const Color(0xFFFFF2CC);
    var paintLarge = Paint()..color = const Color(0xFFFFF2CC);

    canvas.drawCircle(
        Offset(size.width * 0.2, size.height * 0.1), 100, paintSmall);
    canvas.drawCircle(
        Offset(size.width * 0.8, size.height * 0.7), 200, paintLarge);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
