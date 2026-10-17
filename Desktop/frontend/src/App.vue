<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { ipc } from './api/ipc';
import { themeManager } from './theme/theme';
import { NAV_ITEMS, SUB_TABS, resolveRoute, type NavTab } from './constants/navigation';
import { isWebMode } from './utils/env';
import { initPlatform, usePlatform } from './composables/usePlatform';
import M3Icon from './components/M3Icon.vue';
import NavItem from './components/NavItem.vue';
import StatusBadge from './components/StatusBadge.vue';
import ServiceAlertModal from './components/ServiceAlertModal.vue';
import LoginView from './views/LoginView.vue';
import appLogo from './assets/images/logo-universal.png';
import OverviewView from './views/OverviewView.vue';
import ResolveView from './views/ResolveView.vue';
import ProtectView from './views/ProtectView.vue';
import DevicesView from './views/DevicesView.vue';
import SystemView from './views/SystemView.vue';

const appVersion = __APP_VERSION__;
const { platformLabel } = usePlatform();
const navItems = NAV_ITEMS;
const currentTab = ref<NavTab>('overview');
const currentSub = ref<string>('');
const isConnected = ref(false);
const showAlertModal = ref(false);

// 宽屏（≥1024）展示文本侧栏，中屏（768–1024）折叠为图标栏
const wideSidebar = ref(true);
let mql: MediaQueryList | null = null;

const currentNav = computed(() => navItems.find((i) => i.id === currentTab.value));

// Web 远程管理与用户态：与主界面彻底分离
const webMode = isWebMode();
const isAuthenticated = ref(!webMode);
const isCheckingAuth = ref(webMode);
const authPageMode = ref<'login' | 'setup'>('login');
const isAuthInitialized = ref(true);
const currentUser = ref(localStorage.getItem('diting_session_user') || '');

let unsubConn: (() => void) | null = null;
let unsubAuth: (() => void) | null = null;

function parseRoute() {
  try {
    const url = new URL(window.location.href);
    const hashParts = url.hash.replace(/^#\/?/, '').split('/');
    const hashTab = (hashParts[0] || '').split(/[?#]/)[0];
    // hash 优先于 ?tab=：hash 是应用内导航的实时状态，query 只是首次深链的入口。
    // 反过来的话，URL 一旦带上 ?tab=，parseRoute 在每次 hashchange 时都会把它
    // 重新读回来，侧栏导航被永久锁死在同一页。
    const rawTab = (hashTab || url.searchParams.get('tab') || '').toLowerCase();
    // 子页签同理：hash 第二段优先，其次查询参数
    const hashSub = (hashParts[1] || '').split(/[?#]/)[0];
    const rawSub = (hashSub || url.searchParams.get('sub') || '').toLowerCase();
    const route = resolveRoute(rawTab, rawSub);
    if (route) {
      currentTab.value = route.tab;
      currentSub.value = route.sub;
    } else if (rawSub) {
      currentSub.value = rawSub;
    }

    const hashQueryIndex = url.hash.indexOf('?');
    const hashParams = hashQueryIndex >= 0 ? new URLSearchParams(url.hash.substring(hashQueryIndex)) : null;

    const themeParam = url.searchParams.get('theme') || hashParams?.get('theme');
    if (themeParam === 'light' || themeParam === 'dark' || themeParam === 'system') {
      themeManager.setThemeMode(themeParam);
    }
    const paletteParam = url.searchParams.get('palette') || hashParams?.get('palette');
    if (paletteParam === 'classic' || paletteParam === 'adguard') {
      themeManager.setThemePalette(paletteParam);
    }
    if (url.searchParams.has('modal')) {
      showAlertModal.value = url.searchParams.get('modal') === 'alert';
    }
  } catch {}
}

/** 切换大类；可选携带小类（跨类深链跳转，如总览快捷卡片直达「解析 / 上游解析」） */
function handleNavigate(tab: NavTab, sub?: string) {
  currentTab.value = tab;
  const nextSub =
    sub && SUB_TABS[tab]?.some((s) => s.id === sub) ? sub : '';
  currentSub.value = nextSub;
  try {
    // 清掉一次性的深链参数：留着它们会让 URL 与当前视图长期不一致，
    // 也会被外部工具当成「用户仍在那个页面」。
    const url = new URL(window.location.href);
    let changed = false;
    for (const key of ['tab', 'sub']) {
      if (url.searchParams.has(key)) {
        url.searchParams.delete(key);
        changed = true;
      }
    }
    if (changed) {
      window.history.replaceState(null, '', url.pathname + (url.search ? url.search : '') + url.hash);
    }
    window.location.hash = nextSub ? `#/${tab}/${nextSub}` : `#/${tab}`;
  } catch {}
}

async function checkWebAuth() {
  if (!webMode) {
    isAuthenticated.value = true;
    isCheckingAuth.value = false;
    ipc.connectWS();
    ipc.checkHealth();
    return;
  }

  isCheckingAuth.value = true;
  try {
    const status = await ipc.getAuthStatus();
    isAuthInitialized.value = Boolean(status.initialized);
    if (!status.initialized) {
      authPageMode.value = 'setup';
      isAuthenticated.value = false;
    } else {
      const token = localStorage.getItem('diting_session_token');
      if (!token) {
        authPageMode.value = 'login';
        isAuthenticated.value = false;
      } else {
        try {
          await ipc.getStatus();
          isAuthenticated.value = true;
          currentUser.value = localStorage.getItem('diting_session_user') || status.username || 'admin';
          ipc.connectWS();
          ipc.checkHealth();
        } catch {
          await ipc.logout();
          isAuthenticated.value = false;
          authPageMode.value = 'login';
        }
      }
    }
  } catch {
    isAuthenticated.value = false;
    authPageMode.value = 'login';
  } finally {
    isCheckingAuth.value = false;
  }
}

async function handleLogout() {
  await ipc.logout();
  currentUser.value = '';
  isAuthenticated.value = false;
  authPageMode.value = 'login';
  ipc.disconnectWS();
}

function handleAuthSuccess() {
  isAuthenticated.value = true;
  isAuthInitialized.value = true;
  currentUser.value = localStorage.getItem('diting_session_user') || 'admin';
  ipc.connectWS();
  ipc.checkHealth();
}

onMounted(() => {
  parseRoute();
  initPlatform();
  window.addEventListener('hashchange', parseRoute);

  mql = window.matchMedia('(min-width: 1024px)');
  wideSidebar.value = mql.matches;
  mql.addEventListener('change', handleMqlChange);

  checkWebAuth();

  unsubAuth = ipc.onAuthRequired((required) => {
    if (webMode && required) {
      isAuthenticated.value = false;
      currentUser.value = '';
      authPageMode.value = isAuthInitialized.value ? 'login' : 'setup';
      ipc.disconnectWS();
    }
  });

  unsubConn = ipc.onConnectionChange((connected) => {
    isConnected.value = connected;
    const url = new URL(window.location.href);
    const suppressAlert = url.searchParams.has('noalert');
    if (!connected && !suppressAlert && !webMode) {
      setTimeout(() => {
        const currentUrl = new URL(window.location.href);
        if (!ipc.isConnected && !currentUrl.searchParams.has('noalert')) {
          showAlertModal.value = true;
        }
      }, 2000);
    } else if (connected) {
      showAlertModal.value = false;
    }
  });
});

function handleMqlChange(e: MediaQueryListEvent) {
  wideSidebar.value = e.matches;
}

onUnmounted(() => {
  window.removeEventListener('hashchange', parseRoute);
  if (mql) mql.removeEventListener('change', handleMqlChange);
  if (unsubConn) unsubConn();
  if (unsubAuth) unsubAuth();
});
</script>

<template>
  <!-- 1. Web 模式鉴权初始状态检查中（仅冷启动短暂检测 Token 时展示） -->
  <div
    v-if="webMode && isCheckingAuth"
    class="flex h-screen w-screen items-center justify-center bg-surface-base text-text-muted select-none"
  >
    <div class="flex flex-col items-center gap-3">
      <img :src="appLogo" alt="Logo" class="w-10 h-10 object-contain rounded-md animate-pulse" />
      <span class="text-xs text-text-sub font-mono">DITING DNS 控制台安全载入中...</span>
    </div>
  </div>

  <!-- 2. Web 模式且未通过鉴权：展示完全独立的沉浸式登录页面（与主系统完全解耦） -->
  <LoginView
    v-else-if="webMode && !isAuthenticated"
    :initial-mode="authPageMode"
    @success="handleAuthSuccess"
  />

  <!-- 3. 已认证登录态或桌面客户端：展示系统主界面 -->
  <div
    v-else
    class="flex h-screen w-screen overflow-hidden bg-surface-base text-text-main font-sans antialiased select-none"
  >
    <!-- 侧边导航：宽屏文本栏（w-56）／中屏图标栏（w-16） -->
    <nav
      class="hidden md:flex shrink-0 flex-col py-4 border-r border-surface-border bg-surface-base z-20"
      :class="wideSidebar ? 'w-56' : 'w-16'"
    >
      <!-- 品牌：软件 Logo + 宋体字标 -->
      <div
        class="flex items-center gap-2.5 px-4 mb-5 cursor-pointer app-interactive-card"
        :class="wideSidebar ? '' : 'justify-center px-0'"
        @click="handleNavigate('overview')"
        role="button"
        tabindex="0"
        title="返回系统总览"
      >
        <div class="relative w-8 h-8 shrink-0 flex items-center justify-center">
          <img
            :src="appLogo"
            alt="谛听 Logo"
            class="w-8 h-8 object-contain rounded-md"
          />
          <span
            class="absolute -bottom-0.5 -right-0.5 w-2.5 h-2.5 rounded-full border-2 border-surface-base"
            :class="isConnected ? 'bg-status-success' : 'bg-status-error'"
            :title="isConnected ? '后台服务已连接' : '后台服务未连接'"
          />
        </div>
        <div v-if="wideSidebar" class="flex flex-col leading-none min-w-0">
          <span class="font-serif text-[15px] font-semibold text-text-main">谛听</span>
          <span class="label-quiet mt-1">DITING DNS</span>
        </div>
      </div>

      <!-- 导航项 -->
      <div class="flex flex-col gap-0.5 px-2" :class="wideSidebar ? '' : 'items-center px-0'">
        <NavItem
          v-for="item in navItems"
          :key="item.id"
          :id="item.id"
          :label="item.label"
          :icon="item.icon"
          :active="currentTab === item.id"
          :icon-only="!wideSidebar"
          @navigate="handleNavigate"
        />
      </div>
    </nav>

    <!-- 小屏底部导航栏 -->
    <nav class="md:hidden fixed bottom-0 left-0 right-0 h-14 z-30 bg-surface-card/95 backdrop-blur-md border-t border-surface-border flex items-center justify-around px-1">
      <NavItem
        v-for="item in navItems"
        :key="item.id"
        :id="item.id"
        :label="item.label"
        :icon="item.icon"
        :active="currentTab === item.id"
        icon-only
        @navigate="handleNavigate"
      />
    </nav>

    <!-- 主视口 -->
    <main class="flex-1 flex flex-col h-full overflow-hidden bg-surface-base">
      <!-- 顶栏 -->
      <header class="h-13 shrink-0 flex items-center justify-between gap-3 px-4 sm:px-6 py-2.5 border-b border-surface-border bg-surface-base">
        <div class="flex items-baseline gap-3 min-w-0">
          <span class="font-serif text-[15px] font-semibold text-text-main truncate">
            {{ currentNav?.label }}
          </span>
          <span class="text-[12px] text-text-muted truncate hidden sm:inline">
            {{ currentNav?.hint }}
          </span>
        </div>

        <div class="flex items-center gap-3 shrink-0">
          <!-- 环境标识 -->
          <span class="label-quiet hidden lg:inline font-mono">
            {{ webMode ? '局域网 Web 控制台' : `${platformLabel || '桌面'} v${appVersion}` }}
          </span>

          <!-- 用户态与登出 -->
          <div v-if="currentUser" class="flex items-center gap-2">
            <span class="text-[12px] text-text-sub hidden sm:inline">
              <span class="text-text-muted">管理员</span>
              <span class="font-mono ml-1.5">{{ currentUser }}</span>
            </span>
            <button
              v-if="webMode"
              type="button"
              @click="handleLogout"
              class="app-btn-secondary app-btn-compact"
              title="退出当前登录会话"
            >
              <M3Icon name="logout" :size="14" />
              <span class="hidden sm:inline">退出</span>
            </button>
          </div>

          <StatusBadge
            :status="isConnected ? 'active' : 'error'"
            :text="isConnected ? '服务运行中' : '服务未连接'"
            :pulse="isConnected"
            size="sm"
          />
        </div>
      </header>

      <!-- 视图容器（小屏预留底部导航安全间距） -->
      <div class="flex-1 overflow-y-auto px-4 sm:px-6 py-4 sm:py-5 pb-20 md:pb-5">
        <OverviewView
          v-if="currentTab === 'overview'"
          :sub="currentSub"
          @navigate="handleNavigate"
        />
        <ResolveView v-else-if="currentTab === 'resolve'" :sub="currentSub" />
        <ProtectView v-else-if="currentTab === 'protect'" :sub="currentSub" />
        <DevicesView v-else-if="currentTab === 'devices'" :sub="currentSub" />
        <SystemView v-else-if="currentTab === 'system'" :sub="currentSub" />
      </div>
    </main>

    <!-- 后台核心服务管理弹窗 -->
    <ServiceAlertModal
      :open="showAlertModal"
      @close="showAlertModal = false"
      @connected="isConnected = true"
    />
  </div>
</template>
