/// Disclaimer text shown by the disclaimer page.
library;

class MockDisclaimerTerm {
  const MockDisclaimerTerm({required this.title, required this.content});

  final String title;
  final String content;
}

const mockDisclaimerTerms = <MockDisclaimerTerm>[
  MockDisclaimerTerm(
    title: '一、软件性质',
    content:
        '谛听是一款开源的本地域名解析与流量观测工具，不以任何形式提供网络接入服务。'
        '软件本身不含任何服务器、节点或订阅内容，也不代替任何网络服务商。',
  ),
  MockDisclaimerTerm(
    title: '二、使用方式',
    content:
        '用户应仅在自有设备与自有网络上使用本软件。将本软件用于任何网络接入、'
        '绕过计费或在未授权网络上运行的行为，均超出软件设计用途。',
  ),
  MockDisclaimerTerm(
    title: '三、责任范围',
    content:
        '因使用或无法使用本软件导致的任何直接或间接损失，包括但不限于数据丢失、'
        '服务中断、设备损坏，作者与贡献者均不承担责任。',
  ),
  MockDisclaimerTerm(
    title: '四、第三方组件',
    content:
        '本软件的界面组件层移植自 DITING（GPL-3.0-or-later），'
        '并使用了 JetBrains Mono、Twemoji 等第三方资源。各组件的许可条款见仓库 '
        'NOTICE.md，使用本软件即表示同时接受这些条款。',
  ),
  MockDisclaimerTerm(
    title: '五、无担保',
    content:
        '本软件按「现状」提供，不附带任何明示或暗示的担保，'
        '包括但不限于适销性、特定用途适用性与不侵权的担保。',
  ),
  MockDisclaimerTerm(
    title: '六、责任限制',
    content:
        '在法律允许的最大范围内，作者不对任何间接、附带、特殊或后果性损害负责，'
        '即使已被告知此类损害的可能性。',
  ),
  MockDisclaimerTerm(
    title: '七、隐私',
    content:
        '本软件默认不收集、不上传任何用户数据。日志与规则仅保存在本地；'
        '若用户主动配置 WebDAV 备份，数据将上传至用户自行指定的服务器。',
  ),
  MockDisclaimerTerm(
    title: '八、许可',
    content:
        '本软件以 GPL-3.0-or-later 发布。你可以自由使用、修改与再分发，'
        '但衍生作品必须沿用同一许可并保留原始版权声明。',
  ),
  MockDisclaimerTerm(
    title: '九、条款变更',
    content:
        '作者保留随时修改本免责声明的权利。变更后的条款随新版本一同发布，'
        '继续使用即视为接受修改后的条款。',
  ),
  MockDisclaimerTerm(
    title: '十、接受条款',
    content:
        '在继续使用本软件前，请确认你已阅读、理解并同意上述全部条款。'
        '若不同意，请立即停止使用并卸载本软件。',
  ),
];
