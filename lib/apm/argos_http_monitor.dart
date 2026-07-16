import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'dart:typed_data';

import 'package:argos_inspector/apm/argos_base_monitor.dart';
import 'package:argos_inspector/config/argos_config.dart';
import 'package:argos_inspector/argos_manager.dart';
import 'package:argos_inspector/model/argos_model.dart';
import 'package:argos_inspector/model/argos_http_info_model.dart';
import 'package:argos_inspector/storage/argos_packet_storage.dart';

class ArgosHttpMonitor implements ArgosBaseMonitor {
  ArgosConfig? config;

  String? Function()? proxyProvider;

  ArgosHttpMonitor._internal();

  static late final ArgosHttpMonitor _instance = ArgosHttpMonitor._internal();

  static ArgosHttpMonitor get instance => _instance;

  @override
  ArgosHttpMonitor init({
    ArgosConfig? config,
  }) {
    final HttpOverrides? origin = HttpOverrides.current;
    HttpOverrides.global = ArgosHttpOverrides(
      origin,
    );
    this.config = config;
    return this;
  }

  @override
  void onReport(ArgosBaseModel model) {}
}

class ArgosHttpOverrides extends HttpOverrides {
  final HttpOverrides? origin;
  ArgosHttpOverrides(
    this.origin,
  );

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    if (origin != null) {
      final HttpClient raw = origin!.createHttpClient(context)
        ..findProxy = _findProxy;
      return ArgosHttpClient(raw);
    }
    HttpOverrides.global = null;
    final HttpClient raw = HttpClient(context: context)..findProxy = _findProxy;

    raw.badCertificateCallback =
        ((X509Certificate cert, String host, int port) => Platform.isAndroid);

    HttpOverrides.global = this;
    return ArgosHttpClient(raw);
  }

  String _findProxy(url) {
    try {
      final String? proxy = ArgosHttpMonitor.instance.proxyProvider?.call();
      return HttpClient.findProxyFromEnvironment(
        url,
        environment: proxy?.isNotEmpty ?? false
            ? {
                'http_proxy': proxy!,
                'https_proxy': proxy,
              }
            : {},
      );
    } catch (_) {
      return 'DIRECT';
    }
  }
}

void _dispatchHttpInfo(ArgosHttpInfo? info) {
  if (info == null || info.recorded) return;
  info.recorded = true;
  final ArgosManager manager = ArgosManager.instance;
  if (!manager.captureEnabled) return;
  if (manager.listener != null &&
      (manager.config?.hostWhiteList?.contains(info.uri?.host) ?? false)) {
    manager.listener!(info);
  }
  if (manager.captureEnabled) {
    ArgosPacketStorage.instance.append(
      info,
      maxRecords: manager.config?.maxPacketRecords ?? 200,
      resourceMaxRecords: manager.config?.resourceMaxRecords ?? 50,
      routeName: manager.currentRoute,
    );
  }
}

class ArgosHttpClient implements HttpClient {
  ArgosHttpClient(this.origin);

  final HttpClient origin;

  @override
  set autoUncompress(bool value) => origin.autoUncompress = value;

  @override
  bool get autoUncompress => origin.autoUncompress;

  @override
  set idleTimeout(Duration value) => origin.idleTimeout = value;

  @override
  Duration get idleTimeout => origin.idleTimeout;

  @override
  set connectionTimeout(Duration? value) => origin.connectionTimeout = value;

  @override
  Duration? get connectionTimeout => origin.connectionTimeout;

  @override
  set maxConnectionsPerHost(int? value) => origin.maxConnectionsPerHost = value;

  @override
  int? get maxConnectionsPerHost => origin.maxConnectionsPerHost;

  @override
  set userAgent(String? value) => origin.userAgent = value;

  @override
  String? get userAgent => origin.userAgent;

  @override
  void addCredentials(
      Uri url, String realm, HttpClientCredentials credentials) {
    origin.addCredentials(url, realm, credentials);
  }

  @override
  void addProxyCredentials(
      String host, int port, String realm, HttpClientCredentials credentials) {
    origin.addProxyCredentials(host, port, realm, credentials);
  }

  @override
  set authenticate(
      Future<bool> Function(Uri url, String scheme, String realm)? f) {
    origin.authenticate =
        f as Future<bool> Function(Uri url, String scheme, String? realm);
  }

  @override
  set authenticateProxy(
      Future<bool> Function(String host, int port, String scheme, String realm)?
          f) {
    origin.authenticateProxy = f as Future<bool> Function(
        String host, int port, String scheme, String? realm);
  }

  @override
  set badCertificateCallback(
      bool Function(X509Certificate cert, String host, int port)? callback) {
    origin.badCertificateCallback = callback;
  }

  @override
  void close({bool force = false}) {
    origin.close(force: force);
  }

  @override
  set findProxy(String Function(Uri url)? f) {
    origin.findProxy = f;
  }

  // 方法用来监控请求
  // 注意：每次请求必须新建 ArgosHttpInfo。此前用实例字段 + `??=` 的写法会导致
  // 同一个 HttpClient 实例（例如 Dio 的 IOHttpClientAdapter 会缓存并复用 client）
  // 下所有请求共用同一个 ArgosHttpInfo，从而被 `_dispatchHttpInfo` 的 recorded
  // 标记吞掉，只有首个请求能被记录。
  Future<HttpClientRequest> monitor(Future<HttpClientRequest> future) async {
    ArgosHttpInfo? httpInfo;
    try {
      final HttpClientRequest request = await future;
      httpInfo = ArgosHttpInfo(request.uri, request.method);
      return ArgosHttpClientRequest(request, httpInfo);
    } catch (error) {
      httpInfo = ArgosHttpInfo(Uri(), 'UNKNOWN');
      httpInfo.error = error.toString();
      httpInfo.response.updateError();
      _dispatchHttpInfo(httpInfo);
      rethrow;
    }
  }

  void addRequestBody(HttpClientRequest request) {
    if (request.method.toUpperCase() != 'GET') {}
  }

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) {
    return monitor(origin.delete(host, port, path));
  }

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) {
    return monitor(origin.deleteUrl(url));
  }

  @override
  Future<HttpClientRequest> get(String host, int port, String path) {
    return monitor(origin.get(host, port, path));
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    return monitor(origin.getUrl(url));
  }

  @override
  Future<HttpClientRequest> head(String host, int port, String path) {
    return monitor(origin.head(host, port, path));
  }

  @override
  Future<HttpClientRequest> headUrl(Uri url) {
    return monitor(origin.headUrl(url));
  }

  @override
  Future<HttpClientRequest> open(
      String method, String host, int port, String path) {
    return monitor(origin.open(method, host, port, path));
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) {
    return monitor(origin.openUrl(method, url));
  }

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) {
    return monitor(origin.patch(host, port, path));
  }

  @override
  Future<HttpClientRequest> patchUrl(Uri url) {
    return monitor(origin.patchUrl(url));
  }

  @override
  Future<HttpClientRequest> post(String host, int port, String path) {
    return monitor(origin.post(host, port, path));
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) {
    return monitor(origin.postUrl(url));
  }

  @override
  Future<HttpClientRequest> put(String host, int port, String path) {
    return monitor(origin.put(host, port, path));
  }

  @override
  Future<HttpClientRequest> putUrl(Uri url) {
    return monitor(origin.postUrl(url));
  }

  @override
  set connectionFactory(
      Future<ConnectionTask<Socket>> Function(
              Uri url, String? proxyHost, int? proxyPort)?
          f) {}

  @override
  set keyLog(Function(String line)? callback) {
    // TODO: implement keyLog
  }
}

class ArgosHttpClientRequest implements HttpClientRequest {
  ArgosHttpClientRequest(this.origin, this.httpInfo);

  final HttpClientRequest origin;
  final ArgosHttpInfo? httpInfo;

  @override
  bool get bufferOutput => origin.bufferOutput;

  @override
  set bufferOutput(bool value) => origin.bufferOutput = value;

  @override
  int get contentLength => origin.contentLength;

  @override
  set contentLength(int value) => origin.contentLength = value;

  @override
  Encoding get encoding => origin.encoding;

  @override
  set encoding(Encoding value) => origin.encoding = value;

  @override
  bool get followRedirects => origin.followRedirects;

  @override
  set followRedirects(bool value) => origin.followRedirects = value;

  @override
  int get maxRedirects => origin.maxRedirects;

  @override
  set maxRedirects(int value) => origin.maxRedirects = value;

  @override
  set persistentConnection(bool value) => origin.persistentConnection = value;

  @override
  bool get persistentConnection => origin.persistentConnection;

  @override
  HttpHeaders get headers => origin.headers;

  @override
  String get method => origin.method;

  @override
  Uri get uri => origin.uri;

  @override
  HttpConnectionInfo? get connectionInfo => origin.connectionInfo;

  @override
  List<Cookie> get cookies => origin.cookies;

  @override
  Future<HttpClientResponse> get done => origin.done;

  @override
  void write(Object? obj) {
    origin.write(obj);
    httpInfo?.request.add('$obj');
  }

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) {
    origin.writeAll(objects, separator);
    httpInfo?.request.add(objects.map((e) => '$e').join(separator));
  }

  @override
  void writeCharCode(int charCode) {
    origin.writeCharCode(charCode);
    httpInfo?.request.add(String.fromCharCode(charCode));
  }

  @override
  void writeln([dynamic obj = '']) {
    origin.writeln(obj);
    httpInfo?.request.add('$obj\n');
  }

  @override
  void add(List<int> data) {
    origin.add(data);
    recordParameter(data);
  }

  void recordParameter(List<int> data) {
    try {
      httpInfo?.request.header = headers;
      httpInfo?.request.add(encoding.decode(data));
    } catch (_) {
      // Ignore undecodable fragments and keep the request monitor non-fatal.
    }
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    origin.addError(error, stackTrace);
  }

  @override
  Future<dynamic> addStream(Stream<List<int>> stream) {
    stream = stream.asBroadcastStream();
    stream.listen((List<int> event) {
      recordParameter(event);
    });
    return origin.addStream(stream);
  }

  @override
  Future<HttpClientResponse> close() {
    httpInfo?.request.header = headers;
    return monitor(origin.close());
  }

  Future<HttpClientResponse> monitor(Future<HttpClientResponse> future) async {
    final HttpClientResponse response = await future;

    return ArgosHttpClientResponse(response, recordResponse);
  }

  void recordResponse(int code, String result, HttpHeaders header, int size) {
    httpInfo?.response.update(code, result, header, size);
    _dispatchHttpInfo(httpInfo);
  }

  @override
  Future<dynamic> flush() {
    return origin.flush();
  }

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {
    return origin.abort(exception, stackTrace);
  }
}

extension HttpClientRequestExt on HttpClientRequest {
  void abort([Object? exception, StackTrace? stackTrace]) {
    this.abort(exception, stackTrace);
  }
}

class ArgosHttpClientResponse implements HttpClientResponse {
  ArgosHttpClientResponse(this.origin, this.recordResponse);

  final HttpClientResponse origin;
  final Function(int, String, HttpHeaders, int) recordResponse;

  @override
  Future<bool> any(bool Function(List<int> element) test) {
    return origin.any(test);
  }

  @override
  Stream<List<int>> asBroadcastStream(
      {void Function(StreamSubscription<List<int>> subscription)? onListen,
      void Function(StreamSubscription<List<int>> subscription)? onCancel}) {
    return _recordingStream()
        .asBroadcastStream(onListen: onListen, onCancel: onCancel);
  }

  @override
  Stream<E> asyncExpand<E>(Stream<E>? Function(List<int> event) convert) {
    return _recordingStream().asyncExpand(convert);
  }

  @override
  Stream<E> asyncMap<E>(FutureOr<E> Function(List<int> event) convert) {
    return _recordingStream().asyncMap(convert);
  }

  @override
  Stream<R> cast<R>() {
    return _recordingStream().cast<R>();
  }

  @override
  X509Certificate? get certificate => origin.certificate;

  @override
  HttpClientResponseCompressionState get compressionState =>
      origin.compressionState;

  @override
  HttpConnectionInfo? get connectionInfo => origin.connectionInfo;

  @override
  Future<bool> contains(dynamic needle) {
    return origin.contains(needle);
  }

  @override
  int get contentLength => origin.contentLength;

  @override
  List<Cookie> get cookies => origin.cookies;

  @override
  Future<Socket> detachSocket() {
    return origin.detachSocket();
  }

  @override
  Stream<List<int>> distinct(
      [bool Function(List<int> previous, List<int> next)? equals]) {
    return origin.distinct(equals);
  }

  @override
  Future<E> drain<E>([E? futureValue]) {
    return origin.drain(futureValue);
  }

  @override
  Future<List<int>> elementAt(int index) {
    return elementAt(index);
  }

  @override
  Future<bool> every(bool Function(List<int> element) test) {
    return origin.every(test);
  }

  @override
  Stream<S> expand<S>(Iterable<S> Function(List<int> element) convert) {
    return _recordingStream().expand(convert);
  }

  @override
  Future<List<int>> get first => origin.first;

  @override
  Future<List<int>> firstWhere(bool Function(List<int> element) test,
      {List<int> Function()? orElse}) {
    return origin.firstWhere(test, orElse: orElse);
  }

  @override
  Future<S> fold<S>(
      S initialValue, S Function(S previous, List<int> element) combine) {
    return origin.fold(initialValue, combine);
  }

  @override
  Future<dynamic> forEach(void Function(List<int> element) action) {
    return origin.forEach(action);
  }

  @override
  Stream<List<int>> handleError(Function onError,
      {bool Function(dynamic error)? test}) {
    return origin.handleError(onError, test: test);
  }

  @override
  HttpHeaders get headers => origin.headers;

  @override
  bool get isBroadcast => origin.isBroadcast;

  @override
  Future<bool> get isEmpty => origin.isEmpty;

  @override
  bool get isRedirect => origin.isRedirect;

  @override
  Future<String> join([String separator = '']) {
    return origin.join(separator);
  }

  @override
  Future<List<int>> get last => origin.last;

  @override
  Future<List<int>> lastWhere(bool Function(List<int> element) test,
      {List<int> Function()? orElse}) {
    return origin.lastWhere(test, orElse: orElse);
  }

  @override
  Future<int> get length => origin.length;

  bool isTextResponse() {
    return headers['content-type'] != null &&
        (headers['content-type'].toString().contains('json') ||
            headers['content-type'].toString().contains('text') ||
            headers['content-type'].toString().contains('xml'));
  }

  Encoding? getEncoding() {
    String charset;
    if (headers.contentType != null && headers.contentType?.charset != null) {
      charset = headers.contentType!.charset!;
    } else {
      charset = 'utf-8';
    }
    return Encoding.getByName(charset);
  }

  // 返回一个会在数据流过时累积 bytes、结束时调用 recordResponse 的 stream。
  // Dio 走 cast()/transform() 等路径时不会触发 listen 覆盖逻辑，需要统一从这里
  // 拿包装 stream 来保证抓包记录。
  Stream<List<int>> _recordingStream() {
    if (!isTextResponse()) {
      recordResponse(statusCode, '', headers, contentLength);
      return origin;
    }
    final chunks = <List<int>>[];
    final controller = StreamController<List<int>>();
    StreamSubscription<List<int>>? subscription;
    controller.onListen = () {
      subscription = origin.listen(
        (data) {
          chunks.add(data);
          controller.add(data);
        },
        onError: controller.addError,
        onDone: () {
          try {
            final encoding = getEncoding();
            final allBytes = chunks.expand((c) => c).toList();
            final actualSize =
                contentLength >= 0 ? contentLength : allBytes.length;
            if (encoding != null) {
              recordResponse(
                  statusCode, encoding.decode(allBytes), headers, actualSize);
            } else {
              recordResponse(statusCode, '返回结果解析失败', headers, actualSize);
            }
          } catch (_) {
            recordResponse(statusCode, '返回结果解析失败', headers, contentLength);
          }
          controller.close();
        },
        cancelOnError: false,
      );
    };
    controller.onPause = () => subscription?.pause();
    controller.onResume = () => subscription?.resume();
    controller.onCancel = () => subscription?.cancel();
    return controller.stream;
  }

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    if (!isTextResponse()) {
      recordResponse(statusCode, '', headers, contentLength);
      return origin.listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
    }
    final chunks = <List<int>>[];
    void onDataWrapper(List<int> result) {
      onData?.call(result);
      chunks.add(result);
    }

    void onDoneWrapper() {
      try {
        final encoding = getEncoding();
        if (encoding != null) {
          final allBytes = chunks.expand((c) => c).toList();
          final actualSize =
              contentLength >= 0 ? contentLength : allBytes.length;
          recordResponse(
              statusCode, encoding.decode(allBytes), headers, actualSize);
        } else {
          recordResponse(statusCode, '返回结果解析失败', headers, contentLength);
        }
      } catch (e) {
        recordResponse(statusCode, '返回结果解析失败', headers, contentLength);
      }
      onDone?.call();
    }

    return origin.listen(onDataWrapper,
        onError: onError, onDone: onDoneWrapper, cancelOnError: cancelOnError);
  }

  @override
  Stream<S> map<S>(S Function(List<int> event) convert) {
    return _recordingStream().map(convert);
  }

  @override
  bool get persistentConnection => origin.persistentConnection;

  @override
  Future<dynamic> pipe(StreamConsumer<List<int>> streamConsumer) {
    return _recordingStream().pipe(streamConsumer);
  }

  @override
  String get reasonPhrase => origin.reasonPhrase;

  @override
  Future<HttpClientResponse> redirect(
      [String? method, Uri? url, bool? followLoops]) {
    return origin.redirect(method, url, followLoops);
  }

  @override
  List<RedirectInfo> get redirects => origin.redirects;

  @override
  Future<List<int>> reduce(
      List<int> Function(List<int> previous, List<int> element) combine) {
    return origin.reduce(combine);
  }

  @override
  Future<List<int>> get single => origin.single;

  @override
  Future<List<int>> singleWhere(bool Function(List<int> element) test,
      {List<int> Function()? orElse}) {
    return origin.singleWhere(test, orElse: orElse);
  }

  @override
  Stream<List<int>> skip(int count) {
    return origin.skip(count);
  }

  @override
  Stream<List<int>> skipWhile(bool Function(List<int> element) test) {
    return origin.skipWhile(test);
  }

  @override
  int get statusCode => origin.statusCode;

  @override
  Stream<List<int>> take(int count) {
    return origin.take(count);
  }

  @override
  Stream<List<int>> takeWhile(bool Function(List<int> element) test) {
    return origin.takeWhile(test);
  }

  @override
  Stream<List<int>> timeout(Duration timeLimit,
      {void Function(EventSink<List<int>> sink)? onTimeout}) {
    return origin.timeout(timeLimit, onTimeout: onTimeout);
  }

  @override
  Future<List<List<int>>> toList() {
    return _recordingStream().toList();
  }

  @override
  Future<Set<List<int>>> toSet() {
    return origin.toSet();
  }

  @override
  Stream<S> transform<S>(StreamTransformer<List<int>, S> streamTransformer) {
    Stream<S> s = origin.transform<S>(streamTransformer);
    if (!isTextResponse()) {
      recordResponse(statusCode, '', headers, contentLength);
      return s;
    }
    s = s.asBroadcastStream();
    final stringChunks = <String>[];
    final byteChunks = <List<int>>[];
    s.listen((S event) {
      if (event is Uint8List) {
        byteChunks.add(event);
      } else if (event is String) {
        stringChunks.add(event);
      }
    }, onDone: () {
      if (stringChunks.isNotEmpty) {
        final joined = stringChunks.join();
        final actualSize =
            contentLength >= 0 ? contentLength : utf8.encode(joined).length;
        recordResponse(statusCode, joined, headers, actualSize);
      } else if (byteChunks.isNotEmpty) {
        final allBytes = byteChunks.expand((c) => c).toList();
        final actualSize = contentLength >= 0 ? contentLength : allBytes.length;
        var encoding = getEncoding();
        if (encoding != null) {
          String decodeResult = '';
          switch (encoding.runtimeType) {
            case Utf8Codec:
              decodeResult = utf8.decode(allBytes, allowMalformed: true);
              break;
            case Latin1Decoder:
              decodeResult = latin1.decode(allBytes, allowInvalid: true);
              break;
            case AsciiDecoder:
              decodeResult = ascii.decode(allBytes, allowInvalid: true);
              break;
            default:
              decodeResult = encoding.decode(allBytes);
          }
          recordResponse(statusCode, decodeResult, headers, actualSize);
        } else {
          recordResponse(statusCode, '返回结果解析失败', headers, actualSize);
        }
      } else {
        recordResponse(statusCode, '', headers, 0);
      }
    });
    return s;
  }

  @override
  Stream<List<int>> where(bool Function(List<int> event) test) {
    return origin.where(test);
  }
}
