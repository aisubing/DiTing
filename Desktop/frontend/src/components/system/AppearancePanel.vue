<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { themeManager, type ThemeMode, type ThemePalette } from '../../theme/theme';
import AppCard from '../ui/AppCard.vue';
import M3Icon from '../M3Icon.vue';

// 主题模式与配色方案响应式状态（始终与 ThemeManager 单一事实来源保持同步）
const currentMode = computed(() => themeManager.themeModeRef.value);
const currentPalette = computed(() => themeManager.themePaletteRef.value);

function handleModeChange(mode: ThemeMode) {
  themeManager.setThemeMode(mode);
}

function handlePaletteChange(palette: ThemePalette) {
  themeManager.setThemePalette(palette);
}

const statusText = computed(() => {
  const paletteName = currentPalette.value === 'adguard' ? 'AdGuard 绿' : '经典墨朱';
  const modeName = currentMode.value === 'dark' ? '深色' : currentMode.value === 'light' ? '浅色' : '跟随系统';
  return `${paletteName} · ${modeName}`;
});

const modeOptions = computed(() => [
  { id: 'system' as const, name: '跟随系统' },
  { id: 'light' as const, name: currentPalette.value === 'adguard' ? '浅色护盾' : '浅色宣纸' },
  { id: 'dark' as const, name: currentPalette.value === 'adguard' ? '深色幽绿' : '深色墨夜' },
]);
</script>

<template>
  <div class="space-y-5 select-none">
    <AppCard
      title="外观与界面主题"
      subtitle="多套设计体系自由切换，深浅模式与视觉体验全局适配"
      icon="palette"
    >
      <template #actions>
        <span class="text-[11px] font-semibold text-text-muted">
          当前: {{ statusText }}
        </span>
      </template>

      <!-- 1. 主题配色方案切换 -->
      <div class="space-y-2 mt-2">
        <label class="text-[11px] font-semibold text-text-muted block">主题配色方案</label>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
          <!-- 经典墨朱主题 -->
          <button
            type="button"
            @click="handlePaletteChange('classic')"
            class="app-btn-base justify-between h-13 px-3.5 rounded-lg border text-left"
            :class="[
              currentPalette === 'classic'
                ? 'bg-brand-primary text-brand-on-primary border-brand-primary shadow-xs'
                : 'bg-surface-card-sub border-surface-border text-text-main hover:bg-surface-hover',
            ]"
          >
            <div class="flex items-center gap-2.5">
              <span class="w-3.5 h-3.5 rounded-full bg-[#9E2B25] shrink-0 border border-black/10" />
              <div class="flex flex-col leading-tight">
                <span class="text-[13px] font-semibold">经典水墨 (默认)</span>
                <span class="text-[11px] opacity-75 mt-0.5">水墨黑白主色 · 朱砂红印章强调</span>
              </div>
            </div>
            <M3Icon
              v-if="currentPalette === 'classic'"
              name="check"
              :size="16"
              class="shrink-0"
            />
          </button>

          <!-- AdGuard 绿主题 -->
          <button
            type="button"
            @click="handlePaletteChange('adguard')"
            class="app-btn-base justify-between h-13 px-3.5 rounded-lg border text-left"
            :class="[
              currentPalette === 'adguard'
                ? 'bg-brand-primary text-brand-on-primary border-brand-primary shadow-xs'
                : 'bg-surface-card-sub border-surface-border text-text-main hover:bg-surface-hover',
            ]"
          >
            <div class="flex items-center gap-2.5">
              <span class="w-3.5 h-3.5 rounded-full bg-[#67B279] shrink-0 border border-black/10" />
              <div class="flex flex-col leading-tight">
                <span class="text-[13px] font-semibold">AdGuard 绿</span>
                <span class="text-[11px] opacity-75 mt-0.5">源自 AdGuard 官方规范 · 护盾绿主色</span>
              </div>
            </div>
            <M3Icon
              v-if="currentPalette === 'adguard'"
              name="check"
              :size="16"
              class="shrink-0"
            />
          </button>
        </div>
      </div>

      <!-- 2. 明暗模式切换按钮组 -->
      <div class="space-y-2 mt-4.5">
        <label class="text-[11px] font-semibold text-text-muted block">界面明暗模式</label>
        <div class="flex flex-wrap gap-2.5">
          <button
            v-for="m in modeOptions"
            :key="m.id"
            type="button"
            @click="handleModeChange(m.id)"
            class="app-btn-base flex-1 min-w-[90px]"
            :class="[
              currentMode === m.id
                ? 'bg-brand-primary text-brand-on-primary border border-brand-primary'
                : 'bg-surface-card-sub border border-surface-border text-text-sub hover:bg-surface-hover',
            ]"
          >
            {{ m.name }}
          </button>
        </div>
      </div>

      <template #footer>
        <!-- 响应式动态设计规范展示 -->
        <div class="app-card-sub p-3 flex items-center gap-3">
          <!-- 经典墨朱展示色块 -->
          <template v-if="currentPalette === 'classic'">
            <div class="flex items-center -space-x-1 shrink-0">
              <span class="w-5 h-5 rounded-md bg-[#1A1A1C] border border-surface-border z-10" title="墨 #1A1A1C"></span>
              <span class="w-5 h-5 rounded-md bg-[#8A8B8E] border border-surface-border" title="灰 #8A8B8E"></span>
              <span class="w-5 h-5 rounded-md bg-[#F1EFE9] border border-surface-border" title="宣纸 #F1EFE9"></span>
              <span class="w-5 h-5 rounded-md bg-[#9E2B25] border border-surface-border" title="朱砂 #9E2B25"></span>
            </div>
            <div>
              <div class="text-[12px] font-semibold text-text-main">
                墨 · 朱 视觉规范体系
              </div>
              <div class="text-[11px] text-text-muted leading-tight mt-0.5">
                以水墨黑白灰为主调，朱砂红用于关键拦截与重要警示，内敛厚重、深浅双色对等适配。
              </div>
            </div>
          </template>

          <!-- AdGuard 绿展示色块 -->
          <template v-else>
            <div class="flex items-center -space-x-1 shrink-0">
              <span class="w-5 h-5 rounded-md bg-[#67B279] border border-surface-border z-10" title="AdGuard 护盾绿 #67B279"></span>
              <span class="w-5 h-5 rounded-md bg-[#5B9F6B] border border-surface-border" title="交互深绿 #5B9F6B"></span>
              <span class="w-5 h-5 rounded-md bg-[#D9ECDE] border border-surface-border" title="柔和底衬 #D9ECDE"></span>
              <span class="w-5 h-5 rounded-md bg-[#1F1F1F] border border-surface-border" title="深色炭灰 #1F1F1F"></span>
            </div>
            <div>
              <div class="text-[12px] font-semibold text-text-main">
                AdGuard 绿色视觉规范体系
              </div>
              <div class="text-[11px] text-text-muted leading-tight mt-0.5">
                参考 AdGuard 官方设计源码提取，以标志性 #67B279 护盾绿为主基调，清爽安全、层级分明且视觉协调。
              </div>
            </div>
          </template>
        </div>
      </template>
    </AppCard>
  </div>
</template>
