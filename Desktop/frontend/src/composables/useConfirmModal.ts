import { ref } from 'vue';

export interface ConfirmDialogOptions {
  title?: string;
  message: string;
  confirmText?: string;
  cancelText?: string;
  danger?: boolean;
  showCancel?: boolean;
}

/**
 * 确认弹窗状态管理（替代原生阻断式 window.confirm）
 */
export function useConfirmModal() {
  const isOpen = ref(false);
  const options = ref<ConfirmDialogOptions>({
    title: '确认操作',
    message: '',
    confirmText: '确定',
    cancelText: '取消',
    danger: false,
    showCancel: true,
  });

  let resolvePromise: ((value: boolean) => void) | null = null;

  function ask(opts: ConfirmDialogOptions): Promise<boolean> {
    // 上一个确认框若未作答就再次 ask（错误处理路径里连发两次确认），
    // 旧 Promise 会被新 resolve 覆盖而永不 settle——其后的 saving/deleting
    // 标志永久卡 true，按钮失活直到刷新。这里先把旧请求按「取消」结清。
    if (resolvePromise) {
      const pending = resolvePromise;
      resolvePromise = null;
      pending(false);
    }
    options.value = {
      title: '确认操作',
      confirmText: '确定',
      cancelText: '取消',
      danger: false,
      showCancel: true,
      ...opts,
    };
    isOpen.value = true;
    return new Promise((resolve) => {
      resolvePromise = resolve;
    });
  }

  function handleConfirm() {
    isOpen.value = false;
    if (resolvePromise) {
      resolvePromise(true);
      resolvePromise = null;
    }
  }

  function handleCancel() {
    isOpen.value = false;
    if (resolvePromise) {
      resolvePromise(false);
      resolvePromise = null;
    }
  }

  return { isOpen, options, ask, handleConfirm, handleCancel };
}
