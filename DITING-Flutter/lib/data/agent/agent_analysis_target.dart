/// What the user asked the model to look at. Split from the prompt builders so the UI can carry a
/// target around (and compare two of them) without dragging the prompt text along.
library;

sealed class AgentAnalysisTarget {
  const AgentAnalysisTarget();

  /// Panel title, e.g. 域名安全分析.
  String get title;

  /// One-line context under the title, so a reopened panel still says what it is about.
  String get subtitle;

  /// Domain targets can offer "add to allow/block list"; traffic targets cannot.
  bool get isDomain;
}

/// One domain; [contextLogs] is extra context the caller already holds.
class AgentDomainTarget extends AgentAnalysisTarget {
  const AgentDomainTarget(this.domain, {this.contextLogs = const []});

  final String domain;
  final List<String> contextLogs;

  @override
  String get title => '域名安全分析';

  @override
  String get subtitle => domain;

  @override
  bool get isDomain => true;

  // Value equality: the analysis session is keyed on the target, so a rebuild must not look like a
  // new request. `contextLogs` is deliberately excluded — it only refines the prompt.
  @override
  bool operator ==(Object other) =>
      other is AgentDomainTarget && other.domain == domain;

  @override
  int get hashCode => Object.hash(AgentDomainTarget, domain);
}

class AgentTrafficTarget extends AgentAnalysisTarget {
  const AgentTrafficTarget();

  @override
  String get title => '网络流量分析';

  @override
  String get subtitle => '基于近期 DNS 与 HTTPS 监控数据';

  @override
  bool get isDomain => false;

  @override
  bool operator ==(Object other) => other is AgentTrafficTarget;

  @override
  int get hashCode => (AgentTrafficTarget).hashCode;
}
