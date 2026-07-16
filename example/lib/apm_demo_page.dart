import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

/// Demonstrates the crash / jank / resource APM capabilities by providing
/// buttons that trigger a framework error, an unhandled async exception, a
/// synthetic UI-thread stall, and an on-demand memory reading.
class ApmDemoPage extends StatefulWidget {
  const ApmDemoPage({Key? key}) : super(key: key);

  @override
  State<ApmDemoPage> createState() => _ApmDemoPageState();
}

class _ApmDemoPageState extends State<ApmDemoPage> {
  String _memoryText = '点击下方按钮读取内存';
  bool _throwInBuild = false;

  void _throwSyncError() {
    // Triggers FlutterError.onError during build.
    setState(() => _throwInBuild = true);
  }

  void _throwAsyncError() {
    // Unhandled async exception → PlatformDispatcher.instance.onError.
    Future(() => throw StateError('Argos demo: unhandled async exception'));
  }

  void _causeJank() {
    // Block the UI thread long enough to drop several frames.
    final end = DateTime.now().add(const Duration(milliseconds: 400));
    while (DateTime.now().isBefore(end)) {
      // Busy-wait on purpose to starve the frame pipeline.
    }
    setState(() {});
  }

  void _readMemory() {
    final rss = ProcessInfo.currentRss;
    final maxRss = ProcessInfo.maxRss;
    setState(() {
      _memoryText = 'RSS ${_mb(rss)} / peak ${_mb(maxRss)}';
    });
  }

  String _mb(int bytes) => '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    if (_throwInBuild) {
      throw StateError('Argos demo: framework build error');
    }
    return Scaffold(
      appBar: AppBar(title: const Text('APM demo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.bug_report),
            label: const Text('抛出框架错误 (build)'),
            onPressed: _throwSyncError,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.error_outline),
            label: const Text('抛出未捕获异步异常'),
            onPressed: _throwAsyncError,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.slow_motion_video),
            label: const Text('制造卡顿 (阻塞 UI 线程 400ms)'),
            onPressed: _causeJank,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.memory),
            label: const Text('读取当前内存'),
            onPressed: _readMemory,
          ),
          const SizedBox(height: 12),
          Text(_memoryText, style: const TextStyle(fontSize: 13)),
          const Divider(height: 32),
          ElevatedButton.icon(
            icon: const Icon(Icons.wifi_tethering),
            label: const Text('打开 Inspector 查看事件'),
            onPressed: () => Navigator.pushNamed(context, '/packets'),
          ),
        ],
      ),
    );
  }
}
