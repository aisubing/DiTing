<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { ipc } from '../../api/ipc';
import type { DNS64Config } from '../../api/types';
import M3Icon from '../M3Icon.vue';
import AppCard from '../ui/AppCard.vue';
import StatusBadge from '../StatusBadge.vue';
import ToastBanner from '../ToastBanner.vue';
import { extractSwitchValue } from '../../utils/switch';
import { useToast } from '../../composables/useToast';

const dns64Config = ref<DNS64Config>({
  enabled: false,
  prefixes: ['64:ff9b::/96'],
});

const loading = ref(false);
const saving = ref(false);
const prefixesText = ref('');
const { toast, show: showToast, dismiss } = useToast();

async function loadData() {
  loading.value = true;
  try {
    const st = await ipc.getStatus();
    if (st && st.dns64) {
      dns64Config.value = st.dns64;
      prefixesText.value = (st.dns64.prefixes || ['64:ff9b::/96']).join('\n');
    }
  } catch (err: any) {
    showToast(err.message || '加载 DNS64 配置失败', true);
  } finally {
    loading.value = false;
  }
}

async function handleToggle(e: Event) {
  const nextVal = extractSwitchValue(e);
  dns64Config.value.enabled = nextVal;
  await saveConfig();
}

async function saveConfig() {
  saving.value = true;
  try {
    const list = prefixesText.value
      .split('\n')
      .map((s) => s.trim())
      .filter(Boolean);

    if (list.length === 0) {
      list.push('64:ff9b::/96');
      prefixesText.value = '64:ff9b::/96';
    }

    await ipc.configureDNS64({
      enabled: dns64Config.value.enabled,
      prefixes: list,
    });
    dns64Config.value.prefixes = list;
    showToast(`DNS64 过渡合成配置已更新 (状态: ${dns64Config.value.enabled ? '已开启' : '已关闭'})`);
  } catch (err: any) {
    showToast(err.message || '更新 DNS64 配置失败', true);
  } finally {
    saving.value = false;
  }
}

function resetToDefaultPrefix() {
  prefixesText.value = '64:ff9b::/96';
}

onMounted(() => {
  loadData();
});
</script>

<template>
  <div class="space-y-5 select-none">
    <ToastBanner v-if="toast" :message="toast.message" :type="toast.isError ? 'error' : 'success'" dismissible @dismiss="dismiss" />

    <AppCard
      title="DNS64 IPv6-only 网络过渡合成"
      subtitle="遵循 RFC 6052 / RFC 6147 规范，为纯 IPv6 终端自动将纯 IPv4 目标合成为 AAAA 记录"
      icon="router"
    >
      <template #badge>
        <StatusBadge
          :status="dns64Config.enabled ? 'active' : 'inactive'"
          :text="dns64Config.enabled ? 'DNS64 合成中' : '功能已停用'"
          size="sm"
        />
      </template>

      <template #actions>
        <md-switch
          :selected="dns64Config.enabled"
          :disabled="saving || loading"
          @change="handleToggle"
        />
      </template>

      <div class="space-y-4 mt-3 text-xs">
        <p class="text-[12px] text-text-sub leading-relaxed">
          当客户端位于纯 IPv6 (IPv6-only) 网络并通过 NAT64 网关访问互联网时，若目标域名仅有 IPv4 (A) 记录而无原生 IPv6 (AAAA) 记录，DNS64 引擎将使用指定的前缀将 IPv4 报文自动合成映射为 IPv6 AAAA 地址返回，实现端到端顺畅互联。
        </p>

        <div>
          <div class="flex items-center justify-between mb-1.5">
            <label class="font-semibold text-text-main">用于合成的 IPv6 前缀 (Prefixes)</label>
            <button
              type="button"
              @click="resetToDefaultPrefix"
              class="text-[11px] text-accent-seal hover:underline cursor-pointer"
            >
              填入标准知名前缀 (64:ff9b::/96)
            </button>
          </div>
          <textarea
            v-model="prefixesText"
            rows="3"
            placeholder="64:ff9b::/96"
            class="w-full rounded-md border border-surface-border bg-surface-card-sub p-2.5 font-mono text-xs text-text-main focus:outline-none focus:border-accent-seal"
          ></textarea>
          <span class="text-[10px] text-text-muted mt-1 block">
            每行一个 IPv6 网段 CIDR。支持 /96, /64, /56, /48, /40, /32 各种长度前缀。默认使用知名公共前缀 <code class="font-mono">64:ff9b::/96</code>。
          </span>
        </div>

        <div class="app-card-sub p-3 space-y-1.5 text-[11px] text-text-muted">
          <div class="font-semibold text-text-main flex items-center gap-1.5">
            <M3Icon name="info" :size="14" class="text-accent-seal" />
            <span>智能保护机制</span>
          </div>
          <p>
            • 谛听已内置 RFC 6147 规范排除网段，自动避免回环地址、链路本地地址、私有保留网段及重复嵌套合成。<br />
            • 若目标域名原生拥有可用的 IPv6 AAAA 记录，系统将直接返回原生记录而不做额外合成。
          </p>
        </div>
      </div>

      <template #footer>
        <div class="flex items-center justify-end">
          <button
            type="button"
            @click="saveConfig"
            :disabled="saving"
            class="app-btn-primary"
          >
            <M3Icon name="check" :size="14" />
            <span>{{ saving ? '保存中...' : '保存 DNS64 配置' }}</span>
          </button>
        </div>
      </template>
    </AppCard>
  </div>
</template>
