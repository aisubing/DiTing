/// 本进程的内存快照。
///
/// 字段口径写在名字里，因为这里最容易混：
/// - [totalPss]：整进程的 **PSS**（比例分摊后的实际物理占用），用来和整机内存
///   比，得到「这个 App 占了多少」；
/// - [javaHeap] / [nativeHeap]：**堆分配量**（`Runtime` 已用堆、
///   `Debug.getNativeHeapAllocatedSize`），回答「堆里放了什么」。
///
/// 两者不是同一个量：PSS 含映射页与共享库，堆分配只算分配器给出的字节，所以
/// 堆分配之和不会等于 PSS。卡片上因此分两处展示，不把后者当成分段拼进前者。
/// 早先版本试图用 `summary.java-heap` / `summary.native-heap` 做 PSS 分段，
/// 但在 Android 14 模拟器上这两项恒为 0（`dumpsys meminfo` 同样报 0，堆占用
/// 全落在 `Unknown` 里），照读会得到「总占用 339MB、Java 堆 0B」的自相矛盾。
library;

class ProcessMemory {
  const ProcessMemory({
    this.totalPss = 0,
    this.javaHeap = 0,
    this.nativeHeap = 0,
    this.systemTotal = 0,
    this.systemAvail = 0,
    this.available = false,
  });

  /// 进程 PSS，字节。
  final int totalPss;

  /// Java 堆已用，字节。
  final int javaHeap;

  /// 原生堆已分配，字节。
  final int nativeHeap;

  /// 整机内存总量，字节。
  final int systemTotal;

  /// 整机可用内存，字节。
  final int systemAvail;

  /// 通道是否给出了可用的 PSS；false 时卡片显示破折号而不是 0。
  final bool available;

  /// 进程占用占整机内存的比例，用于进度条。
  double get systemShare => available && systemTotal > 0
      ? (totalPss / systemTotal).clamp(0.0, 1.0)
      : 0;

  /// 原生通道把 KB 作为整数传上来；这里统一换成字节。
  static ProcessMemory fromMap(Object? raw) {
    if (raw is! Map) return const ProcessMemory();
    int kb(String key) => ((raw[key] as num?)?.toInt() ?? 0) * 1024;
    return ProcessMemory(
      totalPss: kb('totalPss'),
      javaHeap: kb('javaHeap'),
      nativeHeap: kb('nativeHeap'),
      systemTotal: kb('systemTotal'),
      systemAvail: kb('systemAvail'),
      available: raw['available'] == true,
    );
  }
}
