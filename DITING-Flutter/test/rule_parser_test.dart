import 'package:diting/data/rules/rule_domain_utils.dart';
import 'package:diting/data/rules/rule_models.dart';
import 'package:diting/data/rules/rule_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Equivalent of 1.4.3's `AdGuardRuleParserTest`: a semantic drift silently blocks too much
/// or too little
void main() {
  group('域名 / 修饰符', () {
    test('标准拦截规则与修饰符', () {
      final standard = parseRule('||example.com^');
      expect(standard, isNotNull);
      expect(standard!.pattern, 'example.com');
      expect(standard.important, isFalse);
      expect(standard.appScope, isNull);

      final appImportant = parseRule(
        '||ads.net^\$app=com.app1|com.app2,important',
      );
      expect(appImportant, isNotNull);
      expect(appImportant!.pattern, 'ads.net');
      expect(appImportant.important, isTrue);
      expect(appImportant.appScope, 'com.app1|com.app2');
      expect(appImportant.appInverted, isFalse);

      final inverted = parseRule('||tracker.com^\$app=~com.android.chrome');
      expect(inverted, isNotNull);
      expect(inverted!.pattern, 'tracker.com');
      expect(inverted.appScope, 'com.android.chrome');
      expect(inverted.appInverted, isTrue);

      final wildcard = parseRule(
        '||*-analytics.google.com^\$app=com.google.android.gms',
      );
      expect(wildcard, isNotNull);
      expect(wildcard!.pattern, '*-analytics.google.com');
      expect(wildcard.isWildcard, isTrue);
    });

    test('放行规则与修饰符', () {
      final allow = parseAllowRule(
        '@@||*-analytics.google.com^\$app=com.google.android.gms,important',
      );
      expect(allow, isNotNull);
      expect(allow!.pattern, '*-analytics.google.com');
      expect(allow.isWildcard, isTrue);
      expect(allow.important, isTrue);
      expect(allow.appScope, 'com.google.android.gms');
    });

    test('注释与空行被忽略', () {
      expect(parseRule('! comment'), isNull);
      expect(parseRule('# comment'), isNull);
      expect(parseRule('   '), isNull);
      expect(parseAllowRule('! allow comment'), isNull);
    });

    test('\$all 与 \$all,important', () {
      expect(parseRule('||example.com^\$all')!.pattern, 'example.com');
      expect(parseRule('||example.com^\$all,important')!.important, isTrue);
    });

    test('\$~app= 前缀同样表示取反', () {
      final rule = parseRule('||tracker.com^\$~app=com.android.chrome');
      expect(rule, isNotNull);
      expect(rule!.pattern, 'tracker.com');
      expect(rule.appScope, 'com.android.chrome');
      expect(rule.appInverted, isTrue);
    });

    test('只对 HTTP 有意义的修饰符整行忽略', () {
      expect(
        parseCategorizedLine('||example.com^\$image,third-party').ignoredCount,
        1,
      );
      expect(
        parseCategorizedLine('||example.com^\$removeparam=utm_source')
            .ignoredCount,
        1,
      );
      expect(
        parseCategorizedLine('||example.com/banner.js\$script,badfilter')
            .ignoredCount,
        1,
      );
    });

    test('~denyallow= 丢弃修饰符但保留规则', () {
      final line = parseCategorizedLine(
        '||example.com^\$~denyallow=a.com|b.com',
      );
      expect(line.blockRules, hasLength(1));
      expect(line.blockRules.first.pattern, 'example.com');
      expect(line.blockRules.first.denyallow, isNull);
    });
  });

  group('dnsrewrite', () {
    test('IPv4 / IPv6 / CNAME 三种目标', () {
      final ipv4 = parseCategorizedLine('||example.com^\$dnsrewrite=1.2.3.4');
      expect(ipv4.rewriteRules, hasLength(1));
      expect(ipv4.rewriteRules.first.pattern, 'example.com');
      expect(ipv4.rewriteRules.first.targetType, RewriteTargetType.ipv4);
      expect(ipv4.rewriteRules.first.targetValue, '1.2.3.4');

      final ipv6 = parseCategorizedLine('||ipv6.com^\$dnsrewrite=2001:db8::1');
      expect(ipv6.rewriteRules, hasLength(1));
      expect(ipv6.rewriteRules.first.targetType, RewriteTargetType.ipv6);
      expect(ipv6.rewriteRules.first.targetValue, '2001:db8::1');

      final cname = parseCategorizedLine(
        '||cname.com^\$dnsrewrite=target.example.org',
      );
      expect(cname.rewriteRules, hasLength(1));
      expect(cname.rewriteRules.first.targetType, RewriteTargetType.cname);
      expect(cname.rewriteRules.first.targetValue, 'target.example.org');
    });

    test('NXDOMAIN 与黑洞地址变成拦截规则', () {
      final nx = parseCategorizedLine('||blocked.com^\$dnsrewrite=NXDOMAIN');
      expect(nx.blockRules, hasLength(1));
      expect(nx.blockRules.first.pattern, 'blocked.com');

      final zero = parseCategorizedLine('||sinkhole.com^\$dnsrewrite=0.0.0.0');
      expect(zero.blockRules, hasLength(1));
      expect(zero.blockRules.first.pattern, 'sinkhole.com');
    });
  });

  group('hosts 与 dnsmasq', () {
    test('黑洞 hosts 一行多域名展开成多条拦截', () {
      final sinkhole = parseCategorizedLine(
        '0.0.0.0 ads.example.com tracker.example.com # ad hosts',
      );
      expect(sinkhole.blockRules, hasLength(2));
      expect(sinkhole.blockRules[0].pattern, 'ads.example.com');
      expect(sinkhole.blockRules[1].pattern, 'tracker.example.com');
      expect(sinkhole.rewriteRules, isEmpty);
    });

    test('真实 IP 的 hosts 行变成覆写', () {
      final realIp = parseCategorizedLine(
        '1.2.3.4 host1.example.com host2.example.com',
      );
      expect(realIp.blockRules, isEmpty);
      expect(realIp.rewriteRules, hasLength(2));
      expect(realIp.rewriteRules[0].pattern, 'host1.example.com');
      expect(realIp.rewriteRules[0].targetValue, '1.2.3.4');
      expect(realIp.rewriteRules[1].pattern, 'host2.example.com');
    });

    test('dnsmasq 黑洞三种写法都算拦截', () {
      for (final line in [
        'address=/blocked.com/',
        'address=/sink.com/0.0.0.0',
        'address=/null.com/#',
      ]) {
        final parsed = parseCategorizedLine(line);
        expect(parsed.blockRules, hasLength(1), reason: line);
        expect(parsed.rewriteRules, isEmpty, reason: line);
      }
    });

    test('dnsmasq 真实 IP 与域名目标变成覆写', () {
      final ip = parseCategorizedLine('address=/custom.com/10.0.0.1');
      expect(ip.rewriteRules, hasLength(1));
      expect(ip.rewriteRules.first.targetValue, '10.0.0.1');

      final cname = parseCategorizedLine(
        'server=/alias.com/target.example.org',
      );
      expect(cname.rewriteRules, hasLength(1));
      expect(cname.rewriteRules.first.targetType, RewriteTargetType.cname);
      expect(cname.rewriteRules.first.targetValue, 'target.example.org');
    });
  });

  group('整份文本', () {
    test('混合文本按族归类', () {
      // Matches Kotlin's `trimIndent()`: dropped blank lines would add an extra ignored entry
      const text =
          '! Title: Unified List\n'
          '# Comment line\n'
          '[Adblock Plus 2.0]\n'
          'example.com##.ad-banner\n'
          '||ad.com^\n'
          '@@||allow.com^\n'
          r'||rewrite.com^$dnsrewrite=1.2.3.4'
          '\n'
          '0.0.0.0 sink.com\n'
          '10.0.0.2 real.com\n'
          'address=/masq-block.com/\n'
          'address=/masq-ip.com/10.0.0.3';
      final parsed = parseCategorized(text);
      expect(parsed.blockRules.map((r) => r.pattern), [
        'ad.com',
        'sink.com',
        'masq-block.com',
      ]);
      expect(parsed.allowRules.map((r) => r.pattern), ['allow.com']);
      expect(parsed.rewriteRules.map((r) => r.pattern), [
        'rewrite.com',
        'real.com',
        'masq-ip.com',
      ]);
      expect(parsed.cosmeticRules, hasLength(1));
      expect(parsed.ignoredCount, 3);
    });

    test('badfilter 关掉同键规则，且与顺序无关', () {
      const forward = '||example.com^\n||example.com^\$badfilter';
      final a = parseCategorized(forward);
      expect(a.blockRules, isEmpty);
      expect(a.badfilteredCount, 1);

      const reversed = '||example.com^\$badfilter\n||example.com^';
      final b = parseCategorized(reversed);
      expect(b.blockRules, isEmpty);
      expect(b.badfilteredCount, 1);
    });

    test('放行 badfilter 只关放行规则', () {
      const text =
          '||example.com^\n@@||example.com^\n@@||example.com^\$badfilter';
      final parsed = parseCategorized(text);
      expect(parsed.blockRules, hasLength(1));
      expect(parsed.allowRules, isEmpty);
      expect(parsed.badfilteredCount, 1);
    });

    test('重复行计入 duplicate 且只保留一条', () {
      const text = '||dup.com^\n||dup.com^\n||dup.com^';
      final parsed = parseCategorized(text);
      expect(parsed.blockRules, hasLength(1));
      expect(parsed.duplicateCount, 2);
    });
  });

  group('元素隐藏分隔符', () {
    test('#\$@# 例外形式不被降级成整域拦截', () {
      final line = parseCategorizedLine('example.com#\$@#.ad-banner');
      expect(line.blockRules, isEmpty);
      expect(line.cosmeticRules, hasLength(1));
      expect(line.cosmeticRules.first.isException, isTrue);
      expect(line.cosmeticRules.first.selector, '.ad-banner');
    });

    test('## / #@# / #?# 都识别为 cosmetic', () {
      for (final line in [
        'example.com##.ad',
        'example.com#@#.ad',
        'example.com#?#.ad',
      ]) {
        final parsed = parseCategorizedLine(line);
        expect(parsed.cosmeticRules, hasLength(1), reason: line);
        expect(parsed.blockRules, isEmpty, reason: line);
      }
    });
  });

  group('域名工具', () {
    test('通配符归一化与 IP 判定', () {
      expect(normalizeWildcardDomain('*'), '*');
      expect(normalizeWildcardDomain('*.Example.COM'), '*.example.com');
      expect(normalizeWildcardDomain('bad domain'), isNull);
      expect(looksLikeLiteralIp('1.2.3.4'), isTrue);
      expect(looksLikeLiteralIp('::1'), isTrue);
      expect(looksLikeLiteralIp('example.com'), isFalse);
      expect(normalizeDomain('Example.COM.'), 'example.com');
      expect(normalizeDomain('1.2.3.4'), isNull);
      expect(normalizeDomain('nodot'), isNull);
    });
  });
}
