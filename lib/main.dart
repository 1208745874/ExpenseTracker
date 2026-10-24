import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '冰柱子支出',
      theme: ThemeData(
        // 浅蓝色主题
        primaryColor: Colors.lightBlue.shade400,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.lightBlue.shade300,
          primary: Colors.lightBlue.shade400,
          surface: Colors.lightBlue.shade50,
        ),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.lightBlue.shade50,
          foregroundColor: Colors.lightBlue.shade800,
          elevation: 0,
          centerTitle: true,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.lightBlue,
          foregroundColor: Colors.white,
        ),
      ),
      home: const MainPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// 主页面——底部导航 + 4个页面切换
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  // 当前选中的底部导航索引（0:首页, 1:历史, 2:统计, 3:设置）
  int _selectedIndex = 0;

  // 4个页面实例（为了后面能通过 GlobalKey 调用刷新方法，先保持普通创建）
  final List<Widget> _pages = const [
    HomeScreen(),
    HistoryScreen(),
    StatsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 根据选中的索引显示对应的页面
      body: _pages[_selectedIndex],
      // 底部导航栏
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed, // 4个以上时固定样式
        selectedItemColor: Colors.lightBlue.shade600,
        unselectedItemColor: Colors.grey.shade500,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: '历史',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: '统计',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}