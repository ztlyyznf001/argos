## 1. 修复 ArgosHttpClientRequest write 系列方法

- [x] 1.1 在 `write(Object? obj)` 中追加 `httpInfo?.request.add('$obj')`
- [x] 1.2 在 `writeln([dynamic obj])` 中追加 `httpInfo?.request.add('$obj\n')`
- [x] 1.3 在 `writeAll(Iterable, [String separator])` 中追加 `httpInfo?.request.add(objects.map((e) => '$e').join(separator))`
- [x] 1.4 在 `writeCharCode(int charCode)` 中追加 `httpInfo?.request.add(String.fromCharCode(charCode))`
- [x] 1.5 在 `close()` 中同步 `httpInfo?.request.header = headers`，确保无 body 请求也能记录完整请求头

## 2. 验证

- [x] 2.1 运行 `dart analyze lib/apm/argos_http_monitor.dart` 无新增错误
