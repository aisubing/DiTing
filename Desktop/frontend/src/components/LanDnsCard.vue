<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import { ipc } from '../api/ipc';
import type { LANStatusResponse } from '../api/types';
import M3Icon from './M3Icon.vue';
import StatusBadge from './StatusBadge.vue';
import ToastBanner from './ToastBanner.vue';
import AppCard from './ui/AppCard.vue';
import CopyRow from './ui/CopyRow.vue';
import InlineAlert from './ui/InlineAlert.vue';
import { revertSwitch, extractSwitchValue } from '../utils/switch';
import { useFlashMessage } from '../composables/useFlashMessage';
import { usePlatform } from '../composables/usePlatform';

const loading = ref(false);
const toggling = ref(false);
const togglingFw = ref(false);
const lanStatus = ref<LANStatusResponse | null>(null);

const { successMessage, errorMessage, flashSuccess } = useFlashMessage(4000);
const { isLinux } = usePlatform();

const allowLAN = computed(() => Boolean(lanStatus.value?.allowLAN));
const lanAddresses = computed(() => lanStatus.value?.lanAddresses || []);
const firewallAllowed = computed(() => Boolean(lanStatus.value?.firewallAllowed));

/**
 * 防火墙后端判定：仅当后端明确为 "none"（系统未安装任何防火墙管理器）时，
 * 视为无需放行；空串或未知值一律按“支持”处理，避免旧响应下误隐藏放行按钮。
 */
const firewallBackend = computed(() => lanStatus.value?.firewallBackend || '');
const firewallSupported = computed(() => firewallBackend.value !== 'none');

/** 防火墙后端副题：无后端 / Windows Defender / Linux 实际探测到的后端 */
const firewallSubtitle = computed(() => {
  if (!firewallSupported.value) return '未检测到系统防火墙后端';
  if (isLinux.value) {
    const backend = firewallBackend.value || 'firewalld / ufw / nftables';
    return `防火墙端口安全规则托管（${backend}）`;
  }
  return 'Windows Defender 端口安全规则托管';
});

async function loadData() {
  loading.value = true;
  errorMessage.value = '';
  try {
    lanStatus.value = await ipc.getLANStatus();
  } catch (err: any) {
    errorMessage.value = err.message || '加载局域网 DNS 服务状态失败';
  } finally {
    loading.value = false;
  }
}

async function handleToggleLAN(e: Event) {
  const enable = extractSwitchValue(e);
  toggling.value = true;
  errorMessage.value = '';

  try {
    await ipc.configureLAN({
      allowLAN: enable,
      configureFirewall: true,
    });
    flashSuccess(
      enable
        ? '局域网 DNS 服务器已成功开启！局域网内其他设备现可填入本机 IP 使用。'
        : '已关闭局域网 DNS 服务，恢复为仅本机 (127.0.0.1) 监听。'
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
    const msg = await ipc.configureFirewall(nextState);
    flashSuccess(msg || (nextState ? '已放行防火墙 53 端口' : '已关闭防火墙放行'), 3000);
    await loadData();
  } catch (err: any) {
    errorMessage.value = `配置防火墙失败: ${err.message}`;
  } finally {
    togglingFw.value = false;
  }
}

onMounted(() => {
  loadData();
});
</script>

<template>
  <div class="space-y-5 select-none">
    <!-- 消息提示栏 -->
    <ToastBanner v-if="successMessage" :message="successMessage" type="success" compact />
    <ToastBanner v-if="errorMessage" :message="errorMessage" type="error" compact dismissible @dismiss="errorMessage = ''" />

    <!-- 宽屏两列卡片网格，窄屏单列 -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-5 items-stretch">
      <!-- 1. 局域网 DNS 服务控制与 IP 地址卡片 -->
      <AppCard
        title="局域网 DNS 服务"
        subtitle="提供 AdGuard Home 兼容的局域网中心解析"
        icon="router"
      >
        <template #badge>
          <StatusBadge
            :status="allowLAN ? 'active' : 'inactive'"
            :text="allowLAN ? '全网监听 (0.0.0.0)' : '仅本机模式'"
            size="sm"
          />
        </template>

        <template #actions>
          <span class="text-[11px] font-semibold text-text-sub hidden sm:inline">
            {{ allowLAN ? '服务已激活' : '已关闭' }}
          </span>
          <md-switch
            :selected="allowLAN"
            :disabled="toggling || loading"
            @change="handleToggleLAN"
          />
        </template>

        <p class="text-[12px] text-text-sub leading-relaxed mt-3">
          开启后，局域网设备（路由器、手机、平板、NAS）可将首选 DNS 设为本机 IP，共享加速与拦截。
        </p>

        <!-- IP 地址列表 -->
        <div class="mt-3.5 space-y-2">
          <div class="flex items-center justify-between">
            <span class="text-[11px] font-bold text-text-main">本机可用的局域网 DNS 地址</span>
            <button
              type="button"
              @click="loadData"
              :disabled="loading"
              class="app-btn-secondary app-btn-compact"
              title="刷新本机网卡 IP"
            >
              <M3Icon name="refresh" :size="13" :class="loading ? 'animate-spin' : ''" />
              <span>刷新 IP</span>
            </button>
          </div>

          <div v-if="lanAddresses.length > 0" class="space-y-1.5 pt-1">
            <CopyRow
              v-for="ip in lanAddresses"
              :key="ip"
              :text="ip"
              :tag="ip.includes(':') ? 'IPv6' : 'IPv4 首选'"
              :tagType="ip.includes(':') ? 'ipv6' : 'ipv4'"
            />
          </div>
          <div v-else class="text-xs text-text-muted italic py-3 text-center">
            未检测到物理活动网卡 IP，请确认已连接 Wi-Fi 或以太网。
          </div>
        </div>
      </AppCard>

      <!-- 2. 防火墙入站状态与放行控制卡片（Windows Defender / firewalld·ufw·nftables） -->
      <AppCard
        title="防火墙入站放行"
        :subtitle="firewallSubtitle"
        icon="shield"
      >
        <template #badge>
          <span
            class="px-2 py-0.5 rounded-full text-[10px] font-bold"
            :class="!firewallSupported
              ? 'bg-surface-card-sub text-text-muted'
              : (firewallAllowed ? 'bg-status-success-bg text-status-success' : 'bg-status-warning-bg text-status-warning')"
          >
            {{ !firewallSupported ? '无需放行' : (firewallAllowed ? '53 端口已放行' : '未放行') }}
          </span>
        </template>

        <div class="space-y-3 mt-3 text-[12px] text-text-sub leading-relaxed">
          <p>
            局域网外部设备需通过 UDP/TCP 53 端口向本机发送 DNS 解析请求。
          </p>
          <p>
            如果系统防火墙拦截了 53 端口入站流量，手机或路由器将无法连通本机并导致断网。点击下方按钮可由系统自动添加或移除安全放行规则。
          </p>

          <InlineAlert v-if="!firewallSupported" type="info">
            系统未检测到防火墙后端（firewalld / ufw / nftables / iptables），53 端口已直接对外开放，无需放行规则。
          </InlineAlert>

          <div v-else class="app-card-sub p-3 flex items-center justify-between gap-3">
            <div>
              <span class="text-[11px] text-text-muted block">入站规则状态</span>
              <span class="font-semibold text-text-main text-[12px] mt-0.5 block">
                {{ firewallAllowed ? '允许局域网设备接入 53 端口' : '53 端口受限或被拦截' }}
              </span>
            </div>
            <M3Icon
              :name="firewallAllowed ? 'check_circle' : 'warning'"
              :size="20"
              :class="firewallAllowed ? 'text-status-success' : 'text-status-warning'"
            />
          </div>
        </div>

        <template v-if="firewallSupported" #footer>
          <button
            type="button"
            @click="handleToggleFirewall"
            :disabled="togglingFw"
            class="w-full"
            :class="firewallAllowed ? 'app-btn-secondary' : 'app-btn-primary'"
          >
            <M3Icon v-if="togglingFw" name="sync" :size="14" class="animate-spin" />
            <M3Icon v-else :name="firewallAllowed ? 'block' : 'verified_user'" :size="14" />
            <span>{{ firewallAllowed ? '移除防火墙入站放行' : '一键放行入站 53 端口' }}</span>
          </button>
        </template>
      </AppCard>

      <!-- 3. 方案 A：路由器全局配置卡片 (强烈推荐) -->
      <AppCard
        title="方案 A：路由器全局配置"
        icon="wifi"
      >
        <template #badge>
          <span class="px-2 py-0.5 rounded-full text-[10px] font-bold bg-accent-seal text-white">
            强烈推荐
          </span>
        </template>

        <div class="space-y-2 mt-3 text-xs text-text-sub leading-relaxed">
          <p>
            登录家用路由器后台管理页面（通常为 <code class="font-mono bg-surface-card-sub px-1 py-0.5 rounded text-text-main">192.168.1.1</code> 或 <code class="font-mono bg-surface-card-sub px-1 py-0.5 rounded text-text-main">192.168.0.1</code>）。
          </p>
          <p>
            进入「局域网 LAN 设置」或「DHCP 服务器」，将「主 DNS 服务器」修改为本机局域网 IP：
          </p>
          <CopyRow
            v-if="lanAddresses[0]"
            :text="lanAddresses[0]"
          />
          <div v-else class="app-card-sub p-2.5 font-mono text-[12px] font-bold text-text-main">
            192.168.x.x
          </div>
          <p class="text-[11px] text-text-muted">
            保存并重启路由器或手机 Wi-Fi，全屋所有设备即可统一生效，享受广告拦截与极速解析！
          </p>
        </div>
      </AppCard>

      <!-- 4. 方案 B：手机与电脑单机独立配置卡片 -->
      <AppCard
        title="方案 B：单终端独立配置"
        icon="devices"
      >
        <template #badge>
          <span class="px-2 py-0.5 rounded-full text-[10px] font-semibold bg-surface-card-sub text-text-sub border border-surface-border-sub">
            独立体验
          </span>
        </template>

        <div class="space-y-2 mt-3 text-xs text-text-sub leading-relaxed">
          <p>
            在目标手机、平板或电脑的 Wi-Fi 设置中，找到当前连接的 Wi-Fi 网络详情。
          </p>
          <p>
            将「IP 设置」从 DHCP 切换为「静态 / 手动」，在「DNS 1」输入本机局域网 IP：
          </p>
          <CopyRow
            v-if="lanAddresses[0]"
            :text="lanAddresses[0]"
          />
          <div v-else class="app-card-sub p-2.5 font-mono text-[12px] font-bold text-text-main">
            192.168.x.x
          </div>
          <p class="text-[11px] text-text-muted">
            适用于不具备路由器管理权限，或仅希望特定设备单独体验谛听防护效果的使用场景。
          </p>
        </div>
      </AppCard>
    </div>
  </div>
</template>
