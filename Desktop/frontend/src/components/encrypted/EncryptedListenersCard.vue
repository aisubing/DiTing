<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { ipc } from '../../api/ipc';
import type { EncryptedDNSStatusResponse, ConfigureEncryptedDNSRequest } from '../../api/types';
import AppCard from '../ui/AppCard.vue';
import StatusBadge from '../StatusBadge.vue';
import InlineAlert from '../ui/InlineAlert.vue';
import CopyRow from '../ui/CopyRow.vue';
import M3Icon from '../M3Icon.vue';
import { extractSwitchValue, revertSwitch } from '../../utils/switch';

const props = defineProps<{ status: EncryptedDNSStatusResponse | null }>();
const emit = defineEmits<{
  (e: 'error', message: string): void;
  (e: 'success', message: string): void;
  (e: 'changed', s: EncryptedDNSStatusResponse): void;
  (e: 'saving', v: boolean): void;
}>();

const saving = ref(false);
const listenAddress = ref('');
const serverName = ref('');
const dohPath = ref('');
const dotPort = ref(853);
const dohPort = ref(443);
const doqPort = ref(853);

const cfg = computed(() => props.status?.config);
const enabled = computed(() => cfg.value?.enabled ?? false);

/** 各协议是否真的在监听——配置打开不等于绑上了端口 */
const dotLive = computed(() => Boolean(props.status?.dotListen));
const dotLiveAddr = computed(() => props.status?.dotListen || '');
const dohLive = computed(() => Boolean(props.status?.dohListen));
const dohLiveAddr = computed(() => props.status?.dohListen || '');
const doqLive = computed(() => Boolean(props.status?.doqListen));
const doqLiveAddr = computed(() => props.status?.doqListen || '');

/** 有任一协议被选中但总开关没开，配置不会生效——提前说出来 */
const anyProtocolOn = computed(
  () => Boolean(cfg.value?.dotEnabled || cfg.value?.dohEnabled || cfg.value?.doqEnabled),
);

/** 网络参数草稿是否被用户改动过（改动后不被父级状态刷新回卷） */
const draftDirty = ref(false);

function markDraftDirty() {
  draftDirty.value = true;
}

function applyServerNetwork(s: EncryptedDNSStatusResponse) {
  listenAddress.value = s.config.listenAddress;
  serverName.value = s.config.serverName;
  dohPath.value = s.config.dohPath;
  dotPort.value = s.config.dotPort;
  dohPort.value = s.config.dohPort;
  doqPort.value = s.config.doqPort;
  draftDirty.value = false;
}

watch(
  () => props.status,
  (s) => {
    if (!s) return;
    // 草稿未保存时不能回填：父级状态在任意卡片 changed / 刷新时都会整体替换，
    // 旧实现会把用户正在输入的网络参数静默覆写回服务器值。
    if (draftDirty.value) return;
    applyServerNetwork(s);
  },
  { immediate: true },
);

async function send(patch: ConfigureEncryptedDNSRequest, okText = '加密 DNS 配置已更新') {
  try {
    saving.value = true;
    emit('saving', true);
    const res = await ipc.configureEncryptedDNS(patch);
    draftDirty.value = false;
    emit('changed', res);
    emit('success', okText);
  } catch (err: any) {
    emit('error', err?.message || '更新加密 DNS 配置失败');
  } finally {
    saving.value = false;
    emit('saving', false);
  }
}

async function toggleMaster(e: Event) {
  const next = extractSwitchValue(e);
  try {
    saving.value = true;
    emit('saving', true);
    const res = await ipc.configureEncryptedDNS({ enabled: next });
    emit('changed', res);
    emit('success', `加密 DNS 服务已${next ? '开启' : '关闭'}`);
  } catch (err: any) {
    revertSwitch(e, !next);
    emit('error', err?.message || '切换加密 DNS 服务失败');
  } finally {
    saving.value = false;
    emit('saving', false);
  }
}

async function toggleProtocol(e: Event, key: 'dotEnabled' | 'dohEnabled' | 'doqEnabled', label: string) {
  const next = extractSwitchValue(e);
  try {
    saving.value = true;
    emit('saving', true);
    const res = await ipc.configureEncryptedDNS({ [key]: next } as ConfigureEncryptedDNSRequest);
    emit('changed', res);
    emit('success', `${label} 已${next ? '启用' : '停用'}`);
  } catch (err: any) {
    revertSwitch(e, !next);
    emit('error', err?.message || `切换 ${label} 失败`);
  } finally {
    saving.value = false;
    emit('saving', false);
  }
}

function saveNetwork() {
  return send(
    {
      listenAddress: listenAddress.value,
      serverName: serverName.value,
      dohPath: dohPath.value,
      dotPort: Number(dotPort.value),
      dohPort: Number(dohPort.value),
      doqPort: Number(doqPort.value),
    },
    '监听参数已保存',
  );
}

async function resetNetwork() {
  const s = props.status;
  if (!s) return;
  listenAddress.value = '';
  serverName.value = '';
  dohPath.value = s.defaultDohPath;
  dotPort.value = s.defaultDotPort;
  dohPort.value = s.defaultDohPort;
  doqPort.value = s.defaultDoqPort;
  draftDirty.value = false;
}

const INPUT_CLS =
  'w-full h-[34px] px-3 rounded-md border border-surface-border bg-surface-card-sub text-xs text-text-main font-mono focus:outline-none focus:border-accent-seal';
</script>

<template>
  <AppCard
    title="加密 DNS 服务"
    subtitle="在局域网内以 DoT / DoH / DoQ 提供解析，终端无需明文查询"
    icon="dns"
    :iconSize="16"
  >
    <template #badge>
      <StatusBadge
        :status="enabled ? 'active' : 'inactive'"
        :text="enabled ? '已启用' : '未启用'"
        size="sm"
      />
    </template>

    <template #actions>
      <md-switch :selected="enabled" :disabled="saving" @change="toggleMaster" />
    </template>

    <div class="space-y-3 mt-3 text-xs">
      <InlineAlert
        v-if="enabled && !anyProtocolOn"
        type="warning"
        message="服务总开关已打开，但三种协议都没选中，因此不会有任何监听。"
      />

      <div class="app-card-sub p-3 space-y-2.5">
        <div class="text-[13px] font-bold text-text-main">协议</div>
        <div class="space-y-2">
          <div class="flex items-center justify-between gap-3">
            <div class="min-w-0">
              <div class="text-text-main text-[12px]">
                DoT
                <span class="text-[10px] text-text-muted font-mono ml-1">DNS over TLS · RFC 7858</span>
              </div>
              <div class="text-[11px] text-text-muted">
                端口 {{ cfg?.dotPort ?? 853 }}，客户端用 <code class="font-mono">tls://</code> 连接
              </div>
              <div v-if="cfg?.dotEnabled" class="text-[11px] mt-0.5 font-mono">
                <span v-if="dotLive" class="text-status-success">正在监听 {{ dotLiveAddr }}</span>
                <span v-else class="text-status-warning">
                  未在监听（服务未启动、证书不可用或端口被占用）
                </span>
              </div>
            </div>
            <md-switch
              :selected="cfg?.dotEnabled ?? false"
              :disabled="saving"
              @change="(e: Event) => toggleProtocol(e, 'dotEnabled', 'DoT')"
            />
          </div>
          <div class="flex items-center justify-between gap-3 border-t border-surface-border-sub pt-2">
            <div class="min-w-0">
              <div class="text-text-main text-[12px]">
                DoH
                <span class="text-[10px] text-text-muted font-mono ml-1">DNS over HTTPS · RFC 8484</span>
              </div>
              <div class="text-[11px] text-text-muted">
                端口 {{ cfg?.dohPort ?? 443 }}，路径 <code class="font-mono">{{ cfg?.dohPath || '/dns-query' }}</code>
              </div>
              <div v-if="cfg?.dohEnabled" class="text-[11px] mt-0.5 font-mono">
                <span v-if="dohLive" class="text-status-success">正在监听 {{ dohLiveAddr }}</span>
                <span v-else class="text-status-warning">
                  未在监听（服务未启动、证书不可用或端口被占用）
                </span>
              </div>
            </div>
            <md-switch
              :selected="cfg?.dohEnabled ?? false"
              :disabled="saving"
              @change="(e: Event) => toggleProtocol(e, 'dohEnabled', 'DoH')"
            />
          </div>
          <div
            v-if="cfg?.dohEnabled && (status?.dohUrls?.length ?? 0) > 0"
            class="border-t border-surface-border-sub pt-2 space-y-1.5"
          >
            <div class="text-[11px] text-text-muted">客户端填写以下任一地址即可使用：</div>
            <CopyRow
              v-for="url in status?.dohUrls || []"
              :key="url"
              :text="url"
              :open-url="url"
              open-title="在浏览器中打开（应显示 400，说明服务在响应）"
            />
          </div>
          <div class="flex items-center justify-between gap-3 border-t border-surface-border-sub pt-2">
            <div class="min-w-0">
              <div class="text-text-main text-[12px]">
                DoQ
                <span class="text-[10px] text-text-muted font-mono ml-1">DNS over QUIC · RFC 9250</span>
              </div>
              <div class="text-[11px] text-text-muted">端口 {{ cfg?.doqPort ?? 853 }}，UDP 上的加密解析</div>
              <div v-if="cfg?.doqEnabled" class="text-[11px] mt-0.5 font-mono">
                <span v-if="doqLive" class="text-status-success">正在监听 {{ doqLiveAddr }}</span>
                <span v-else class="text-status-warning">
                  未在监听（服务未启动、证书不可用或端口被占用）
                </span>
              </div>
            </div>
            <md-switch
              :selected="cfg?.doqEnabled ?? false"
              :disabled="saving"
              @change="(e: Event) => toggleProtocol(e, 'doqEnabled', 'DoQ')"
            />
          </div>
        </div>
      </div>

      <div class="app-card-sub p-3 space-y-2.5">
        <div class="text-[13px] font-bold text-text-main">监听参数</div>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
          <div>
            <label class="text-[11px] font-semibold text-text-muted block mb-1">监听地址</label>
            <input v-model="listenAddress" @input="markDraftDirty" :class="INPUT_CLS" placeholder="留空表示全部网卡" />
          </div>
          <div>
            <label class="text-[11px] font-semibold text-text-muted block mb-1">服务器名（客户端连接用）</label>
            <input v-model="serverName" @input="markDraftDirty" :class="INPUT_CLS" placeholder="dns.lan" />
          </div>
          <div>
            <label class="text-[11px] font-semibold text-text-muted block mb-1">DoT 端口</label>
            <input v-model.number="dotPort" @input="markDraftDirty" type="number" min="1" max="65535" :class="INPUT_CLS" />
          </div>
          <div>
            <label class="text-[11px] font-semibold text-text-muted block mb-1">DoH 端口</label>
            <input v-model.number="dohPort" @input="markDraftDirty" type="number" min="1" max="65535" :class="INPUT_CLS" />
          </div>
          <div>
            <label class="text-[11px] font-semibold text-text-muted block mb-1">DoQ 端口</label>
            <input v-model.number="doqPort" @input="markDraftDirty" type="number" min="1" max="65535" :class="INPUT_CLS" />
          </div>
          <div>
            <label class="text-[11px] font-semibold text-text-muted block mb-1">DoH 路径</label>
            <input v-model="dohPath" @input="markDraftDirty" :class="INPUT_CLS" placeholder="/dns-query" />
          </div>
        </div>
        <p class="text-[11px] text-text-muted leading-relaxed">
          服务器名会被写进证书的 SAN，终端按它连接才不会报证书错误。
        </p>
        <div class="flex items-center justify-end gap-2">
          <button type="button" class="app-btn-secondary app-btn-compact" :disabled="saving" @click="resetNetwork">
            <M3Icon name="undo" :size="13" />
            <span>恢复默认</span>
          </button>
          <button type="button" class="app-btn-primary app-btn-compact" :disabled="saving" @click="saveNetwork">
            <M3Icon name="check" :size="13" />
            <span>保存</span>
          </button>
        </div>
      </div>
    </div>
  </AppCard>
</template>
