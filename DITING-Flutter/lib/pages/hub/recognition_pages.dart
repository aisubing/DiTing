/// Sponsor and co-builder lists (upstream `SponsorListScreen`), from remote JSON.
library;

import 'package:diting/pages/hub/recognition_common.dart';
import 'package:material_ui/material_ui.dart';

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
