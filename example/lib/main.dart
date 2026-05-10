import 'package:flutter/material.dart';
import 'dart:async';

import 'package:mmkv/mmkv.dart';
import 'package:argos/argos.dart';

import 'package:argos_example/list_example.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MMKV.initialize();

  Future.delayed(const Duration(milliseconds: 500)).then(
    (_) => ArgosManager.instance.init(
      config: ArgosConfig(
        apmTypes: [ArgosCapability.network],
        enableStorage: true,
        maxPacketRecords: 200,
      ),
      listener: (ArgosBaseModel? model) {
        debugPrint(model?.getValue());
      },
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _ArgosRouteObserver extends NavigatorObserver {
  void _update(Route<dynamic>? route) {
    ArgosManager.instance.currentRoute = route?.settings.name ?? '';
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _update(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _update(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _update(newRoute);
}

class _MyAppState extends State<MyApp> {
  final _routeObserver = _ArgosRouteObserver();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [_routeObserver],
      routes: {
        '/listPage': (context) => const ListExamplePage(),
        '/packets': (context) => const ArgosPacketListPage(),
        '/': (context) => const MyHomePage(),
      },
      initialRoute: '/',
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plugin example app'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/listPage'),
              child: const Text('滚动列表 (触发网络请求)'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/packets'),
              child: const Text('查看抓包记录'),
            ),
          ],
        ),
      ),
    );
  }
}
