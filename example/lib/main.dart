import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:ui';

import 'package:mmkv/mmkv.dart';
import 'package:argos_inspector/argos_inspector.dart';

import 'package:argos_example/list_example.dart';
import 'package:argos_example/mmkv_storage_adapter.dart';
import 'package:argos_example/native_demo_page.dart';
import 'package:argos_example/apm_demo_page.dart';

const bool _manualSessionDemo = bool.fromEnvironment(
  'ARGOS_MANUAL_SESSION_DEMO',
  defaultValue: false,
);

const bool _adaptiveSessionDemo = bool.fromEnvironment(
  'ARGOS_ADAPTIVE_SESSION_DEMO',
  defaultValue: false,
);

ArgosSessionContext _cachedDemoContext = ArgosSessionContext(
  fingerprint: 'demo-user|tenant-a',
  attributes: const <String, String>{'tenant': 'tenant-a'},
);

void _switchDemoContext() {
  final useTenantB = _cachedDemoContext.attributes['tenant'] != 'tenant-b';
  final tenant = useTenantB ? 'tenant-b' : 'tenant-a';
  _cachedDemoContext = ArgosSessionContext(
    fingerprint: 'demo-user|$tenant',
    attributes: <String, String>{'tenant': tenant},
  );
  debugPrint(
    '[ArgosSession:context] switched to $tenant; '
    'the next accepted event rolls the adaptive session',
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  await MMKV.initialize();

  Future.delayed(const Duration(milliseconds: 500)).then((_) {
    ArgosManager.instance.init(
      config: ArgosConfig(
        apmTypes: [
          ArgosCapability.network,
          ArgosCapability.crash,
          ArgosCapability.jank,
          ArgosCapability.resource,
        ],
        enableStorage: true,
        sessionMode: _manualSessionDemo
            ? ArgosSessionMode.manual
            : ArgosSessionMode.automatic,
        automaticSessionPolicy: _adaptiveSessionDemo
            ? ArgosAutomaticSessionPolicy.adaptive(
                backgroundTimeout: const Duration(seconds: 10),
                maxDuration: const Duration(minutes: 2),
                contextProvider: () => _cachedDemoContext,
              )
            : const ArgosAutomaticSessionPolicy.process(),
        maxSessions: 5,
        maxPacketRecords: 200,
        storageAdapter: MmkvStorageAdapter(),
      ),
      listener: (ArgosBaseModel? model) {
        final metadata = model?.eventMetadata;
        debugPrint(
          '[ArgosEvent] type=${model?.type} '
          'session=${metadata?.sessionId} sequence=${metadata?.sequence} '
          '${model?.getValue()}',
        );
      },
    );
    ArgosNativeCapture.instance.enable();
    _logSessions('init');
  });

  runApp(const MyApp());
}

Future<void> _logSessions(String phase) async {
  final manager = ArgosManager.instance;
  final sessions = await manager.getSessions();
  for (final session in sessions) {
    final records = await manager.getSessionRecords(session.id);
    debugPrint(
      '[ArgosSession:$phase] id=${session.id} endedAt=${session.endedAt} '
      'reason=${session.endReason} records=${records.length} '
      'truncated=${session.truncated}',
    );
  }
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
      builder: (context, child) => ArgosWidgetInspector(
        enabled: kDebugMode,
        child: child!,
      ),
      navigatorObservers: [_routeObserver],
      routes: {
        '/listPage': (context) => const ListExamplePage(),
        '/packets': (context) => const ArgosPacketListPage(),
        '/nativeDemo': (context) => const NativeCaptureDemoPage(),
        '/apmDemo': (context) => const ApmDemoPage(),
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
            ArgosTunable(
              id: 'home.runtime-tuning-card',
              label: '首页实时调参卡片',
              properties: const <ArgosTuningProperty>[
                ArgosDoubleTuningProperty(
                  id: 'fontSize',
                  label: '字号',
                  initialValue: 20,
                  min: 12,
                  max: 36,
                  divisions: 12,
                  decimalPlaces: 0,
                ),
                ArgosDoubleTuningProperty(
                  id: 'padding',
                  label: '外边距',
                  initialValue: 8,
                  min: 0,
                  max: 32,
                  divisions: 16,
                  decimalPlaces: 0,
                ),
                ArgosDoubleTuningProperty(
                  id: 'opacity',
                  label: '透明度',
                  initialValue: 1,
                  min: 0.2,
                  max: 1,
                  divisions: 8,
                  decimalPlaces: 1,
                ),
                ArgosDoubleTuningProperty(
                  id: 'borderRadius',
                  label: '圆角',
                  initialValue: 12,
                  min: 0,
                  max: 32,
                  divisions: 16,
                  decimalPlaces: 0,
                ),
                ArgosColorTuningProperty(
                  id: 'color',
                  label: '背景色',
                  initialValue: Color(0xFFEDE7F6),
                ),
                ArgosColorTuningProperty(
                  id: 'textColor',
                  label: '字体颜色',
                  initialValue: Color(0xFF311B92),
                ),
              ],
              builder: (context, values) {
                return Opacity(
                  opacity: values.doubleValue('opacity'),
                  child: Padding(
                    padding: EdgeInsets.all(values.doubleValue('padding')),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: values.colorValue('color'),
                        borderRadius: BorderRadius.circular(
                          values.doubleValue('borderRadius'),
                        ),
                      ),
                      child: Text(
                        '长按我实时调参',
                        style: TextStyle(
                          fontSize: values.doubleValue('fontSize'),
                          color: values.colorValue('textColor'),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            const _SessionDemoControls(),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/listPage'),
              child: const Text('滚动列表 (触发网络请求)'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/packets'),
              child: const Text('查看抓包记录'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/nativeDemo'),
              child: const Text('原生抓包 demo'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/apmDemo'),
              child: const Text('APM demo (崩溃/卡顿/资源)'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimal session lifecycle demo. The app uses automatic mode by default;
/// run with `--dart-define=ARGOS_MANUAL_SESSION_DEMO=true` to start idle and
/// drive the whole recording window with these four buttons. Use
/// `--dart-define=ARGOS_ADAPTIVE_SESSION_DEMO=true` to enable a 10-second
/// background boundary, a 2-minute maximum, and the context switch below.
class _SessionDemoControls extends StatefulWidget {
  const _SessionDemoControls();

  @override
  State<_SessionDemoControls> createState() => _SessionDemoControlsState();
}

class _SessionDemoControlsState extends State<_SessionDemoControls> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _refresh(VoidCallback action) {
    action();
    setState(() {});
  }

  String _stateLabel(ArgosSessionState state) {
    switch (state) {
      case ArgosSessionState.idle:
        return 'idle';
      case ArgosSessionState.recording:
        return 'recording';
      case ArgosSessionState.paused:
        return 'paused';
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = ArgosManager.instance;
    final session = manager.activeSession;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Session: ${_stateLabel(manager.sessionState)}'
          '${session == null ? '' : ' · ${session.id}'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (_adaptiveSessionDemo)
          Text(
            'Adaptive context: '
            '${_cachedDemoContext.attributes['tenant']}',
          ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          children: [
            TextButton(
              onPressed: () => _refresh(() {
                final session =
                    manager.startSession(label: 'example manual repro');
                debugPrint('[ArgosSession:start] id=${session.id}');
              }),
              child: const Text('Start'),
            ),
            TextButton(
              onPressed: () => _refresh(manager.pauseSession),
              child: const Text('Pause'),
            ),
            TextButton(
              onPressed: () => _refresh(manager.resumeSession),
              child: const Text('Resume'),
            ),
            TextButton(
              onPressed: () async {
                await manager.stopSession();
                await _logSessions('stop');
                if (mounted) setState(() {});
              },
              child: const Text('Stop'),
            ),
            if (_adaptiveSessionDemo)
              TextButton(
                onPressed: () => _refresh(_switchDemoContext),
                child: const Text('Switch Context'),
              ),
          ],
        ),
      ],
    );
  }
}
