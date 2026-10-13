# 手动发布清单

从改版本号到 npm + GitHub Release 上线的全流程，基于 `0.4.0` 的实际发布整理。

替换占位符：`X.Y.Z` 为新版本号，`<上次tag>` 为上一个 tag（如 `v0.4.0`）。

---

## 一次性准备（换机器才需要重做）

**npm 登录与 scope**

```sh
npm whoami --registry=https://registry.npmjs.org/
```

期望输出 `wzwjustdoit`。scoped 包必须 `--access public`，且 `@wzwjustdoit` scope 需已存在。

**git remote 布局**

```sh
git remote -v
```

期望 `origin` = 自己的 fork（`wzwjustdoit/dsh-git-bash`），`upstream` = 上游（`inmny/dsh-git-bash`）。把默认推送目标钉在 fork 上，防止误推上游：

```sh
git config remote.pushDefault origin
```

**凭据助手**：用 gh 给 github.com 提供凭据。`gh auth setup-git --hostname github.com` 会写入下面两条：

```ini
[credential "https://github.com"]
    helper =
    helper = !'<gh 的完整路径>' auth git-credential
```

- **上面那条空的 `helper =` 不要删**：它的作用是清空从全局继承的 `credential.helper`，确保只有 gh 生效。删掉后，全局配置的凭据助手（如 git-credential-manager）会重新进入凭据链，推送时弹出登录框。
- 若 `gh` 不在 `PATH` 中，把 `<>` 里换成 gh 的完整路径；在 `!` 命令里用正斜杠更稳。

---

## 每次发版

### 1. 定稿

- `package.json` 的 `version` 改成 `X.Y.Z`。
- `RELEASE.md` 增加 `## X.Y.Z` 一节（**放在最上面**，新版本在前）。
- 全文搜一遍旧版本号，确认没有漏网：

```sh
rg -n "<旧版本号>" -g '!node_modules*' -g '!.git' .
```

### 2. 验证

```sh
pnpm run typecheck
git diff --stat <上次tag> HEAD -- native/     # native/ 有改动才需重建
pnpm run clean && pnpm exec tsc -p tsconfig.json
node --test
```

要点：

- 用 `node --test` 跑测试，**不要用 `pnpm test`** —— 后者会先跑 `build`，连带 `build:native`。
- 本仓库有若干既有的测试失败（断言写死了 `MSYSTEM=MINGW*`、受限模式需从 Git Bash 启动），与本次发布无关，可忽略。
- 这一步之后确认 `lib/` 是最新的，且工作区**只有**预期的改动。

**native build 判定**：若 `git diff --stat <上次tag> HEAD -- native/` 输出为空（native 源码与二进制都没动），可跳过 native build；否则需要 Visual Studio C++ Build Tools + CMake 3.25+，并跑 `pnpm run build:native`。

### 3. 提交

```sh
git add -A
git commit -m "repo: 发布 X.Y.Z"
```

### 4. 打 tag

```sh
git tag -a vX.Y.Z -m "dsh-plugin-git-bash X.Y.Z"
git tag --list
```

### 5. 推 git

```sh
git remote -v                 # 先确认 origin 指向自己的 fork
git push -u origin main
git push origin vX.Y.Z
```

### 6. 发布到 npm

```sh
npm publish --access public --ignore-scripts --registry=https://registry.npmjs.org/
```

- `--registry` 视情况指定：**若本机配置了镜像源，务必显式加上**，否则会把包发到镜像、或发布失败。先确认当前源：

  ```sh
  npm config get registry
  ```

  输出不是 `https://registry.npmjs.org/` 就说明配了镜像（可能来自 `NPM_CONFIG_REGISTRY` 环境变量或 `.npmrc`），此时必须加 `--registry=https://registry.npmjs.org/`。
- `--ignore-scripts` 用于跳过 native 重建（对应第 2 步的判定）。**若本次 native 有改动，去掉该参数**，让 `prepublishOnly` / `prepack` 正常执行。
- 发布后 registry 索引有几十秒到几分钟延迟，刚发布时 `npm view` 可能 404，稍等再查。

### 7. GitHub Release

只发**本版本一节**，不要整个 `RELEASE.md`：

```sh
# 先切出单节，存成临时文件（在 Git Bash 里执行）
awk '/^## X\.Y\.Z/{f=1} /^## / && !/^## X\.Y\.Z/ && f{exit} f' RELEASE.md > notes.md

head -5 notes.md      # 确认开头是本版本一节
```

再建 Release：

```sh
gh release create vX.Y.Z --repo wzwjustdoit/dsh-git-bash \
  --title "X.Y.Z" --notes-file notes.md --verify-tag
```

`--verify-tag` 让 tag 不存在时中止，避免 gh 悄悄新建一个 tag。

### 8. 核对

```sh
npm view @wzwjustdoit/dsh-plugin-git-bash version dist-tags --registry=https://registry.npmjs.org/
```

期望 `version = X.Y.Z`、`dist-tags = { latest: 'X.Y.Z' }`。

实机验证（在 **Git Bash** 里跑，以便受限模式也能测）：

```sh
dsh plugin --profile web add @wzwjustdoit/dsh-plugin-git-bash@X.Y.Z
```

重启 `dsh web`，新建会话，确认 shell：

```sh
printf 'shell=%s\nversion=%s\nmsystem=%s\n' "$BASH" "$BASH_VERSION" "$MSYSTEM"
```

再分别切 `read-only` / `workspace-write` 各跑一条命令，确认不报 `exit 125` / `0xC0000022`。

---

## 已知坑

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| `git push` 弹出登录框 | `[credential "https://github.com"]` 里空的 `helper =` 被删了，全局的凭据助手重新进入凭据链 | 补回那行空 `helper =` |
| `npm whoami` 报 `ENEEDAUTH` | 若配了镜像源，该源上通常没有你的登录态 | 加 `--registry=https://registry.npmjs.org/` |
| `npm publish` 触发 CMake/MSVC 构建 | `prepublishOnly` / `prepack` 钩子 | 加 `--ignore-scripts`（仅在 native 无改动时） |
| Release 正文混入旧版本 | `--notes-file` 传了整个 `RELEASE.md` | 只传切好的单节 `notes.md` |
| 推送推到了别人的仓库 | `origin` 仍指向上游 | 先 `git remote -v` 确认 |
| 浏览器打开包页面报 403 | Cloudflare 拦截无头请求 | 用 `npm view` 验证，或直接用浏览器访问 |
