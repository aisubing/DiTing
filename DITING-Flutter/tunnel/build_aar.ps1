# 从 DITING-Flutter/tunnel 源码重建 tunnel AAR（新版工程内自含的构建入口）。
#
# 两个单架构版本，打包时由 android/app/build.gradle.kts 按目标 ABI 自动选用：
#   arm64（默认，真机）  -> android/app/libs/tunnel.aar     入库，覆盖即更新
#   x64  （模拟器 x86_64）-> android/app/libs/tunnel-x64.aar 不入库，按需生成
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File build_aar.ps1              # arm64 -> tunnel.aar
#   powershell -ExecutionPolicy Bypass -File build_aar.ps1 -Arch x64    # x86_64 -> tunnel-x64.aar
#   powershell -ExecutionPolicy Bypass -File build_aar.ps1 -Arch all    # 两个都出
#
# 参数细节与排障记录见 docs/development/aar-build-notes.md（仓库根相对本目录）。
param(
    [ValidateSet('arm64', 'x64', 'all')]
    [string]$Arch = 'arm64'
)

$ErrorActionPreference = 'Stop'
$moduleDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $moduleDir

# --- 环境探测：Android SDK、JDK（javac 供 gomobile 编译 Java 包装层）---
if (-not $env:ANDROID_HOME -or -not (Test-Path $env:ANDROID_HOME)) {
    foreach ($candidate in @(
        "$env:LOCALAPPDATA\Android\Sdk",
        'D:\Androidsdk'
    )) {
        if (Test-Path $candidate) { $env:ANDROID_HOME = $candidate; break }
    }
}
if (-not $env:ANDROID_HOME -or -not (Test-Path $env:ANDROID_HOME)) {
    throw 'ANDROID_HOME 未设置且未在常见位置找到 Android SDK；请安装后重试。'
}
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME

if (-not $env:JAVA_HOME -or -not (Test-Path "$env:JAVA_HOME\bin\javac.exe")) {
    foreach ($candidate in @(
        'C:\Program Files\Android\Android Studio\jbr',
        "$env:LOCALAPPDATA\Programs\Android Studio\jbr"
    )) {
        if (Test-Path "$candidate\bin\javac.exe") { $env:JAVA_HOME = $candidate; break }
    }
}
if (-not $env:JAVA_HOME -or -not (Test-Path "$env:JAVA_HOME\bin\javac.exe")) {
    throw '未找到含 javac 的 JDK（尝试过 JAVA_HOME 与 Android Studio JBR）；请设置 JAVA_HOME 后重试。'
}
$env:Path = "$env:JAVA_HOME\bin;$env:Path"

if (-not (Get-Command gomobile -ErrorAction SilentlyContinue)) {
    throw 'gomobile 未安装；先执行: go install golang.org/x/mobile/cmd/gomobile@latest'
}

# gomobile 在临时工程里读不了本仓库 VCS 状态，必须关闭 stamping（见构建记录）。
$env:GOFLAGS = '-buildvcs=false'

function Invoke-GomobileBind {
    param([string]$Target, [string]$Output)
    Write-Host "[INFO] ANDROID_HOME = $env:ANDROID_HOME"
    Write-Host "[INFO] JAVA_HOME    = $env:JAVA_HOME"
    Write-Host "[INFO] target       = $Target"
    Write-Host "[INFO] output       = $Output"

    # PS 5.1 直写 `-target=$Target` 不展开变量（按字面量传给原生命令），必须走数组 splatting。
    $bindArgs = @(
        'bind',
        "-target=$Target",
        '-androidapi', '24',
        '-trimpath',
        '-ldflags=-s -w',
        '-o', $Output,
        '.'
    )
    & gomobile @bindArgs
    if ($LASTEXITCODE -ne 0) { throw "gomobile bind 失败（target=$Target，exit $LASTEXITCODE）。" }
    Write-Host "[DONE] $Output"
}

$libsDir = Join-Path $moduleDir '..\android\app\libs'
switch ($Arch) {
    'arm64' {
        Invoke-GomobileBind -Target 'android/arm64' -Output (Join-Path $libsDir 'tunnel.aar')
    }
    'x64' {
        Invoke-GomobileBind -Target 'android/amd64' -Output (Join-Path $libsDir 'tunnel-x64.aar')
    }
    'all' {
        Invoke-GomobileBind -Target 'android/arm64' -Output (Join-Path $libsDir 'tunnel.aar')
        Invoke-GomobileBind -Target 'android/amd64' -Output (Join-Path $libsDir 'tunnel-x64.aar')
    }
}
