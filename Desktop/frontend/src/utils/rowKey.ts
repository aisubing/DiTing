/**
 * 为可删除列表的行对象分配稳定且类型安全的渲染 key。
 *
 * Vue 的 `:key` 类型只接受 string | number | symbol，不能直接用行对象；
 * 而用数组下标作 key 时，删除中间行会让后续行原位复用 DOM，导致焦点与
 * 未保存输入串到上移的行。这里以行对象的引用为键生成稳定字符串：对象不变
 * 则 key 不变，删除中间行后其余行的 key 仍各自唯一，Vue 会重建而不是复用。
 */

export function createRowKey<T extends object>(): (row: T) => string {
  const keys = new WeakMap<T, string>();
  let seq = 0;
  return (row: T): string => {
    const existing = keys.get(row);
    if (existing) return existing;
    const key = `row-${++seq}`;
    keys.set(row, key);
    return key;
  };
}
