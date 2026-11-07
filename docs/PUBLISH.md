# 发布与下载构建产物 · CI / Artifacts guide

本文档说明如何**触发构建**、**下载未签名 IPA / macOS App / 截图**，以及构建失败时怎么办。
仓库：<https://github.com/wiorigami/oripa-swift>（工作流文件：`.github/workflows/ci.yml`）。

前置：代码已推送到 GitHub（见 [`TOKEN-GUIDE.md`](TOKEN-GUIDE.md)）；
安装方法见 [`INSTALL.md`](INSTALL.md)。

---

## 1. 什么时候会自动构建

| 触发方式 | 说明 |
|---|---|
| **push 到 `main`** | 每次推送自动运行 `test` / `ios` / `macos` 三个 job（并行） |
| **Pull Request** | PR 的提交会自动跑一遍；同一 PR 的新提交会取消旧的运行 |
| **手动触发** | Actions → 左侧 `CI` → 右上 **Run workflow** → 选择 `main` 分支 → **Run workflow** |

不需要任何 secrets / 签名证书：iOS job 使用 `CODE_SIGNING_ALLOWED=NO` 打印**未签名** IPA。

## 2. 构建耗时与 job 说明

| Job | 内容 | 首次耗时（大约） |
|---|---|---|
| `test` | `swift build` + `swift run ORIPATests` + 无头 UI 截图 | 5–10 分钟 |
| `ios` | 安装 XcodeGen、生成 Xcode 工程、Release 编译、打包未签名 IPA | 10–20 分钟 |
| `macos` | Release 编译 ORIPAMac、组装 `.app`、ad-hoc 签名、zip | 6–12 分钟 |

三个 job **互相独立**：`test` 失败不会阻止 `ios` / `macos` 产出 artifact，反之亦然。
第一次运行还要下载/编译 SwiftPM 依赖，可能更慢；之后的运行有缓存会快一些。

## 3. 下载构建产物（Artifacts）

1. 打开仓库页面 → **Actions** 标签页。
2. 左侧点 **CI**，在列表中点击**最新一次**运行（绿色 ✓ 表示成功；黄色圆点表示进行中）。
3. 页面滚动到底部 **Artifacts** 区域，点击对应文件下载：

   | Artifact 名称 | 内容 | 用途 |
   |---|---|---|
   | **`ORIPA-unsigned.ipa`** | ZIP，解压后是 `ORIPA-unsigned.ipa` | iOS/iPadOS 安装（[INSTALL.md](INSTALL.md)） |
   | **`ORIPA-macOS`** | ZIP，解压后是 `ORIPA.app` | macOS 13+ 直接运行 |
   | **`oripa-ui-snapshots`** | ZIP：所有界面 PNG + `manifest.json` | 视觉检查/截图 |
   | `ios-build-log` | 仅在 iOS job 失败时出现 | 排查 Xcode 编译错误 |

   > **注意**：artifact 本身是 ZIP（GitHub 的打包方式），下载后需要先解压。例如下载得到
   > `ORIPA-unsigned.ipa.zip`，解压出 `ORIPA-unsigned.ipa` 后再交给 Sideloadly。
   >
   > **下载 artifact 需要登录 GitHub 账号**（即使是公开仓库）；Windows/macOS 浏览器都可以。

4. 命令行下载（已 `gh auth login` 的情况）：

   ```bash
   cd /Users/william/Desktop/hns/apps/oripa-swift
   gh run list --limit 5                    # 找到最新的成功运行
   gh run download <run-id>                 # 下载该次运行的全部 artifact 到当前目录
   gh run download <run-id> -n ORIPA-unsigned.ipa   # 只下载某一个
   unzip -o ORIPA-unsigned.ipa.zip
   ```

### Artifact 保留时间

CI 中设置 `retention-days: 14`，即 artifact **只保留 14 天**。过期后：

* 重新运行 workflow（手动触发即可）→ 生成新的 artifact；或
* 打 tag / 建 GitHub Release 并把 IPA/zip 上传到 Release（Release 资产永久保留）。

## 4. 构建失败怎么办

1. Actions → 点进失败的运行 → 点红色 ✗ 的 job，查看日志。
2. iOS job 失败时，除了网页日志，还会额外生成 **`ios-build-log`** artifact
   （完整 `xcodebuild` 日志）；`scripts/build_ipa.sh` 在失败时也会把最后 150 行打印到日志。
3. 常见的修复方式：
   * **Swift 编译错误**：在本地跑 `swift build` / `swift run ORIPATests` 复现并修复；
   * **iOS 专属错误**：iOS 用 Xcode 的 iOS SDK 编译共享代码，`#if os(iOS)` 的 API 需要
     按 `docs/PORT-CONTRACT.md` 做跨平台守卫；本地 `swift build` 是 macOS 编译，抓不到
     iOS 专属错误，只能看 CI 日志；
   * **XcodeGen 失败**：本地执行 `xcodegen generate` 确认 `project.yml` 有效；
   * **workflow 文件推送被拒绝**：凭据缺少 `workflow` scope（见 `TOKEN-GUIDE.md`）；
   * **runner 排队/资源**：重新运行即可；private 仓库会消耗 Actions 分钟数。
4. 修好后重新 push，或在该运行页面点 **Re-run failed jobs**。

## 5. 发一个新版本（版本号规则）

版本号需要**手动**同步（CI 不校验，PR review 时检查）：

| 值 | 文件 |
|---|---|
| 版本号 `0.2.3.3` | `Sources/ORIPACore/Version.swift`（`AppInfo.version`）+ `project.yml`（`MARKETING_VERSION`） |
| 构建号 `2` | `Sources/ORIPACore/Version.swift`（`AppInfo.build`）+ `project.yml`（`CURRENT_PROJECT_VERSION`） |
| macOS bundle id | `scripts/build_mac.sh`（`com.origamitoolbox.oripa.mac`） |

> **iOS bundle id `com.origamitoolbox.oripa` 绝对不能改**：改了以后新版本会被 iOS 当成
> 另一个 App，旧版用户升级时看不到原来的工程文件（见 `docs/INSTALL.md` 第 4 节）。

发布流程：

1. 修改版本号 → `git commit -m "Bump version to x.y.z"` → `git push`。
2. 等 CI 三个 job 全绿。
3. 下载 `ORIPA-unsigned.ipa` / `ORIPA-macOS` 自测。
4. （可选）在 GitHub 上创建 Release（`Draft a new release` → 打 tag，如 `v0.2.3.3`），
   把 IPA 和 macOS zip 作为 Release 资产上传，方便用户长期下载。

## 6. 安全说明

* 本仓库**不使用任何 secrets**：无签名证书、无 Apple ID、无 token 写入仓库。
* 产物是**未签名 IPA**（iOS 需要用户自己签名）和**未公证的 macOS app**（ad-hoc 签名）。
* GitHub Actions 的 artifact 谁有仓库访问权谁就能下载；公开仓库下载需登录 GitHub。
* 不要把 Apple ID 密码、开发者证书、PAT 写进 Issue/PR/代码或 workflow。

## 7. 常见问题速查

| 问题 | 原因/解决 |
|---|---|
| Artifacts 区域是空的 | 该 job 还没跑完；artifact 只在 job 结束后上传。 |
| 只有 `oripa-ui-snapshots`，没有 IPA | `ios` job 失败或被跳过；检查该 job 日志和 `ios-build-log`。 |
| 下载的 IPA 装不上 | 需要自己签名（Sideloadly 等）；见 `INSTALL.md`。 |
| artifact 打不开/已过期 | 超过 14 天，重新运行 workflow 生成新的。 |
| 修改 `.github/workflows/ci.yml` 后 push 被拒 | token 缺少 `workflow` 权限（见 `TOKEN-GUIDE.md` 方案 B/C）。 |
| 想只跑某一个 job | 目前不支持单独触发；可在 fork 里临时改 workflow，或本地跑对应脚本（`scripts/build_mac.sh` / `scripts/build_ipa.sh`）。 |
