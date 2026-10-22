/// 赞助者 / 共建者名单的数据模型与校验。
///
/// 数据来源是仓库根目录的 `recognition_members.json`（云端下发，改完推到
/// GitHub `main` 即生效，见 `docs/development/recognition-members.md`）。
/// 这里只做两件事：把 JSON 解析成强类型列表，并按文档里的约束校验——
/// 名字非空、同一数组内不重复、头像文件名符合 `^[a-z0-9_]+_avatar\.jpg$`。
///
/// 校验失败一律抛 [FormatException]：调用方据此判定「这份配置不可用」，
/// 保留上一次成功的缓存，而不是把半份坏名单渲染给用户。
library;

import 'dart:convert';

/// 云端名单配置地址（与旧版 `RecognitionMembersRepository` 一致）。
const recognitionMembersUrl =
    'https://raw.githubusercontent.com/haoze-evolluling/DITING/main/'
    'recognition_members.json';

/// 头像资源根地址。
const recognitionAvatarBaseUrl =
    'https://raw.githubusercontent.com/haoze-evolluling/DITING/main/avatars/';

/// 头像文件名必须以 `<小写字母/数字/下划线>_avatar.jpg` 结尾。
final _avatarFileNamePattern = RegExp(r'^[a-z0-9_]+_avatar\.jpg$');

/// 名单里的一位成员。
class RecognitionMember {
  const RecognitionMember({required this.name, this.avatarFileName});

  final String name;

  /// 自定义头像文件名；缺省表示这位成员没有头像，界面画默认人形占位。
  final String? avatarFileName;
}

/// 一份完整名单。
class RecognitionMembers {
  const RecognitionMembers({
    required this.version,
    required this.sponsors,
    required this.coBuilders,
  });

  /// 配置版本号；每次更新名单建议递增（仅用于展示/排查）。
  final int version;

  /// 赞助者，顺序即 JSON 数组顺序（按赞助时间由早到晚）。
  final List<RecognitionMember> sponsors;

  /// 共建者，顺序即 JSON 数组顺序（按昵称字母/拼音排序）。
  final List<RecognitionMember> coBuilders;

  static const empty = RecognitionMembers(
    version: 0,
    sponsors: [],
    coBuilders: [],
  );
}

/// 解析并校验一份名单 JSON。
///
/// 抛 [FormatException] 的三种情况：根结构不对、必需字段缺失/类型不符、
/// 违反唯一性或头像命名规范。
RecognitionMembers parseRecognitionMembers(String raw) {
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException catch (error) {
    throw FormatException('名单配置不是合法 JSON：${error.message}');
  }
  if (decoded is! Map) {
    throw const FormatException('名单配置根节点必须是对象');
  }
  final version = decoded['version'];
  if (version is! int) {
    throw const FormatException('名单配置缺少版本号');
  }
  return RecognitionMembers(
    version: version,
    sponsors: _parseMembers(decoded['sponsors'], 'sponsors'),
    coBuilders: _parseMembers(decoded['coBuilders'], 'coBuilders'),
  );
}

List<RecognitionMember> _parseMembers(Object? raw, String field) {
  if (raw is! List) {
    throw FormatException('名单配置缺少 $field 数组');
  }
  final members = <RecognitionMember>[];
  final names = <String>{};
  final avatarFileNames = <String>{};
  for (final item in raw) {
    if (item is! Map) {
      throw FormatException('$field 中存在非对象元素');
    }
    final name = item['name'];
    if (name is! String || name.trim().isEmpty) {
      throw FormatException('$field 中存在空的成员名称');
    }
    final trimmed = name.trim();
    if (!names.add(trimmed)) {
      throw FormatException('$field 中存在重复成员：$trimmed');
    }
    final rawAvatar = item['avatarFileName'];
    String? avatarFileName;
    if (rawAvatar != null && rawAvatar is! String) {
      throw FormatException('$field 中 $trimmed 的头像文件名类型错误');
    }
    if (rawAvatar is String && rawAvatar.trim().isNotEmpty) {
      final value = rawAvatar.trim();
      if (!_avatarFileNamePattern.hasMatch(value)) {
        throw FormatException('$field 中 $trimmed 的头像文件名无效：$value');
      }
      if (!avatarFileNames.add(value)) {
        throw FormatException('$field 中存在重复头像文件：$value');
      }
      avatarFileName = value;
    }
    members.add(RecognitionMember(name: trimmed, avatarFileName: avatarFileName));
  }
  return List.unmodifiable(members);
}
