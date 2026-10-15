/** 谛听 (DITING) 主题管理：浅色 / 深色 / 跟随系统 与 经典水墨 / AdGuard 绿配色方案 */
import { ref, readonly } from 'vue';

export type ThemeMode = 'light' | 'dark' | 'system';
export type ThemePalette = 'classic' | 'adguard';

const STORAGE_KEY_MODE = 'diting_theme_mode';
const STORAGE_KEY_PALETTE = 'diting_theme_palette';

const CLASSIC_DARK_BG = '#16171A';
const CLASSIC_DARK_FG = '#E9E8E4';
const CLASSIC_LIGHT_BG = '#FAF9F5';
const CLASSIC_LIGHT_FG = '#1A1A1C';

const ADGUARD_DARK_BG = '#141715';
const ADGUARD_DARK_FG = '#E4E9E5';
const ADGUARD_LIGHT_BG = '#F6F8F6';
const ADGUARD_LIGHT_FG = '#1F2D22';

class ThemeManager {
  private currentMode = ref<ThemeMode>('system');
  private currentPalette = ref<ThemePalette>('classic');
  private isDarkActive = ref<boolean>(false);
  private mediaListenerAttached = false;

  constructor() {
    this.init();
  }

  private init() {
    if (typeof window === 'undefined') return;

    try {
      const savedMode = localStorage.getItem(STORAGE_KEY_MODE) as ThemeMode;
      if (savedMode === 'light' || savedMode === 'dark' || savedMode === 'system') {
        this.currentMode.value = savedMode;
      }
      const savedPalette = localStorage.getItem(STORAGE_KEY_PALETTE) as ThemePalette;
      if (savedPalette === 'classic' || savedPalette === 'adguard') {
        this.currentPalette.value = savedPalette;
      }
    } catch {}

    this.attachSystemThemeListener();
    this.applyTheme();
  }

  private attachSystemThemeListener() {
    if (this.mediaListenerAttached || typeof window === 'undefined' || !window.matchMedia) return;
    try {
      const mql = window.matchMedia('(prefers-color-scheme: dark)');
      mql.addEventListener('change', () => {
        if (this.currentMode.value === 'system') {
          this.applyTheme();
        }
      });
      this.mediaListenerAttached = true;
    } catch {}
  }

  public getThemeMode(): ThemeMode {
    return this.currentMode.value;
  }

  public get themeModeRef() {
    return readonly(this.currentMode);
  }

  public getThemePalette(): ThemePalette {
    return this.currentPalette.value;
  }

  public get themePaletteRef() {
    return readonly(this.currentPalette);
  }

  public get isDarkRef() {
    return readonly(this.isDarkActive);
  }

  public setThemeMode(mode: ThemeMode) {
    this.currentMode.value = mode;
    try {
      localStorage.setItem(STORAGE_KEY_MODE, mode);
    } catch {}
    this.applyTheme();
  }

  public setThemePalette(palette: ThemePalette) {
    this.currentPalette.value = palette;
    try {
      localStorage.setItem(STORAGE_KEY_PALETTE, palette);
    } catch {}
    this.applyTheme();
  }

  public applyTheme() {
    if (typeof window === 'undefined') return;

    const prefersDark = window.matchMedia?.('(prefers-color-scheme: dark)').matches ?? false;
    const isDark = this.currentMode.value === 'dark' || (this.currentMode.value === 'system' && prefersDark);
    this.isDarkActive.value = isDark;
    const isAdguard = this.currentPalette.value === 'adguard';

    const root = document.documentElement;
    root.classList.toggle('dark', isDark);
    root.setAttribute('data-theme', isDark ? 'dark' : 'light');
    root.setAttribute('data-palette', this.currentPalette.value);

    const targetBg = isDark
      ? (isAdguard ? ADGUARD_DARK_BG : CLASSIC_DARK_BG)
      : (isAdguard ? ADGUARD_LIGHT_BG : CLASSIC_LIGHT_BG);
    const targetFg = isDark
      ? (isAdguard ? ADGUARD_DARK_FG : CLASSIC_DARK_FG)
      : (isAdguard ? ADGUARD_LIGHT_FG : CLASSIC_LIGHT_FG);

    root.style.backgroundColor = targetBg;
    root.style.color = targetFg;
  }
}

export const themeManager = new ThemeManager();
