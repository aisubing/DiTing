import type { AutoStartStatus, CoreServiceStatus } from './types';
import { isDesktopApp } from '../utils/env';

/**
 * Web 模式下的服务状态数据源。
 *
 * 由 ipc 门面在构造时注入（HttpTransport → CoreApi），避免 native.ts
 * 反向依赖传输层造成循环引用。
 */
export interface CoreServiceStatusProvider {
  getCoreServiceStatus(): Promise<CoreServiceStatus>;
}

let statusProvider: CoreServiceStatusProvider | null = null;

/** 注册 Web 模式服务状态数据源（由 IPC 门面调用）。 */
export function setCoreServiceStatusProvider(provider: CoreServiceStatusProvider | null): void {
  statusProvider = provider;
}

// Wails 全局对象类型声明
declare global {
  interface Window {
    go?: {
      main?: {
        App?: {
          GetPlatform?: () => Promise<string>;
          RunEmergencyRestore?: () => Promise<string>;
          IsAutoStartEnabled?: () => Promise<boolean>;
          SetAutoStart?: (enable: boolean) => Promise<boolean>;
          GetCoreServiceStatus?: () => Promise<CoreServiceStatus>;
          StartCoreService?: () => Promise<string>;
          StopCoreService?: () => Promise<string>;
          RestartCoreService?: () => Promise<string>;
          InstallCoreService?: () => Promise<string>;
          InstallAndStartCoreService?: () => Promise<string>;
          UninstallCoreService?: () => Promise<string>;
          ConfigureFirewallForLAN?: (enable: boolean) => Promise<string>;
        };
      };
    };
  }
}

export class NativeBridgeService {
  public isDesktopApp(): boolean {
    return isDesktopApp();
  }

  public async runNativeEmergencyRestore(): Promise<string> {
    if (window.go?.main?.App?.RunEmergencyRestore) {
      return await window.go.main.App.RunEmergencyRestore();
    }
    return 'Web 环境不支持原生底层 DNS 应急自愈，请在宿主机桌面端执行';
  }

  /**
   * 获取宿主机开机自启托管状态。
   *
   * 桌面端读取当前用户的自启开关；Web 端改由宿主机服务上报的实际托管
   * 机制判定（服务自启 / 登录自启），避免在服务已托管自启时误报未配置。
   */
  public async getAutoStartStatus(): Promise<AutoStartStatus> {
    // 桌面端以当前用户的自启开关为准，不回退到宿主机托管状态：
    // 后者包含系统服务自启，会让开关显示"已开启"却无法由此处关闭。
    if (isDesktopApp()) {
      try {
        const enabled = await window.go?.main?.App?.IsAutoStartEnabled?.();
        if (enabled !== undefined) {
          return {
            enabled,
            mechanism: enabled ? 'login_item' : 'none',
            detail: enabled ? '已开启当前用户登录自启。' : '尚未配置开机自启。',
          };
        }
      } catch (e) {
        console.warn('获取开机自启状态失败:', e);
      }
      return { enabled: false, mechanism: 'none', detail: '暂时无法获取本机开机自启状态。' };
    }

    const remote = await this.fetchRemoteStatus();
    if (remote?.autoStart) return remote.autoStart;

    return { enabled: false, mechanism: 'none', detail: '暂时无法获取宿主机开机自启状态。' };
  }

  public async isAutoStartEnabled(): Promise<boolean> {
    return (await this.getAutoStartStatus()).enabled;
  }

  public async setAutoStart(enable: boolean): Promise<boolean> {
    if (window.go?.main?.App?.SetAutoStart) {
      return await window.go.main.App.SetAutoStart(enable);
    }
    return enable;
  }

  /** 桌面端返回原生放行结果；Web 端返回 null 表示需回退到服务端接口 */
  public async configureFirewallForLAN(enable: boolean): Promise<string | null> {
    if (window.go?.main?.App?.ConfigureFirewallForLAN) {
      try {
        return await window.go.main.App.ConfigureFirewallForLAN(enable);
      } catch {
        return null;
      }
    }
    return null;
  }

  /**
   * 获取宿主机后台核心服务状态。
   *
   * 桌面端直接调用 Wails 绑定；Web 端经宿主机服务接口读取真实状态。
   * 两者均失败时返回带明确说明的未知状态，而非伪装成"未安装"——
   * 后者会让用户误以为宿主机根本没有部署核心服务。
   */
  public async getCoreServiceStatus(): Promise<CoreServiceStatus> {
    // 桌面端已内嵌服务进程，原生绑定是唯一权威来源，不做远程回退。
    if (isDesktopApp()) {
      try {
        const res = await window.go?.main?.App?.GetCoreServiceStatus?.();
        if (res) return res as CoreServiceStatus;
      } catch (err: any) {
        console.warn('获取核心服务状态失败:', err);
      }
      return {
        installed: false,
        running: false,
        state: 'unknown',
        stateText: '状态未知',
        executablePath: '',
        isElevated: false,
        canInstall: false,
        message: '暂时无法读取本机核心服务状态。',
      };
    }

    const remote = await this.fetchRemoteStatus();
    if (remote) return remote;

    return {
      installed: false,
      running: false,
      state: 'unknown',
      stateText: '状态未知',
      executablePath: '',
      isElevated: false,
      canInstall: false,
      message: '暂时无法读取宿主机核心服务状态，请确认与后台服务的连接是否正常。',
    };
  }

  /** 经宿主机服务接口读取状态；不可用时返回 null 交由调用方降级处理。 */
  private async fetchRemoteStatus(): Promise<CoreServiceStatus | null> {
    if (!statusProvider) return null;
    try {
      return await statusProvider.getCoreServiceStatus();
    } catch (err) {
      console.warn('经服务接口读取核心服务状态失败:', err);
      return null;
    }
  }

  public async startCoreService(): Promise<string> {
    if (window.go?.main?.App?.StartCoreService) {
      return await window.go.main.App.StartCoreService();
    }
    throw new Error('当前环境为 Web 浏览器，不支持直接启动宿主机系统服务，请在宿主机上手动管理后台服务');
  }

  public async stopCoreService(): Promise<string> {
    if (window.go?.main?.App?.StopCoreService) {
      return await window.go.main.App.StopCoreService();
    }
    throw new Error('当前环境为 Web 浏览器，不支持直接停止宿主机系统服务，请在宿主机上手动管理后台服务');
  }

  public async restartCoreService(): Promise<string> {
    if (window.go?.main?.App?.RestartCoreService) {
      return await window.go.main.App.RestartCoreService();
    }
    throw new Error('当前环境为 Web 浏览器，不支持直接重启宿主机系统服务，请在宿主机上手动管理后台服务');
  }

  public async installCoreService(): Promise<string> {
    if (window.go?.main?.App?.InstallCoreService) {
      return await window.go.main.App.InstallCoreService();
    }
    throw new Error('当前环境为 Web 浏览器，不支持注册宿主机系统服务，请在宿主机上以管理员权限安装');
  }

  public async installAndStartCoreService(): Promise<string> {
    if (window.go?.main?.App?.InstallAndStartCoreService) {
      return await window.go.main.App.InstallAndStartCoreService();
    }
    throw new Error('当前环境为 Web 浏览器，不支持一键安装并启动宿主机系统服务，请在宿主机上以管理员权限安装');
  }

  public async uninstallCoreService(): Promise<string> {
    if (window.go?.main?.App?.UninstallCoreService) {
      return await window.go.main.App.UninstallCoreService();
    }
    throw new Error('当前环境为 Web 浏览器，不支持卸载宿主机系统服务，请在宿主机上以管理员权限卸载');
  }
}

export const nativeBridge = new NativeBridgeService();
