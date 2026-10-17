/**
 * 软件界面截图接口
 * 依赖 Wails 原生窗口截屏能力（当前仅 Windows 桌面端实现），非桌面环境不支持。
 */

/**
 * 运行期取 Wails 绑定的 CaptureWindow。
 *
 * 不能静态 `import { CaptureWindow } from '../../wailsjs/go/main/App'`：
 * wailsjs 是 `wails generate` 的产物且不入库（.gitignore），静态 import 会让
 * 一切不走 wails 代码生成的构建（CI 的 `npm run build`、web-only 打包、
 * 新环境检出）在类型检查阶段直接失败，而报错还指向与截图无关的入口。
 * 绑定本身在运行期就挂在 window.go 上，直接读它即可。
 */
type CaptureWindowFn = (outputPath: string) => Promise<string>;

function captureWindowBinding(): CaptureWindowFn | undefined {
  if (typeof window === 'undefined') return undefined;
  return (window as any).go?.main?.App?.CaptureWindow as CaptureWindowFn | undefined;
}

export async function captureAppScreenshot(outputPath = ''): Promise<string> {
  const capture = captureWindowBinding();
  if (capture) {
    return await capture(outputPath);
  }
  throw new Error('当前环境不支持原生窗口截图，请在桌面客户端中使用');
}

// 挂载至全局 window 对象，便于测试脚本、控制台调用或自动化测试
if (typeof window !== 'undefined') {
  (window as any).captureScreenshot = captureAppScreenshot;
}
