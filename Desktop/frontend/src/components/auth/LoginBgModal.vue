<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import AppModal from '../AppModal.vue';
import M3Icon from '../M3Icon.vue';
import { ipc } from '../../api/ipc';
import { isDesktopApp } from '../../utils/env';
import {
  compressImageFile,
  validateImageUrl,
  saveLoginBgConfig,
  clearLoginBgConfig,
  isInternalBgUrl,
  type LoginBgConfig,
} from '../../utils/imageCompressor';

const props = withDefaults(
  defineProps<{
    open: boolean;
    currentConfig: LoginBgConfig;
    adminPassword?: string;
    isAuthInitialized?: boolean;
    isAuthenticated?: boolean;
  }>(),
  {
    adminPassword: '',
    isAuthInitialized: true,
    isAuthenticated: false,
  }
);

const emit = defineEmits<{
  (e: 'close'): void;
  (e: 'change', config: LoginBgConfig): void;
}>();

const activeTab = ref<'local' | 'url'>('local');
const localPreviewUrl = ref('');
const urlPreviewUrl = ref('');
const imageUrlInput = ref('');
const opacity = ref(40);
const blur = ref(0);
const adminPasswordInput = ref('');
const showAdminPassword = ref(false);

const isProcessing = ref(false);
const errorMsg = ref('');
const successMsg = ref('');
const fileInput = ref<HTMLInputElement | null>(null);

const needPasswordVerification = computed(() => {
  if (isDesktopApp()) return false;
  if (!props.isAuthInitialized) return false;
  if (props.isAuthenticated) return false;
  if (typeof window !== 'undefined') {
    const host = window.location.hostname;
    if (host === 'localhost' || host === '127.0.0.1' || host === '::1') {
      return false;
    }
  }
  return true;
});

const isCurrentCustom = computed(() => {
  return (
    props.currentConfig.type === 'custom' ||
    isInternalBgUrl(props.currentConfig.url) ||
    props.currentConfig.url?.startsWith('data:')
  );
});

const effectivePreviewUrl = computed(() => {
  return activeTab.value === 'local' ? localPreviewUrl.value : urlPreviewUrl.value;
});

watch(
  () => props.open,
  (val) => {
    if (val) {
      errorMsg.value = '';
      successMsg.value = '';
      adminPasswordInput.value = props.adminPassword || '';
      opacity.value = props.currentConfig.opacity ?? 40;
      blur.value = props.currentConfig.blur ?? 0;

      const currentUrl = props.currentConfig.url || '';
      const isCustom = isCurrentCustom.value;

      if (isCustom) {
        activeTab.value = 'local';
        localPreviewUrl.value = currentUrl;
        imageUrlInput.value = '';
        urlPreviewUrl.value = '';
      } else if (props.currentConfig.type === 'url' || (currentUrl && !currentUrl.startsWith('data:'))) {
        activeTab.value = 'url';
        imageUrlInput.value = currentUrl;
        urlPreviewUrl.value = currentUrl;
        localPreviewUrl.value = '';
      } else {
        activeTab.value = 'local';
        localPreviewUrl.value = '';
        imageUrlInput.value = '';
        urlPreviewUrl.value = '';
      }
    }
  },
  { immediate: true }
);

async function handleFileSelect(e: Event) {
  const target = e.target as HTMLInputElement;
  const file = target.files?.[0];
  if (!file) return;

  errorMsg.value = '';
  successMsg.value = '';

  if (!file.type.startsWith('image/')) {
    errorMsg.value = '请选择合法的图片文件（支持 PNG、JPG、WebP、SVG）';
    return;
  }

  isProcessing.value = true;
  try {
    const compressed = await compressImageFile(file, 1920, 1080, 0.82);
    localPreviewUrl.value = compressed;
    successMsg.value = '图片读取成功（已智能压缩，分辨率自动适配）';
  } catch (err: any) {
    errorMsg.value = err.message || '图片读取与压缩失败，请重试';
  } finally {
    isProcessing.value = false;
    if (fileInput.value) fileInput.value.value = '';
  }
}

async function handleApplyUrl() {
  const url = imageUrlInput.value.trim();
  if (!url) {
    errorMsg.value = '请输入有效的网络图片链接';
    return;
  }

  errorMsg.value = '';
  successMsg.value = '';
  isProcessing.value = true;

  const valid = await validateImageUrl(url);
  isProcessing.value = false;

  if (!valid) {
    errorMsg.value = '图片链接加载失败，请检查网络地址是否正确或是否存在跨域防盗链';
    return;
  }

  urlPreviewUrl.value = url;
  successMsg.value = '网络图片检测成功，已应用预览';
}

function clearActivePreview() {
  if (activeTab.value === 'local') {
    localPreviewUrl.value = '';
  } else {
    urlPreviewUrl.value = '';
    imageUrlInput.value = '';
  }
}

async function handleSave() {
  errorMsg.value = '';

  let targetType: 'custom' | 'url' = 'custom';
  let targetUrl = '';

  if (activeTab.value === 'url') {
    const inputUrl = imageUrlInput.value.trim();
    if (!inputUrl && !urlPreviewUrl.value) {
      errorMsg.value = '请输入有效的网络图片链接并加载预览';
      return;
    }
    if (inputUrl && inputUrl !== urlPreviewUrl.value) {
      isProcessing.value = true;
      const valid = await validateImageUrl(inputUrl);
      isProcessing.value = false;
      if (!valid) {
        errorMsg.value = '图片链接加载失败，请检查网络地址是否正确或是否存在跨域防盗链';
        return;
      }
      urlPreviewUrl.value = inputUrl;
    }
    targetType = 'url';
    targetUrl = urlPreviewUrl.value;
  } else {
    targetType = 'custom';
    if (!localPreviewUrl.value) {
      errorMsg.value = '请先选择本地图片文件或点击“恢复默认背景”';
      return;
    }
    targetUrl = localPreviewUrl.value;
  }

  isProcessing.value = true;
  try {
    const passwordToUse = adminPasswordInput.value.trim() || props.adminPassword;
    const res = await ipc.setLoginBackground({
      type: targetType,
      url: targetUrl,
      opacity: opacity.value,
      blur: blur.value,
      adminPassword: passwordToUse,
    });

    const finalType = res?.type || targetType;
    const finalUrl = res?.url || (finalType === 'custom' ? '/api/v1/auth/background/image' : targetUrl);

    saveLoginBgConfig(finalType, finalUrl, opacity.value, blur.value);
    emit('change', {
      type: finalType,
      url: finalUrl,
      opacity: opacity.value,
      blur: blur.value,
      updatedAt: res?.updatedAt,
    });
    emit('close');
  } catch (err: any) {
    errorMsg.value = err.message || '保存配置失败，请检查网络或服务端连接状态';
  } finally {
    isProcessing.value = false;
  }
}

async function handleResetDefault() {
  errorMsg.value = '';
  isProcessing.value = true;
  try {
    const passwordToUse = adminPasswordInput.value.trim() || props.adminPassword;
    const res = await ipc.resetLoginBackground(passwordToUse);
    clearLoginBgConfig();
    localPreviewUrl.value = '';
    urlPreviewUrl.value = '';
    imageUrlInput.value = '';
    opacity.value = 40;
    blur.value = 0;
    successMsg.value = '已恢复系统默认背景（不设置背景图）';

    emit('change', {
      type: 'none',
      url: '',
      opacity: 40,
      blur: 0,
      updatedAt: res?.updatedAt,
    });
    setTimeout(() => {
      emit('close');
    }, 400);
  } catch (err: any) {
    errorMsg.value = err.message || '恢复默认背景失败';
  } finally {
    isProcessing.value = false;
  }
}
</script>

<template>
  <AppModal
    :open="open"
    @close="emit('close')"
    max-width="max-w-lg"
  >
    <template #headline>
      <div class="flex items-center gap-3 w-full">
        <div class="w-10 h-10 rounded-md bg-brand-container flex items-center justify-center shrink-0">
          <M3Icon name="image" :size="22" class="text-text-main" />
        </div>
        <div>
          <h3 class="section-title">自定义登录背景</h3>
          <p class="text-xs text-text-sub mt-0.5">
            自由上传本地壁纸或指定网络图片，主服务器全局存储并多端同步
          </p>
        </div>
      </div>
    </template>

    <div class="space-y-4 py-1 select-none max-h-[65vh] overflow-y-auto px-0.5">
      <!-- 提示信息 -->
      <div v-if="errorMsg" class="p-2.5 rounded-md bg-status-error-bg border border-status-error/30 text-status-error text-xs flex items-center gap-2">
        <M3Icon name="error" :size="16" class="shrink-0" />
        <span class="break-words">{{ errorMsg }}</span>
      </div>
      <div v-if="successMsg" class="p-2.5 rounded-md bg-status-success-bg border border-status-success/30 text-status-success text-xs flex items-center gap-2">
        <M3Icon name="check_circle" :size="16" class="shrink-0" />
        <span class="break-words">{{ successMsg }}</span>
      </div>

      <!-- 选项卡切换 -->
      <div class="flex rounded-md bg-surface-card-sub p-1 border border-surface-border-sub text-xs">
        <button
          type="button"
          @click="activeTab = 'local'"
          class="flex-1 py-1.5 rounded text-center font-medium transition-colors cursor-pointer"
          :class="activeTab === 'local' ? 'bg-surface-card text-text-main shadow-xs' : 'text-text-sub hover:text-text-main'"
        >
          本地图片上传
        </button>
        <button
          type="button"
          @click="activeTab = 'url'"
          class="flex-1 py-1.5 rounded text-center font-medium transition-colors cursor-pointer"
          :class="activeTab === 'url' ? 'bg-surface-card text-text-main shadow-xs' : 'text-text-sub hover:text-text-main'"
        >
          网络图片链接
        </button>
      </div>

      <!-- 本地上传区域 -->
      <div v-if="activeTab === 'local'" class="space-y-2">
        <input
          ref="fileInput"
          type="file"
          accept="image/png,image/jpeg,image/webp,image/svg+xml"
          class="hidden"
          @change="handleFileSelect"
        />
        <div
          @click="fileInput?.click()"
          role="button"
          tabindex="0"
          class="border-2 border-dashed border-surface-border hover:border-brand-primary/50 rounded-lg p-5 flex flex-col items-center justify-center gap-2 text-center cursor-pointer transition-colors bg-surface-card-sub/40 hover:bg-surface-card-sub app-interactive-card"
        >
          <div class="w-10 h-10 rounded-full bg-surface-card flex items-center justify-center text-text-sub shadow-xs">
            <M3Icon name="upload" :size="20" />
          </div>
          <div class="text-xs font-semibold text-text-main">
            {{ localPreviewUrl ? '点击更换本地壁纸文件' : '点击选择本地图片文件' }}
          </div>
          <div class="text-[11px] text-text-muted">
            支持 PNG、JPG、WebP、SVG，客户端自动智能缩放并持久化存储于主服务器
          </div>
        </div>
        <div
          v-if="localPreviewUrl && !localPreviewUrl.startsWith('data:')"
          class="px-2.5 py-1.5 rounded bg-brand-container/20 text-brand-primary text-[11px] flex items-center gap-1.5"
        >
          <M3Icon name="cloud_done" :size="14" class="shrink-0" />
          <span>当前已加载服务端存储的壁纸，微调暗度或模糊后直接点击保存即可</span>
        </div>
      </div>

      <!-- 网络 URL 输入区域 -->
      <div v-else class="space-y-2">
        <div class="flex gap-2">
          <input
            v-model="imageUrlInput"
            type="url"
            placeholder="https://example.com/wallpaper.jpg"
            class="flex-1 px-3 py-2 text-xs rounded-md border border-surface-border bg-surface-card text-text-main focus:outline-none focus:border-brand-primary placeholder:text-text-muted"
            @keydown.enter="handleApplyUrl"
          />
          <button
            type="button"
            @click="handleApplyUrl"
            :disabled="isProcessing || !imageUrlInput.trim()"
            class="app-btn-secondary app-btn-compact"
          >
            <M3Icon :name="isProcessing ? 'sync' : 'search'" :size="14" :class="isProcessing ? 'animate-spin' : ''" />
            <span>加载</span>
          </button>
        </div>
        <div class="text-[11px] text-text-muted">
          可输入公网图床、Unsplash 或本地局域网 NAS 中的壁纸地址
        </div>
      </div>

      <!-- 图片预览缩略图 -->
      <div v-if="effectivePreviewUrl" class="relative rounded-md overflow-hidden border border-surface-border bg-surface-card h-32 flex items-center justify-center group">
        <img
          :src="effectivePreviewUrl"
          alt="背景预览"
          class="w-full h-full object-cover transition-transform group-hover:scale-105"
        />
        <div
          class="absolute inset-0 bg-black pointer-events-none transition-opacity"
          :style="{ opacity: opacity / 100, backdropFilter: blur > 0 ? `blur(${blur}px)` : 'none' }"
        />
        <div class="absolute bottom-2 left-2 px-2 py-0.5 rounded bg-black/60 backdrop-blur-xs text-[10px] text-white">
          预览效果 (含遮罩与模糊)
        </div>
        <button
          type="button"
          @click="clearActivePreview"
          class="absolute top-2 right-2 p-1 rounded-full bg-black/60 hover:bg-black/80 text-white transition-colors cursor-pointer"
          title="移除选定图片"
        >
          <M3Icon name="close" :size="14" />
        </button>
      </div>

      <!-- 视觉微调滑块 -->
      <div v-if="effectivePreviewUrl" class="space-y-3 p-3 rounded-md bg-surface-card-sub/60 border border-surface-border-sub text-xs">
        <div class="space-y-1.5">
          <div class="flex items-center justify-between text-text-sub font-medium">
            <span>背景遮罩暗度</span>
            <span class="font-mono text-text-main">{{ opacity }}%</span>
          </div>
          <input
            v-model.number="opacity"
            type="range"
            min="10"
            max="90"
            step="5"
            class="w-full accent-brand-primary cursor-pointer"
          />
          <div class="text-[11px] text-text-muted">提高遮罩比例可确保明亮图片下卡片文字依然清晰可见</div>
        </div>

        <div class="space-y-1.5 pt-1 border-t border-surface-border-sub">
          <div class="flex items-center justify-between text-text-sub font-medium">
            <span>背景毛玻璃模糊</span>
            <span class="font-mono text-text-main">{{ blur }}px</span>
          </div>
          <input
            v-model.number="blur"
            type="range"
            min="0"
            max="16"
            step="1"
            class="w-full accent-brand-primary cursor-pointer"
          />
          <div class="text-[11px] text-text-muted">适度模糊可使复杂背景更柔和，凸显前景登录表单</div>
        </div>
      </div>

      <!-- 局域网远程管理员凭据验证（仅远程未登录时要求） -->
      <div
        v-if="needPasswordVerification"
        class="space-y-2 p-3 rounded-md bg-surface-card-sub/80 border border-surface-border-sub text-xs"
      >
        <div class="flex items-center justify-between text-text-sub font-medium">
          <div class="flex items-center gap-1.5 text-accent-seal">
            <M3Icon name="lock" :size="14" />
            <span>局域网远程管理员密码验证</span>
          </div>
          <span class="text-[11px] text-text-muted">跨端保存全局生效</span>
        </div>
        <div class="relative flex items-center">
          <input
            v-model="adminPasswordInput"
            :type="showAdminPassword ? 'text' : 'password'"
            autocomplete="current-password"
            placeholder="请输入管理员密码以授权全局变更"
            class="w-full h-8 px-2.5 pr-8 text-xs rounded border border-surface-border bg-surface-card text-text-main focus:outline-none focus:border-brand-primary placeholder:text-text-muted"
          />
          <button
            type="button"
            @click="showAdminPassword = !showAdminPassword"
            class="absolute right-2 text-text-muted hover:text-text-main cursor-pointer"
            title="显隐密码"
          >
            <M3Icon :name="showAdminPassword ? 'visibility_off' : 'visibility'" :size="14" />
          </button>
        </div>
      </div>
    </div>

    <template #actions>
      <div class="flex flex-wrap items-center justify-between gap-2.5 w-full">
        <button
          v-if="currentConfig.url || effectivePreviewUrl"
          type="button"
          @click="handleResetDefault"
          :disabled="isProcessing"
          class="app-btn-secondary text-status-error border-status-error/40 hover:bg-status-error-bg disabled:opacity-50"
          title="清除自定义背景并还原默认极简背景"
        >
          <M3Icon :name="isProcessing ? 'sync' : 'refresh'" :size="14" :class="isProcessing ? 'animate-spin' : ''" />
          <span>恢复默认背景</span>
        </button>
        <div v-else />

        <div class="flex items-center gap-2 ml-auto">
          <button
            type="button"
            @click="emit('close')"
            class="app-btn-secondary"
          >
            取消
          </button>
          <button
            type="button"
            @click="handleSave"
            :disabled="isProcessing"
            class="app-btn-primary"
          >
            <M3Icon :name="isProcessing ? 'sync' : 'check'" :size="16" :class="isProcessing ? 'animate-spin' : ''" />
            <span>保存并应用</span>
          </button>
        </div>
      </div>
    </template>
  </AppModal>
</template>
