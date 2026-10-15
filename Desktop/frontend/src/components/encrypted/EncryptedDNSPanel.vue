<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { ipc } from '../../api/ipc';
import type { EncryptedDNSStatusResponse } from '../../api/types';
import ToastBanner from '../ToastBanner.vue';
import InlineAlert from '../ui/InlineAlert.vue';
import M3Icon from '../M3Icon.vue';
import CertificateCard from './CertificateCard.vue';
import EncryptedListenersCard from './EncryptedListenersCard.vue';
import ClientIDCard from './ClientIDCard.vue';
import DDRCard from './DDRCard.vue';
import { useToast } from '../../composables/useToast';

const { toast, show: showToast, dismiss } = useToast();

const status = ref<EncryptedDNSStatusResponse | null>(null);
const loading = ref(false);
const loadError = ref('');
/** 子卡片正在下发配置；期间禁用跨卡片的重载按钮，避免读到写了一半的状态 */
const saving = ref(false);

async function loadData(notify = false) {
  try {
    loading.value = true;
    loadError.value = '';
    status.value = await ipc.getEncryptedDNSStatus();
    if (notify) showToast('状态已刷新');
  } catch (err: any) {
    loadError.value = err?.message || '获取加密 DNS 服务状态失败';
  } finally {
    loading.value = false;
  }
}

function onChanged(next: EncryptedDNSStatusResponse) {
  status.value = next;
}

onMounted(() => {
  loadData();
});
</script>

<template>
  <div class="space-y-6 select-none max-w-7xl mx-auto">
    <ToastBanner
      v-if="toast"
      :message="toast.message"
      :type="toast.isError ? 'error' : 'success'"
      dismissible
      @dismiss="dismiss"
    />

    <div class="flex items-start justify-between gap-3">
      <p class="text-[12px] text-text-muted leading-relaxed">
        为局域网内的终端提供加密解析入口：终端把查询交给本机，由本机统一向上游转发，
        链路中不再出现明文 DNS，也便于对全局流量做统一拦截与审计。
      </p>
      <button
        type="button"
        class="app-btn-secondary app-btn-compact shrink-0"
        :disabled="loading || saving"
        @click="loadData(true)"
      >
        <M3Icon name="refresh" :size="13" />
        <span>刷新</span>
      </button>
    </div>

    <InlineAlert v-if="loadError" type="error" :message="loadError" />

    <template v-if="status">
      <CertificateCard
        :status="status"
        :saving="saving"
        @changed="onChanged"
        @success="(m: string) => showToast(m)"
        @error="(m: string) => showToast(m, true)"
      />
      <EncryptedListenersCard
        :status="status"
        @changed="onChanged"
        @saving="(v: boolean) => (saving = v)"
        @success="(m: string) => showToast(m)"
        @error="(m: string) => showToast(m, true)"
      />
      <ClientIDCard :status="status" />
      <DDRCard
        :status="status"
        @changed="onChanged"
        @saving="(v: boolean) => (saving = v)"
        @success="(m: string) => showToast(m)"
        @error="(m: string) => showToast(m, true)"
      />
    </template>

    <div v-else-if="loading" class="app-card p-8 text-center text-xs text-text-muted">正在读取加密 DNS 服务配置…</div>
  </div>
</template>
