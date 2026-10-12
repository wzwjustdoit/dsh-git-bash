# dsh-plugin-git-bash

让 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) 在 Windows 上默认使用 Git for Windows Bash，并保留 DSH 的 `read-only`、`workspace-write` 和 `danger-full-access` 权限语义。

![Git Bash 在 DeepSeek Harness 中运行](assets/teaser.png)

## 使用方法

插件安装到 profile 后，`standard`、`code`、`cordis` 和 `minimal` preset 会使用 Git Bash 代替 PowerShell。前台命令、后台命令和 Web Agent preset 共用同一个 executor。

新建会话后可以运行以下命令确认 shell：

```sh
printf 'shell=%s\nversion=%s\nmsystem=%s\n' "$BASH" "$BASH_VERSION" "$MSYSTEM"
```

`MSYSTEM` 应为 `MINGW64` 或 `MINGW32`。

Web 界面中的 Bash 工具行可以展开查看 command、cwd、stdout/stderr 和 exit status。`run_code` 内的 nested Bash 调用使用同一套 terminal 详情；过长的 command 会自动换行，output 则保留终端横向滚动，以维持日志和表格的列对齐。

插件只作为 bundle layer 安装到目标 profile，不修改 DSH 安装目录。

## 安装或更新

从 npm 安装固定版本到 Web profile：

```sh
dsh plugin --profile web add dsh-plugin-git-bash@0.3.3
```

更新现有安装时使用同一条命令。安装完成后重启 `dsh web`，让 Host 和浏览器 client 同时加载新版本，然后新建会话。

安装最新版时可以省略版本号：

```sh
dsh plugin --profile web add dsh-plugin-git-bash
```

开发本地版本时传入 checkout 路径：

```powershell
dsh plugin --profile web add C:\path\to\dsh-git-bash
```

## 权限模式

### `read-only` 和 `workspace-write`

受限命令仍由 DSH Windows ACL sandbox 创建 `WRITE_RESTRICTED` token。插件在 sandbox 内先运行 native guard，再由 guard 启动 Git Bash：

```text
DSH ACL runner -> msys-token-guard.exe -> bash.exe -> child processes
```

- `read-only` 可以启动 Git Bash，但不能写 workspace。
- `workspace-write` 只能写 DSH 授权的 workspace 和 private temp。

### `danger-full-access`

该模式不经过 native guard，也不进入 sandbox，直接以正常权限运行 Git Bash。它使用 `DSH_GIT_BASH_PATH`（未设置专属运行时时的 `DSH_GIT_BASH_PATH_CONFINED` 不参与），与受限模式的两份运行时相互独立——见[两个运行时](#两个运行时重要)。

## 配置 Git Bash 路径

插件会自动探测 Program Files、用户安装目录和 Scoop 中的 Git Bash。Web GUI 中打开 `设置 -> 插件 -> 插件配置`，展开 `Git Bash` 卡片后可以直接输入 `bash.exe` 路径，或通过 `选择 Git 安装目录` 调用系统路径选择窗口。保存后，后续 Bash 命令会立即使用新路径；恢复默认值会回到 profile 配置或自动探测结果。

### 两个运行时（重要）

插件使用**两个** Git Bash，通过两个环境变量区分：

| 环境变量 | 服务的场景 | 推荐配置 |
| --- | --- | --- |
| `DSH_GIT_BASH_PATH` | 启动 `dsh web` 的启动脚本、以及 `danger-full-access` 模式 | 你自己日常使用的那份 Git for Windows |
| `DSH_GIT_BASH_PATH_CONFINED` | `read-only`、`workspace-write` 模式 | 一份**独立**的 Git for Windows（如 PortableGit 解压版），专供插件使用 |

**为什么必须分成两份：** `danger-full-access` 以正常（Medium）完整性运行，会让 MSYS2 在 `\BaseNamedObjects` 下创建 `msys-2.0S5-<安装路径哈希>`；受限模式的子进程被降到 Low 完整性，**无法打开**已存在的 Medium 对象。只要两份 Git 的安装路径不同，哈希就不同，两者各自创建各自的共享对象，互不干扰。若两份指向同一安装，受限模式会在 `danger-full-access` 运行期间报 `0xC0000022`。

**注意事项（请务必阅读）：**

1. **`DSH_GIT_BASH_PATH_CONFINED` 必须与 `DSH_GIT_BASH_PATH` 指向不同的 Git 安装。** 指向同一份会退回成"共用一份"，受限模式将不可用。
2. **`DSH_GIT_BASH_PATH` 不要指向受限专属的那份。** 它同时服务启动脚本；若指向专属 Git，启动脚本会用专属 Git 启动 `dsh web`，反而制造冲突。
3. **`DSH_GIT_BASH_PATH_CONFINED` 的那份 Git 建议只交给插件使用。** 不要手动打开它并保持运行，也不要用它启动 `dsh web`。
4. 两份都可以是 Git for Windows（不必是不同版本）。

未设置 `DSH_GIT_BASH_PATH_CONFINED` 时，受限模式回落到 `DSH_GIT_BASH_PATH` 与自动探测，行为与旧版本一致（但在 `danger-full-access` 与受限模式混用同一份 Git 时，可能遇到上面第 4 条描述的问题）。

### 启动方式（重要）

**强烈建议用本仓库提供的启动脚本启动 `dsh web`。** 原因：DSH 的 Windows ACL sandbox 需要 server 进程 token 的 default DACL 含当前用户 SID；由 `explorer.exe` / `cmd.exe` 直接派生的进程往往不含，会导致受限模式全部 `exit 125`。经 Git Bash 启动可以让 MSYS2 把 DACL 重置为含用户 SID 的标准形状。

启动脚本位于 [`scripts/web-startup/`](scripts/web-startup/)：

```text
scripts/web-startup/
├── dsh.web.startup.gitbash.vbs   # 隐藏窗口启动（推荐加入"启动"文件夹实现开机自启）
├── dsh.web.startup.gitbash.bat   # 前台启动 / 排查问题
└── dsh.web.startup.gitbash.sh    # 实际逻辑（由 .bat 调用）
```

用法：把 `scripts/web-startup/` 整个目录**复制到任意位置**，按需设置 `DSH_GIT_BASH_PATH`（指向你日常的 Git Bash），然后双击 `.bat`，或把 `.vbs` 的快捷方式放进"启动"文件夹。

### 无 GUI / 手动配置

无 GUI 场景可以在启动 DSH 前设置环境变量：

```powershell
$env:DSH_GIT_BASH_PATH = 'D:\Apps\Git\bin\bash.exe'
$env:DSH_GIT_BASH_PATH_CONFINED = 'D:\dsh-git-runtime\usr\bin\bash.exe'
dsh web
```

也可以直接在 profile 的 `cordis.patch.yml` 中为 provider 配置 `executable` 与 `confinedExecutable`：

```yaml
- id: git-bash-shell
  name: dsh-plugin-git-bash
  config:
    executable: D:\Apps\Git\bin\bash.exe
    confinedExecutable: D:\dsh-git-runtime\usr\bin\bash.exe
```

## 平台支持

运行时要求：

- Windows x64
- Node.js 24 或更高版本
- DSH `0.1.2-rc.1`
- Git for Windows x64

npm 包包含预编译的 `msys-token-guard.exe` 和 `msys-token-guard-hook.dll`，普通安装不需要 Visual Studio 或 CMake。当前 native guard 仅支持 `win32-x64`；其他架构在受限模式下返回 `SANDBOX_UNAVAILABLE`，不会降级到未隔离执行。

Microsoft Detours 4.0.1 源码按 MIT 许可存放在 `native/vendor/detours`，许可文本随 npm 包分发。Detours 的 DLL path 参数使用 Windows ANSI API，因此插件安装路径必须能由当前系统代码页无损表示，并且不能超过 `MAX_PATH`；不满足条件时 guard 会 fail closed。

## 开发

安装依赖并运行完整验证：

```sh
pnpm install
pnpm test
pnpm run pack:check
```

在 Windows 上重建 native artifact 还需要 Visual Studio C++ Build Tools 和 CMake 3.25 或更高版本。`pnpm test` 会以 C++20、静态 MSVC runtime、CFG、CET、ASLR 和 NX 构建 native guard，然后运行 Windows ACL permission matrix、fail-closed、Web client 和 package metadata 测试。

非 Windows 主机不会交叉编译 native guard，只会检查预编译 artifact 是否存在。

## License

MIT
