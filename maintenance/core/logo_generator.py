#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
谛听 (DITING) 品牌资产生成引擎

单一形状源：DITING-Legacy/app/src/main/res/drawable/ic_splash_squircle_logo.xml
（N=3 超椭圆容器 + 居中球体雷达图腾），配色由本模块统一定义：

  浅色模式  background #FAF8F9    foreground #007AFE
  深色模式  background #1F1F22    foreground #2E83FF

不依赖 Qt / cairo / rsvg —— 光栅化由 `core.vector_raster` 完成，仅需 Pillow。

用法：
    python -m maintenance.core.logo_generator            # 导出全部平台资源
    python -m maintenance.core.logo_generator --check    # 只校验源矢量可解析
"""

import os
import sys
import xml.etree.ElementTree as ET
from typing import Callable, Dict, List, Optional, Sequence, Tuple

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

from PIL import Image

try:  # 作为包导入
    from . import vector_raster as vr
except ImportError:  # 直接脚本运行
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from core import vector_raster as vr  # type: ignore[no-redef]

AND = "{http://schemas.android.com/apk/res/android}"

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
BRAND_XML = os.path.join(
    ROOT_DIR, "DITING-Legacy", "app", "src", "main", "res", "drawable", "ic_splash_squircle_logo.xml"
)

# === 品牌调色板（唯一真源） ===
LIGHT = {"background": "#FAF8F9", "foreground": "#007AFE"}
DARK = {"background": "#1F1F22", "foreground": "#2E83FF"}

# Android 传统启动器位图规格（px）：mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi
ANDROID_DENSITIES: Sequence[Tuple[str, int]] = (
    ("mdpi", 48),
    ("hdpi", 72),
    ("xhdpi", 96),
    ("xxhdpi", 144),
    ("xxxhdpi", 192),
)

DESKTOP_SIZES = (1024, 512, 256)
ICO_SIZES = (16, 24, 32, 48, 64, 128, 256)


def _log_default(level: str, message: str) -> None:
    print(f"[{level.upper()}] {message}")


# --------------------------------------------------------------------------- #
# 源矢量解析
# --------------------------------------------------------------------------- #
def load_shapes(palette: Dict[str, str], xml_path: Optional[str] = None) -> Tuple[List[vr.Shape], Tuple[float, float, float, float]]:
    """把 Android VectorDrawable 解析为可按任意配色渲染的形状序列。"""
    path = xml_path or BRAND_XML
    if not os.path.exists(path):
        raise FileNotFoundError(f"未找到品牌矢量源: {path}")

    root = ET.parse(path).getroot()
    view_w = float(root.get(AND + "viewportWidth"))
    view_h = float(root.get(AND + "viewportHeight"))
    color_map = {
        "@color/ic_launcher_background": palette["background"],
        "@color/ic_launcher_foreground": palette["foreground"],
    }
    shapes: List[vr.Shape] = []

    def walk(node: ET.Element, matrix: vr.Matrix) -> None:
        for child in node:
            tag = child.tag.split("}")[-1]
            if tag == "group":
                tx = float(child.get(AND + "translateX") or 0)
                ty = float(child.get(AND + "translateY") or 0)
                sx = float(child.get(AND + "scaleX") or 1)
                sy = float(child.get(AND + "scaleY") or 1)
                px = float(child.get(AND + "pivotX") or 0)
                py = float(child.get(AND + "pivotY") or 0)
                local = vr.multiply(
                    vr.translation(tx, ty),
                    vr.multiply(
                        vr.translation(px, py),
                        vr.multiply(vr.scaling(sx, sy), vr.translation(-px, -py)),
                    ),
                )
                walk(child, vr.multiply(matrix, local))
            elif tag == "path":
                data = child.get(AND + "pathData")
                fill = child.get(AND + "fillColor") or ""
                if not data or not fill:
                    continue
                color = color_map.get(fill, fill)
                if not color.startswith("#"):
                    continue
                shapes.append(vr.Shape(data, color, matrix))

    walk(root, vr.IDENTITY)
    if not shapes:
        raise ValueError(f"品牌矢量源中没有任何可渲染路径: {path}")
    return shapes, (0.0, 0.0, view_w, view_h)


_RENDER_CACHE: Dict[Tuple[str, int], Image.Image] = {}


def render_icon(palette: Dict[str, str], size: int, supersample: int = 4) -> Image.Image:
    """渲染正方形品牌图标（超椭圆底 + 球体雷达图腾），同配色同尺寸复用结果。"""
    key = (palette["background"] + palette["foreground"], size)
    cached = _RENDER_CACHE.get(key)
    if cached is not None:
        return cached.copy()
    shapes, view_box = load_shapes(palette)
    image = vr.render(shapes, size, size, view_box, supersample=supersample)
    _RENDER_CACHE[key] = image
    return image.copy()


def squircle_svg(palette: Dict[str, str]) -> str:
    """生成与位图完全等价的 SVG（供网页 / Linux pixmaps 使用）。"""
    shapes, (vx, vy, vw, vh) = load_shapes(palette)
    body = "\n  ".join(
        f'<path fill="{shape.color}" transform="matrix({",".join(f"{v:g}" for v in shape.matrix)})" '
        f'd="{shape.path_data}" />'
        for shape in shapes
    )
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vx:g} {vy:g} {vw:g} {vh:g}" '
        f'width="{int(vw)}" height="{int(vh)}">\n'
        f"  <!-- 谛听 DITING 品牌图标：{palette['background']} / {palette['foreground']} -->\n"
        f"  {body}\n</svg>\n"
    )


def adaptive_svg() -> str:
    """随系统明暗自动切换的品牌 SVG（用于浏览器 favicon / 网页 logo）。"""
    light_svg = squircle_svg(LIGHT)
    dark_svg = squircle_svg(DARK)
    import re

    def body(svg: str) -> str:
        inner = svg.split(">", 1)[1].rsplit("</svg>", 1)[0]
        return re.sub(r"<!--.*?-->", "", inner, flags=re.S).strip()

    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 144 144" width="144" height="144">\n'
        "  <style>\n"
        "    .diting-brand--dark { display: none; }\n"
        "    @media (prefers-color-scheme: dark) {\n"
        "      .diting-brand--light { display: none; }\n"
        "      .diting-brand--dark { display: inline; }\n"
        "    }\n"
        "  </style>\n"
        f'  <g class="diting-brand--light">{body(light_svg)}</g>\n'
        f'  <g class="diting-brand--dark">{body(dark_svg)}</g>\n'
        "</svg>\n"
    )


# --------------------------------------------------------------------------- #
# 导出
# --------------------------------------------------------------------------- #
def _save_png(image: Image.Image, path: str, log: Callable[[str, str], None]) -> str:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path, "PNG", optimize=True)
    log("info", f"PNG {image.width}x{image.height}: {path}")
    return path


def _save_ico(base: Image.Image, path: str, log: Callable[[str, str], None]) -> str:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    frames = [base.resize((s, s), Image.LANCZOS) for s in ICO_SIZES]
    frames[-1].save(path, format="ICO", sizes=[(s, s) for s in ICO_SIZES], append_images=frames[:-1])
    log("info", f"ICO {len(ICO_SIZES)} 规格: {path}")
    return path


def export_desktop(log: Callable[[str, str], None]) -> List[str]:
    """桌面端（Wails + Vue3）：Windows 图标、Linux pixmap、Web favicon 与前端资源。"""
    desktop = os.path.join(ROOT_DIR, "Desktop")
    files: List[str] = []

    light_1024 = render_icon(LIGHT, 1024)
    light_512 = light_1024.resize((512, 512), Image.LANCZOS)
    dark_512 = render_icon(DARK, 512)

    files.append(_save_png(light_1024, os.path.join(desktop, "build", "appicon.png"), log))
    files.append(_save_ico(light_512, os.path.join(desktop, "build", "windows", "icon.ico"), log))
    # Linux 桌面启动器 / 窗口管理器图标
    files.append(_save_png(light_512, os.path.join(desktop, "build", "linux", "diting.png"), log))

    assets = os.path.join(desktop, "frontend", "src", "assets", "images")
    files.append(_save_png(light_512, os.path.join(assets, "logo-universal.png"), log))
    files.append(_save_png(dark_512, os.path.join(assets, "logo-universal-dark.png"), log))

    public = os.path.join(desktop, "frontend", "public")
    files.append(_save_png(light_512, os.path.join(public, "appicon.png"), log))
    files.append(_save_ico(light_512, os.path.join(public, "favicon.ico"), log))
    files.append(_save_png(dark_512, os.path.join(public, "appicon-dark.png"), log))

    for path in (os.path.join(assets, "logo.svg"), os.path.join(public, "logo.svg")):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(adaptive_svg())
        log("info", f"SVG (随明暗切换): {path}")
        files.append(path)
    return files


def export_flutter_assets(log: Callable[[str, str], None]) -> List[str]:
    """Flutter 应用内展示用图标（关于页），浅色与深色各一份。"""
    images = os.path.join(ROOT_DIR, "DITING-Flutter", "assets", "images")
    files = [
        _save_png(render_icon(LIGHT, 512), os.path.join(images, "icon.png"), log),
        _save_png(render_icon(DARK, 512), os.path.join(images, "icon_dark.png"), log),
    ]
    return files


def export_android_launcher(res_dir: str, log: Callable[[str, str], None], label: str = "") -> List[str]:
    """
    生成传统启动器位图（API < 26 与部分第三方桌面使用）。

    浅色写入 mipmap-<density>/，深色写入 mipmap-night-<density>/，
    两者都覆盖自适应图标之外的全部回退路径。
    """
    if not os.path.isdir(res_dir):
        log("warn", f"跳过 {label or res_dir}：未找到 res 目录")
        return []

    files: List[str] = []
    for folder_suffix, palette in (("", LIGHT), ("-night", DARK)):
        base = render_icon(palette, 192)
        for density, size in ANDROID_DENSITIES:
            for name in ("ic_launcher.png", "ic_launcher_round.png"):
                target = os.path.join(res_dir, f"mipmap{folder_suffix}-{density}", name)
                _save_png(base.resize((size, size), Image.LANCZOS), target, log)
                files.append(target)
    return files


def export_all(on_log: Optional[Callable[[str, str], None]] = None) -> Dict[str, object]:
    log = on_log or _log_default
    exported: List[str] = []
    exported += export_desktop(log)
    exported += export_flutter_assets(log)
    exported += export_android_launcher(
        os.path.join(ROOT_DIR, "DITING-Flutter", "android", "app", "src", "main", "res"), log, "DITING-Flutter"
    )
    exported += export_android_launcher(
        os.path.join(ROOT_DIR, "DITING-Legacy", "app", "src", "main", "res"), log, "DITING-Legacy"
    )
    log("info", f"完成，共导出 {len(exported)} 个品牌资源文件")
    return {"success": True, "files": exported, "palettes": {"light": LIGHT, "dark": DARK}}


# --------------------------------------------------------------------------- #
# 维护工具箱兼容层（旧接口：自定义底色 / 图腾色）
# --------------------------------------------------------------------------- #
def generate_squircle_svg(
    bg_color: str = LIGHT["background"],
    totem_color: str = LIGHT["foreground"],
    subtle_gradient: bool = False,
    xml_path: Optional[str] = None,
) -> str:
    """兼容旧调用：返回单色 SVG。品牌规范已统一为纯色，渐变参数被忽略。"""
    palette = {"background": bg_color, "foreground": totem_color}
    shapes, (vx, vy, vw, vh) = load_shapes(palette, xml_path)
    body = "\n  ".join(
        f'<path fill="{shape.color}" transform="matrix({",".join(f"{v:g}" for v in shape.matrix)})" '
        f'd="{shape.path_data}" />'
        for shape in shapes
    )
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vx:g} {vy:g} {vw:g} {vh:g}" '
        f'width="{int(vw)}" height="{int(vh)}">\n  {body}\n</svg>\n'
    )


def export_logo_assets(
    bg_color: Optional[str] = None,
    totem_color: Optional[str] = None,
    subtle_gradient: bool = False,
    output_dir: Optional[str] = None,
    on_log: Optional[Callable[[str, str], None]] = None,
) -> Dict[str, object]:
    """兼容旧调用：按品牌规范导出全部平台资源，并可额外输出到自定义目录。"""
    log = on_log or _log_default
    if subtle_gradient:
        log("warn", "品牌规范已统一为纯色图标，渐变参数被忽略")
    if bg_color or totem_color:
        log("warn", "自定义配色仅影响额外导出目录，仓库内资源始终使用品牌规范色")
    result = export_all(log)
    files = list(result["files"])  # type: ignore[arg-type]

    if output_dir and os.path.isdir(output_dir):
        custom_svg = os.path.join(output_dir, "diting_logo.svg")
        shake = {"background": bg_color or LIGHT["background"], "foreground": totem_color or LIGHT["foreground"]}
        with open(custom_svg, "w", encoding="utf-8") as handle:
            handle.write(squircle_svg(shake))
        files.append(custom_svg)
        files.append(
            _save_png(
                render_icon({"background": bg_color or LIGHT["background"], "foreground": totem_color or LIGHT["foreground"]}, 1024),
                os.path.join(output_dir, "diting_logo_1024.png"),
                log,
            )
        )
        log("info", f"已额外导出自选目录产物: {output_dir}")

    result["files"] = files
    return result


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description="谛听品牌图标导出工具（无需 Qt）")
    parser.add_argument("--check", action="store_true", help="仅校验品牌矢量源可解析")
    parser.add_argument("--preview", default=None, help="输出一张浅/深色对照预览图到指定路径")
    args = parser.parse_args()

    if args.check:
        for name, palette in (("light", LIGHT), ("dark", DARK)):
            shapes, view_box = load_shapes(palette)
            print(f"{name}: {len(shapes)} 条路径, viewBox={view_box}")
        return 0

    if args.preview:
        light = render_icon(LIGHT, 512)
        dark = render_icon(DARK, 512)
        canvas = Image.new("RGB", (1024, 512), "#7F7F7F")
        canvas.paste(light, (0, 0), light)
        canvas.paste(dark, (512, 0), dark)
        canvas.save(args.preview, "PNG")
        print(f"预览已写入 {args.preview}")
        return 0

    export_all()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
