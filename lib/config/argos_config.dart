import 'package:argos/storage/argos_storage_adapter.dart';

enum ArgosCapability {
  network,
  fps,
}

class ArgosConfig {
  final List<String>? hostWhiteList;

  final List<ArgosCapability>? apmTypes;

  final bool enableStorage;

  final int maxPacketRecords;

  final String? Function()? proxyProvider;

  final ArgosStorageAdapter? storageAdapter;

  ArgosConfig({
    this.hostWhiteList,
    this.apmTypes,
    this.enableStorage = false,
    this.maxPacketRecords = 200,
    this.proxyProvider,
    this.storageAdapter,
  });
}
