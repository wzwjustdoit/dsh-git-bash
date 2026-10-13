# RELEASE NOTE

## 0.4.0

### 适配 DSH 0.2.x

npm 上的 0.3.3 只声明支持 DSH 0.1.x（peer 依赖 `^0.1.2-rc.0`），装到 0.2.x 会被拒载。这次把插件迁到 0.2.x 并能真正跑起来：

- **插件注册失败**：0.2.0 的 `dsh-shell` 不再导出 `SHELL_SETTINGS_NAMESPACE`，具名导入在模块加载阶段就抛 `SyntaxError`，DSH 随之失去全部 shell 提供者（桌面端表现为新建会话一直 `agent: waiting for shell`、权限切换按钮消失）。已移除该导入与 `ctx.isolate("settings")`，执行入口从 `run`/`start`/`runArgv`/`startArgv` 迁到 `execute(spec)` + `executeArgv(...)`。
- **第一条命令报 `config.timeoutMs.get is not a function`**：`z.intersect` 重建 schema 时丢了 `volatile` 标记，DSH 没法把配置解析成可用的活配置；改用 `LOCAL_BASH_CONFIG.set(...)` 扩展字段。
- **DSH 拒绝启动，报 `web boot: 1 entry did not activate`**：0.2 删掉了 `settingsScope` 服务，client 仍把它写进 `inject`，entry 永远 pending；改为运行时用 `ctx.get("settingsScope")` 探测。
- 依赖对齐 0.2.x（`0.1.6-alpha.2` → `0.2.0-rc.2`），补上 `dsh-subprocess` / `dsh-timeout`。

### 受限模式改用另一份 Git Bash 路径

以前两份用途共用一份 Git，受限模式必然失败：所有 MSYS 程序 `exit 127`，stderr 出现 `NtCreateDirectoryObject(\BaseNamedObjects\msys-2.0S5-<Git Bash 路径哈希>): 0xC0000022`。原因是沙箱把受限子进程降到 Low 完整性，它打不开 `danger-full-access` 以 Medium 完整性创建的 MSYS 共享对象。现在受限模式改用另一份 Git Bash 路径（路径不同 → 哈希不同），子进程便能自行创建该对象，两种模式互不干扰。对应新增 `confinedExecutable` / `DSH_GIT_BASH_PATH_CONFINED`，不填则回落到原行为（共用一份，仍可能冲突）。

### 修复：danger-full-access 忽略配置的 Git

该模式下配置的 `executable` / `DSH_GIT_BASH_PATH` 被完全忽略，跑的是 `PATH` 里的任意 `bash`。原因是 `94c967e`（2026-09-30，适配 0.2.0 执行接口）把该分支的 `this.runArgv(spec, this.argv(...))` 换成了 `super.execute(spec)`，`LocalBashExecutor` 基类的 argv 硬编码为 `["bash", "-c", …]`。现已改回插件自己的 `argv()`，三种模式共用 `executable → DSH_GIT_BASH_PATH → 自动探测` 一条链。

### 启动脚本

DSH 主进程 token 的 default DACL 必须含当前用户 SID，而 `explorer.exe` / `cmd.exe` 直接派生的进程往往不含，会让受限模式全部 `exit 125`（`dsh web`）或直接崩溃（DSH desktop）。经 Git Bash 启动可让 MSYS2 把 DACL 重置为标准形状。

仓库提供两套可复制的脚本：`scripts/dsh.web.startup/`（`dsh web`）与 `scripts/dsh.desktop.startup/`（Electron GUI）。每套含自定位 `.vbs`（开机自启）、`.bat`（前台启动）、`.sh`（实际逻辑）；desktop 版用 `DSH_DESKTOP_EXE` 指定可执行文件。

### 设置卡片

- 设置卡片同时提供两个路径字段：`executable`（启动脚本 / danger-full-access）与 `confinedExecutable`（read-only / workspace-write），可分别选择、重置、保存。

## 0.3.3

上一个发布版（[npm](https://www.npmjs.com/package/dsh-plugin-git-bash)，`25a7557`，2026-09-17）。插件的基本形态在这一版定型；更早的 0.1.0 ~ 0.3.2 是逐步搭起来的，下面只列最终结果：

- 让 DSH 在 Windows 上默认用 Git for Windows Bash，替代 PowerShell；前台命令、后台命令和 Web Agent 共用同一个 executor。
- 三种权限语义：`read-only` / `workspace-write` 走 DSH 的 Windows ACL 沙箱，先运行 native guard（`msys-token-guard.exe`）创建 `WRITE_RESTRICTED` token，再由它启动 Git Bash；`danger-full-access` 不做隔离，直接以正常权限运行。
- 图形化配置 Git 路径（设置卡片里选择安装目录），并自动探测 Program Files、用户安装目录、Scoop、`GIT_INSTALL_ROOT` 和 `PATH`。
- Web 端接入 Bash 工具行与终端详情：命令自动换行，输出保留横向滚动以维持列对齐。
- 仅支持 Windows x64；npm 包内含预编译的 guard，普通安装不需要 Visual Studio 或 CMake。
- 本版自身的新增：`msys-token-guard.exe --normalize-server-dacl`，在受限模式首次执行前，把 server 进程 token 的 default DACL 自动补成含用户 SID 的标准形状。
