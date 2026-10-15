<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { ipc } from '../../api/ipc';
import type { EncryptedDNSStatusResponse, ConfigureACLRequest } from '../../api/types';
import AppCard from '../ui/AppCard.vue';
import StatusBadge from '../StatusBadge.vue';
import InlineAlert from '../ui/InlineAlert.vue';
import M3Icon from '../M3Icon.vue';
import { extractSwitchValue, revertSwitch } from '../../utils/switch';

const props = defineProps<{ status: EncryptedDNSStatusResponse | null }>();
const emit = defineEmits<{
  (e: 'error', message: string): void;
  (e: 'success', message: string): void;
  (e: 'changed', s: EncryptedDNSStatusResponse): void;
  (e: 'saving', v: boolean): void;
}>();

const INPUT_CLS =
  'w-full h-[34px] px-3 rounded-md border border-surface-border bg-surface-card-sub text-xs text-text-main focus:outline-none focus:border-accent-seal focus:ring-1 focus:ring-accent-seal/40 font-mono';
const AREA_CLS = `${INPUT_CLS} h-auto p-2.5 leading-relaxed`;

const saving = ref(false);
const editing = ref(false);
const confirming = ref(false);

/** 编辑区草稿：只有点保存才回写服务端 */
const sourcesText = ref('');
const headerName = ref('');

const cfg = computed(() => props.status?.config?.reverseProxy);
const enabled = computed(() => Boolean(cfg.value?.enabled));
const sources = computed(() => cfg.value?.trustedSources ?? []);

/** 全放行条目：任何人都能伪造来源，界面必须持续提醒 */
const unrestricted = computed(() => Boolean(props.status?.unrestrictedTrust));

/** 草稿里是否填了全放行，决定保存时要不要先弹二次确认 */
const draftUnrestricted = computed(() =>
  parseSources(sourcesText.value).some((s) => isUnrestricted(s))
);

/** 把文本域拆成条目：一行一个，也容许逗号分隔 */
function parseSources(text: string): string[] {
  return text
    .split(/[\n,]/)
    .map((s) => s.trim())
    .filter((s) => s !== '');
}

/**
 * 判断是否为「信任所有人」的网段。
 * 用 0 位掩码识别而不是字符串比对，'0.0.0.0/00' 这类写法同样能识破。
 */
function isUnrestricted(entry: string): boolean {
  const slash = entry.indexOf('/');
  if (slash < 0) return false;
  const prefix = Number(entry.slice(slash + 1));
  return Number.isFinite(prefix) && prefix === 0;
}

// 服务端刷新后同步草稿，避免界面停留在旧值上
watch(
  [sources, () => cfg.value?.clientIpHeader],
  () => {
    sourcesText.value = sources.value.join('\n');
    headerName.value = cfg.value?.clientIpHeader ?? '';
  },
  { immediate: true }
);

async function apply(req: ConfigureACLRequest, okText: string) {
  try {
    saving.value = true;
    emit('saving', true);
    const res = await ipc.configureEncryptedACL(req);
    emit('changed', res);
    emit('success', okText);
    editing.value = false;
  } catch (err: any) {
    emit('error', err?.message || '更新反向代理配置失败');
    throw err;
  } finally {
    saving.value = false;
    emit('saving', false);
  }
}

async function toggle(e: Event) {
  const next = extractSwitchValue(e);
  // 列表为空时开启等于「谁都不信」，转发头依旧被忽略，故不拦截
  try {
    await apply({ enabled: next }, next ? '已按可信来源还原客户端 IP' : '已停止采信转发头');
  } catch {
    revertSwitch(e, !next);
  }
}

async function save() {
  const list = parseSources(sourcesText.value);
  // 全放行需要一个显式确认：光靠一条警告文案挡不住手快的人
  if (draftUnrestricted.value && !confirming.value) {
    confirming.value = true;
    return;
  }
  confirming.value = false;
  try {
    await apply(
      {
        trustedSources: list,
        clientIpHeader: headerName.value.trim(),
        confirmUnrestricted: draftUnrestricted.value,
      },
      '可信来源已保存'
    );
  } catch {
    /* 错误已通过 emit 上报 */
  }
}

function cancel() {
  editing.value = false;
  confirming.value = false;
  sourcesText.value = sources.value.join('\n');
  headerName.value = cfg.value?.clientIpHeader ?? '';
}
</script>

<template>
  <AppCard
    title="反向代理可信来源"
    subtitle="DoH 位于反向代理之后时，按代理提供的转发头还原真实客户端 IP"
    icon="router"
    :iconSize="16"
  >
    <template #badge>
      <StatusBadge
        :status="enabled && sources.length > 0 ? 'active' : 'inactive'"
        :text="enabled && sources.length > 0 ? '已启用' : '未启用'"
        size="sm"
      />
    </template>

    <template #actions>
      <md-switch :selected="enabled" :disabled="saving" @change="toggle" />
    </template>

    <div class="space-y-3 mt-3 text-xs">
      <InlineAlert
        v-if="unrestricted"
        type="warning"
        message="可信来源包含全放行网段（0.0.0.0/0 或 ::/0）：任何直连方都能伪造客户端来源，访问控制与按 IP 的限速会同时失效。建议改成具体的代理地址。"
      />

      <p class="text-[11px] text-text-muted leading-relaxed">
        转发头（<code class="font-mono text-text-sub">X-Forwarded-For</code>、
        <code class="font-mono text-text-sub">X-Real-IP</code>）是调用方可以随便写的。
        只有列在这里的代理发来的请求才会被采信，其余一律以直连地址为准——
        否则任何匿名客户端加一个头就能把自己伪装成白名单成员。
        <strong class="text-text-sub">不在反向代理后面的部署请保持关闭。</strong>
      </p>

      <div v-if="!editing" class="space-y-2">
        <div class="flex items-center justify-between">
          <span class="text-[11px] font-semibold text-text-sub">可信来源</span>
          <button type="button" class="app-btn-secondary app-btn-compact" :disabled="saving" @click="editing = true">
            <M3Icon name="edit" :size="13" />
            <span>编辑</span>
          </button>
        </div>
        <p v-if="sources.length === 0" class="text-[11px] text-text-muted">
          列表为空，当前不采信任何转发头。
        </p>
        <div v-else class="flex flex-wrap gap-1.5">
          <span
            v-for="s in sources"
            :key="s"
            class="px-2 py-0.5 rounded font-mono text-[11px] border"
            :class="isUnrestricted(s) ? 'border-status-warning text-status-warning' : 'border-surface-border text-text-sub'"
          >
            {{ s }}
          </span>
        </div>
        <p v-if="cfg?.clientIpHeader" class="text-[11px] text-text-muted">
          自定义头：<span class="font-mono text-text-sub">{{ cfg.clientIpHeader }}</span>
        </p>
      </div>

      <div v-else class="space-y-2.5">
        <div>
          <label class="block text-[11px] font-semibold text-text-sub mb-1">
            可信代理地址（每行一个，支持 IP 或 CIDR）
          </label>
          <textarea
            v-model="sourcesText"
            rows="3"
            :class="AREA_CLS"
            placeholder="10.0.0.5&#10;192.168.1.0/24"
          ></textarea>
          <p class="text-[11px] text-text-muted mt-1">
            只填代理本身的地址，不要填终端网段。
          </p>
        </div>

        <div>
          <label class="block text-[11px] font-semibold text-text-sub mb-1">
            自定义转发头（可留空）
          </label>
          <input v-model="headerName" :class="INPUT_CLS" placeholder="CF-Connecting-IP" />
          <p class="text-[11px] text-text-muted mt-1">
            留空时依次尝试 X-Forwarded-For 与 X-Real-IP；Cloudflare 等使用自有头名的服务需填写。
          </p>
        </div>

        <InlineAlert
          v-if="confirming"
          type="warning"
          message="列表里包含全放行网段，保存后任何人都能伪造客户端来源。确认要继续吗？"
        />

        <div class="flex items-center justify-end gap-2">
          <button type="button" class="app-btn-secondary app-btn-compact" :disabled="saving" @click="cancel">
            <span>取消</span>
          </button>
          <button
            type="button"
            class="app-btn-primary app-btn-compact"
            :class="confirming ? 'app-btn-warning' : ''"
            :disabled="saving"
            @click="save"
          >
            <span>{{ confirming ? '确认保存' : '保存' }}</span>
          </button>
        </div>
      </div>
    </div>
  </AppCard>
</template>
