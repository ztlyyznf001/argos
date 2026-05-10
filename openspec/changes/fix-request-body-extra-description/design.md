## Context

`ArgosHttpClientRequest` captures request body by overriding `add(List<int> data)` and calling `recordParameter(data)`. However, `HttpClientRequest` also exposes `write(Object?)`, `writeln([dynamic])`, `writeAll(Iterable, [String])`, and `writeCharCode(int)` from `IOSink`. All four of these are currently overridden to delegate to `origin` only — body written through any of them is silently ignored by the monitor.

When a caller uses `write(body)` (the most common pattern for string bodies in Dart) the captured `requestBody` remains empty or incomplete. If any part of the body happens to land in `parameters` via a direct `add()` call (e.g., from an underlying library), that fragment shows up in the UI/clipboard as an isolated artifact — manifesting as the reported "extra description" at the end.

## Goals / Non-Goals

**Goals:**
- Capture request body regardless of whether it arrives via `add()`, `write()`, `writeln()`, `writeAll()`, or `writeCharCode()`
- Keep the fix minimal and self-contained within `ArgosHttpClientRequest`

**Non-Goals:**
- Changing the capture strategy for response body (separate concern)
- Addressing chunked/streaming request bodies beyond current `addStream()` handling

## Decisions

### 决策：在各 write 方法中直接追加字符串到 `httpInfo.request`

Each write method already has access to `httpInfo`. The simplest fix is to call `httpInfo?.request.add(string)` inline, parallel to the `origin.*` call:

```dart
@override
void write(Object? obj) {
  origin.write(obj);
  httpInfo?.request.add('$obj');
}

@override
void writeln([dynamic obj = '']) {
  origin.writeln(obj);
  httpInfo?.request.add('$obj\n');
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
```

**Alternative considered**: Remove the `write`/`writeln`/`writeAll`/`writeCharCode` overrides entirely and let `IOSink`'s default implementation call `this.add()`. Rejected because `ArgosHttpClientRequest` uses `implements` (not `extends`), so there is no default IOSink implementation to inherit.

**Alternative considered**: Buffer all body data into a `BytesBuilder` and flush at `close()`. Adds complexity and delays capture unnecessarily; not needed.

## Risks / Trade-offs

- **Risk**: `write(obj)` captures `obj.toString()` while `origin.write(obj)` uses the same `'$obj'` conversion — these are equivalent, so no divergence.
- **Risk**: `writeln` appends `\n`; this matches what the origin sends, keeping the captured body consistent with the actual transmitted bytes.
- **Trade-off**: We append strings directly to `parameters` rather than bytes; this is consistent with the existing `recordParameter()` path which also decodes bytes to strings before appending.

## Migration Plan

No data migration required. The change affects only in-memory capture; persisted records from before the fix will simply lack the previously-missed body fragments.
