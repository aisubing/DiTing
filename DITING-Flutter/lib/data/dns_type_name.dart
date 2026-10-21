/// DNS 记录类型数字 → 展示名（旧版 `dnsTypeName` 逐字照抄，含 `TYPE$n` 兜底）。
///
/// 放在 `data/` 而不是 `pages/logs/logs_shared.dart`：仪表盘概览的聚合层也要把
/// `dns_cache.queryType` 转成 `A` / `AAAA`，让页面层提供这个函数会逼着 state 层
/// 反向 import 页面，两处各写一份则必然出现「缓存页写 A、概览块写 TYPE1」。
library;

String dnsTypeName(int type) => switch (type) {
  1 => 'A',
  28 => 'AAAA',
  5 => 'CNAME',
  15 => 'MX',
  16 => 'TXT',
  2 => 'NS',
  12 => 'PTR',
  255 => 'ANY',
  _ => 'TYPE$type',
};
