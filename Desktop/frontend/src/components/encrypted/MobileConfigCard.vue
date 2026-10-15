<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import QRCode from 'qrcode';
import { ipc } from '../../api/ipc';
import type { EncryptedDNSStatusResponse } from '../../api/types';
import AppCard from '../ui/AppCard.vue';
import StatusBadge from '../StatusBadge.vue';
import InlineAlert from '../ui/InlineAlert.vue';
import M3Icon from '../M3Icon.vue';
import CopyRow from '../ui/CopyRow.vue';

const props = defineProps<{ status: EncryptedDNSStatusResponse | null }>();

const cfg = computed(() => props.status?.config);
const enabled = computed(() => Boolean(cfg.value?.enabled));

/** 只有真正在监听的协议才能写进描述文件，否则设备装上一份指向空端口的配置 */
const dohLive = computed(() => Boolean(cfg.value?.dohEnabled && props.status?.dohListen));
const dotLive = computed(() => Boolean(cfg.value?.dotEnabled && props.status?.dotListen));

const protocol = ref<'HTTPS' | 'TLS'>('HTTPS');
const qrDataUrl = ref('');

/** 首选 DoH：iOS 对 HTTPS 型描述文件支持最完整 */
watch(
  [dohLive, dotLive],
  () => {
    protocol.value = dohLive.value ? 'HTTPS' : 'TLS';
  },
  { immediate: true }
);

const downloadURL = computed(() => (enabled.value ? ipc.encryptedMobileConfigURL(protocol.value) : ''));

/** 二维码让手机扫码即可下载，不必手工敲内网地址 */
watch(
  downloadURL,
  async (url) => {
    if (!url) {
      qrDataUrl.value = '';
      return;
    }
    try {
      qrDataUrl.value = await QRCode.toDataURL(url, {
        width: 160,
        margin: 1,
        color: { dark: '#1A1A1C', light: '#FFFFFF' },
      });
    } catch (err) {
      console.warn('生成描述文件二维码失败:', err);
      qrDataUrl.value = '';
    }
  },
  { immediate: true }
);

const ready = computed(() => dohLive.value || dotLive.value);

/** 下载走浏览器而非 fetch：设备需要按媒体类型接管这份文件 */
function download() {
  if (!downloadURL.value) return;
  window.open(downloadURL.value, '_blank');
}
</script>

<template>
  <AppCard
    title="Apple 设备配置描述文件"
    subtitle="生成 .mobileconfig，让 iPhone / iPad / Mac 一键接入本机加密解析"
    icon="download"
    :iconSize="16"
  >
    <template #badge>
      <StatusBadge
        :status="ready && enabled ? 'active' : 'inactive'"
        :text="ready && enabled ? '可下载' : '不可用'"
        size="sm"
      />
    </template>

    <div class="space-y-3 mt-3 text-xs">
      <InlineAlert
        v-if="!enabled"
        type="warning"
        message="加密 DNS 服务尚未启用。描述文件生成出来的地址会指向一个没在监听的端口，请先启用服务。"
      />
      <InlineAlert
        v-else-if="!ready"
        type="warning"
        message="当前没有正在运行的加密监听器。请先启用 DoH 或 DoT 并确认端口已绑定，再生成描述文件。"
      />

      <p class="text-[11px] text-text-muted leading-relaxed">
        描述文件内嵌 DNS 设置载荷，安装后设备的全部 DNS 查询会走本机的加密入口，
        无需手工逐项填写地址。文件内容会随配置实时生成，不需要提前导出。
      </p>

      <!-- 协议选择：DoH 优先，两者都在监听时允许切换 -->
      <div v-if="dohLive && dotLive" class="flex items-center gap-2">
        <span class="text-[11px] text-text-sub font-semibold">协议</span>
        <div class="flex rounded-lg overflow-hidden border border-border-subtle">
          <button
            v-for="p in (['HTTPS', 'TLS'] as const)"
            :key="p"
            type="button"
            class="px-3 py-1 text-[11px] font-semibold transition-colors"
            :class="protocol === p ? 'bg-accent text-white' : 'bg-transparent text-text-sub hover:text-text-main'"
            @click="protocol = p"
          >
            {{ p === 'HTTPS' ? 'DoH (HTTPS)' : 'DoT (TLS)' }}
          </button>
        </div>
      </div>

      <div v-if="ready && enabled" class="flex items-center justify-center gap-4 app-card-sub p-4">
        <img v-if="qrDataUrl" :src="qrDataUrl" alt="描述文件下载二维码" class="w-[160px] h-[160px] rounded-lg bg-white p-1" />
        <div class="space-y-2 min-w-0">
          <div class="text-[13px] font-bold text-text-main">扫码安装</div>
          <p class="text-[11px] text-text-muted leading-relaxed">
            用 iPhone / iPad 相机扫描左侧二维码，系统会提示安装描述文件。
            手机需与本机在同一局域网内。
          </p>
          <button type="button" class="app-btn-primary app-btn-compact" @click="download">
            <M3Icon name="download" :size="13" />
            <span>下载描述文件</span>
          </button>
        </div>
      </div>

      <div v-if="ready && enabled" class="space-y-2">
        <CopyRow :text="downloadURL" :tag="protocol" :open-url="downloadURL" open-title="在浏览器中打开以下载" />
        <div class="app-card-sub p-3 space-y-1.5">
          <div class="text-[13px] font-bold text-text-main">iOS / iPadOS 安装步骤</div>
          <ol class="list-decimal list-inside space-y-1 text-[11px] text-text-muted leading-relaxed">
            <li>用 Safari 打开上面的下载地址（其他浏览器不会唤起安装）。</li>
            <li>按提示允许下载配置描述文件。</li>
            <li>进入「设置」，顶部会出现「已下载描述文件」，点进去后选择「安装」。</li>
            <li>系统要求输入锁屏密码，确认两次安装即可。</li>
            <li>安装后回到「设置 → 通用 → VPN 与设备管理」，可核对已安装的描述文件。</li>
          </ol>
          <p class="text-[11px] text-status-warning leading-relaxed">
            使用自签证书时，还需在「关于本机 → 证书信任设置」里手动信任 DITING 的证书，
            否则设备的 DNS 查询会失败。macOS 上同一份文件双击即可安装。
          </p>
        </div>
      </div>
    </div>
  </AppCard>
</template>
