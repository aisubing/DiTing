<script setup lang="ts">
import { ref, computed } from 'vue';
import { ipc } from '../../api/ipc';
import type { EncryptedDNSStatusResponse, ConfigureEncryptedDNSRequest } from '../../api/types';
import AppCard from '../ui/AppCard.vue';
import StatusBadge from '../StatusBadge.vue';
import InlineAlert from '../ui/InlineAlert.vue';
import { extractSwitchValue, revertSwitch } from '../../utils/switch';

const props = defineProps<{ status: EncryptedDNSStatusResponse | null }>();
const emit = defineEmits<{
  (e: 'error', message: string): void;
  (e: 'success', message: string): void;
  (e: 'changed', s: EncryptedDNSStatusResponse): void;
  (e: 'saving', v: boolean): void;
}>();

const saving = ref(false);
const confirming = ref(false);

const cfg = computed(() => props.status?.config);
const enabled = computed(() => Boolean(cfg.value?.ddrEnabled));
const serverName = computed(() => cfg.value?.serverName || '');

/** 证书是否覆盖了 IP：决定 DoT 能否被广播出去 */
const certHasIPs = computed(() => (props.status?.cert.ipAddresses?.length ?? 0) > 0);
const certTrusted = computed(() => Boolean(props.status?.cert.loaded));

/** 哪些协议真的在监听——只有它们会被写进 DDR 应答 */
const liveProtocols = computed(() => {
  const out: string[] = [];
  if (props.status?.dotListen && cfg.value?.dotEnabled && certHasIPs.value) out.push('DoT');
  if (props.status?.dohListen && cfg.value?.dohEnabled) out.push('DoH');
  if (props.status?.doqListen && cfg.value?.doqEnabled) out.push('DoQ');
  return out;
});

/** 自签证书几乎不可能被客户端预先信任，这是 DDR 最大的风险来源 */
const selfSigned = computed(() => Boolean(props.status?.cert.selfSigned));

async function apply(next: boolean, okText: string) {
  try {
    saving.value = true;
    emit('saving', true);
    const res = await ipc.configureEncryptedDNS({ ddrEnabled: next } as ConfigureEncryptedDNSRequest);
    emit('changed', res);
    emit('success', okText);
  } catch (err: any) {
    emit('error', err?.message || '更新 DDR 配置失败');
    throw err;
  } finally {
    saving.value = false;
    emit('saving', false);
  }
}

async function toggle(e: Event) {
  const next = extractSwitchValue(e);
  // 开启前必须二次确认：DDR 会让客户端自动切换解析入口，
  // 证书不被信任时这一步就是「失去 DNS」
  if (next && !confirming.value) {
    confirming.value = true;
    return;
  }
  confirming.value = false;
  try {
    await apply(next, next ? 'DDR 已开启，客户端探测将得到本机地址' : 'DDR 已关闭');
  } catch {
    revertSwitch(e, !next);
  }
}

function cancelConfirm(e: Event) {
  confirming.value = false;
  revertSwitch(e, false);
}

async function confirmEnable() {
  confirming.value = false;
  try {
    await apply(true, 'DDR 已开启，客户端探测将得到本机地址');
  } catch {
    /* 错误已通过 emit 上报 */
  }
}
</script>

<template>
  <AppCard
    title="指定解析器发现（DDR）"
    subtitle="应答 _dns.resolver.arpa 探测，让终端自动发现本机的加密解析入口"
    icon="sync"
    :iconSize="16"
  >
    <template #badge>
      <StatusBadge
        :status="enabled ? 'active' : 'inactive'"
        :text="enabled ? '已开启' : '未开启'"
        size="sm"
      />
    </template>

    <template #actions>
      <md-switch :selected="enabled" :disabled="saving" @change="toggle" />
    </template>

    <div class="space-y-3 mt-3 text-xs">
      <InlineAlert
        v-if="confirming"
        type="warning"
        message="开启 DDR 后，支持该标准的终端会自动把解析切到本机。如果证书不被这些终端信任，它们会直接失去解析能力——建议先确认证书已安装并受信任。"
      />
      <div v-if="confirming" class="flex items-center justify-end gap-2">
        <button type="button" class="app-btn-secondary app-btn-compact" @click="cancelConfirm">
          <span>取消</span>
        </button>
        <button type="button" class="app-btn-primary app-btn-compact" :disabled="saving" @click="confirmEnable">
          <span>确认开启</span>
        </button>
      </div>

      <InlineAlert
        v-if="!serverName"
        type="warning"
        message="请先在「监听参数」里填写服务器名。DDR 应答里的 Target 必须是域名，没有服务器名什么也广播不出去。"
      />
      <InlineAlert
        v-else-if="selfSigned && !confirming"
        type="info"
        message="当前使用自签证书。DDR 只在客户端已经信任该证书时才有意义，否则终端会解析失败。"
      />

      <p class="text-[11px] text-text-muted leading-relaxed">
        DDR（RFC 9462）让终端向
        <code class="font-mono text-text-sub">_dns.resolver.arpa</code>
        发一次 SVCB 查询，由本机告诉它「用哪个地址、哪种协议做加密解析」，
        终端因此无需手工填写地址。服务端只广播<strong class="text-text-sub">确实在监听</strong>的入口。
      </p>

      <div v-if="enabled" class="app-card-sub p-3 space-y-1.5">
        <div class="text-[13px] font-bold text-text-main">将被广播的入口</div>
        <p v-if="liveProtocols.length === 0" class="text-[11px] text-status-warning">
          当前没有任何加密监听在运行，探测会返回空应答。
        </p>
        <template v-else>
          <div v-for="p in liveProtocols" :key="p" class="text-[11px] text-text-muted">
            <span class="font-mono text-text-sub">{{ p }}</span>
          </div>
          <p v-if="cfg?.dotEnabled && !certHasIPs" class="text-[11px] text-status-warning leading-relaxed">
            DoT 未被广播：DoT 客户端从证书的 IP 地址里取连接地址，而当前证书没有包含任何 IP。
            请在证书卡片里为证书补上监听地址对应的 IP，或改用 IP 地址签发。
          </p>
        </template>
        <p v-if="certTrusted === false" class="text-[11px] text-status-error">
          证书当前未成功载入，加密入口不可用。
        </p>
      </div>
    </div>
  </AppCard>
</template>
