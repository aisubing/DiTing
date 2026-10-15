<script setup lang="ts">
import { computed, ref } from 'vue';
import { ipc } from '../api/ipc';
import type { CheckHostResult } from '../api/types';
import { RCODE_NAMES } from '../api/types';
import M3Icon from './M3Icon.vue';
import AppCard from './ui/AppCard.vue';

const emit = defineEmits<{
  (e: 'error', message: string): void;
}>();

const testDomain = ref('');
const testQType = ref('A');
const testResult = ref<CheckHostResult | null>(null);
const testing = ref(false);

/** 重写命中的结论文本：以应答码或记录内容呈现，而非笼统的「已放行」 */
const rewriteLabel = computed(() => {
  const rw = testResult.value?.rewritten;
  if (!rw) return '已被重写';
  return RCODE_NAMES[rw.rcode] || `RCODE ${rw.rcode}`;
});

async function runTest() {
  if (!testDomain.value.trim()) return;
  try {
    testing.value = true;
    testResult.value = await ipc.checkHost(testDomain.value.trim(), testQType.value);
  } catch (err: any) {
    emit('error', err?.message || '规则检测异常');
  } finally {
    testing.value = false;
  }
}

function fillExample(domain: string) {
  testDomain.value = domain;
  runTest();
}
</script>

<template>
  <div class="grid grid-cols-1 lg:grid-cols-2 gap-5 items-stretch select-none">
    <!-- 左侧：输入与检测设置卡片 -->
    <AppCard
      title="网址拦截模拟测试"
      subtitle="输入域名快速检测是否命中过滤拦截规则"
      icon="search"
      :iconSize="16"
    >
      <div class="space-y-3 mt-3 text-xs">
        <div>
          <label class="text-[11px] font-semibold text-text-muted block mb-1">测试目标域名</label>
          <input
            v-model="testDomain"
            placeholder="例如: ad.example.com 或 tracker.domain.com"
            @keyup.enter="runTest"
            class="w-full h-[34px] px-3 rounded-md border border-surface-border bg-surface-card-sub text-xs focus:outline-none focus:border-accent-seal text-text-main placeholder:text-text-muted font-mono"
          />
        </div>

        <div>
          <label class="text-[11px] font-semibold text-text-muted block mb-1">DNS 记录类型</label>
          <select
            v-model="testQType"
            class="w-full h-[34px] px-3 rounded-md border border-surface-border bg-surface-card-sub text-xs focus:outline-none focus:border-accent-seal text-text-main cursor-pointer"
          >
            <option value="A">IPv4 地址解析 (A 记录)</option>
            <option value="AAAA">IPv6 地址解析 (AAAA 记录)</option>
            <option value="ANY">任意解析类型 (ANY)</option>
          </select>
        </div>

        <!-- 快速测试预设标签 -->
        <div class="pt-1">
          <span class="text-[11px] text-text-muted block mb-1.5">快速填充示例：</span>
          <div class="flex flex-wrap gap-1.5">
            <button
              type="button"
              @click="fillExample('adservice.google.com')"
              class="app-btn-chip font-mono text-[11px]"
            >
              adservice.google.com
            </button>
            <button
              type="button"
              @click="fillExample('telemetry.microsoft.com')"
              class="app-btn-chip font-mono text-[11px]"
            >
              telemetry.microsoft.com
            </button>
            <button
              type="button"
              @click="fillExample('baidu.com')"
              class="app-btn-chip font-mono text-[11px]"
            >
              baidu.com
            </button>
          </div>
        </div>
      </div>

      <template #footer>
        <button
          type="button"
          @click="runTest"
          :disabled="testing || !testDomain.trim()"
          class="app-btn-primary w-full"
        >
          <M3Icon :name="testing ? 'refresh' : 'bolt'" :size="15" :class="testing ? 'animate-spin' : ''" />
          <span>{{ testing ? '正在执行规则匹配...' : '立即模拟检测' }}</span>
        </button>
      </template>
    </AppCard>

    <!-- 右侧：检测诊断结果卡片 -->
    <AppCard
      title="规则诊断与拦截判定"
      subtitle="规则匹配结果、所属规则库与响应动作"
      icon="verified_user"
      :iconSize="16"
    >
      <div v-if="!testResult" class="py-14 text-center text-xs text-text-muted space-y-2">
        <M3Icon name="search" :size="32" class="text-text-muted opacity-40 mx-auto" />
        <p>在左侧输入域名并点击「立即模拟检测」以查看规则判定明细</p>
      </div>

      <div v-else class="space-y-3 mt-3 text-xs">
        <!-- 判定结论标识 -->
        <div
          class="p-3.5 rounded-md border flex items-center justify-between gap-3"
          :class="
            testResult.blocked
              ? 'bg-status-error-bg border-status-error/30'
              : testResult.action === 'rewrite'
                ? 'bg-brand-container/40 border-brand-primary/30'
                : testResult.action === 'allow'
                  ? 'bg-status-success-bg border-status-success/30'
                  : 'bg-surface-card-sub border-surface-border-sub'
          "
        >
          <div class="flex items-center gap-2.5 min-w-0">
            <span
              class="px-2 py-0.5 rounded text-[11px] font-bold shrink-0"
              :class="
                testResult.blocked
                  ? 'bg-accent-seal text-white'
                  : testResult.action === 'rewrite'
                    ? 'bg-brand-primary text-white'
                    : testResult.action === 'allow'
                      ? 'bg-status-success text-white'
                      : 'bg-surface-card text-text-sub border border-surface-border'
              "
            >
              {{
                testResult.blocked
                  ? '已拦截 (阻断访问)'
                  : testResult.action === 'rewrite'
                    ? `已重写 (${rewriteLabel})`
                    : testResult.action === 'allow'
                      ? '已放行 (信任名单)'
                      : '未命中 (正常解析)'
              }}
            </span>
            <span class="font-mono font-bold text-text-main text-[13px] truncate select-all">
              {{ testDomain }}
            </span>
          </div>
          <span class="text-[11px] font-mono text-text-muted shrink-0">{{ testQType }}</span>
        </div>

        <!-- 明细字段磁贴 -->
        <div class="space-y-2">
          <div class="app-card-sub p-2.5 space-y-0.5">
            <span class="text-[11px] text-text-muted block">命中的防护规则</span>
            <span class="font-mono text-text-main font-semibold text-[12px] block truncate select-all">
              {{ testResult.matchedRule || '未命中任何规则' }}
            </span>
          </div>

          <div class="grid grid-cols-2 gap-2.5">
            <div class="app-card-sub p-2.5 space-y-0.5">
              <span class="text-[11px] text-text-muted block">来源规则库</span>
              <span class="font-medium text-text-main text-[12px] block truncate">
                {{ testResult.listName || '无' }}
              </span>
            </div>

            <div class="app-card-sub p-2.5 space-y-0.5">
              <span class="text-[11px] text-text-muted block">处置判定原因</span>
              <span class="font-medium text-text-main text-[12px] block truncate">
                {{ testResult.reason || '正常直连解析' }}
              </span>
            </div>
          </div>

          <!-- 重写命中的应答内容 -->
          <div v-if="testResult.rewritten" class="app-card-sub p-2.5 space-y-1">
            <span class="text-[11px] text-text-muted block">$dnsrewrite 应答内容</span>
            <p v-if="!testResult.rewritten.summary?.length" class="font-mono text-text-main text-[11px]">
              {{ rewriteLabel }}，不返回任何记录（权威 NODATA）
            </p>
            <ul v-else class="space-y-0.5">
              <li
                v-for="(item, idx) in testResult.rewritten.summary"
                :key="idx"
                class="font-mono text-text-main text-[11px] break-all select-all"
              >
                {{ item }}
              </li>
            </ul>
          </div>
        </div>
      </div>

      <template #footer>
        <div class="text-[11px] text-text-muted">
          支持 AdGuard、Hosts 及自定义规则即时模拟测试。
        </div>
      </template>
    </AppCard>
  </div>
</template>
