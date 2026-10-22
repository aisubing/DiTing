import 'dart:io';

import 'package:diting/data/recognition/recognition_members.dart';
import 'package:flutter_test/flutter_test.dart';

/// 名单解析的守门测试。
///
/// 这份 JSON 由维护者手工推到 GitHub，写错的可能性集中在三处：名字重复、
/// 头像文件名不合规、数组/根字段缺失。解析器必须把这些判成「整份不可用」，
/// 否则页面会渲染半份坏名单（或一个空头像的洞）。
void main() {
  group('parseRecognitionMembers', () {
    test('解析合法配置并保持数组顺序', () {
      final members = parseRecognitionMembers('''
{
  "version": 3,
  "sponsors": [
    {"name": "alone", "avatarFileName": "alone_avatar.jpg"},
    {"name": "轻"}
  ],
  "coBuilders": [
    {"name": "AceTaffy1883", "avatarFileName": "acetaffy1883_avatar.jpg"}
  ]
}
''');
      expect(members.version, 3);
      expect(members.sponsors.map((m) => m.name), ['alone', '轻']);
      expect(members.sponsors.first.avatarFileName, 'alone_avatar.jpg');
      expect(members.sponsors.last.avatarFileName, isNull);
      expect(members.coBuilders.single.name, 'AceTaffy1883');
    });

    test('缺版本号 / 缺数组都视为配置无效', () {
      expect(
        () => parseRecognitionMembers('{"sponsors":[],"coBuilders":[]}'),
        throwsFormatException,
      );
      expect(
        () => parseRecognitionMembers('{"version":1,"sponsors":[]}'),
        throwsFormatException,
      );
    });

    test('空名称与重复名称被拒绝', () {
      expect(
        () => parseRecognitionMembers(
          '{"version":1,"sponsors":[{"name":"   "}],"coBuilders":[]}',
        ),
        throwsFormatException,
      );
      expect(
        () => parseRecognitionMembers(
          '{"version":1,"sponsors":[{"name":"a"},{"name":"a"}],"coBuilders":[]}',
        ),
        throwsFormatException,
      );
    });

    test('非法或重复的头像文件名被拒绝', () {
      expect(
        () => parseRecognitionMembers(
          '{"version":1,"sponsors":[{"name":"a","avatarFileName":"A.png"}],'
          '"coBuilders":[]}',
        ),
        throwsFormatException,
      );
      expect(
        () => parseRecognitionMembers(
          '{"version":1,"sponsors":[{"name":"a","avatarFileName":"x_avatar.jpg"},'
          '{"name":"b","avatarFileName":"x_avatar.jpg"}],"coBuilders":[]}',
        ),
        throwsFormatException,
      );
    });

    test('仓库根目录的那份名单可以被解析', () {
      // 打包不内置名单，但仓库根目录这份就是要推到 GitHub 的原始文件：
      // 解析不过说明发出去的配置会让所有客户端降级，属于发布前必须挡住的错。
      final raw = File(
        '../recognition_members.json',
      ).readAsStringSync();
      final members = parseRecognitionMembers(raw);
      expect(members.sponsors.length, greaterThan(5));
      expect(members.coBuilders.length, greaterThan(5));
      expect(members.sponsors.every((m) => m.name.isNotEmpty), isTrue);
    });
  });
}
