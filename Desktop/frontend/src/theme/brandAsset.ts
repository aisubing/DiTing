import { computed } from 'vue';
import { themeManager } from './theme';
import logoLight from '../assets/images/logo-universal.png';
import logoDark from '../assets/images/logo-universal-dark.png';

/**
 * 品牌图标：浅色模式 #FAF8F9 / #007AFE，深色模式 #1F1F22 / #2E83FF。
 * 两套位图由 `maintenance/core/logo_generator.py` 从同一矢量源生成，形状完全一致。
 */
export function useBrandLogo() {
  return computed(() => (themeManager.isDarkRef.value ? logoDark : logoLight));
}
