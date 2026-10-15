<script setup lang="ts">
import { ref, computed } from 'vue';
import type { EncryptedDNSStatusResponse } from '../../api/types';
import AppCard from '../ui/AppCard.vue';
import InlineAlert from '../ui/InlineAlert.vue';
import CopyRow from '../ui/CopyRow.vue';

const props = defineProps<{ status: EncryptedDNSStatusResponse | null }>();

const clientId = ref('');

const serverName = computed(() => props.status?.config.serverName || '');
const dotPort = computed(() => props.status?.config.dotPort ?? 853);
const dohPort = computed(() => props.status?.config.dohPort ?? 443);
const dohPath = computed(() => props.status?.config.dohPath || '/dns-query');

/**
 * 与后端 ValidateClientID 同一套规则：字母数字加中间连字符，最长 63 字节。
 *
 * 前端先校验只是为了即时反馈，真正的把关仍在服务端——这里的判断结果
 * 不会被当成安全边界，只决定「要不要把示例地址显示出来」。
 */
const validation = computed(() => {
  const id = clientId.value.trim();
  if (!id) return { ok: false, reason: '' };
  if (id.length > 63) return { ok: false, reason: '长度不能超过 63 个字符' };
  if (!/^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$/.test(id)) {
    return { ok: false, reason: '只能包含字母、数字与连字符，且不能以连字符开头或结尾' };
  }
  return { ok: true, reason: '' };
});

/** DoH 的路径段 ClientID 优先于 Host，因此这里直接给带路径的地址 */
const dohURL = computed(() => {
  if (!validation.value.ok || !serverName.value) return '';
  const suffix = dohPort.value === 443 ? '' : `:${dohPort.value}`;
  return `https://${serverName.value}${suffix}${dohPath.value}/${clientId.value.trim()}`;
});

/** DoT 靠 SNI 传 ClientID，写成 tls:// 形式便于多数客户端直接粘贴 */
const dotURL = computed(() => {
  if (!validation.value.ok || !serverName.value) return '';
  const host = `${clientId.value.trim()}.${serverName.value}`;
  const name = dotPort.value === 853 ? host : `${host}:${dotPort.value}`;
  return `tls://${name}`;
});

const INPUT_CLS =
  'w-full h-[34px] px-3 rounded-md border border-surface-border bg-surface-card-sub text-xs text-text-main font-mono focus:outline-none focus:border-accent-seal';
</script>

<template>
  <AppCard
    title="客户端标识（ClientID）"
    subtitle="给每台终端一个固定身份，便于按设备查看日志与分别下发策略"
    icon="devices"
    :iconSize="16"
  >
    <div class="space-y-3 mt-3 text-xs">
      <InlineAlert
        v-if="!serverName"
        type="warning"
        message="请先在上方「监听参数」里填写服务器名。ClientID 是挂在服务器名之下的子域，没有服务器名就无法构造。"
      />

      <p class="text-[11px] text-text-muted leading-relaxed">
        在加密入口的连接名（DoT 的 SNI、DoH 的路径段）前面加一级标签即可。
        例如服务器名为
        <code class="font-mono text-text-sub">{{ serverName || 'dns.lan' }}</code>
        ，终端用
        <code class="font-mono text-text-sub">laptop.{{ serverName || 'dns.lan' }}</code>
        连接时，这台设备的查询就会带上 <code class="font-mono text-text-sub">laptop</code> 这个身份。
        只识别紧邻服务器名的那一级标签，更长的上级域名不会被当作 ClientID。
      </p>

      <div>
        <label class="text-[11px] font-semibold text-text-muted block mb-1">为哪台设备生成示例</label>
        <input v-model="clientId" :class="INPUT_CLS" placeholder="如 laptop、phone、living-room-tv" />
        <p v-if="validation.reason" class="text-[11px] text-status-error mt-1">{{ validation.reason }}</p>
      </div>

      <div v-if="validation.ok" class="space-y-1.5">
        <div v-if="dotURL">
          <div class="text-[11px] text-text-muted mb-1">DoT（DoH 同理，把标签放到路径最后一段）</div>
          <CopyRow :text="dotURL" tag="DoT" />
        </div>
        <div v-if="dohURL">
          <div class="text-[11px] text-text-muted mb-1">DoH</div>
          <CopyRow :text="dohURL" tag="DoH" />
        </div>
      </div>

      <p class="text-[11px] text-text-muted leading-relaxed">
        ClientID 由客户端自行声明，服务端只做格式校验，不做认证——
        它用于区分设备，不能替代访问控制。设备改名后请同步更新对应的策略与分组。
      </p>
    </div>
  </AppCard>
</template>
