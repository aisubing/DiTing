<script setup lang="ts">
import { computed } from 'vue';
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
  const paletteName = currentPalette.value === 'adguard' ? 'AdGuard 绿' : '经典水墨';
  const modeName = currentMode.value === 'dark' ? '深色' : currentMode.value === 'light' ? '浅色' : '跟随系统';
  return `${paletteName} · ${modeName}`;
});

const modeOptions = computed(() => [
  {
    id: 'system' as const,
    name: '跟随系统',
    subtext: '自动匹配',
    desc: '依据 Windows 系统深浅偏好自动同步',
    icon: 'contrast',
  },
  {
    id: 'light' as const,
    name: '浅色模式',
    subtext: currentPalette.value === 'adguard' ? '浅色护盾' : '浅色宣纸',
    desc: '明亮通透，适合白天与高采光环境',
    icon: 'light_mode',
  },
  {
    id: 'dark' as const,
    name: '深色模式',
    subtext: currentPalette.value === 'adguard' ? '深色幽绿' : '深色墨夜',
    desc: '幽静护眼，适合夜间弱光与防眩光',
    icon: 'dark_mode',
  },
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
        <div class="flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-surface-card-sub border border-surface-border text-[11px] font-medium text-text-sub">
          <span class="w-1.5 h-1.5 rounded-full bg-brand-primary" />
          <span>当前: {{ statusText }}</span>
        </div>
      </template>

      <!-- 1. 主题配色方案选择 -->
      <div class="space-y-3.5 mt-1">
        <div class="flex items-baseline justify-between">
          <div>
            <h4 class="text-[13px] font-semibold text-text-main">主题配色方案</h4>
            <p class="text-[11px] text-text-muted mt-0.5">选择符合个人偏好的视觉设计体系，所有界面元素即时协调匹配</p>
          </div>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <!-- 经典墨朱主题卡片 -->
          <div
            role="button"
            tabindex="0"
            @click="handlePaletteChange('classic')"
            @keydown.enter.prevent="handlePaletteChange('classic')"
            @keydown.space.prevent="handlePaletteChange('classic')"
            class="group relative rounded-xl p-4 sm:p-5 border transition-all duration-200 cursor-pointer flex flex-col justify-between text-left focus:outline-none"
            :class="[
              currentPalette === 'classic'
                ? 'border-brand-primary ring-2 ring-brand-primary/15 bg-brand-container/15 shadow-sm'
                : 'border-surface-border bg-surface-card hover:border-surface-border/80 hover:bg-surface-hover/30 hover:shadow-xs',
            ]"
          >
            <!-- 视觉界面 Mini Mockup 预览窗口 -->
            <div class="h-28 rounded-lg mb-3.5 border border-surface-border-sub/80 overflow-hidden relative select-none p-2.5 flex gap-2.5 bg-[#FAF9F5] dark:bg-[#1E1F23] transition-colors">
              <!-- Mini 侧边导航 -->
              <div class="w-10 rounded-md bg-[#1A1A1C] dark:bg-[#121316] p-1.5 flex flex-col items-center gap-1.5 shrink-0 shadow-xs">
                <span class="w-2.5 h-2.5 rounded-full bg-[#9E2B25]" />
                <span class="w-4 h-1 rounded-full bg-white/40 mt-1" />
                <span class="w-4 h-1 rounded-full bg-white/20" />
                <span class="w-4 h-1 rounded-full bg-white/20" />
              </div>
              <!-- Mini 内容工作区 -->
              <div class="flex-1 flex flex-col justify-between py-0.5">
                <div class="flex items-center justify-between">
                  <div class="flex items-center gap-1.5">
                    <span class="text-[10px] font-bold tracking-tight text-[#1A1A1C] dark:text-[#E9E8E4]">谛听 DNS</span>
                    <span class="text-[9px] px-1 py-0.2 rounded bg-[#9E2B25] text-white font-medium">墨 · 朱</span>
                  </div>
                  <span class="w-1.5 h-1.5 rounded-full bg-[#2F6B4F]" />
                </div>
                <div class="rounded bg-white dark:bg-[#26272B] p-1.5 border border-[#E3E0D6] dark:border-[#34353A] shadow-xs">
                  <div class="flex items-center justify-between text-[9px] text-[#55565A] dark:text-[#B4B4B0] font-medium">
                    <span>拦截率 28.4%</span>
                    <span class="text-[#9E2B25] font-bold">已过滤</span>
                  </div>
                  <div class="w-full bg-[#F1EFE9] dark:bg-[#34353A] h-1.5 rounded-full mt-1 overflow-hidden">
                    <div class="bg-[#9E2B25] h-full rounded-full" style="width: 65%" />
                  </div>
                </div>
                <div class="flex items-center gap-1 text-[8px] text-[#8A8B8E] dark:text-[#7C7D80]">
                  <span class="w-1.5 h-1.5 rounded-xs bg-[#8A8B8E]" />
                  <span>水墨宣纸基调 · 朱砂印章点缀</span>
                </div>
              </div>
            </div>

            <!-- 卡片文本与状态区 -->
            <div class="space-y-2">
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <span class="w-2.5 h-2.5 rounded-full bg-[#9E2B25] shrink-0" />
                  <span class="text-[14px] font-semibold text-text-main">经典水墨</span>
                  <span class="text-[10px] px-1.5 py-0.5 rounded bg-surface-card-sub border border-surface-border text-text-muted">默认</span>
                </div>
                <!-- 勾选指示器 -->
                <div
                  class="w-5 h-5 rounded-full flex items-center justify-center transition-transform shrink-0"
                  :class="[
                    currentPalette === 'classic'
                      ? 'bg-brand-primary text-brand-on-primary scale-100'
                      : 'border-2 border-surface-border scale-90 opacity-40',
                  ]"
                >
                  <M3Icon v-if="currentPalette === 'classic'" name="check" :size="13" />
                </div>
              </div>

              <p class="text-[11.5px] text-text-sub leading-relaxed">
                以东方传统水墨黑白为基调，朱砂红用于关键拦截与警示。内敛雅致，沉稳清正。
              </p>

              <!-- 颜色色谱条 -->
              <div class="flex items-center gap-2 pt-1 border-t border-surface-border-sub/60">
                <span class="text-[10px] text-text-muted">核心色彩:</span>
                <div class="flex items-center gap-1.5">
                  <span class="w-4 h-4 rounded-full bg-[#1A1A1C] border border-black/10 shrink-0" title="墨色 #1A1A1C" />
                  <span class="w-4 h-4 rounded-full bg-[#8A8B8E] border border-black/10 shrink-0" title="石灰 #8A8B8E" />
                  <span class="w-4 h-4 rounded-full bg-[#F1EFE9] border border-black/10 shrink-0" title="宣纸 #F1EFE9" />
                  <span class="w-4 h-4 rounded-full bg-[#9E2B25] border border-black/10 shrink-0" title="朱砂 #9E2B25" />
                </div>
              </div>
            </div>
          </div>

          <!-- AdGuard 绿主题卡片 -->
          <div
            role="button"
            tabindex="0"
            @click="handlePaletteChange('adguard')"
            @keydown.enter.prevent="handlePaletteChange('adguard')"
            @keydown.space.prevent="handlePaletteChange('adguard')"
            class="group relative rounded-xl p-4 sm:p-5 border transition-all duration-200 cursor-pointer flex flex-col justify-between text-left focus:outline-none"
            :class="[
              currentPalette === 'adguard'
                ? 'border-brand-primary ring-2 ring-brand-primary/15 bg-brand-container/15 shadow-sm'
                : 'border-surface-border bg-surface-card hover:border-surface-border/80 hover:bg-surface-hover/30 hover:shadow-xs',
            ]"
          >
            <!-- 视觉界面 Mini Mockup 预览窗口 -->
            <div class="h-28 rounded-lg mb-3.5 border border-surface-border-sub/80 overflow-hidden relative select-none p-2.5 flex gap-2.5 bg-[#F5F7F5] dark:bg-[#161C18] transition-colors">
              <!-- Mini 侧边导航 -->
              <div class="w-10 rounded-md bg-[#67B279] dark:bg-[#25422D] p-1.5 flex flex-col items-center gap-1.5 shrink-0 shadow-xs">
                <span class="w-2.5 h-2.5 rounded-full bg-white" />
                <span class="w-4 h-1 rounded-full bg-white/70 mt-1" />
                <span class="w-4 h-1 rounded-full bg-white/30" />
                <span class="w-4 h-1 rounded-full bg-white/30" />
              </div>
              <!-- Mini 内容工作区 -->
              <div class="flex-1 flex flex-col justify-between py-0.5">
                <div class="flex items-center justify-between">
                  <div class="flex items-center gap-1.5">
                    <span class="text-[10px] font-bold tracking-tight text-[#1F2D22] dark:text-[#E4E9E5]">谛听 DNS</span>
                    <span class="text-[9px] px-1 py-0.2 rounded bg-[#67B279] text-white font-medium">AdGuard 绿</span>
                  </div>
                  <span class="w-1.5 h-1.5 rounded-full bg-[#67B279]" />
                </div>
                <div class="rounded bg-white dark:bg-[#1E2620] p-1.5 border border-[#D3DED5] dark:border-[#2C382E] shadow-xs">
                  <div class="flex items-center justify-between text-[9px] text-[#4E5D52] dark:text-[#A2B5A7] font-medium">
                    <span>拦截率 28.4%</span>
                    <span class="text-[#67B279] font-bold">护盾保护中</span>
                  </div>
                  <div class="w-full bg-[#EDF3EE] dark:bg-[#28352B] h-1.5 rounded-full mt-1 overflow-hidden">
                    <div class="bg-[#67B279] h-full rounded-full" style="width: 75%" />
                  </div>
                </div>
                <div class="flex items-center gap-1 text-[8px] text-[#78867B] dark:text-[#889B8D]">
                  <span class="w-1.5 h-1.5 rounded-xs bg-[#67B279]" />
                  <span>源自官方规范 · 护眼清爽</span>
                </div>
              </div>
            </div>

            <!-- 卡片文本与状态区 -->
            <div class="space-y-2">
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <span class="w-2.5 h-2.5 rounded-full bg-[#67B279] shrink-0" />
                  <span class="text-[14px] font-semibold text-text-main">AdGuard 绿</span>
                  <span class="text-[10px] px-1.5 py-0.5 rounded bg-surface-card-sub border border-surface-border text-text-muted">官方规范</span>
                </div>
                <!-- 勾选指示器 -->
                <div
                  class="w-5 h-5 rounded-full flex items-center justify-center transition-transform shrink-0"
                  :class="[
                    currentPalette === 'adguard'
                      ? 'bg-brand-primary text-brand-on-primary scale-100'
                      : 'border-2 border-surface-border scale-90 opacity-40',
                  ]"
                >
                  <M3Icon v-if="currentPalette === 'adguard'" name="check" :size="13" />
                </div>
              </div>

              <p class="text-[11.5px] text-text-sub leading-relaxed">
                参考 AdGuard 官方设计源码提取，以标志性 #67B279 护盾绿为主色。清爽护眼，层级分明。
              </p>

              <!-- 颜色色谱条 -->
              <div class="flex items-center gap-2 pt-1 border-t border-surface-border-sub/60">
                <span class="text-[10px] text-text-muted">核心色彩:</span>
                <div class="flex items-center gap-1.5">
                  <span class="w-4 h-4 rounded-full bg-[#67B279] border border-black/10 shrink-0" title="护盾绿 #67B279" />
                  <span class="w-4 h-4 rounded-full bg-[#5B9F6B] border border-black/10 shrink-0" title="交互深绿 #5B9F6B" />
                  <span class="w-4 h-4 rounded-full bg-[#D9ECDE] border border-black/10 shrink-0" title="柔和衬底 #D9ECDE" />
                  <span class="w-4 h-4 rounded-full bg-[#1F2D22] border border-black/10 shrink-0" title="深色炭灰 #1F2D22" />
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- 2. 明暗模式切换 -->
      <div class="mt-7 pt-5 border-t border-surface-border-sub space-y-3.5">
        <div>
          <h4 class="text-[13px] font-semibold text-text-main">界面明暗模式</h4>
          <p class="text-[11px] text-text-muted mt-0.5">自由选择深浅对比度，或开启系统自适应跟随</p>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
          <button
            v-for="m in modeOptions"
            :key="m.id"
            type="button"
            @click="handleModeChange(m.id)"
            class="group relative rounded-xl p-3.5 border transition-all duration-150 text-left cursor-pointer flex flex-col justify-between gap-2.5 focus:outline-none"
            :class="[
              currentMode === m.id
                ? 'border-brand-primary ring-2 ring-brand-primary/15 bg-brand-container/20 text-text-main shadow-xs'
                : 'border-surface-border bg-surface-card hover:bg-surface-hover/50 text-text-sub',
            ]"
          >
            <div class="flex items-center justify-between w-full">
              <div class="flex items-center gap-2.5">
                <div
                  class="w-7 h-7 rounded-lg flex items-center justify-center transition-colors"
                  :class="[
                    currentMode === m.id
                      ? 'bg-brand-primary text-brand-on-primary'
                      : 'bg-surface-card-sub border border-surface-border-sub text-text-muted group-hover:text-text-main',
                  ]"
                >
                  <M3Icon :name="m.icon" :size="16" />
                </div>
                <div class="flex flex-col">
                  <span class="text-[13px] font-semibold text-text-main">{{ m.name }}</span>
                  <span class="text-[10px] text-text-muted font-medium">{{ m.subtext }}</span>
                </div>
              </div>

              <!-- 激活状态勾选小圆点 -->
              <div
                class="w-4 h-4 rounded-full flex items-center justify-center transition-transform shrink-0"
                :class="[
                  currentMode === m.id
                    ? 'bg-brand-primary text-brand-on-primary scale-100'
                    : 'border border-surface-border scale-75 opacity-30',
                ]"
              >
                <M3Icon v-if="currentMode === m.id" name="check" :size="10" />
              </div>
            </div>

            <p class="text-[11px] text-text-muted leading-tight">
              {{ m.desc }}
            </p>
          </button>
        </div>
      </div>

      <!-- 3. 卡片底部信息说明栏 -->
      <template #footer>
        <div class="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 text-[11.5px] text-text-muted">
          <div class="flex items-center gap-2">
            <M3Icon name="verified_user" :size="15" class="text-brand-primary shrink-0" />
            <span>设置即刻全局渲染生效，已自动持久化保存至本地系统。</span>
          </div>
          <div class="flex items-center gap-1.5 shrink-0">
            <span class="inline-block w-2 h-2 rounded-full bg-status-success" />
            <span class="font-medium text-text-sub">已应用：{{ statusText }}</span>
          </div>
        </div>
      </template>
    </AppCard>
  </div>
</template>
