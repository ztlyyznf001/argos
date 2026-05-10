import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:argos/storage/argos_packet_storage.dart';

class ListExamplePage extends StatefulWidget {
  const ListExamplePage({Key? key}) : super(key: key);

  @override
  State<ListExamplePage> createState() => _ListExamplePageState();
}

class _ListExamplePageState extends State<ListExamplePage> {
  String _responseBody = '(no requests yet)';

  Future<void> _concurrentBurst({int count = 50}) async {
    setState(() => _responseBody = 'firing $count concurrent requests...');
    final before = (await ArgosPacketStorage.instance.getAllAsync()).length;
    final sw = Stopwatch()..start();

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    final futures = List.generate(count, (i) async {
      try {
        final resp = await dio.get<String>(
          'https://httpbin.org/uuid',
          queryParameters: {'i': i},
          options: Options(responseType: ResponseType.plain),
        );
        return resp.statusCode ?? -1;
      } catch (_) {
        return -1;
      }
    });
    final results = await Future.wait(futures);
    sw.stop();

    // Writes are fire-and-forget through the serialized chain; give it a
    // moment to drain before reading back.
    await Future.delayed(const Duration(milliseconds: 300));

    final after = await ArgosPacketStorage.instance.getAllAsync();
    final okHttp = results.where((c) => c == 200).length;
    final newlyStored = after.length - before;

    setState(() => _responseBody = '''Concurrent test complete
Elapsed: ${sw.elapsedMilliseconds} ms
HTTP 200: $okHttp / $count
Stored records: $before → ${after.length}  (+$newlyStored)
Expected +$count (or trimmed by maxPacketRecords)

First 5 records:
${after.take(5).map((r) => '${r.method} ${r.uri}').join('\n')}''');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Concurrent burst example'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            tooltip: 'Fire 50 concurrent requests',
            onPressed: () => _concurrentBurst(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Text(_responseBody),
      ),
    );
  }
}
