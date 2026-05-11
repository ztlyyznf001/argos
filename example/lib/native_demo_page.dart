import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NativeCaptureDemoPage extends StatelessWidget {
  const NativeCaptureDemoPage({Key? key}) : super(key: key);

  static const MethodChannel _channel =
      MethodChannel('argos_example/native_demo');

  Future<void> _invoke(BuildContext context, String method) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _channel.invokeMethod<void>(method);
      messenger.showSnackBar(
        SnackBar(content: Text('已发起原生请求：$method')),
      );
    } on PlatformException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('调用失败：${e.message ?? e.code}')),
      );
    } on MissingPluginException {
      messenger.showSnackBar(
        const SnackBar(content: Text('当前平台未注册原生 demo channel')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;

    return Scaffold(
      appBar: AppBar(title: const Text('原生抓包 demo')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed:
                  isIOS ? () => _invoke(context, 'sendIosRequest') : null,
              child: const Text('iOS 原生请求'),
            ),
            if (!isIOS)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  '仅在 iOS 上可用',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isAndroid
                  ? () => _invoke(context, 'sendAndroidRequest')
                  : null,
              child: const Text('Android 原生请求'),
            ),
            if (!isAndroid)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  '仅在 Android 上可用',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            const SizedBox(height: 32),
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
