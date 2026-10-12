# dsh.desktop.startup —— 经 Git Bash 启动 DSH desktop

## 为什么需要它

DSH 的 Windows ACL sandbox 需要 DSH 主进程 token 的 **default DACL 含当前用户 SID**。由 `explorer.exe` / `cmd.exe` 直接派生的进程通常不含用户 SID，会导致受限模式（`read-only` / `workspace-write`）失败：

```text
msys-token-guard: OpenProcessToken(child default DACL) failed (Win32 5)     # exit 125
pwsh 以 0xC0000142 (STATUS_DLL_INIT_FAILED) 退出，且无输出
```

让 `DeepSeek Harness.exe` 的祖先链上出现 Git Bash，MSYS2 就会把该 DACL 重置为含用户 SID 的标准形状，受限模式随即恢复正常。

## 文件

| 文件 | 用途 |
| --- | --- |
| `dsh.desktop.startup.gitbash.vbs` | 隐藏窗口启动；建议把它的快捷方式放进"启动"文件夹实现开机自启 |
| `dsh.desktop.startup.gitbash.bat` | 前台启动 / 排查问题 |
| `dsh.desktop.startup.gitbash.sh` | 实际启动逻辑，由 `.bat` 调用 |

## 用法

1. 把**整个目录**复制到任意位置（脚本内部按相对路径互相引用，可整体移动）。
2. 设置环境变量 `DSH_GIT_BASH_PATH`，指向你日常使用的 Git for Windows 的 `bash.exe`。`.bat` 会在变量缺失或路径不存在时报错退出。
3. 需要时设置 `DSH_DESKTOP_EXE`，指向 `DeepSeek Harness.exe` 的完整路径（默认见 `.sh` 内注释）。路径可用 Windows 形式或 `/c/...` 形式。
4. 双击 `dsh.desktop.startup.gitbash.bat` 前台启动，或把 `.vbs` 的快捷方式放进"启动"文件夹。

## 注意

- 这份脚本使用的 Git 应与插件 `danger-full-access` 用的那份一致（即 `DSH_GIT_BASH_PATH`）；**不要**把它指向 `DSH_GIT_BASH_PATH_CONFINED` 的那份。
- 脚本不包含任何个人化配置；如需额外的 `PATH` / 证书 / 代理设置，请自行在本机环境中配置。
