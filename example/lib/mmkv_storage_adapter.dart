import 'package:argos_inspector/argos_inspector.dart';
import 'package:mmkv/mmkv.dart';

class MmkvStorageAdapter implements ArgosStorageAdapter {
  MmkvStorageAdapter({String mmapID = 'argos'}) : _mmkv = MMKV(mmapID);

  final MMKV _mmkv;

  @override
  Future<String?> read(String key) async => _mmkv.decodeString(key);

  @override
  Future<void> write(String key, String value) async {
    _mmkv.encodeString(key, value);
  }

  @override
  Future<void> clear(String key) async {
    _mmkv.removeValue(key);
  }
}
