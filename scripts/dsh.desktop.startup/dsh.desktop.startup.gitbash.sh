#!/usr/bin/env bash
# =============================================================================
# dsh.desktop.startup.gitbash.sh — 经 Git Bash 启动 DSH Desktop (Electron GUI 程序)
#
# 【为什么必须经过 Git Bash 启动】
#   DSH 的 Windows ACL 沙箱在受限模式(read-only / workspace-write)下, 会用
#   msys-token-guard.exe 在受限 token 内启动 Git Bash。guard 需要以
#       TOKEN_QUERY | TOKEN_ADJUST_DEFAULT
#   打开子进程 token, 而 TOKEN_ADJUST_DEFAULT 属于"写"类权限, 在
#   WRITE_RESTRICTED token 下必须两趟权限检查都通过。
#
#   若 DSH 主进程 token 的 default DACL 缺当前用户 SID(由 explorer.exe /
#   cmd.exe 派生的进程往往如此), 第一趟检查就会失败:
#       msys-token-guard: OpenProcessToken(child default DACL) failed (Win32 5)
#   后果是受限模式下所有命令 exit 125 / SandboxUnavailableError。
#
#   MSYS2 运行时在 bash.exe 启动时, 会把自己的 token default DACL 重置为含用户
#   SID 的标准形状 [用户 ALL, Administrators ALL, SYSTEM ALL]。凡是从 bash 派生的
#   进程都继承这个形状, 沙箱随即恢复正常。
#   因此: 必须让 Desktop 可执行文件的祖先链上出现 Git Bash。
#   详见 https://github.com/inmny/dsh-git-bash 的 README "启动方式" 一节。
#
# 【用法】
#   双击同目录的 dsh.desktop.startup.gitbash.bat 或 dsh.desktop.startup.gitbash.vbs
#   想换 Desktop 安装位置: 直接修改本文件特定行,或者 设置环境变量 DSH_DESKTOP_EXE 指向 "DeepSeek Harness.exe" (绝对路径)
#
# =============================================================================

set -euo pipefail

# Desktop 可执行文件位置。想换安装位置就改这里, 或事先设置 DSH_DESKTOP_EXE。
DSH_DESKTOP_EXE="${DSH_DESKTOP_EXE:-/c/Program Files/DeepSeek Harness/DeepSeek Harness.exe}"

echo "[dsh.desktop.startup.gitbash.sh]  bash              = $BASH"
echo "[dsh.desktop.startup.gitbash.sh]  msystem           = $MSYSTEM"
echo "[dsh.desktop.startup.gitbash.sh]  DSH_GIT_BASH_PATH = $DSH_GIT_BASH_PATH"
echo "[dsh.desktop.startup.gitbash.sh]  desktop exe       = $DSH_DESKTOP_EXE"
echo "[dsh.desktop.startup.gitbash.sh]  cwd               = $PWD"

if [ ! -f "$DSH_DESKTOP_EXE" ]; then
    echo "[dsh.desktop.startup.gitbash.sh]  Desktop EXE Not Found: $DSH_DESKTOP_EXE" >&2
    exit 1
fi

# =============================================================================
# 启动命令
#
# exec 让 Electron 主进程直接取代 bash —— 宿主进程因此继承这个已被 MSYS2
# 归一化过 token 的进程, 受限模式下的沙箱恢复正常。
# =============================================================================
exec "$DSH_DESKTOP_EXE"
