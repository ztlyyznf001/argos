abstract class ArgosStorageAdapter {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> clear(String key);
}
