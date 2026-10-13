#!/usr/bin/env bash
# =============================================================================
# dsh.web.startup.gitbash.sh — 经 Git Bash 启动 `dsh web` (node 进程)
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
#   详见 https://github.com/wzwjustdoit/dsh-git-bash 的 README "启动方式" 一节。
#
# 【用法】
#   双击同目录的 dsh.web.startup.gitbash.bat 或 dsh.web.startup.gitbash.vbs
#
# =============================================================================

set -euo pipefail

# 监听端口: 命令行第 1 个参数 > 环境变量 DSH_WEB_PORT > 默认 1688
PORT="${1:-${DSH_WEB_PORT:-1688}}"

# 启动目录。它会成为 Web 会话的默认 workspace 根目录。
# 想固定到别处就在调用前设置 DSH_WEB_WORKDIR。
WORKDIR="${DSH_WEB_WORKDIR:-$HOME}"

cd "$WORKDIR"

echo "[dsh.web.startup.gitbash.sh]  bash              = $BASH"
echo "[dsh.web.startup.gitbash.sh]  msystem           = $MSYSTEM"
echo "[dsh.web.startup.gitbash.sh]  DSH_GIT_BASH_PATH = $DSH_GIT_BASH_PATH"
echo "[dsh.web.startup.gitbash.sh]  dsh               = $(command -v dsh)"
echo "[dsh.web.startup.gitbash.sh]  cwd               = $PWD"
echo "[dsh.web.startup.gitbash.sh]  port              = $PORT"

# =============================================================================
# 启动命令
# =============================================================================
exec dsh web --port "$PORT"
