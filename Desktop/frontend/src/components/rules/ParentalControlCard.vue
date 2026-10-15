<script setup lang="ts">
import { ref, computed } from 'vue';
import { ipc } from '../../api/ipc';
import type { SafeBrowsingResponse } from '../../api/types';
import AppCard from '../ui/AppCard.vue';
import StatusBadge from '../StatusBadge.vue';
import { extractSwitchValue, revertSwitch } from '../../utils/switch';

const emit = defineEmits<{ (e: 'error', message: string): void; (e: 'success', message: string): void }>();

const res = ref<SafeBrowsingResponse | null>(null);
const saving = ref(false);
const loaded = ref(false);

const enabled = computed(() => res.value?.config.parentalEnabled ?? false);
const sbEnabled = computed(() => res.value?.config.enabled ?? false);

async function fetchData() {
  try {
    res.value = await ipc.getSafeBrowsing();
    loaded.value = true;
  } catch (err: any) {
    emit('error', err?.message || '获取家长控制配置失败');
  }
}

async function toggleParental(e: Event) {
  const next = extractSwitchValue(e);
  try {
    saving.value = true;
    // 只提交这一个字段：可与恶意网址库的开关各自独立地切换，
    // 两边同时写入时不会把对方的设置覆盖回默认值
    res.value = await ipc.configureSafeBrowsing({ parentalEnabled: next });
    emit('success', `家长控制已${next ? '开启' : '关闭'}`);
  } catch (err: any) {
    revertSwitch(e, !next);
    emit('error', err?.message || '更新家长控制开关失败');
  } finally {
    saving.value = false;
  }
}

defineExpose({ fetchData });
fetchData();
</script>

<template>
  <AppCard
    title="家长控制"
    subtitle="借第三方分类库拦截成人内容域名，与恶意网址库各自独立开关"
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
      <md-switch :selected="enabled" :disabled="saving || !loaded" @change="toggleParental" />
    </template>

    <div class="space-y-3 mt-3 text-xs">
      <p class="text-[11px] text-text-sub leading-relaxed">
        与恶意网址库机制相同，查询后缀为 <code class="font-mono">pc.dns.adguard.com</code>，
        仅域名哈希前缀会离开本机。
      </p>

      <div class="p-2.5 rounded-md border border-surface-border-sub bg-surface-card-sub text-[11px] text-text-muted leading-relaxed">
        <p>
          两个服务同时命中时，日志中的归因优先记为
          <span class="font-semibold text-text-main">恶意网址库</span>——
          被收录为钓鱼或恶意软件站点比内容分类更值得关注。
        </p>
        <p class="mt-1.5">
          只对 A / AAAA / HTTPS / SVCB 这类会产生连接的查询生效；
          MX、TXT 等不建立连接的记录类型不受影响，邮件与域名验证流程不会因此中断。
        </p>
      </div>

      <div
        v-if="enabled && !sbEnabled"
        class="p-2.5 rounded-md border border-amber-500/30 bg-amber-500/10 text-[11px] text-text-sub leading-relaxed"
      >
        恶意网址库当前未开启。两者互不依赖，可只开家长控制；但钓鱼与恶意软件站点不在家长控制的分类范围内。
      </div>
    </div>

    <template #footer>
      <div class="text-[11px] text-text-muted">
        查询超时、缓存容量与有效期与恶意网址库共用，在上方卡片中调整。
      </div>
    </template>
  </AppCard>
</template>
