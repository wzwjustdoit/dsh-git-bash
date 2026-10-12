# dsh.web.startup —— 经 Git Bash 启动 `dsh web`

## 为什么需要它

DSH 的 Windows ACL sandbox 需要 `dsh web` 的 **server 进程 token default DACL 含当前用户 SID**。由 `explorer.exe` / `cmd.exe` 直接派生的进程通常不含用户 SID，会导致受限模式（`read-only` / `workspace-write`）所有命令 `exit 125`：

```text
msys-token-guard: OpenProcessToken(child default DACL) failed (Win32 5)
```

从 Git Bash 启动可以让 MSYS2 把该 DACL 重置为含用户 SID 的标准形状，受限模式随即恢复正常。

## 文件

| 文件 | 用途 |
| --- | --- |
| `dsh.web.startup.gitbash.vbs` | 隐藏窗口启动；建议把它的快捷方式放进"启动"文件夹实现开机自启 |
| `dsh.web.startup.gitbash.bat` | 前台启动 / 排查问题 |
| `dsh.web.startup.gitbash.sh` | 实际启动逻辑，由 `.bat` 调用 |

## 用法

1. 把**整个目录**复制到任意位置（脚本内部按相对路径互相引用，可整体移动）。
2. 设置环境变量 `DSH_GIT_BASH_PATH`，指向你日常使用的 Git for Windows 的 `bash.exe`。`.bat` 会在变量缺失或路径不存在时报错退出。
3. 双击 `dsh.web.startup.gitbash.bat` 前台启动，或把 `.vbs` 的快捷方式放进"启动"文件夹。

## 参数

| 位置 | 名称 | 默认值 | 说明 |
| --- | --- | --- | --- |
| 参数 1 | 端口 | `1688` | 也可用 `DSH_WEB_PORT` |
| 环境变量 | `DSH_WEB_PORT` | `1688` | 命令行参数优先 |
| 环境变量 | `DSH_WEB_WORKDIR` | `$HOME` | 启动目录，会成为 Web 会话的默认 workspace 根目录 |

## 注意

- 这份脚本使用的 Git 应与插件 `danger-full-access` 用的那份一致（即 `DSH_GIT_BASH_PATH`）；**不要**把它指向 `DSH_GIT_BASH_PATH_CONFINED` 的专属 Git。
- 脚本不包含任何个人化配置；如需额外的 `PATH` / 证书 / 代理设置，请自行在本机环境中配置。
