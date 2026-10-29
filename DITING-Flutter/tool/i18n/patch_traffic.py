"""Replace the multi-line explanatory paragraphs in the traffic attribution sheet."""

import re

p = 'lib/pages/traffic/traffic_rows.dart'
s = open(p, encoding='utf-8').read()

blocks = [
    (
        "                    '流量按 UID 归因：每个应用的上下行字节数由引擎按 UID 累计后'",
        "                    context.l10n.trafficScopeBody,",
    ),
    (
        "                    '这里只统计经过本机隧道处理的流量，未进入隧道的直连流量不计入；'",
        "                    context.l10n.trafficWhyLowerBody,",
    ),
    (
        "                    '实时速率需要内核每秒回报的速率序列；本仓的按天流量表只有'",
        "                    context.l10n.trafficWhyNoRateBody,",
    ),
    (
        "                    '按天保留，由原生侧的清理策略删除过期行；'",
        "                    context.l10n.trafficRetentionBody,",
    ),
    (
        "                    '流量表里没有系统应用标记，页面按旧版 SystemAppClassifier 的'",
        "                    context.l10n.trafficSystemAppsBody,",
    ),
    (
        "                '上游对应 ui/traffic/TrafficAttributionDialog.kt 与 '",
        "                context.l10n.trafficUpstreamFooter,",
    ),
]

for start_marker, replacement in blocks:
    start = s.index(start_marker)
    # The paragraph ends with the first `,` that closes a quoted line.
    end = s.index("',", start) + 2
    # Consume the trailing quote lines of the same string group.
    while True:
        rest = s[end:]
        stripped = rest.lstrip()
        if stripped.startswith("'"):
            end = end + (len(rest) - len(stripped)) + len(stripped)
            end = s.index("',", end) + 2
        else:
            break
    s = s[:start] + replacement + s[end:]

open(p, 'w', encoding='utf-8').write(s)
print('ok')
