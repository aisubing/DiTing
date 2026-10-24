<script setup lang="ts">
import { ref, computed, watch, onMounted, onUnmounted } from 'vue';
import { ipc } from '../api/ipc';
import { themeManager, type ThemeMode, type ThemePalette } from '../theme/theme';
import { useBrandLogo } from '../theme/brandAsset';
import {
  loadLoginBgConfig,
  saveLoginBgConfig,
  resolveBackgroundUrl,
  type LoginBgConfig,
} from '../utils/imageCompressor';
import { useAuthForm } from '../composables/useAuthForm';
import M3Icon from '../components/M3Icon.vue';
import InlineAlert from '../components/ui/InlineAlert.vue';
import LoginBgModal from '../components/auth/LoginBgModal.vue';

const props = withDefaults(
  defineProps<{
    initialMode?: 'login' | 'setup';
  }>(),
  {
    initialMode: 'login',
  }
);

const emit = defineEmits<{
  (e: 'success'): void;
}>();

const {
  currentMode,
  username,
  password,
  confirmPassword,
  showPassword,
  showConfirmPassword,
  loading,
  errorMsg,
  successMsg,
  lockoutSeconds,
  isAuthInitialized,
  checkAuthStatus,
  submitSetup,
  submitLogin,
} = useAuthForm(props.initialMode);

watch(
  () => props.initialMode,
  (val) => {
    if (val) currentMode.value = val;
  }
);

// 背景图配置
const bgConfig = ref<LoginBgConfig>(loadLoginBgConfig());
const showBgModal = ref(false);

// 主题模式与配色方案（响应式关联 ThemeManager）
const currentThemeMode = computed(() => themeManager.themeModeRef.value);
const currentPalette = computed(() => themeManager.themePaletteRef.value);

function togglePalette() {
  const next: ThemePalette = currentPalette.value === 'classic' ? 'adguard' : 'classic';
  themeManager.setThemePalette(next);
}

// 注入版本号
const appLogo = useBrandLogo();
const appVersion = __APP_VERSION__;

const hasCustomBg = computed(() => bgConfig.value.type !== 'none' && Boolean(bgConfig.value.url));

const bgStyle = computed(() => {
  if (!bgConfig.value.url) return {};
  const cfg = ipc.getConfig();
  const baseUrl = cfg.host ? `http://${cfg.host}:${cfg.port}` : undefined;
  const fullUrl = resolveBackgroundUrl(bgConfig.value.url, baseUrl);
  const safeUrl = fullUrl.replace(/'/g, "\\'");
  return {
    backgroundImage: `url('${safeUrl}')`,
    filter: bgConfig.value.blur > 0 ? `blur(${bgConfig.value.blur}px)` : 'none',
    transform: bgConfig.value.blur > 0 ? 'scale(1.05)' : 'none',
  };
});

function cycleTheme() {
  const modes: ThemeMode[] = ['light', 'dark', 'system'];
  const nextIdx = (modes.indexOf(currentThemeMode.value) + 1) % modes.length;
  const nextMode = modes[nextIdx] ?? 'system';
  themeManager.setThemeMode(nextMode);
}

const themeIcon = computed(() => {
  if (currentThemeMode.value === 'dark') return 'contrast';
  if (currentThemeMode.value === 'light') return 'palette';
  return 'settings';
});

const themeLabel = computed(() => {
  if (currentThemeMode.value === 'dark') return '深色模式';
  if (currentThemeMode.value === 'light') return '浅色模式';
  return '跟随系统';
});

async function handleSubmit() {
  let ok = false;
  if (currentMode.value === 'setup') {
    ok = await submitSetup();
  } else {
    ok = await submitLogin();
  }
  if (ok) {
    const delay = currentMode.value === 'setup' ? 700 : 500;
    setTimeout(() => {
      emit('success');
    }, delay);
  }
}

function handleBgChange(newCfg: LoginBgConfig) {
  const cfg = ipc.getConfig();
  const baseUrl = cfg.host ? `http://${cfg.host}:${cfg.port}` : undefined;
  const resolved = resolveBackgroundUrl(newCfg.url, baseUrl);
  bgConfig.value = {
    ...newCfg,
    url: resolved,
  };
}

async function fetchServerBackground() {
  try {
    const remote = await ipc.getLoginBackground();
    if (remote) {
      const cfg = ipc.getConfig();
      const baseUrl = cfg.host ? `http://${cfg.host}:${cfg.port}` : undefined;
      const resolved = resolveBackgroundUrl(remote.url, baseUrl);
      bgConfig.value = {
        type: remote.type,
        url: resolved,
        opacity: remote.opacity ?? 40,
        blur: remote.blur ?? 0,
        updatedAt: remote.updatedAt,
      };
      saveLoginBgConfig(remote.type, resolved, remote.opacity ?? 40, remote.blur ?? 0);
    }
  } catch {}
}

let unsubEvents: (() => void) | null = null;
let syncTimer: ReturnType<typeof setInterval> | null = null;

function handleVisibilityOrFocus() {
  if (typeof document !== 'undefined' && document.visibilityState === 'visible') {
    fetchServerBackground();
  }
}

onMounted(() => {
  checkAuthStatus(props.initialMode);
  fetchServerBackground();
  syncTimer = setInterval(fetchServerBackground, 30000);
  if (typeof window !== 'undefined') {
    window.addEventListener('visibilitychange', handleVisibilityOrFocus);
    window.addEventListener('focus', handleVisibilityOrFocus);
  }
  unsubEvents = ipc.onEvent((event) => {
    if (event.type === 'background') {
      fetchServerBackground();
    }
  });
});

onUnmounted(() => {
  if (syncTimer) clearInterval(syncTimer);
  if (typeof window !== 'undefined') {
    window.removeEventListener('visibilitychange', handleVisibilityOrFocus);
    window.removeEventListener('focus', handleVisibilityOrFocus);
  }
  if (unsubEvents) unsubEvents();
});
</script>

<template>
  <div class="relative min-h-screen w-full flex flex-col justify-between overflow-x-hidden overflow-y-auto font-sans select-none bg-surface-base text-text-main">
    <!-- 1. 自定义壁纸背景层 (支持平滑过渡与模糊) -->
    <div
      v-if="hasCustomBg"
      class="fixed inset-0 z-0 bg-cover bg-center bg-no-repeat transition-all duration-700 pointer-events-none"
      :style="bgStyle"
    />

    <!-- 2. 背景遮罩层 (保证前景卡片文字高清晰度) -->
    <div
      v-if="hasCustomBg"
      class="fixed inset-0 z-0 bg-black pointer-events-none transition-opacity duration-300"
      :style="{ opacity: bgConfig.opacity / 100 }"
    />

    <!-- 3. 装饰性柔光背景（仅默认背景下呈现） -->
    <div
      v-if="!hasCustomBg"
      class="absolute inset-0 pointer-events-none overflow-hidden"
    >
      <div class="absolute -top-[20%] left-1/2 -translate-x-1/2 w-[600px] h-[500px] rounded-full bg-accent-seal/5 dark:bg-accent-seal/10 blur-[120px]" />
      <div class="absolute -bottom-[20%] right-[10%] w-[500px] h-[400px] rounded-full bg-brand-container/40 dark:bg-brand-container/20 blur-[100px]" />
    </div>

    <!-- 顶栏辅助操作：主题切换与自定义壁纸入口 -->
    <header class="relative z-10 w-full px-4 sm:px-8 py-4 flex items-center justify-between">
      <div
        class="flex items-center gap-2.5 transition-all duration-300"
        :class="hasCustomBg ? 'px-3 py-1.5 rounded-lg bg-surface-card/75 backdrop-blur-md border border-surface-border/60 shadow-xs' : ''"
      >
        <img :src="appLogo" alt="Logo" class="w-7 h-7 object-contain rounded-md" />
        <span class="font-serif text-sm font-semibold tracking-wide text-text-main">谛听 DITING</span>
      </div>

      <div class="flex items-center gap-2">
        <!-- 自定义背景入口按钮 -->
        <button
          type="button"
          @click="showBgModal = true"
          class="app-btn-secondary app-btn-compact relative backdrop-blur-md"
          :class="hasCustomBg ? 'border-accent-seal/50 text-accent-seal bg-surface-card/60' : 'bg-surface-card/70'"
          title="配置登录页自定义背景图片"
        >
          <M3Icon name="image" :size="14" />
          <span class="hidden sm:inline">自定义背景</span>
          <span
            v-if="hasCustomBg"
            class="w-1.5 h-1.5 rounded-full bg-accent-seal"
            title="已启用自定义背景"
          />
        </button>

        <!-- 配色方案切换按钮 -->
        <button
          type="button"
          @click="togglePalette"
          class="app-btn-secondary app-btn-compact backdrop-blur-md bg-surface-card/70"
          :title="`当前配色：${currentPalette === 'adguard' ? 'AdGuard 绿色' : '经典墨朱'}（点击切换）`"
        >
          <span
            class="w-2.5 h-2.5 rounded-full shrink-0 border border-black/10"
            :class="currentPalette === 'adguard' ? 'bg-[#67B279]' : 'bg-[#9E2B25]'"
          />
          <span class="hidden sm:inline">{{ currentPalette === 'adguard' ? 'AdGuard 绿' : '经典墨朱' }}</span>
        </button>

        <!-- 主题切换按钮 -->
        <button
          type="button"
          @click="cycleTheme"
          class="app-btn-secondary app-btn-compact backdrop-blur-md bg-surface-card/70"
          :title="`当前主题：${themeLabel}（点击切换）`"
        >
          <M3Icon :name="themeIcon" :size="14" />
          <span class="hidden sm:inline">{{ themeLabel }}</span>
        </button>
      </div>
    </header>

    <!-- 中部主登录卡片容器（自适应不同屏幕尺寸） -->
    <main class="relative z-10 flex-1 flex items-center justify-center p-4 sm:p-6 py-6 sm:py-8">
      <div
        class="w-full max-w-sm sm:max-w-md rounded-xl transition-all duration-300"
        :class="[
          hasCustomBg
            ? 'bg-surface-card/90 dark:bg-surface-card/85 backdrop-blur-md shadow-2xl border border-surface-border/80'
            : 'bg-surface-card shadow-xl border border-surface-border'
        ]"
      >
        <!-- 卡片头部品牌标识 -->
        <div class="p-6 sm:p-8 pb-4 text-center">
          <div class="inline-flex items-center justify-center w-14 h-14 rounded-xl bg-brand-container shadow-xs mb-3.5 mx-auto">
            <img :src="appLogo" alt="谛听 Logo" class="w-10 h-10 object-contain rounded-md" />
          </div>
          <h1 class="font-serif text-xl sm:text-2xl font-bold tracking-tight text-text-main">
            谛听 DNS 控制台
          </h1>
          <p class="text-xs text-text-sub mt-1.5 leading-relaxed">
            {{ currentMode === 'setup' ? '初始化管理员密码，守护局域网远程管理安全' : '局域网远程管理服务 · 请验证管理员凭据' }}
          </p>
        </div>

        <!-- 表单区域 -->
        <form @submit.prevent="handleSubmit" class="px-6 sm:px-8 pb-6 sm:pb-8 space-y-4">
          <InlineAlert v-if="errorMsg" :message="errorMsg" type="error" shake />
          <InlineAlert v-if="successMsg" :message="successMsg" type="success" />

          <!-- 安全锁定倒计时提示 -->
          <div
            v-if="lockoutSeconds > 0"
            class="p-3 rounded-lg bg-status-warning-bg border border-status-warning/30 text-status-warning text-xs flex items-center gap-2"
          >
            <M3Icon name="alarm" :size="16" class="shrink-0" />
            <span>安全保护频控锁定中，请等待 {{ lockoutSeconds }} 秒后再试</span>
          </div>

          <!-- 用户名 -->
          <div class="space-y-1">
            <label class="block text-xs font-medium text-text-sub">管理员账号</label>
            <div class="relative">
              <input
                v-model="username"
                type="text"
                autocomplete="username"
                :disabled="loading || lockoutSeconds > 0"
                class="w-full h-10 px-3 text-sm rounded-md border border-surface-border bg-surface-card text-text-main focus:outline-none focus:border-brand-primary transition-colors disabled:opacity-50"
                placeholder="admin"
              />
            </div>
          </div>

          <!-- 密码输入框 -->
          <div class="space-y-1">
            <div class="flex items-center justify-between">
              <label class="block text-xs font-medium text-text-sub">
                {{ currentMode === 'setup' ? '设置初始密码 (至少 4 位)' : '管理员密码' }}
              </label>
            </div>
            <div class="relative flex items-center">
              <input
                v-model="password"
                :type="showPassword ? 'text' : 'password'"
                autocomplete="current-password"
                :disabled="loading || lockoutSeconds > 0"
                class="w-full h-10 pl-3 pr-10 text-sm rounded-md border border-surface-border bg-surface-card text-text-main focus:outline-none focus:border-brand-primary transition-colors disabled:opacity-50"
                placeholder="请输入密码"
              />
              <button
                type="button"
                @click="showPassword = !showPassword"
                class="absolute right-2.5 p-1 text-text-muted hover:text-text-main cursor-pointer"
                title="显隐密码"
              >
                <M3Icon :name="showPassword ? 'visibility_off' : 'visibility'" :size="16" />
              </button>
            </div>
          </div>

          <!-- 确认密码（仅设置模式） -->
          <div v-if="currentMode === 'setup'" class="space-y-1">
            <label class="block text-xs font-medium text-text-sub">确认管理员密码</label>
            <div class="relative flex items-center">
              <input
                v-model="confirmPassword"
                :type="showConfirmPassword ? 'text' : 'password'"
                autocomplete="new-password"
                :disabled="loading || lockoutSeconds > 0"
                class="w-full h-10 pl-3 pr-10 text-sm rounded-md border border-surface-border bg-surface-card text-text-main focus:outline-none focus:border-brand-primary transition-colors disabled:opacity-50"
                placeholder="请再次输入设置的新密码"
              />
              <button
                type="button"
                @click="showConfirmPassword = !showConfirmPassword"
                class="absolute right-2.5 p-1 text-text-muted hover:text-text-main cursor-pointer"
                title="显隐密码"
              >
                <M3Icon :name="showConfirmPassword ? 'visibility_off' : 'visibility'" :size="16" />
              </button>
            </div>
          </div>

          <!-- 提交登录按钮 -->
          <div class="pt-2">
            <button
              type="submit"
              :disabled="loading || lockoutSeconds > 0"
              class="app-btn-primary w-full h-11 text-sm font-semibold shadow-md flex items-center justify-center gap-2 cursor-pointer"
            >
              <M3Icon :name="loading ? 'sync' : 'check'" :size="18" :class="loading ? 'animate-spin' : ''" />
              <span>{{ currentMode === 'setup' ? '完成初始化并进入控制台' : '立即登录' }}</span>
            </button>
          </div>

          <!-- 模式切换与安全提示 -->
          <div class="pt-2 border-t border-surface-border text-center text-[11px] text-text-muted space-y-1">
            <div class="flex items-center justify-center gap-1.5 text-text-sub">
              <M3Icon name="shield" :size="13" class="text-accent-seal" />
              <span>SHA-256 加盐哈希保护 · 连续错误自动安全锁定</span>
            </div>
          </div>
        </form>
      </div>
    </main>

    <!-- 底部版权信息 -->
    <footer class="relative z-10 py-3 text-center text-[11px] px-4">
      <span
        class="transition-all duration-300"
        :class="hasCustomBg ? 'inline-block px-3.5 py-1 rounded-full bg-surface-card/75 backdrop-blur-md border border-surface-border/60 text-text-sub shadow-2xs' : 'text-text-muted'"
      >
        谛听 (DITING) DNS 解析加速与安全防护系统
      </span>
    </footer>

    <!-- 自定义背景弹窗 -->
    <LoginBgModal
      :open="showBgModal"
      :current-config="bgConfig"
      :admin-password="password"
      :is-auth-initialized="isAuthInitialized"
      :is-authenticated="Boolean(ipc.isConnected && ipc.token)"
      @close="showBgModal = false"
      @change="handleBgChange"
    />
  </div>
</template>
