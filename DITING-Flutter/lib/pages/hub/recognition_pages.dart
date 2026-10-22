/// 赞助者名单 / 共建者名单（上游 `SponsorListScreen` / `CoBuilderListScreen`）。
///
/// 两页共用 [RecognitionListPage]：数据来自云端 `recognition_members.json`，
/// 头像是真实图片（内置资源优先，云端新增的联网取，失败退回默认头像）。
/// 上一轮这里是写死的名字列表 + 用昵称首字拼的彩色字母圆——头像从来不是图片，
/// 名单也和服务器无关。
library;

import 'package:diting/pages/hub/recognition_common.dart';
import 'package:material_ui/material_ui.dart';

/// 赞助者名单。
class SponsorListPage extends StatelessWidget {
  const SponsorListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return RecognitionListPage(
      title: '赞助者名单',
      intro:
          '感谢每一位支持谛听项目的朋友！名单默认按赞助时间由早到晚排列，'
          '可通过右上角按钮切换为由晚到早；与赞助金额无关，每一份支持都同样珍贵。',
      sectionTitle: '赞助者',
      select: (members) => members.sponsors,
      sortable: true,
    );
  }
}

/// 共建者名单。
class CoBuildersPage extends StatelessWidget {
  const CoBuildersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return RecognitionListPage(
      title: '共建者名单',
      intro:
          '感谢每一位为谛听提出建议、帮助测试的共建者！名单按用户名称的字母顺序排列，'
          '中文名称按拼音排序。',
      sectionTitle: '共建者',
      select: (members) => members.coBuilders,
    );
  }
}
