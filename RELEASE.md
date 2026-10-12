# 变更记录

本文件记录自 **0.3.3 发布**（基线提交 `25a7557`）以来的改动，按**功能**归类，而非按时间流水。

## 基线：`25a7557` — repo: 发布 0.3.3（2026-09-17）

npm 上 **0.3.3** 对应的提交（2026-09-17）。它只做两件事：

1. 把版本号标记为 0.3.3 并发布到 npm；
2. 修复 issue #4 —— 新增 `msys-token-guard.exe --normalize-server-dacl` 子命令与对应源码，并在 `src/index.ts` 中于受限模式首次执行前调用它。

**要点**：该提交只动版本与发布元数据，**面向当时宿主（DSH 0.1.x）的代码形态没有变化**——`package.json` 的 `peerDependencies` 仍是 `^0.1.2-rc.0`。所以 npm 上的 0.3.3 在 DSH 0.2.x 上会因 peer 不匹配被拒载，这正是后续改动要解决的问题。

---

## 一、宿主接口适配（DSH 0.1.6 → 0.2.0）· 2026-09-20 ~ 2026-09-30

跟随宿主 API 变更，让插件能在新宿主上加载与运行。**这是 0.2.x 下"装不上/一装就崩"系列问题的第一层。**

| 提交 | 内容 |
| --- | --- |
| `a57fbee` | 依赖升级到 `0.1.6-alpha.2` 对齐宿主，补齐 `dsh-subprocess` / `dsh-timeout` 钉子 |
| `3a254f6` | 适配宿主 0.1.6 的异步沙箱 `confine()` 与 `installSection` 新 API；`run()`/`start()` 对齐异步签名；`agents.ts` 回调显式返回 `undefined` |
| `94c967e` | 迁移到 0.2.0 的 shell 执行接缝：`run`/`start`/`runArgv`/`startArgv` → `execute(spec)` + `executeArgv(...)`；移除 `SHELL_SETTINGS_NAMESPACE` 具名导入与 `ctx.isolate("settings")`；`onProcessDone` 参数改名；`confine` 补 `signal` 实参；peer/dev 依赖对齐 `0.2.0-rc.2` |

> `94c967e` 在改写 `danger-full-access` 分支时，把 `this.runArgv(spec, this.argv(...))` 换成了 `super.execute(spec)`，**引入了第三节要修的那个 bug**。

## 二、0.2.x 加载期与配置期修复 · 2026-10-01 ~ 2026-10-12

接口迁移后仍暴露的三个问题，都会让插件"能装但不可用"。

| 提交 | 症状 | 修复 |
| --- | --- | --- |
| `6e16fbb` | 插件能加载，但**第一条命令即报 `config.timeoutMs.get is not a function`** | `z.intersect` 会重建 object schema 并丢弃 `volatile` 标记，改用 `LOCAL_BASH_CONFIG.set(...)` 扩展字段 |
| `06750a1` | 宿主报 `web boot: 1 entry did not activate` 并拒绝启动 | DSH 0.2 移除了 `settingsScope` 服务，把它从 client `inject` 移除，改为 `ctx.get("settingsScope")` 运行时探测 |
| `53c6593` | `danger-full-access` 下**配置的 Git 被完全忽略**（走了 PATH 里任意 bash） | 该分支此前调用宿主基类 `execute()`（argv 硬编码为 `["bash","-c",…]`），改为走 `this.executeArgv(spec, this.argv(spec.command))`，三种模式共用一条解析链 |

## 三、受限模式可用性（核心功能）· 2026-10-12

**本批最重要的改动**，解决 DSH 0.2 下受限模式无法使用的问题（Low integrity 对 MSYS 共享对象的封锁）。

`9eddf57` —— 受限模式使用一份**路径不同**的 Git 安装：

- **根因**：DSH 的 Windows ACL 沙箱把受限子进程降到 Low 完整性，使其无法打开已存在的 Medium 对象；MSYS2 因 `NtCreateDirectoryObject(\BaseNamedObjects\msys-2.0S5-<安装路径哈希>)` 返回 `0xC0000022`，所有 MSYS 程序 `exit 127`。
- **方案**：受限模式改用另一份 Git，其安装路径哈希与 `danger-full-access` 不同，受限子进程便能**自行创建**该共享对象（对象随进程退出而销毁），两种模式互不干扰。实测：同一份安装时 full-access 运行期间受限命令失败；两份不同安装时并行正常。
- **实现**：`discovery.ts` 新增 `DSH_GIT_BASH_PATH_CONFINED` 与 `configuredGitBashPath()`；`index.ts` 新增 `confinedExecutable` 字段，`executable` 解析按模式分流（`danger-full-access` 用 `executable`/`DSH_GIT_BASH_PATH`；受限模式优先 `confinedExecutable`/`DSH_GIT_BASH_PATH_CONFINED`，缺失时回落）。

## 四、启动脚本（`scripts/`）· 2026-10-12

解决受限模式的另一个前置条件：DSH 主进程 token 的 default DACL 必须含当前用户 SID，而 `explorer.exe` / `cmd.exe` 直接派生的进程往往不含。经 Git Bash 启动可让 MSYS2 重置该 DACL。

| 提交 | 内容 |
| --- | --- |
| `9eddf57` | 首次提交可复制的启动脚本 `scripts/web-startup/`（`.vbs` 自定位、`.bat` + `.sh`） |
| `4cec708` | 目录改名 `scripts/web-startup` → `scripts/dsh.web.startup`；新增 `scripts/dsh.desktop.startup/`（经 Git Bash 启动 DSH desktop，理由相同）；三件套通用化：`.vbs` 自定位、`.bat` 相对路径、`.sh` 剥离个人 curl/PATH 定制并把可执行路径改为 `DSH_DESKTOP_EXE` |
| `5bd5931` | 脚本文本与**文件编码**规范化：`.bat` 用 CRLF + UTF-8（无 BOM），`.vbs` 用 CRLF + UTF-16 LE + BOM；README 补「进程类型」说明 |

两套目录（`dsh.web.startup` / `dsh.desktop.startup`）各自带 `README.md`，说明用途、文件表、用法与变量（`DSH_WEB_*` / `DSH_DESKTOP_EXE`）。

## 五、界面与文档 · 2026-10-12

| 提交 | 内容 |
| --- | --- |
| `088d317` | GUI 设置卡片支持 `confinedExecutable`：把路径输入抽成可复用的 `GitBashPathField`，同时渲染两个字段（各自独立的路径选择、覆盖标记、重置与保存）；README 措辞统一为「两个环境变量的分工」。顺带修复 client 测试 harness（补 `ctx.get`、展开函数组件），**client 测试 2/12 → 12/12** |
| `b3365be` | 润色 README「配置与启动」一节：补「卡片字段 ↔ 配置项 ↔ 环境变量」对应表、补 desktop 说明、新增「典型症状」段（`exit 127` + `0xC0000022`）、修正失效的章节引用 |
| `5bd5931` | 见第四节（同时含脚本 README 润色） |

---

## 提交索引

| 提交 | 归类 |
| --- | --- |
| `a57fbee` | 一、宿主接口适配 |
| `3a254f6` | 一、宿主接口适配 |
| `94c967e` | 一、宿主接口适配 |
| `6e16fbb` | 二、0.2.x 加载期与配置期修复 |
| `06750a1` | 二、0.2.x 加载期与配置期修复 |
| `53c6593` | 二、0.2.x 加载期与配置期修复 |
| `9eddf57` | 三、受限模式可用性 / 四、启动脚本 |
| `4cec708` | 四、启动脚本 |
| `088d317` | 五、界面与文档 |
| `b3365be` | 五、界面与文档 |
| `5bd5931` | 四、启动脚本 / 五、界面与文档 |

## 尚未解决

- **`workspace-write` 仍受 issue #4 影响**：guard 以 `TOKEN_QUERY | TOKEN_ADJUST_DEFAULT` 打开子进程 token 时，`TOKEN_ADJUST_DEFAULT` 属于写类权限，在 `WRITE_RESTRICTED` token 下两趟检查都需通过；若 server token 的 default DACL 缺用户 SID，则报 `Win32 5`（`exit 125`）。这与本文件记录的改动相互独立，需单独处理。
- **自动化测试仍有既有失败**：`test/discovery.test.mjs` 与 `test/executor.test.mjs` 中若干断言写死 `MSYSTEM` 为 `MINGW32|MINGW64`（而 `usr/bin/bash` 报 `MSYS`），另有 `usr/usr/bin` 路径拼接假设，属测试自身的可移植性问题。
