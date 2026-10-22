/// 1.4.3 `KeyObfuscator` 的等价实现：三组异或掩码 + 标准 Base64。
///
/// ## 为什么要照抄同一套算法
///
/// 旧版把厂商的 API Key 混淆后写进 `agent_ai_providers_json`。升级用户装上本仓后，
/// 那个 JSON 里躺着**旧版写的密文**：
/// - 只会 Dart 的 `base64` 解不出来，界面会显示「缺少密钥」，用户以为设置丢了；
/// - 反向也成立：本仓写明文，用户回退到 1.4.3 时那里解出来是乱码。
///
/// 所以这里逐字节照搬 `util/KeyObfuscator.kt`：三组 8 字节密钥、按索引循环异或、
/// UTF-8 编解码、带填充的标准 Base64 字母表。任何一处不同，两边就互不兼容。
///
/// 这**不是**加密：掩码就写在源码里。它的作用是不让密钥以明文出现在
/// `shared_prefs/*.xml` 里（旧版注释写明这是目的），此处如实沿用、不夸大。
library;

import 'dart:convert';

const _ka = [0x4D, 0x1A, 0xC8, 0x37, 0x62, 0x9E, 0xFB, 0x54];
const _kb = [0x29, 0x6C, 0xD3, 0x8E, 0x71, 0x05, 0xBA, 0x4F];
const _kc = [0xBE, 0x34, 0x65, 0x8A, 0x71, 0x22, 0xD9, 0x46];

/// 混淆一个明文 Key；空串原样返回（旧版对空串不做任何处理）。
String sealApiKey(String plain) {
  if (plain.trim().isEmpty) return '';
  final source = utf8.encode(plain);
  final mixed = List<int>.generate(source.length, (index) {
    return (source[index] ^
            _ka[index % _ka.length] ^
            _kb[index % _kb.length] ^
            _kc[index % _kc.length]) &
        0xFF;
  });
  return base64.encode(mixed);
}

/// 还原一个混淆过的 Key。
///
/// 解不开时返回**空串**而不是抛异常：旧版 `open()` 也是这个行为，调用方据此显示
/// 「缺少密钥」。抛异常会让整个厂商列表读不出来——一条坏数据连累整页。
String openApiKey(String sealed) {
  if (sealed.trim().isEmpty) return '';
  try {
    final mixed = base64.decode(sealed);
    final plain = List<int>.generate(mixed.length, (index) {
      return (mixed[index] ^
              _ka[index % _ka.length] ^
              _kb[index % _kb.length] ^
              _kc[index % _kc.length]) &
          0xFF;
    });
    return utf8.decode(plain);
  } on FormatException {
    // Base64 非法或不是合法 UTF-8 字节序列。
    return '';
  }
}
