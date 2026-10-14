<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue';
import QRCode from 'qrcode';
import { ipc } from '../api/ipc';
import type { WebStatusResponse } from '../api/types';
import M3Icon from './M3Icon.vue';
import StatusBadge from './StatusBadge.vue';
import ToastBanner from './ToastBanner.vue';
import AppCard from './ui/AppCard.vue';
import CopyRow from './ui/CopyRow.vue';
import LoginModal from './LoginModal.vue';
import { revertSwitch, extractSwitchValue } from '../utils/switch';
import { validatePort } from '../utils/validators';
import { useFlashMessage } from '../composables/useFlashMessage';

const loading = ref(false);
const toggling = ref(false);
const togglingFw = ref(false);
const webStatus = ref<WebStatusResponse | null>(null);
const showPasswordModal = ref(false);
const selectedQrUrl = ref<string>('');
const qrDataUrl = ref<string>('');
const isEditingPort = ref(false);
const customPort = ref('15353');

const { successMessage, errorMessage, flashSuccess } = useFlashMessage(3000);

const isEnabled = computed(() => !!webStatus.value?.enabled);
const webUrls = computed(() => webStatus.value?.webUrls || []);
const firewallAllowed = computed(() => !!webStatus.value?.firewallAllowed);
const adminUser = computed(() => webStatus.value?.username || 'admin');
const isInitialized = computed(() => !!webStatus.value?.initialized);

/**
 * 防火墙后端判定：仅当后端明确为 "none"（系统未安装任何防火墙管理器）时，
 * 视为无需放行；空串或未知值一律按“支持”处理，避免旧响应下误隐藏放行按钮。
 */
const firewallSupported = computed(() => (webStatus.value?.firewallBackend || '') !== 'none');

async function loadData() {
  loading.value = true;
  errorMessage.value = '';
  try {
    const data = await ipc.getWebStatus();
    webStatus.value = data;
    customPort.value = String(data.port || 15353);
    if (data.webUrls && data.webUrls.length > 0) {
      selectedQrUrl.value = data.webUrls[0] || '';
      generateQR(data.webUrls[0] || '');
    }
  } catch (err: any) {
    errorMessage.value = err.message || '加载局域网 Web 状态失败';
  } finally {
    loading.value = false;
  }
}

async function generateQR(url: string) {
  if (!url) {
    qrDataUrl.value = '';
    return;
  }
  try {
    qrDataUrl.value = await QRCode.toDataURL(url, {
      width: 160,
      margin: 1,
      color: {
        dark: '#1A1A1C',
        light: '#FFFFFF',
      },
    });
  } catch (e) {
    console.warn('生成二维码失败:', e);
  }
}

watch(selectedQrUrl, (newUrl) => {
  generateQR(newUrl);
});

async function handleToggleWeb(e: Event) {
  const enable = extractSwitchValue(e);
  toggling.value = true;
  errorMessage.value = '';

  const portNum = parseInt(customPort.value, 10) || 15353;

  try {
    await ipc.configureWeb({
      enabled: enable,
      port: portNum,
      configureFirewall: true,
    });
    flashSuccess(
      enable
        ? '局域网 Web 远程管理已成功开启！局域网其他设备现可通过浏览器访问。'
        : '已关闭局域网 Web 管理，服务恢复为仅限本地 (127.0.0.1) 通信。',
      4000
    );
    await loadData();
  } catch (err: any) {
    errorMessage.value = `操作失败: ${err.message}`;
    revertSwitch(e, !enable);
  } finally {
    toggling.value = false;
  }
}

async function handleToggleFirewall() {
  // 系统未检测到防火墙后端时端口本就对外开放，无规则可配置
  if (!firewallSupported.value) return;
  togglingFw.value = true;
  errorMessage.value = '';
  try {
    const nextState = !firewallAllowed.value;
    const msg = await ipc.configureWebFirewall(nextState);
    flashSuccess(msg || (nextState ? '已放行防火墙 Web 端口' : '已关闭防火墙放行'));
    await loadData();
  } catch (err: any) {
    errorMessage.value = `配置防火墙失败: ${err.message}`;
  } finally {
    togglingFw.value = false;
  }
}

async function handleSavePort() {
  if (!validatePort(customPort.value)) {
    errorMessage.value = '请输入有效的端口号 (1-65535)';
    return;
  }
  const portNum = parseInt(customPort.value, 10);
  isEditingPort.value = false;
  try {
    await ipc.configureWeb({
      enabled: isEnabled.value,
      port: portNum,
      configureFirewall: true,
    });
    flashSuccess(`Web 端口已成功更新为 ${portNum}`);
    await loadData();
  } catch (err: any) {
    errorMessage.value = `保存端口失败: ${err.message}`;
  }
}

onMounted(() => {
  loadData();
});
</script>

<template>
  <AppCard
    title="局域网 Web 控制台"
    subtitle="通过手机、平板或局域网浏览器远程管理"
    icon="web"
  >
    <template #badge>
      <StatusBadge
        :status="isEnabled ? 'active' : 'inactive'"
        :text="isEnabled ? '对外开放中' : '仅本地 (127.0.0.1)'"
        :pulse="isEnabled"
        size="sm"
      />
    </template>

    <template #actions>
      <span class="text-[11px] font-semibold text-text-sub hidden sm:inline">
        {{ isEnabled ? '远程管理开启' : '已关闭' }}
      </span>
      <md-switch
        :selected="isEnabled"
        :disabled="loading || toggling"
        @change="handleToggleWeb"
      />
    </template>

    <p v-if="!isEnabled" class="text-[12px] text-text-sub leading-relaxed mt-1">
      开启后，局域网内的手机或电脑可通过浏览器访问完整控制台进行远程管理，与桌面客户端共享核心数据与配置同步。
    </p>

    <!-- 成功与错误反馈横幅 -->
    <div v-if="successMessage || errorMessage" class="space-y-2 mt-2">
      <ToastBanner v-if="successMessage" :message="successMessage" type="success" compact dismissible @dismiss="successMessage = ''" />
      <ToastBanner v-if="errorMessage" :message="errorMessage" type="error" compact dismissible @dismiss="errorMessage = ''" />
    </div>

    <!-- 展开详情面板 (当开启 Web 远程管理时) -->
    <div v-if="isEnabled" class="space-y-3 pt-2">
      <!-- 1. 局域网访问地址列表 -->
      <div class="space-y-2">
        <div class="flex items-center justify-between text-xs">
          <span class="font-bold text-text-main flex items-center gap-1.5">
            <M3Icon name="link" :size="15" class="text-text-main" />
            局域网访问网址 (浏览器直连)
          </span>
          <span class="text-[11px] text-text-muted font-mono">
            端口: {{ webStatus?.port || 15353 }}
          </span>
        </div>

        <div v-if="webUrls.length === 0" class="p-3 rounded-md bg-surface-card-sub text-center text-xs text-text-sub">
          未探测到可用的局域网网卡 IPv4 地址
        </div>
        <div v-else class="space-y-1.5">
          <CopyRow
            v-for="url in webUrls"
            :key="url"
            :text="url"
            showDot
            :openUrl="url"
          />
        </div>
      </div>

      <!-- 2. 管理员凭据与扫码直达 (并排 2 列磁贴) -->
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
        <!-- 账号安全凭据 -->
        <div class="app-card-sub p-3 flex flex-col justify-between gap-2">
          <div>
            <div class="flex items-center gap-1.5 text-xs font-bold text-text-main">
              <M3Icon name="key" :size="15" class="text-text-main" />
              <span>控制台凭据</span>
            </div>
            <div class="mt-2 space-y-0.5">
              <div class="text-[11px] text-text-muted">管理员用户名:</div>
              <div class="font-mono text-[13px] font-bold text-text-main">{{ adminUser }}</div>
              <p class="text-[10px] text-text-muted leading-tight mt-0.5">
                {{ isInitialized ? '密码保护已启用，安全守护' : '尚未初始化密码，首次进入设置' }}
              </p>
            </div>
          </div>

          <button
            type="button"
            @click="showPasswordModal = true"
            class="app-btn-secondary app-btn-compact w-full"
          >
            <M3Icon name="lock_reset" :size="13" />
            <span>{{ isInitialized ? '修改管理员密码' : '设置初始密码' }}</span>
          </button>
        </div>

        <!-- 手机快速扫码 -->
        <div class="app-card-sub p-3 flex flex-col items-center justify-center text-center gap-1.5">
          <div class="p-1 rounded bg-white border border-surface-border shrink-0">
            <img
              v-if="qrDataUrl"
              :src="qrDataUrl"
              alt="手机扫码二维码"
              class="w-20 h-20 block"
            />
            <div v-else class="w-20 h-20 flex items-center justify-center text-text-muted text-[10px]">
              加载中...
            </div>
          </div>
          <span class="text-[10px] text-text-muted leading-tight">
            手机同一 Wi-Fi 相机扫码直达
          </span>
        </div>
      </div>

      <!-- 3. 防火墙状态与端口调整 (双列磁贴) -->
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-2.5 pt-1 border-t border-surface-border-sub">
        <!-- 防火墙规则 -->
        <div class="app-card-sub p-2.5 flex items-center justify-between gap-2">
          <div class="min-w-0">
            <div class="flex items-center gap-1.5">
              <span class="text-[11px] font-bold text-text-main">防火墙</span>
              <StatusBadge
                :status="!firewallSupported ? 'inactive' : (firewallAllowed ? 'active' : 'warning')"
                :text="!firewallSupported ? '无需放行' : (firewallAllowed ? '已放行' : '未放行')"
                size="sm"
              />
            </div>
            <span class="text-[10px] text-text-muted font-mono block truncate">TCP {{ webStatus?.port || 15353 }}</span>
          </div>

          <button
            v-if="firewallSupported"
            type="button"
            @click="handleToggleFirewall"
            :disabled="togglingFw"
            class="app-btn-secondary app-btn-compact shrink-0"
          >
            <M3Icon :name="firewallAllowed ? 'block' : 'shield'" :size="13" />
            <span>{{ firewallAllowed ? '取消放行' : '一键放行' }}</span>
          </button>
        </div>

        <!-- 端口设置 -->
        <div class="app-card-sub p-2.5 flex items-center justify-between gap-2">
          <div class="min-w-0">
            <span class="text-[11px] font-bold text-text-main block">通信端口</span>
            <span class="text-[10px] text-text-muted font-mono block truncate">当前: {{ webStatus?.port || 15353 }}</span>
          </div>

          <div v-if="!isEditingPort" class="shrink-0">
            <button
              type="button"
              @click="isEditingPort = true"
              class="app-btn-secondary app-btn-compact"
            >
              <M3Icon name="tune" :size="13" />
              <span>修改端口</span>
            </button>
          </div>
          <div v-else class="flex items-center gap-1 shrink-0">
            <input
              type="number"
              v-model="customPort"
              class="w-16 px-1.5 py-0.5 text-xs font-mono rounded border border-surface-border bg-surface-card text-text-main focus:outline-none focus:border-accent-seal"
            />
            <button
              type="button"
              @click="handleSavePort"
              class="app-btn-primary app-btn-compact"
            >
              保存
            </button>
          </div>
        </div>
      </div>

      <!-- 无防火墙后端时的说明：端口本就对外开放，无需放行 -->
      <p v-if="!firewallSupported" class="text-[10px] text-text-muted leading-relaxed">
        系统未检测到防火墙后端（firewalld / ufw / nftables / iptables），端口已直接对外开放，无需放行。
      </p>
    </div>
  </AppCard>

  <!-- 弹窗：设置 / 修改管理员密码 -->
  <LoginModal
    :open="showPasswordModal"
    :mode="isInitialized ? 'change_password' : 'setup'"
    @close="showPasswordModal = false"
    @success="loadData"
  />
</template>
