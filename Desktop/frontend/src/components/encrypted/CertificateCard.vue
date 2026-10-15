<script setup lang="ts">
import { ref, computed } from 'vue';
import { ipc } from '../../api/ipc';
import type { EncryptedDNSStatusResponse, CertConfig } from '../../api/types';
import AppCard from '../ui/AppCard.vue';
import AppModal from '../AppModal.vue';
import StatusBadge from '../StatusBadge.vue';
import InlineAlert from '../ui/InlineAlert.vue';
import M3Icon from '../M3Icon.vue';

/** 面板持有状态并统一提示，本卡片只负责证书这一块 */
const props = defineProps<{ status: EncryptedDNSStatusResponse | null; saving?: boolean }>();
const emit = defineEmits<{
  (e: 'error', message: string): void;
  (e: 'success', message: string): void;
  (e: 'changed', s: EncryptedDNSStatusResponse): void;
}>();

type SourceMode = 'self_signed' | 'file' | 'pkcs12';
type EditTab = SourceMode | 'pem';

// 表单控件类名集中在此，避免同一串样式在模板里重复十来遍
const INPUT_CLS =
  'w-full h-[34px] px-3 rounded-md border border-surface-border bg-surface-card-sub text-xs text-text-main focus:outline-none focus:border-accent-seal';
const AREA_CLS = `${INPUT_CLS} h-auto p-2.5 font-mono`;

const busy = ref(false);
const modOpen = ref(false);
const mode = ref<SourceMode>('self_signed');
const editTab = ref<EditTab>('self_signed');

// 自签参数
const keyType = ref('ecdsa');
const commonName = ref('');
const dnsNamesText = ref('');
const ipAddrsText = ref('');
const validDays = ref(825);

// 文件来源参数
const certFile = ref('');
const keyFile = ref('');
const p12Password = ref('');
const p12FileName = ref('');
const p12Base64 = ref('');
const pemCert = ref('');
const pemKey = ref('');

const cert = computed(() => props.status?.cert);
const loaded = computed(() => Boolean(cert.value?.loaded));
const certCfg = computed(() => props.status?.config.cert);

/** 距过期不足 30 天提前示警；已过期按错误处理 */
const expiryTone = computed<'error' | 'warning' | 'success'>(() => {
  const d = cert.value?.daysRemaining ?? 0;
  if (d < 0) return 'error';
  if (d < 30) return 'warning';
  return 'success';
});

const expiryText = computed(() => {
  const d = cert.value?.daysRemaining;
  if (d === undefined) return '—';
  if (d < 0) return `已过期 ${-d} 天`;
  return `剩余 ${d} 天`;
});

/** 客户端实际会去连接的名字；证书没覆盖到它就会报错 */
const connectName = computed(() => props.status?.config.serverName || '');

function splitLines(text: string): string[] {
  return text
    .split(/[\n,]/)
    .map((s) => s.trim())
    .filter(Boolean);
}

function applyEditState() {
  const cfg = certCfg.value;
  mode.value = (cfg?.source as SourceMode) || 'self_signed';
  editTab.value = mode.value;
  keyType.value = cfg?.keyType || 'ecdsa';
  commonName.value = cfg?.commonName || '';
  dnsNamesText.value = (cfg?.dnsNames || []).join('\n');
  ipAddrsText.value = (cfg?.ipAddresses || []).join('\n');
  validDays.value = cfg?.validDays || 825;
  certFile.value = cfg?.certFile || '';
  keyFile.value = cfg?.keyFile || '';
  p12Password.value = '';
  p12FileName.value = '';
  p12Base64.value = '';
  pemCert.value = '';
  pemKey.value = '';
}

function openModal() {
  applyEditState();
  modOpen.value = true;
}

/** 统一下发配置：只传证书段，其余字段交由后端保持原值 */
async function patchCert(patch: Partial<CertConfig>, okText: string) {
  const cfg = certCfg.value;
  if (!cfg) return;
  try {
    busy.value = true;
    const res = await ipc.configureEncryptedDNS({ cert: { ...cfg, ...patch } });
    emit('changed', res);
    modOpen.value = false;
    emit('success', okText);
  } catch (err: any) {
    emit('error', err?.message || '更新证书配置失败');
  } finally {
    busy.value = false;
  }
}

async function generateSelfSigned() {
  try {
    busy.value = true;
    const res = await ipc.generateEncryptedCert({
      keyType: keyType.value,
      commonName: commonName.value,
      dnsNames: splitLines(dnsNamesText.value),
      ipAddresses: splitLines(ipAddrsText.value),
      validDays: Number(validDays.value) || 825,
      // 重新签发会让已信任旧证书的设备全部失效，这里已由用户主动点击触发
      force: true,
    });
    emit('changed', res);
    modOpen.value = false;
    emit('success', '证书已重新签发，需在每台客户端重新信任');
  } catch (err: any) {
    emit('error', err?.message || '生成证书失败');
  } finally {
    busy.value = false;
  }
}

async function importPEM() {
  if (!pemCert.value.trim() || !pemKey.value.trim()) {
    emit('error', '证书与私钥内容都不能为空');
    return;
  }
  try {
    busy.value = true;
    const res = await ipc.importEncryptedCert({
      mode: 'pem',
      certPem: pemCert.value,
      keyPem: pemKey.value,
    });
    emit('changed', res);
    modOpen.value = false;
    emit('success', '证书已导入');
  } catch (err: any) {
    emit('error', err?.message || '导入证书失败');
  } finally {
    busy.value = false;
  }
}

/** 读成 base64：PKCS#12 是二进制，JSON 承载不了裸字节 */
function readFileAsBase64(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      const bytes = new Uint8Array(reader.result as ArrayBuffer);
      let binary = '';
      for (let i = 0; i < bytes.length; i += 1) binary += String.fromCharCode(bytes[i]);
      resolve(btoa(binary));
    };
    reader.onerror = () => reject(new Error('读取文件失败'));
    reader.readAsArrayBuffer(file);
  });
}

async function onP12Picked(e: Event) {
  const input = e.target as HTMLInputElement;
  const file = input.files?.[0];
  if (!file) return;
  try {
    p12Base64.value = await readFileAsBase64(file);
    p12FileName.value = file.name;
  } catch (err: any) {
    emit('error', err?.message || '读取文件失败');
  }
}

async function importPKCS12() {
  if (!p12Base64.value) {
    emit('error', '请先选择 PKCS#12 文件');
    return;
  }
  try {
    busy.value = true;
    const res = await ipc.importEncryptedCert({
      mode: 'pkcs12',
      data: p12Base64.value,
      password: p12Password.value,
    });
    emit('changed', res);
    modOpen.value = false;
    emit('success', '证书已导入');
  } catch (err: any) {
    emit('error', err?.message || '导入 PKCS#12 失败，请确认口令是否正确');
  } finally {
    busy.value = false;
  }
}

async function reload() {
  try {
    busy.value = true;
    emit('changed', await ipc.getEncryptedDNSStatus());
    emit('success', '已重新载入证书');
  } catch (err: any) {
    emit('error', err?.message || '重新载入失败');
  } finally {
    busy.value = false;
  }
}

async function copyFingerprint() {
  const fp = cert.value?.fingerprint || '';
  if (!fp) return;
  try {
    await navigator.clipboard.writeText(fp);
    emit('success', '指纹已复制');
  } catch {
    emit('error', '复制失败，请手动选中');
  }
}
</script>

<template>
  <AppCard
    title="服务端证书"
    subtitle="DoT / DoH / DoQ 监听器共用的证书，客户端必须信任它才会解析"
    icon="key"
    :iconSize="16"
  >
    <template #badge>
      <StatusBadge
        :status="loaded ? 'active' : 'error'"
        :text="loaded ? (cert?.selfSigned ? '自签证书' : '已导入证书') : '未载入'"
        size="sm"
      />
    </template>

    <template #actions>
      <div class="flex items-center gap-2">
        <button type="button" class="app-btn-secondary app-btn-compact" :disabled="busy" @click="reload">
          <M3Icon name="refresh" :size="13" />
          <span>重新载入</span>
        </button>
        <button
          type="button"
          class="app-btn-primary app-btn-compact"
          :disabled="busy || props.saving"
          @click="openModal"
        >
          <M3Icon name="key" :size="13" />
          <span>更换证书</span>
        </button>
      </div>
    </template>

    <div class="space-y-3 mt-3 text-xs">
      <InlineAlert v-if="cert?.error" type="error" :message="cert.error" />
      <InlineAlert
        v-else-if="expiryTone === 'error'"
        type="error"
        :message="`证书${expiryText}，客户端会直接拒绝连接，请尽快更换。`"
      />
      <InlineAlert
        v-else-if="expiryTone === 'warning'"
        type="warning"
        :message="`证书${expiryText}，建议在到期前更换，避免客户端突然中断解析。`"
      />

      <div v-if="loaded">
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
          <div class="app-card-sub p-2.5">
            <div class="text-[10px] text-text-muted mb-0.5">主体</div>
            <div class="font-mono text-[11px] text-text-main break-all">{{ cert?.subject || '—' }}</div>
          </div>
          <div class="app-card-sub p-2.5">
            <div class="text-[10px] text-text-muted mb-0.5">签发者</div>
            <div class="font-mono text-[11px] text-text-main break-all">{{ cert?.issuer || '—' }}</div>
          </div>
          <div class="app-card-sub p-2.5">
            <div class="text-[10px] text-text-muted mb-0.5">有效期</div>
            <div class="font-mono text-[11px] text-text-main">
              {{ (cert?.notBefore || '').slice(0, 10) }} → {{ (cert?.notAfter || '').slice(0, 10) }}
            </div>
          </div>
          <div class="app-card-sub p-2.5">
            <div class="text-[10px] text-text-muted mb-0.5">剩余有效期</div>
            <div
              class="font-mono text-[11px]"
              :class="{
                'text-status-error': expiryTone === 'error',
                'text-status-warning': expiryTone === 'warning',
                'text-text-main': expiryTone === 'success',
              }"
            >
              {{ expiryText }}
            </div>
          </div>
        </div>

        <div class="app-card-sub p-2.5 mt-2">
          <div class="text-[10px] text-text-muted mb-1.5">
            证书覆盖的名字（客户端按这些名字连接才不会报证书错误）
          </div>
          <div class="flex flex-wrap gap-1.5">
            <span
              v-for="n in cert?.dnsNames || []"
              :key="'d-' + n"
              class="px-1.5 py-0.5 rounded border border-brand-primary/40 text-text-main font-mono text-[10px]"
            >{{ n }}</span>
            <span
              v-for="n in cert?.ipAddresses || []"
              :key="'i-' + n"
              class="px-1.5 py-0.5 rounded border border-surface-border text-text-sub font-mono text-[10px]"
            >{{ n }}</span>
            <span
              v-if="!(cert?.dnsNames?.length || cert?.ipAddresses?.length)"
              class="text-text-muted text-[11px]"
            >
              证书未标注任何名字，客户端按名字连接时会报证书错误
            </span>
          </div>
          <div v-if="connectName && !(cert?.dnsNames || []).includes(connectName)" class="mt-1.5">
            <InlineAlert
              type="warning"
              :message="`当前服务器名为「${connectName}」，但它不在证书覆盖的名字里，客户端校验会失败。`"
            />
          </div>
        </div>

        <div class="app-card-sub p-2.5 mt-2">
          <div class="flex items-center justify-between mb-1">
            <span class="text-[10px] text-text-muted">SHA-256 指纹（可在客户端核对）</span>
            <button
              type="button"
              class="app-btn-chip"
              :disabled="!cert?.fingerprint"
              @click="copyFingerprint"
            >
              复制
            </button>
          </div>
          <div class="font-mono text-[10px] text-text-main break-all select-all">
            {{ cert?.fingerprint || '—' }}
          </div>
        </div>
      </div>

      <p class="text-[11px] text-text-muted leading-relaxed">
        证书目录 <code class="font-mono">{{ status?.certDir || '—' }}</code>。
        私钥以仅属主可读的权限存放于此，配置对象与接口响应中都不含私钥材料。
      </p>
    </div>

    <AppModal :open="modOpen" title="更换服务端证书" max-width="max-w-2xl" @close="modOpen = false">
      <div class="space-y-4">
        <div class="flex flex-wrap gap-2">
          <button
            v-for="opt in [
              { id: 'self_signed', label: '自签证书' },
              { id: 'file', label: 'PEM 文件路径' },
              { id: 'pkcs12', label: '上传 PKCS#12' },
              { id: 'pem', label: '粘贴 PEM' },
            ]"
            :key="opt.id"
            type="button"
            class="app-btn-chip"
            :class="editTab === opt.id ? 'ring-1 ring-brand-primary text-text-main' : 'text-text-sub'"
            @click="editTab = opt.id as EditTab"
          >
            {{ opt.label }}
          </button>
        </div>

        <!-- 自签 -->
        <div v-if="editTab === 'self_signed'" class="space-y-2.5">
          <InlineAlert
            type="warning"
            message="自签证书需在每台客户端手动信任，否则客户端会拒绝解析；重新签发会让已信任旧证书的设备全部失效。"
          />
          <div class="grid grid-cols-2 gap-2.5">
            <div>
              <label class="text-[11px] font-semibold text-text-muted block mb-1">密钥类型</label>
              <select v-model="keyType" :class="`${INPUT_CLS} font-mono`">
                <option value="ecdsa">ECDSA P-256（推荐）</option>
                <option value="rsa">RSA 3072</option>
              </select>
            </div>
            <div>
              <label class="text-[11px] font-semibold text-text-muted block mb-1">有效期（天）</label>
              <input v-model.number="validDays" type="number" min="1" max="3650" :class="`${INPUT_CLS} font-mono`" />
            </div>
          </div>
          <div>
            <label class="text-[11px] font-semibold text-text-muted block mb-1">通用名 CN</label>
            <input v-model="commonName" :class="`${INPUT_CLS} font-mono`" placeholder="dns.lan" />
          </div>
          <div>
            <label class="text-[11px] font-semibold text-text-muted block mb-1">域名 SAN（每行一个）</label>
            <textarea v-model="dnsNamesText" rows="3" :class="AREA_CLS" placeholder="dns.lan"></textarea>
          </div>
          <div>
            <label class="text-[11px] font-semibold text-text-muted block mb-1">IP SAN（每行一个）</label>
            <textarea v-model="ipAddrsText" rows="2" :class="AREA_CLS" placeholder="192.168.1.10"></textarea>
          </div>
          <p class="text-[11px] text-text-muted leading-relaxed">
            域名与 IP 都留空时，会自动按「服务器名 + 监听地址」推导，并补上回环地址。
          </p>
        </div>

        <!-- PEM 路径 -->
        <div v-else-if="editTab === 'file'" class="space-y-2.5">
          <InlineAlert
            type="info"
            message="填宿主机上的文件路径，由服务直接读取，适合已有证书链的场景。"
          />
          <div>
            <label class="text-[11px] font-semibold text-text-muted block mb-1">证书链 PEM 路径</label>
            <input v-model="certFile" :class="`${INPUT_CLS} font-mono`" placeholder="C:\certs\fullchain.pem" />
          </div>
          <div>
            <label class="text-[11px] font-semibold text-text-muted block mb-1">私钥 PEM 路径</label>
            <input v-model="keyFile" :class="`${INPUT_CLS} font-mono`" placeholder="C:\certs\privkey.pem" />
          </div>
        </div>

        <!-- PKCS#12 -->
        <div v-else-if="editTab === 'pkcs12'" class="space-y-2.5">
          <InlineAlert
            type="info"
            message="支持 OpenSSL 3.x、Windows certutil 与主流 CA 导出的现代容器（PBES2 + AES-256）。"
          />
          <div>
            <label class="text-[11px] font-semibold text-text-muted block mb-1">PKCS#12 文件</label>
            <input
              type="file"
              accept=".p12,.pfx"
              class="w-full text-xs text-text-sub file:mr-2 file:px-2.5 file:py-1.5 file:rounded-md file:border-0 file:bg-surface-card-sub file:text-text-main file:text-xs"
              @change="onP12Picked"
            />
            <div v-if="p12FileName" class="text-[11px] text-text-muted mt-1 font-mono">已读取：{{ p12FileName }}</div>
          </div>
          <div>
            <label class="text-[11px] font-semibold text-text-muted block mb-1">容器口令</label>
            <input v-model="p12Password" type="password" :class="INPUT_CLS" />
          </div>
        </div>

        <!-- 粘贴 PEM -->
        <div v-else class="space-y-2.5">
          <div>
            <label class="text-[11px] font-semibold text-text-muted block mb-1">证书链 PEM</label>
            <textarea v-model="pemCert" rows="4" :class="`${AREA_CLS} text-[10px]`" placeholder="-----BEGIN CERTIFICATE-----"></textarea>
          </div>
          <div>
            <label class="text-[11px] font-semibold text-text-muted block mb-1">私钥 PEM</label>
            <textarea v-model="pemKey" rows="4" :class="`${AREA_CLS} text-[10px]`" placeholder="-----BEGIN PRIVATE KEY-----"></textarea>
          </div>
        </div>
      </div>

      <template #actions>
        <button type="button" class="app-btn-secondary" @click="modOpen = false">取消</button>
        <button
          v-if="editTab === 'file'"
          type="button"
          class="app-btn-primary"
          :disabled="busy"
          @click="patchCert({ source: 'file', certFile, keyFile }, '证书路径已保存并重新载入')"
        >
          保存路径
        </button>
        <button
          v-else-if="editTab === 'self_signed'"
          type="button"
          class="app-btn-primary"
          :disabled="busy"
          @click="generateSelfSigned"
        >
          签发并使用
        </button>
        <button
          v-else-if="editTab === 'pkcs12'"
          type="button"
          class="app-btn-primary"
          :disabled="busy"
          @click="importPKCS12"
        >
          导入并使用
        </button>
        <button v-else type="button" class="app-btn-primary" :disabled="busy" @click="importPEM">
          导入并使用
        </button>
      </template>
    </AppModal>
  </AppCard>
</template>
