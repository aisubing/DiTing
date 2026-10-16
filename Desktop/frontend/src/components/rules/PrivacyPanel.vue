<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { ipc } from '../../api/ipc';
import type { StatusResponse, ECSConfig, RebindConfig, HostsConfig } from '../../api/types';
import M3Icon from '../M3Icon.vue';
import AppCard from '../ui/AppCard.vue';
import AppModal from '../AppModal.vue';
import StatusBadge from '../StatusBadge.vue';
import SafeSearchCard from './SafeSearchCard.vue';
import AnyQueryCard from './AnyQueryCard.vue';
import SafeBrowsingCard from './SafeBrowsingCard.vue';
import ParentalControlCard from './ParentalControlCard.vue';
import ToastBanner from '../ToastBanner.vue';
import { extractSwitchValue } from '../../utils/switch';
import { useToast } from '../../composables/useToast';

const status = ref<StatusResponse | null>(null);
const loading = ref(false);
const saving = ref(false);

// 协议增强与隐私状态
const enableEDE = ref(true);
const blockPrivatePTR = ref(true);
const blockUnqualified = ref(false);
const blockECH = ref(false);
const blockIPv6 = ref(false);
const blockANY = ref(false);
const blockANYMode = ref('notimp');
const ednsPadding = ref(128);

// ECS 策略状态
const ecsConfig = ref<ECSConfig>({
  enabled: true,
  stripECS: true,
  customSubnet: '',
});

// Rebind 与 Hosts 状态展示与配置
const rebindConfig = ref<RebindConfig>({
  enabled: true,
  allowedDomains: [],
});
const isRebindModalOpen = ref(false);
const rebindDomainsText = ref('');

const hostsConfig = ref<HostsConfig>({
  enabled: true,
  useSystemHost: true,
  customFiles: [],
  ttl: 60,
});

const { toast, show: showToast, dismiss } = useToast();

async function loadData() {
  loading.value = true;
  try {
    const st = await ipc.getStatus();
    if (st) {
      status.value = st;
      enableEDE.value = st.dns?.enableEDE ?? true;
      blockPrivatePTR.value = st.dns?.blockPrivatePTR ?? true;
      blockUnqualified.value = st.dns?.blockUnqualified ?? false;
      blockECH.value = st.dns?.blockECH ?? false;
      blockIPv6.value = st.dns?.blockIPv6 ?? false;
      blockANY.value = st.dns?.blockANY ?? false;
      blockANYMode.value = st.dns?.blockANYMode || 'notimp';
      ednsPadding.value = st.dns?.ednsPadding ?? 128;

      if (st.ecs) {
        ecsConfig.value = st.ecs;
      }
      if (st.rebind) {
        rebindConfig.value = st.rebind;
      }
      if (st.hosts) {
        hostsConfig.value = st.hosts;
      }
    }
  } catch (err: any) {
    showToast(err.message || '加载安全隐私配置失败', true);
  } finally {
    loading.value = false;
  }
}

async function handleToggleEDE(e: Event) {
  const nextVal = extractSwitchValue(e);
  enableEDE.value = nextVal;
  await savePrivacyConfig();
}

async function handleTogglePrivatePTR(e: Event) {
  const nextVal = extractSwitchValue(e);
  blockPrivatePTR.value = nextVal;
  await savePrivacyConfig();
}

async function handleToggleIPv6(e: Event) {
  const nextVal = extractSwitchValue(e);
  blockIPv6.value = nextVal;
  await savePrivacyConfig();
}

async function handleToggleECH(e: Event) {
  const nextVal = extractSwitchValue(e);
  blockECH.value = nextVal;
  await savePrivacyConfig();
}

async function handleToggleANY(nextVal: boolean) {
  blockANY.value = nextVal;
  await savePrivacyConfig();
}

async function handleANYMode(nextVal: string) {
  blockANYMode.value = nextVal;
  await savePrivacyConfig();
}

async function handlePaddingChange() {
  await savePrivacyConfig();
}

async function savePrivacyConfig() {
  saving.value = true;
  try {
    await ipc.configurePrivacy({
      enableEDE: enableEDE.value,
      blockPrivatePTR: blockPrivatePTR.value,
      blockIPv6: blockIPv6.value,
      blockECH: blockECH.value,
      blockANY: blockANY.value,
      blockANYMode: blockANYMode.value,
      ednsPadding: Number(ednsPadding.value) || 0,
    });
    showToast('隐私保护与协议增强策略已更新并即时生效');
  } catch (err: any) {
    showToast(err.message || '更新隐私配置失败', true);
  } finally {
    saving.value = false;
  }
}

async function handleToggleUnqualified(e: Event) {
  const nextVal = extractSwitchValue(e);
  saving.value = true;
  try {
    await ipc.configureBlockUnqualified({
      blockUnqualified: nextVal,
    });
    blockUnqualified.value = nextVal;
    showToast(`防单标签域名外泄已${nextVal ? '开启' : '关闭'}`);
  } catch (err: any) {
    showToast(err.message || '更新单标签防外泄失败', true);
  } finally {
    saving.value = false;
  }
}

async function handleToggleECSEnabled(e: Event) {
  const nextVal = extractSwitchValue(e);
  ecsConfig.value.enabled = nextVal;
  await saveECSConfig();
}

async function handleToggleECSStrip(e: Event) {
  const nextVal = extractSwitchValue(e);
  ecsConfig.value.stripECS = nextVal;
  await saveECSConfig();
}

async function saveECSConfig() {
  saving.value = true;
  try {
    await ipc.configureECS({
      enabled: ecsConfig.value.enabled,
      stripECS: ecsConfig.value.stripECS,
      customSubnet: (ecsConfig.value.customSubnet || '').trim(),
    });
    showToast('EDNS Client Subnet 客户端子网策略已更新');
  } catch (err: any) {
    showToast(err.message || '更新 ECS 配置失败', true);
  } finally {
    saving.value = false;
  }
}

function openRebindModal() {
  rebindDomainsText.value = (rebindConfig.value.allowedDomains || []).join('\n');
  isRebindModalOpen.value = true;
}

async function handleToggleRebind(e: Event) {
  const nextVal = extractSwitchValue(e);
  rebindConfig.value.enabled = nextVal;
  await saveRebindConfig();
}

async function saveRebindDomains() {
  const list = rebindDomainsText.value
    .split('\n')
    .map((s) => s.trim())
    .filter(Boolean);
  rebindConfig.value.allowedDomains = list;
  await saveRebindConfig();
  isRebindModalOpen.value = false;
}

async function saveRebindConfig() {
  saving.value = true;
  try {
    await ipc.configureRebind({
      enabled: rebindConfig.value.enabled,
      allowedDomains: rebindConfig.value.allowedDomains,
    });
    showToast(`DNS Rebinding 防御配置已成功保存 (状态: ${rebindConfig.value.enabled ? '已开启' : '已关闭'})`);
  } catch (err: any) {
    showToast(err.message || '更新 Rebind 配置失败', true);
  } finally {
    saving.value = false;
  }
}

async function handleToggleHosts(e: Event) {
  const nextVal = extractSwitchValue(e);
  hostsConfig.value.enabled = nextVal;
  await saveHostsConfig();
}

async function handleToggleSystemHost(e: Event) {
  const nextVal = (e.target as HTMLInputElement).checked;
  hostsConfig.value.useSystemHost = nextVal;
  await saveHostsConfig();
}

async function saveHostsConfig() {
  saving.value = true;
  try {
    await ipc.configureHosts({
      enabled: hostsConfig.value.enabled,
      useSystemHost: hostsConfig.value.useSystemHost,
      customFiles: hostsConfig.value.customFiles,
      ttl: hostsConfig.value.ttl,
    });
    showToast(`本地 Hosts 解析配置已更新 (状态: ${hostsConfig.value.enabled ? '已开启' : '已关闭'})`);
  } catch (err: any) {
    showToast(err.message || '更新 Hosts 配置失败', true);
  } finally {
    saving.value = false;
  }
}

onMounted(() => {
  loadData();
});
</script>

<template>
  <div class="space-y-5 select-none">
    <ToastBanner v-if="toast" :message="toast.message" :type="toast.isError ? 'error' : 'success'" dismissible @dismiss="dismiss" />

    <!-- 宽屏两列网格：左侧隐私与协议增强，右侧 ECS 客户端子网 -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-5 items-stretch">
      <!-- 1. 协议隐私与外泄防御卡片 -->
      <AppCard
        title="协议隐私与外泄防御"
        subtitle="阻断局域网私有 PTR 与单标签域名泄露，防御 ECH 加密绕过与报文侧信道嗅探"
        icon="shield"
      >
        <div class="space-y-4 mt-3 text-xs">
          <!-- EDE 错误诊断扩展 -->
          <div class="app-card-sub p-3 space-y-2">
            <div class="flex items-center justify-between">
              <div>
                <span class="font-bold text-text-main text-[13px]">Extended DNS Errors (EDE 错误诊断扩展)</span>
                <span class="text-[10px] text-text-muted ml-2 font-mono">RFC 8914</span>
              </div>
              <md-switch
                :selected="enableEDE"
                :disabled="saving"
                @change="handleToggleEDE"
              />
            </div>
            <p class="text-[11px] text-text-sub leading-relaxed">
              向支持的客户端在 OPT 报文中透明返回 RFC 8914 扩展错误代码与原因说明（如策略阻断、速率超限、Rebind 拦截或上游解析故障），便于网络诊断排错。
            </p>
          </div>

          <!-- 私有 PTR 防泄露 -->
          <div class="app-card-sub p-3 space-y-2">
            <div class="flex items-center justify-between">
              <div>
                <span class="font-bold text-text-main text-[13px]">私有反向 PTR 解析防泄露</span>
                <span class="text-[10px] text-text-muted ml-2 font-mono">RFC 6303 / RFC 7793</span>
              </div>
              <md-switch
                :selected="blockPrivatePTR"
                :disabled="saving"
                @change="handleTogglePrivatePTR"
              />
            </div>
            <p class="text-[11px] text-text-sub leading-relaxed">
              阻断局域网私有 IP（如 <code class="font-mono">192.168.x.x</code>、<code class="font-mono">10.x.x.x</code>、<code class="font-mono">fd00::/8</code>）的反向域名 PTR 查询向公共上游泄露。命中且未在本地绑定的反查将直接返回权威 NXDOMAIN。
            </p>
          </div>

          <!-- 防单标签域名外泄 -->
          <div class="app-card-sub p-3 space-y-2">
            <div class="flex items-center justify-between">
              <div>
                <span class="font-bold text-text-main text-[13px]">阻止无点单标签域名外泄</span>
                <span class="text-[10px] text-text-muted ml-2">Intranet Single-Label</span>
              </div>
              <md-switch
                :selected="blockUnqualified"
                :disabled="saving"
                @change="handleToggleUnqualified"
              />
            </div>
            <p class="text-[11px] text-text-sub leading-relaxed">
              拦截没有顶级域名点分隔的内部单标签请求（如 <code class="font-mono">router</code>、<code class="font-mono">printer</code>），防止因拼写错误或内部搜索域配置缺失导致内网主机名泄漏至公共递归解析器。
            </p>
          </div>

          <!-- ECH 防护 -->
          <div class="app-card-sub p-3 space-y-2">
            <div class="flex items-center justify-between">
              <div>
                <span class="font-bold text-text-main text-[13px]">剥离 ECH (加密 ClientHello)</span>
                <span class="text-[10px] text-text-muted ml-2">Prevent Filter Bypass</span>
              </div>
              <md-switch
                :selected="blockECH"
                :disabled="saving"
                @change="handleToggleECH"
              />
            </div>
            <p class="text-[11px] text-text-sub leading-relaxed">
              从上游 HTTPS / SVCB 资源记录中过滤剥离 <code class="font-mono">ech</code> 参数。防止客户端使用 TLS 1.3 ECH 加密真实访问域名，保障本地防火墙与规则引擎审计不被绕过。
            </p>
          </div>

          <!-- ANY 查询最小化（RFC 8482） -->
          <AnyQueryCard
            :enabled="blockANY"
            :mode="blockANYMode"
            :saving="saving"
            @toggle="handleToggleANY"
            @mode="handleANYMode"
          />

          <!-- IPv6 过滤 / 禁用 -->
          <div class="app-card-sub p-3 space-y-2">
            <div class="flex items-center justify-between">
              <div>
                <span class="font-bold text-text-main text-[13px]">过滤 IPv6 (AAAA) 查询</span>
                <span class="text-[10px] text-text-muted ml-2">IPv4-only 提速</span>
              </div>
              <md-switch
                :selected="blockIPv6"
                :disabled="saving"
                @change="handleToggleIPv6"
              />
            </div>
            <p class="text-[11px] text-text-sub leading-relaxed">
              针对所有 AAAA 查询秒级应答权威 NODATA，并在 HTTPS 查询中自动过滤 ipv6hint。在未开通或 IPv6 较差的网络环境下，彻底消除因双栈握手失败或重试导致的网页加载卡顿。
            </p>
          </div>

          <!-- EDNS Padding -->
          <div class="app-card-sub p-3 flex items-center justify-between gap-3">
            <div>
              <span class="font-bold text-text-main text-[13px] block">EDNS0 报文填充大小</span>
              <span class="text-[11px] text-text-muted mt-0.5 block">
                RFC 7830 / 8467。对加密 DNS (DoT / DoH) 填充至固定块，防范报文长度指纹侧信道分析。
              </span>
            </div>
            <select
              v-model.number="ednsPadding"
              @change="handlePaddingChange"
              :disabled="saving"
              class="h-[32px] px-2.5 rounded-md border border-surface-border bg-surface-card text-xs text-text-main font-mono shrink-0 focus:outline-none focus:border-accent-seal"
            >
              <option :value="0">0 (禁用填充)</option>
              <option :value="128">128 字节 (推荐)</option>
              <option :value="256">256 字节</option>
              <option :value="468">468 字节 (RFC 推荐)</option>
              <option v-if="![0, 128, 256, 468].includes(ednsPadding)" :value="ednsPadding">{{ ednsPadding }} 字节</option>
            </select>
          </div>
        </div>
      </AppCard>

      <!-- 2. EDNS Client Subnet (ECS) 隐私策略卡片 -->
      <AppCard
        title="EDNS Client Subnet (ECS 策略)"
        subtitle="RFC 7871 规范：平衡 CDN 智能就近调度与客户端出口 IP 隐私保护"
        icon="tune"
      >
        <template #badge>
          <StatusBadge
            :status="ecsConfig.enabled ? 'active' : 'inactive'"
            :text="ecsConfig.enabled ? 'ECS 策略已生效' : '策略已停用'"
            size="sm"
          />
        </template>

        <template #actions>
          <md-switch
            :selected="ecsConfig.enabled"
            :disabled="saving"
            @change="handleToggleECSEnabled"
          />
        </template>

        <div class="space-y-4 mt-3 text-xs">
          <p class="text-[12px] text-text-sub leading-relaxed">
            EDNS Client Subnet (ECS) 允许向递归解析器携带客户端所在的 IP 子网网段以优化 CDN 调度。但未经处理的原生 ECS 可能会向上游公共 DNS 泄露家庭或企业内网真实网段。
          </p>

          <!-- 剥离客户端真实子网 -->
          <div class="app-card-sub p-3 space-y-2">
            <div class="flex items-center justify-between">
              <div>
                <span class="font-bold text-text-main text-[13px]">剥离请求中的真实客户端子网</span>
                <span class="text-[10px] text-text-muted ml-2 font-mono">Strip ECS (推荐)</span>
              </div>
              <md-switch
                :selected="ecsConfig.stripECS"
                :disabled="saving || !ecsConfig.enabled"
                @change="handleToggleECSStrip"
              />
            </div>
            <p class="text-[11px] text-text-sub leading-relaxed">
              开启后，谛听在转发 DNS 查询时将主动抹除客户端发送的真实出口子网信息，保障家庭或内网各设备的网络隐私。
            </p>
          </div>

          <!-- 自定义伪装子网 -->
          <div>
            <label class="font-semibold text-text-main block mb-1">
              自定义转发子网 (Custom Subnet CIDR)
            </label>
            <input
              v-model="ecsConfig.customSubnet"
              type="text"
              placeholder="例如: 203.0.113.0/24 (留空表示不追加)"
              :disabled="saving || !ecsConfig.enabled"
              class="w-full h-[34px] px-3 rounded-md border border-surface-border bg-surface-card-sub text-xs text-text-main font-mono focus:outline-none focus:border-accent-seal"
            />
            <span class="text-[10px] text-text-muted mt-1 block">
              可选。填写公共出口网段（如特定云服务或省份网段）向权威 DNS 伪装位置以保持最优 CDN 调度，留空则完全保密。
            </span>
          </div>

          <!-- 保存按钮 -->
          <div class="flex justify-end pt-2">
            <button
              type="button"
              @click="saveECSConfig"
              :disabled="saving || !ecsConfig.enabled"
              class="app-btn-primary"
            >
              <M3Icon name="check" :size="14" />
              <span>保存 ECS 策略</span>
            </button>
          </div>

          <!-- 核心防护状态与配置 (Rebinding & Hosts) -->
          <div class="pt-2 border-t border-surface-border-sub space-y-3">
            <span class="text-[11px] font-bold text-text-muted block">内置安全防御模块配置与运行状态</span>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
              <!-- Rebinding 防御 -->
              <div class="app-card-sub p-3 space-y-2">
                <div class="flex items-center justify-between">
                  <div class="min-w-0">
                    <span class="font-semibold text-text-main text-[12px] block">DNS 重绑定防御</span>
                    <span class="text-[10px] text-text-muted">阻断外网域名解析为私有 IP</span>
                  </div>
                  <md-switch
                    :selected="rebindConfig.enabled"
                    :disabled="saving"
                    @change="handleToggleRebind"
                  />
                </div>
                <div class="flex items-center justify-between pt-1 border-t border-surface-border-sub/60">
                  <span class="text-[10px] font-mono text-text-muted">
                    {{ (rebindConfig.allowedDomains || []).length }} 个白名单域名
                  </span>
                  <button
                    type="button"
                    @click="openRebindModal"
                    :disabled="saving"
                    class="text-[11px] text-accent-seal hover:underline cursor-pointer flex items-center gap-1"
                  >
                    <M3Icon name="settings" :size="12" />
                    <span>白名单设置</span>
                  </button>
                </div>
              </div>

              <!-- Hosts 本地解析 -->
              <div class="app-card-sub p-3 space-y-2">
                <div class="flex items-center justify-between">
                  <div class="min-w-0">
                    <span class="font-semibold text-text-main text-[12px] block">本地 Hosts 解析器</span>
                    <span class="text-[10px] text-text-muted">系统与自定义映射优先应答</span>
                  </div>
                  <md-switch
                    :selected="hostsConfig.enabled"
                    :disabled="saving"
                    @change="handleToggleHosts"
                  />
                </div>
                <div class="flex items-center justify-between pt-1 border-t border-surface-border-sub/60">
                  <label class="flex items-center gap-1.5 cursor-pointer text-[10px] text-text-sub">
                    <input
                      type="checkbox"
                      :checked="hostsConfig.useSystemHost"
                      :disabled="saving || !hostsConfig.enabled"
                      @change="handleToggleSystemHost"
                      class="rounded text-accent-seal focus:ring-0"
                    />
                    <span>联动系统 hosts</span>
                  </label>
                  <span class="text-[10px] font-mono text-text-muted">
                    TTL: {{ hostsConfig.ttl || 60 }}s
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </AppCard>
    </div>

    <!-- 强制安全搜索（独立子卡片，避免本文件继续膨胀） -->
    <SafeSearchCard @error="(m) => showToast(m, true)" @success="(m) => showToast(m)" />

    <!-- 声誉查询：恶意网址库与家长控制（机制相同，各自独立开关） -->
    <SafeBrowsingCard @error="(m) => showToast(m, true)" @success="(m) => showToast(m)" />
    <ParentalControlCard @error="(m) => showToast(m, true)" @success="(m) => showToast(m)" />

    <!-- 弹窗：编辑 Rebinding 白名单域名 -->
    <AppModal
      :open="isRebindModalOpen"
      title="DNS 重绑定防御白名单域名"
      @close="isRebindModalOpen = false"
    >
      <div class="space-y-3 text-xs">
        <p class="text-[11px] text-text-sub leading-relaxed">
          名单内的域名允许解析为局域网私有 IP（如 <code class="font-mono">192.168.x.x</code>、<code class="font-mono">10.x.x.x</code>、<code class="font-mono">127.0.0.1</code>）。支持后缀通配（如 <code class="font-mono">.lan</code>、<code class="font-mono">.local</code>）。每行一个。
        </p>
        <div>
          <label class="font-semibold text-text-main block mb-1">允许的白名单域名</label>
          <textarea
            v-model="rebindDomainsText"
            rows="6"
            placeholder="localhost&#10;.local&#10;.lan&#10;.home.arpa&#10;router.lan"
            class="w-full rounded-md border border-surface-border bg-surface-card-sub p-2.5 font-mono text-xs text-text-main focus:outline-none focus:border-accent-seal"
          ></textarea>
        </div>
      </div>

      <template #footer>
        <div class="flex items-center justify-end gap-2 w-full">
          <button type="button" @click="isRebindModalOpen = false" class="app-btn-secondary">
            取消
          </button>
          <button type="button" @click="saveRebindDomains" :disabled="saving" class="app-btn-primary">
            保存白名单
          </button>
        </div>
      </template>
    </AppModal>
  </div>
</template>
