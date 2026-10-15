<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import type { RewriteRule, RewriteRecord } from '../../api/types';
import { REWRITE_RECORD_TYPES, REWRITE_RCODES } from '../../api/types';
import AppModal from '../AppModal.vue';
import M3Icon from '../M3Icon.vue';

const props = defineProps<{
  open: boolean;
  editingItem: RewriteRule | null;
}>();

const emit = defineEmits<{
  (e: 'close'): void;
  (e: 'save', rule: RewriteRule): void;
}>();

type Mode = 'shortcut' | 'records';

const domain = ref('');
const ruleType = ref<'ip' | 'cname' | 'txt'>('ip');
const ipsText = ref('');
const cname = ref('');
const txtText = ref('');
const records = ref<RewriteRecord[]>([]);
const rcode = ref('');
const ttl = ref<number | ''>('');
const error = ref('');
const mode = ref<Mode>('shortcut');

/** 各记录类型的取值示例，直接沿用后端 rewrite_records.go 的语法 */
const RECORD_HINTS: Record<string, string> = {
  A: '10.0.0.5',
  AAAA: 'fd00::5',
  CNAME: 'target.lan',
  TXT: 'v=spf1 ~all',
  MX: '32 mail.lan',
  SRV: '10 60 8080 sip.lan',
  NS: 'ns1.lan',
  PTR: 'host.lan',
  HTTPS: '1 . alpn=h3 port=8443',
  SVCB: '1 . alpn=h2,h3',
};

/** 记录类型列表来自后端同一份定义，避免两处清单各自漂移 */
const recordTypes = REWRITE_RECORD_TYPES;

const isRcodeFailure = computed(() => rcode.value !== '' && rcode.value !== 'NOERROR');

function hintFor(type: string): string {
  return RECORD_HINTS[type] || '记录取值';
}

function addRecord() {
  records.value.push({ type: 'MX', value: '' });
}

function removeRecord(index: number) {
  records.value.splice(index, 1);
}

function resetForm() {
  domain.value = '';
  ruleType.value = 'ip';
  ipsText.value = '';
  cname.value = '';
  txtText.value = '';
  records.value = [];
  rcode.value = '';
  ttl.value = '';
  mode.value = 'shortcut';
}

watch(
  () => props.open,
  (isOpen) => {
    if (!isOpen) return;
    error.value = '';
    resetForm();

    const item = props.editingItem;
    if (!item) return;

    domain.value = item.domain;
    ttl.value = item.ttl || '';
    rcode.value = item.rcode || '';
    records.value = (item.records || []).map((r) => ({ ...r }));

    // 用快捷字段能完整表达的规则优先落到快捷模式，其余（含 MX/SRV 等）走记录模式
    const hasShortcut = !!item.cname || (item.ips && item.ips.length > 0) || (item.txt && item.txt.length > 0);
    if (!hasShortcut && records.value.length > 0) {
      mode.value = 'records';
    }

    if (item.cname) {
      ruleType.value = 'cname';
      cname.value = item.cname;
    } else if (item.txt && item.txt.length > 0) {
      ruleType.value = 'txt';
      txtText.value = item.txt.join('\n');
    } else if (item.ips && item.ips.length > 0) {
      ruleType.value = 'ip';
      ipsText.value = item.ips.join('\n');
    }
  }
);

function handleSave() {
  error.value = '';
  const d = domain.value.trim().toLowerCase();
  if (!d) {
    error.value = '请输入匹配域名（支持精准匹配或 *.lan 泛域名）';
    return;
  }

  const rule: RewriteRule = {
    domain: d,
    ttl: ttl.value ? Number(ttl.value) : undefined,
    rcode: rcode.value || undefined,
  };

  // 记录列表在两种模式下都随表单提交：编辑一条同时含快捷字段与自定义记录的规则时，
  // 切到快捷模式不该把记录列表静默丢掉
  const validRecords = records.value.filter((r) => r.type && r.value.trim());
  if (validRecords.length > 0) {
    rule.records = validRecords.map((r) => ({ type: r.type, value: r.value.trim() }));
  }

  // 应答码覆盖为失败码时后端不返回任何记录，目标必填校验随之失效：
  // 否则用户只能为了通过校验去填一个永远不会生效的目标
  if (isRcodeFailure.value) {
    emit('save', rule);
    return;
  }

  if (mode.value === 'records') {
    if (!rule.records || rule.records.length === 0) {
      error.value = '请至少添加一条有效记录（类型与取值均不能为空）';
      return;
    }
  } else if (ruleType.value === 'ip') {
    const list = ipsText.value
      .split('\n')
      .map((s) => s.trim())
      .filter(Boolean);
    if (list.length === 0) {
      error.value = '请输入至少一个 IPv4 或 IPv6 目标解析地址';
      return;
    }
    rule.ips = list;
  } else if (ruleType.value === 'cname') {
    const c = cname.value.trim().toLowerCase();
    if (!c) {
      error.value = '请输入 CNAME 别名重定向目标域名';
      return;
    }
    rule.cname = c;
  } else if (ruleType.value === 'txt') {
    const list = txtText.value
      .split('\n')
      .map((s) => s.trim())
      .filter(Boolean);
    if (list.length === 0) {
      error.value = '请输入至少一条 TXT 记录文本';
      return;
    }
    rule.txt = list;
  }

  emit('save', rule);
}
</script>

<template>
  <AppModal
    :open="open"
    :title="editingItem ? '编辑 DNS 重写规则' : '添加 DNS 重写与伪装规则'"
    @close="emit('close')"
  >
    <div class="space-y-4 text-xs">
      <div>
        <label class="font-semibold text-text-main block mb-1">匹配域名</label>
        <input
          v-model="domain"
          type="text"
          placeholder="如 host.lan 或 *.home.local"
          class="w-full h-[34px] px-3 rounded-md border border-surface-border bg-surface-card-sub text-xs text-text-main font-mono focus:outline-none focus:border-accent-seal"
        />
        <span class="text-[10px] text-text-muted mt-1 block">
          支持精确域名（如 router.lan）或泛域名（如 *.cluster.internal）
        </span>
      </div>

      <div>
        <label class="font-semibold text-text-muted block mb-1.5">应答目标</label>
        <div class="grid grid-cols-2 gap-2">
          <label
            class="flex items-center justify-center gap-1.5 py-2 px-2.5 rounded-md border cursor-pointer transition-colors text-[11px] font-semibold app-interactive-card"
            :class="mode === 'shortcut' ? 'bg-brand-container/40 border-brand-primary text-brand-primary' : 'border-surface-border bg-surface-card-sub text-text-sub'"
          >
            <input type="radio" v-model="mode" value="shortcut" class="sr-only" />
            <span>快捷目标</span>
          </label>
          <label
            class="flex items-center justify-center gap-1.5 py-2 px-2.5 rounded-md border cursor-pointer transition-colors text-[11px] font-semibold app-interactive-card"
            :class="mode === 'records' ? 'bg-brand-container/40 border-brand-primary text-brand-primary' : 'border-surface-border bg-surface-card-sub text-text-sub'"
          >
            <input type="radio" v-model="mode" value="records" class="sr-only" />
            <span>自定义记录</span>
          </label>
        </div>
      </div>

      <!-- 快捷模式：A/AAAA、CNAME、TXT 三种最常见场景 -->
      <template v-if="mode === 'shortcut'">
        <div>
          <label class="font-semibold text-text-muted block mb-1.5">重写目标类型</label>
          <div class="grid grid-cols-3 gap-2">
            <label
              class="flex items-center justify-center gap-1.5 py-2 px-2.5 rounded-md border cursor-pointer transition-colors text-[11px] font-semibold app-interactive-card"
              :class="ruleType === 'ip' ? 'bg-brand-container/40 border-brand-primary text-brand-primary' : 'border-surface-border bg-surface-card-sub text-text-sub'"
            >
              <input type="radio" v-model="ruleType" value="ip" class="sr-only" />
              <span>A / AAAA 地址</span>
            </label>
            <label
              class="flex items-center justify-center gap-1.5 py-2 px-2.5 rounded-md border cursor-pointer transition-colors text-[11px] font-semibold app-interactive-card"
              :class="ruleType === 'cname' ? 'bg-brand-container/40 border-brand-primary text-brand-primary' : 'border-surface-border bg-surface-card-sub text-text-sub'"
            >
              <input type="radio" v-model="ruleType" value="cname" class="sr-only" />
              <span>CNAME 别名</span>
            </label>
            <label
              class="flex items-center justify-center gap-1.5 py-2 px-2.5 rounded-md border cursor-pointer transition-colors text-[11px] font-semibold app-interactive-card"
              :class="ruleType === 'txt' ? 'bg-brand-container/40 border-brand-primary text-brand-primary' : 'border-surface-border bg-surface-card-sub text-text-sub'"
            >
              <input type="radio" v-model="ruleType" value="txt" class="sr-only" />
              <span>TXT 文本</span>
            </label>
          </div>
        </div>

        <!-- IP 模式输入 -->
        <div v-if="ruleType === 'ip'">
          <label class="font-semibold text-text-main block mb-1">IPv4 / IPv6 目标解析地址</label>
          <textarea
            v-model="ipsText"
            rows="3"
            placeholder="例如:&#10;192.168.1.100&#10;fe80::1"
            class="w-full rounded-md border border-surface-border bg-surface-card-sub p-2.5 font-mono text-xs text-text-main focus:outline-none focus:border-accent-seal"
          ></textarea>
          <span class="text-[10px] text-text-muted mt-1 block">每行一个 IP 地址，支持多 IP 负载均衡返回</span>
        </div>

        <!-- CNAME 模式输入 -->
        <div v-else-if="ruleType === 'cname'">
          <label class="font-semibold text-text-main block mb-1">CNAME 目标重定向域名</label>
          <input
            v-model="cname"
            type="text"
            placeholder="例如: target.myinternal.net"
            class="w-full h-[34px] px-3 rounded-md border border-surface-border bg-surface-card-sub text-xs text-text-main font-mono focus:outline-none focus:border-accent-seal"
          />
          <span class="text-[10px] text-text-muted mt-1 block">系统将自动遵循别名链进行递归解析</span>
        </div>

        <!-- TXT 模式输入 -->
        <div v-else-if="ruleType === 'txt'">
          <label class="font-semibold text-text-main block mb-1">TXT 记录内容</label>
          <textarea
            v-model="txtText"
            rows="3"
            placeholder="在此输入 TXT 文本，每行一条..."
            class="w-full rounded-md border border-surface-border bg-surface-card-sub p-2.5 font-mono text-xs text-text-main focus:outline-none focus:border-accent-seal"
          ></textarea>
        </div>
      </template>

      <!-- 记录模式：MX / SRV / NS / PTR / HTTPS / SVCB 等 -->
      <template v-else>
        <div>
          <div class="flex items-center justify-between mb-1.5">
            <label class="font-semibold text-text-main">自定义记录</label>
            <button type="button" @click="addRecord" class="app-btn-secondary app-btn-compact">
              <M3Icon name="add" :size="13" />
              <span>添加记录</span>
            </button>
          </div>

          <div v-if="records.length > 0" class="space-y-2">
            <div
              v-for="(rec, index) in records"
              :key="index"
              class="flex items-center gap-2"
            >
              <select
                v-model="rec.type"
                class="w-24 h-[32px] px-2 rounded-md border border-surface-border bg-surface-card-sub text-[11px] text-text-main font-mono focus:outline-none focus:border-accent-seal"
              >
                <option v-for="t in recordTypes" :key="t" :value="t">{{ t }}</option>
              </select>
              <input
                v-model="rec.value"
                type="text"
                :placeholder="hintFor(rec.type)"
                class="flex-1 h-[32px] px-2.5 rounded-md border border-surface-border bg-surface-card-sub text-[11px] text-text-main font-mono focus:outline-none focus:border-accent-seal"
              />
              <button
                type="button"
                @click="removeRecord(index)"
                class="app-btn-secondary app-btn-compact !px-2 !text-status-error hover:!bg-status-error/10"
                title="移除该记录"
              >
                <M3Icon name="delete" :size="13" />
              </button>
            </div>
          </div>
          <div
            v-else
            class="p-4 rounded-md border border-dashed border-surface-border-sub text-center text-[11px] text-text-muted"
          >
            尚未添加记录，点击「添加记录」开始
          </div>

          <span class="text-[10px] text-text-muted mt-1.5 block leading-relaxed">
            取值语法与 AdGuard 的
            <code class="font-mono bg-surface-card-sub px-1 py-0.5 rounded text-accent-seal">$dnsrewrite</code>
            一致：MX 填「优先级 主机」，SRV 填「优先级 权重 端口 目标」，
            HTTPS/SVCB 填「优先级 目标 参数...」。仅与匹配记录类型的查询返回这些记录。
          </span>
        </div>
      </template>

      <div>
        <label class="font-semibold text-text-main block mb-1">应答码覆盖 (可选)</label>
        <select
          v-model="rcode"
          class="w-full h-[34px] px-3 rounded-md border border-surface-border bg-surface-card-sub text-xs text-text-main font-mono focus:outline-none focus:border-accent-seal"
        >
          <option value="">不覆盖（正常返回记录）</option>
          <option v-for="c in REWRITE_RCODES" :key="c" :value="c">{{ c }}</option>
        </select>
        <span v-if="isRcodeFailure" class="text-[10px] text-status-warning mt-1 block">
          选择失败应答码后，本条规则只返回该错误码，不再返回任何记录；客户端会认为该域名不可用或被拒绝。
        </span>
      </div>

      <div>
        <label class="font-semibold text-text-muted block mb-1">生存时间 TTL (秒，可选)</label>
        <input
          v-model.number="ttl"
          type="number"
          min="1"
          placeholder="留空则使用全局默认 TTL (60s)"
          class="w-full h-[34px] px-3 rounded-md border border-surface-border bg-surface-card-sub text-xs text-text-main font-mono focus:outline-none focus:border-accent-seal"
        />
      </div>

      <div v-if="error" class="p-2 rounded bg-status-error/10 text-status-error text-[11px] font-medium">
        {{ error }}
      </div>
    </div>

    <template #footer>
      <div class="flex items-center justify-end gap-2 w-full">
        <button type="button" @click="emit('close')" class="app-btn-secondary">
          取消
        </button>
        <button type="button" @click="handleSave" class="app-btn-primary">
          保存重写规则
        </button>
      </div>
    </template>
  </AppModal>
</template>
