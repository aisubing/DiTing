<script setup lang="ts">
import { ref, computed } from 'vue';
import { ipc } from '../../api/ipc';
import type { SafeBrowsingResponse } from '../../api/types';
import AppCard from '../ui/AppCard.vue';
import StatusBadge from '../StatusBadge.vue';
import M3Icon from '../M3Icon.vue';
import { extractSwitchValue, revertSwitch } from '../../utils/switch';

const emit = defineEmits<{ (e: 'error', message: string): void; (e: 'success', message: string): void }>();

const res = ref<SafeBrowsingResponse | null>(null);
const saving = ref(false);
const loaded = ref(false);

// 超时、容量与有效期的本地编辑态：改动后需点保存才下发
const timeoutMs = ref(3000);
const cacheSize = ref(10000);
const cacheTTLSeconds = ref(600);

const enabled = computed(() => res.value?.config.enabled ?? false);
const stats = computed(() => res.value?.stats);
const hitRate = computed(() => {
  const s = stats.value;
  if (!s || s.lookups === 0) return '—';
  return `${Math.round((s.cacheHits / s.lookups) * 100)}%`;
});

/** 查询参数草稿是否被用户改动过（改动后不被服务端回包/开关刷新回卷） */
const draftDirty = ref(false);

function markDraftDirty() {
  draftDirty.value = true;
}

/**
 * 应用服务端回包。开关等非草稿操作只更新展示数据，不能顺手把用户
 * 正在编辑的参数覆写回服务器旧值；只有保存成功才强制同步。
 */
function apply(r: SafeBrowsingResponse | null | undefined, forceSync = false) {
  if (!r) return;
  res.value = r;
  if (draftDirty.value && !forceSync) return;
  timeoutMs.value = r.config.timeoutMs;
  cacheSize.value = r.config.cacheSize;
  cacheTTLSeconds.value = r.config.cacheTTLSeconds;
  draftDirty.value = false;
}

async function fetchData() {
  try {
    apply(await ipc.getSafeBrowsing());
    loaded.value = true;
  } catch (err: any) {
    emit('error', err?.message || '获取恶意网址库配置失败');
  }
}

async function toggleMaster(e: Event) {
  const next = extractSwitchValue(e);
  try {
    saving.value = true;
    apply(await ipc.configureSafeBrowsing({ enabled: next }));
    emit('success', `恶意网址库查询已${next ? '开启' : '关闭'}`);
  } catch (err: any) {
    revertSwitch(e, !next);
    emit('error', err?.message || '更新恶意网址库开关失败');
  } finally {
    saving.value = false;
  }
}

async function saveAdvanced() {
  try {
    saving.value = true;
    // 服务端会把越界参数归一化后回传，这里以回传值为准，
    // 让界面立刻显示真正生效的数字而不是填进去的那个
    apply(
      await ipc.configureSafeBrowsing({
        timeoutMs: Number(timeoutMs.value),
        cacheSize: Number(cacheSize.value),
        cacheTTLSeconds: Number(cacheTTLSeconds.value),
      }),
      true,
    );
    emit('success', '查询参数已保存');
  } catch (err: any) {
    emit('error', err?.message || '保存查询参数失败');
  } finally {
    saving.value = false;
  }
}

defineExpose({ fetchData });
fetchData();
</script>

<template>
  <AppCard
    title="恶意网址库（Safe Browsing）"
    subtitle="借第三方哈希前缀服务核对域名是否被收录为钓鱼、恶意软件站点"
    icon="shield"
    :iconSize="16"
  >
    <template #badge>
      <StatusBadge
        :status="enabled ? 'active' : 'inactive'"
        :text="enabled ? '查询中' : '未启用'"
        size="sm"
      />
    </template>

    <template #actions>
      <md-switch :selected="enabled" :disabled="saving || !loaded" @change="toggleMaster" />
    </template>

    <div class="space-y-3 mt-3 text-xs">
      <p class="text-[11px] text-text-sub leading-relaxed">
        查询时只把域名的 SHA-256 <span class="font-semibold text-text-main">前 2 字节</span>发往
        <code class="font-mono">sb.dns.adguard.com</code>，对方返回命中的完整摘要，本地再比对。
        第三方无法从这 2 个字节还原出完整域名。属外部依赖能力，
        <span class="text-accent-seal font-semibold">默认关闭</span>。
      </p>

      <div class="p-2.5 rounded-md border border-surface-border-sub bg-surface-card-sub">
        <div class="text-[11px] text-text-muted leading-relaxed">
          <span class="font-semibold text-text-main">查询失败一律放行。</span>
          与本地规则不同：本地规则是我们自己掌握的数据，出问题说明配置有误，宁可拦住；
          而声誉查询依赖第三方可用性，让它的抖动决定整个网络的解析成败代价太大。
          失败次数单独计数，便于在下方观察到。
        </div>
      </div>

      <div v-if="stats" class="grid grid-cols-2 sm:grid-cols-5 gap-2">
        <div class="p-2 rounded-md bg-surface-card-sub border border-surface-border-sub">
          <div class="text-[10px] text-text-muted">查询次数</div>
          <div class="font-mono text-[13px] text-text-main">{{ stats.lookups }}</div>
        </div>
        <div class="p-2 rounded-md bg-surface-card-sub border border-surface-border-sub">
          <div class="text-[10px] text-text-muted">命中拦截</div>
          <div class="font-mono text-[13px] text-accent-seal">{{ stats.blocked }}</div>
        </div>
        <div class="p-2 rounded-md bg-surface-card-sub border border-surface-border-sub">
          <div class="text-[10px] text-text-muted">缓存命中率</div>
          <div class="font-mono text-[13px] text-text-main">{{ hitRate }}</div>
        </div>
        <div class="p-2 rounded-md bg-surface-card-sub border border-surface-border-sub">
          <div class="text-[10px] text-text-muted">查询失败</div>
          <div
            class="font-mono text-[13px]"
            :class="stats.failures > 0 ? 'text-amber-500' : 'text-text-main'"
          >
            {{ stats.failures }}
          </div>
        </div>
        <div class="p-2 rounded-md bg-surface-card-sub border border-surface-border-sub">
          <div class="text-[10px] text-text-muted">拦截方式</div>
          <div class="font-mono text-[13px] text-text-main truncate" :title="res?.blockMode">
            {{ res?.blockMode === 'nxdomain' ? 'NXDOMAIN' : res?.blockMode === 'refused' ? 'REFUSED' : res?.blockingIPv4 }}
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-3 gap-2.5">
        <div>
          <label class="text-[11px] font-semibold text-text-muted block mb-1">查询超时 (毫秒)</label>
          <input
            v-model.number="timeoutMs"
            @input="markDraftDirty"
            type="number"
            min="100"
            max="30000"
            :disabled="!enabled"
            class="w-full h-[34px] px-3 rounded-md border border-surface-border bg-surface-card-sub text-xs focus:outline-none focus:border-accent-seal text-text-main font-mono disabled:opacity-50"
          />
        </div>
        <div>
          <label class="text-[11px] font-semibold text-text-muted block mb-1">缓存条目上限</label>
          <input
            v-model.number="cacheSize"
            @input="markDraftDirty"
            type="number"
            min="0"
            :disabled="!enabled"
            class="w-full h-[34px] px-3 rounded-md border border-surface-border bg-surface-card-sub text-xs focus:outline-none focus:border-accent-seal text-text-main font-mono disabled:opacity-50"
          />
        </div>
        <div>
          <label class="text-[11px] font-semibold text-text-muted block mb-1">缓存有效期 (秒)</label>
          <input
            v-model.number="cacheTTLSeconds"
            @input="markDraftDirty"
            type="number"
            min="1"
            :disabled="!enabled"
            class="w-full h-[34px] px-3 rounded-md border border-surface-border bg-surface-card-sub text-xs focus:outline-none focus:border-accent-seal text-text-main font-mono disabled:opacity-50"
          />
        </div>
      </div>

      <div class="flex justify-end">
        <button
          type="button"
          class="app-btn-primary app-btn-compact"
          :disabled="saving || !loaded || !enabled"
          @click="saveAdvanced"
        >
          <M3Icon name="check" :size="14" />
          <span>保存查询参数</span>
        </button>
      </div>
    </div>

    <template #footer>
      <div class="text-[11px] text-text-muted">
        缓存按 2 字节前缀索引——这正是哈希前缀机制本身的粒度，同一前缀下的域名共享一次查询。
      </div>
    </template>
  </AppCard>
</template>
