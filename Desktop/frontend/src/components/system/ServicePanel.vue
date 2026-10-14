<script setup lang="ts">
import { computed, ref, onMounted } from 'vue';
import { ipc } from '../../api/ipc';
import M3Icon from '../M3Icon.vue';
import AppCard from '../ui/AppCard.vue';
import StatusBadge from '../StatusBadge.vue';
import ToastBanner from '../ToastBanner.vue';
import CoreServiceCard from '../CoreServiceCard.vue';
import CopyRow from '../ui/CopyRow.vue';
import { revertSwitch, extractSwitchValue } from '../../utils/switch';
import type { AutoStartStatus } from '../../api/types';
import { isWebMode } from '../../utils/env';
import { usePlatform } from '../../composables/usePlatform';
import { useToast } from '../../composables/useToast';

const webMode = isWebMode();
const { isLinux } = usePlatform();

// Linux Web 控制台：服务自启由 systemd 托管，无桌面端可操作，改为说明文案
const linuxAutostartInfo = computed(() => isLinux.value && webMode);
const autostartSubtitle = computed(() =>
  isLinux.value ? 'systemd 服务自启托管' : 'Windows 用户登录自启配置'
);
const { toast, show: showToast, dismiss } = useToast();
const host = ref('127.0.0.1');
const port = ref('15353');
const token = ref('');
const testingConnection = ref(false);
const connResult = ref<{ success: boolean; message: string } | null>(null);

// 开机自启状态
const autostart = ref(false);
const togglingAutostart = ref(false);
/** 宿主机实际生效的自启托管信息（Web 模式下由服务端上报） */
const autostartStatus = ref<AutoStartStatus | null>(null);

async function checkAutostart() {
  try {
    const st = await ipc.getAutoStartStatus();
    autostartStatus.value = st;
    autostart.value = st.enabled;
  } catch {}
}

/** 自启托管状态文案：区分系统服务托管与用户登录自启 */
const autostartStateText = computed(() => {
  if (!autostart.value) return '未配置开机启动';

  switch (autostartStatus.value?.mechanism) {
    case 'service':
    case 'systemd':
      return '✔ 已由系统服务托管自启';
    case 'xdg':
      return '✔ 已加入桌面登录启动项';
    case 'login_item':
      return '✔ 已加入 Windows 启动项';
    default:
      return '✔ 已配置开机自启';
  }
});

const autostartDetail = computed(
  () => autostartStatus.value?.detail || '可通过此处随时开启或关闭，无需手动配置注册表或任务计划。'
);

async function handleToggleAutostart(e: Event) {
  const enable = extractSwitchValue(e);
  togglingAutostart.value = true;
  try {
    autostart.value = await ipc.setAutoStart(enable);
    showToast(`开机自启已${enable ? '开启' : '关闭'}`);
  } catch (err: any) {
    showToast(`设置开机自启失败: ${err.message}`, true);
    revertSwitch(e, !enable);
  } finally {
    togglingAutostart.value = false;
  }
}

function loadSettings() {
  const cfg = ipc.getConfig();
  host.value = cfg.host;
  port.value = cfg.port;
  token.value = cfg.token;
  checkAutostart();
}

async function testConnection() {
  testingConnection.value = true;
  connResult.value = null;
  ipc.saveConfig(host.value, port.value, token.value);
  try {
    const ok = await ipc.checkHealth();
    if (ok) {
      connResult.value = { success: true, message: '成功连接后台核心服务' };
    } else {
      connResult.value = { success: false, message: '无法连接到后台服务，请确认核心服务已启动' };
    }
  } catch (err: any) {
    connResult.value = { success: false, message: err.message || '连接失败' };
  } finally {
    testingConnection.value = false;
  }
}

function handleSaveIPC() {
  ipc.saveConfig(host.value, port.value, token.value);
  testConnection();
}

onMounted(() => {
  loadSettings();
});
</script>

<template>
  <div class="space-y-5 select-none">
    <!-- 全局消息提示横幅 -->
    <ToastBanner
      v-if="toast"
      :message="toast.message"
      :type="toast.isError ? 'error' : 'success'"
      dismissible
      @dismiss="dismiss"
    />

    <!-- 两列响应式卡片网格 (宽屏两列，窄屏单列) -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-5 items-stretch">
      <!-- 1. IPC 通信配置卡片 -->
      <AppCard
        title="后台服务连接设置"
        subtitle="前端客户端与核心服务的通信管道"
        icon="sync"
      >
        <template #actions>
          <StatusBadge
            :status="connResult?.success ? 'active' : connResult ? 'error' : 'inactive'"
            :text="connResult?.success ? '通信正常' : connResult ? '连接异常' : '已配置'"
            size="sm"
          />
        </template>

        <div class="space-y-3 mt-3">
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <md-outlined-text-field
              label="服务地址 (IP 或主机名)"
              :value="host"
              @input="host = ($event.target as any).value"
              class="w-full"
            ></md-outlined-text-field>

            <md-outlined-text-field
              label="通信端口"
              :value="port"
              @input="port = ($event.target as any).value"
              class="w-full font-mono"
            ></md-outlined-text-field>
          </div>

          <md-outlined-text-field
            label="访问密钥 / 授权 Token (可选)"
            :value="token"
            @input="token = ($event.target as any).value"
            type="password"
            placeholder="留空表示本机无需密码"
            class="w-full"
          ></md-outlined-text-field>
        </div>

        <template #footer>
          <div class="flex items-center justify-between">
            <div v-if="connResult" class="text-[11px] font-medium flex items-center gap-1.5 truncate max-w-[180px]" :class="connResult.success ? 'text-status-success' : 'text-status-error'">
              <M3Icon :name="connResult.success ? 'check_circle' : 'error'" :size="14" />
              <span class="truncate">{{ connResult.message }}</span>
            </div>
            <div v-else />

            <div class="flex items-center gap-2">
              <button
                type="button"
                @click="testConnection"
                :disabled="testingConnection"
                class="app-btn-secondary app-btn-compact"
              >
                <M3Icon name="sync" :size="14" :class="testingConnection ? 'animate-spin' : ''" />
                <span>测试连接</span>
              </button>
              <button
                type="button"
                @click="handleSaveIPC"
                class="app-btn-primary app-btn-compact"
              >
                <M3Icon name="check" :size="14" />
                <span>保存配置</span>
              </button>
            </div>
          </div>
        </template>
      </AppCard>

      <!-- 2. 后台核心服务管理卡片 -->
      <CoreServiceCard />

      <!-- 3. 开机自启托管卡片（Windows 桌面 / Linux systemd） -->
      <AppCard
        title="开机自动启动"
        :subtitle="autostartSubtitle"
        icon="power_settings_new"
      >
        <template #actions>
          <span v-if="linuxAutostartInfo" class="text-[11px] text-text-muted bg-surface-card-sub px-2 py-0.5 rounded border border-surface-border-sub">systemd 托管</span>
          <span v-else-if="webMode" class="text-[11px] text-text-muted bg-surface-card-sub px-2 py-0.5 rounded border border-surface-border-sub">宿主机桌面生效</span>
          <div v-else class="flex items-center gap-2">
            <span class="text-[11px] font-semibold text-text-sub hidden sm:inline">
              {{ autostart ? '自启已开启' : '未开启' }}
            </span>
            <md-switch
              :selected="autostart"
              :disabled="togglingAutostart"
              @change="handleToggleAutostart"
            />
          </div>
        </template>

        <!-- Linux Web 控制台：systemd 托管说明（不可在此直接操作） -->
        <div v-if="linuxAutostartInfo" class="space-y-3 mt-3 text-xs text-text-sub leading-relaxed">
          <p>
            宿主机上的谛听核心服务由 systemd 托管，无需依赖图形桌面登录即可启动。
          </p>
          <div class="app-card-sub p-3 space-y-2">
            <div class="flex items-center justify-between">
              <span class="text-[11px] font-semibold text-text-main">系统自启托管状态</span>
              <span class="font-semibold text-[12px]" :class="autostart ? 'text-status-success' : 'text-text-muted'">
                {{ autostartStateText }}
              </span>
            </div>
            <p class="text-[11px] text-text-muted">{{ autostartDetail }}</p>
          </div>
          <div class="app-card-sub p-3 space-y-2">
            <div class="text-[11px] font-semibold text-text-main">查看自启状态</div>
            <CopyRow text="systemctl is-enabled diting-dnsservice" tag="Shell" tagType="ipv4" />
            <p class="text-[11px] text-text-muted">
              返回 <span class="font-mono">enabled</span> 表示已加入开机自启；如需调整，请在宿主机以 root 执行
              <span class="font-mono">systemctl enable/disable diting-dnsservice</span>。
            </p>
          </div>
        </div>

        <div v-else class="space-y-3 mt-3 text-xs text-text-sub leading-relaxed">
          <p v-if="webMode">
            以下为宿主机实际生效的开机自启托管情况。Web 控制台无法直接修改宿主机的系统服务或注册表配置。
          </p>
          <p v-else>
            在 Windows 系统开机登录后自动启动桌面应用，确保 DNS 拦截、加速和物理网卡保护持续稳定运行。
          </p>
          <div class="app-card-sub p-3 space-y-1">
            <div class="flex items-center justify-between">
              <span class="text-[11px] font-semibold text-text-main">系统自启托管状态</span>
              <span class="font-semibold text-[12px]" :class="autostart ? 'text-status-success' : 'text-text-muted'">
                {{ autostartStateText }}
              </span>
            </div>
            <p class="text-[11px] text-text-muted">
              {{ autostartDetail }}
            </p>
          </div>
        </div>

        <template #footer>
          <div class="text-[11px] text-text-muted">
            <template v-if="linuxAutostartInfo">
              提示：systemd 服务自启随系统启动，先于用户登录，确保 DNS 防护不中断。
            </template>
            <template v-else>
              提示：若同时安装了系统后台服务，核心服务将随 Windows 启动优先就绪。
            </template>
          </div>
        </template>
      </AppCard>
    </div>
  </div>
</template>
