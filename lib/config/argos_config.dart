import 'package:argos_inspector/model/argos_diagnostic_session.dart';
import 'package:argos_inspector/storage/argos_storage_adapter.dart';

enum ArgosCapability {
  network,
  fps,
  crash,
  jank,
  resource,
}

class ArgosConfig {
  final List<String>? hostWhiteList;

  final List<ArgosCapability>? apmTypes;

  final bool enableStorage;

  /// Automatic mode starts on first init only when storage is enabled.
  final ArgosSessionMode sessionMode;

  /// Controls whether an automatically created session spans the process or
  /// rolls at configured adaptive boundaries.
  final ArgosAutomaticSessionPolicy automaticSessionPolicy;

  /// Maximum number of persisted diagnostic sessions.
  final int maxSessions;

  /// Retention cap applied to each non-resource kind (network / crash / jank)
  /// independently. Note: this is now a per-kind cap, not a total across all
  /// records — resource samples are bounded separately by [resourceMaxRecords]
  /// so a fast sampler can never evict a captured crash.
  final int maxPacketRecords;

  /// Retention cap for `resource` records specifically. Kept small because the
  /// resource monitor persists a sample every [resourceSampleInterval]; a
  /// tighter cap stops routine memory samples from crowding storage while still
  /// leaving a rolling window to read a trend from.
  final int resourceMaxRecords;

  final String? Function()? proxyProvider;

  final ArgosStorageAdapter? storageAdapter;

  /// Jank detection: a frame whose total span exceeds
  /// `frameBudget * jankThresholdMultiplier` is treated as a dropped frame.
  /// Defaults to 1.0 (one frame budget).
  final double jankThresholdMultiplier;

  /// Resource monitor sampling period. Defaults to 2 seconds.
  final Duration resourceSampleInterval;

  /// How long the storage layer coalesces writes before flushing to disk.
  /// Coalescing keeps the synchronous `jsonEncode` off the per-write hot path;
  /// the cost is a bounded crash-loss window (records written since the last
  /// flush or backgrounding). `Duration.zero` disables coalescing — every write
  /// persists immediately, no window. Defaults to 5 seconds.
  final Duration storagePersistInterval;

  ArgosConfig({
    this.hostWhiteList,
    this.apmTypes,
    this.enableStorage = false,
    this.sessionMode = ArgosSessionMode.automatic,
    this.automaticSessionPolicy = const ArgosAutomaticSessionPolicy.process(),
    this.maxSessions = 5,
    this.maxPacketRecords = 200,
    this.resourceMaxRecords = 50,
    this.proxyProvider,
    this.storageAdapter,
    this.jankThresholdMultiplier = 1.0,
    this.resourceSampleInterval = const Duration(seconds: 2),
    this.storagePersistInterval = const Duration(seconds: 5),
  })  : assert(maxSessions > 0),
        assert(maxPacketRecords > 0),
        assert(resourceMaxRecords > 0),
        assert(jankThresholdMultiplier > 0),
        assert(!resourceSampleInterval.isNegative),
        assert(!storagePersistInterval.isNegative);
}
