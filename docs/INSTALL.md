# 安装 ORIPA（iOS / iPadOS / macOS）· Installing ORIPA

> **English quick start** is at the bottom of this file. 中文为主，末尾附英文简版。

ORIPA 的 GitHub Actions 会构建两个**未签名/未公证**的产物（不是 App Store 版本）：

| 文件 | 平台 | 说明 |
|---|---|---|
| `ORIPA-unsigned.ipa` | iPhone / iPad（iOS 16+） | 未签名 IPA，需要用 Sideloadly / 爱思助手 / TrollStore 等工具用你自己的证书签名后安装 |
| `ORIPA-macOS.zip` | macOS 13+ | 已 ad-hoc 签名的 `.app`（未公证），首次打开需右键 → 打开 |

> 从 GitHub 下载的 artifact 本身是一个 ZIP 包，里面才是 `ORIPA-unsigned.ipa` / `ORIPA-macOS.zip`。
> 下载位置与方法见 [`PUBLISH.md`](PUBLISH.md)。

Bundle ID 刻意与旧版（WKWebView 版）一致：**`com.origamitoolbox.oripa`**，因此用同一
Apple ID 覆盖安装时，iPad 上已有的工程文件（`Documents/project_data`、`project_thumbs`）
会被保留。**升级前请先阅读第 4 节“从旧版升级 / 数据保留”。**

---

## 1. 安装到 iPhone / iPad

### 1.1 前置条件

* 设备：iPhone 或 iPad，**iOS / iPadOS 16.0 或更高版本**。
* Apple ID：免费 Apple ID 即可（自签名有效期为 7 天，见 1.3）；付费开发者账号为 1 年。
* 电脑：Windows 或 macOS，用于运行签名工具并通过 USB 连接设备（TrollStore 方式除外）。

### 1.2 方法 A：Sideloadly（推荐，Windows / macOS 通用）

1. 从 <https://sideloadly.io> 下载并安装 Sideloadly（macOS 版也可用）。
2. 用 USB 线连接 iPhone/iPad，解锁并在设备上点“信任此电脑”。
3. 打开 Sideloadly，把 `ORIPA-unsigned.ipa` 拖进窗口（或点 IPA 图标选择文件）。
4. 在 `Apple ID` 一栏填入你的 Apple ID（Sideloadly 只用它向 Apple 申请免费签名证书，
   不会上传密码给第三方；如不放心可先注册一个专用 Apple ID）。
5. 点击 **Start**，等待日志显示 `Done`。
6. **在设备上信任证书**：
   - 设置 → 通用 → VPN 与设备管理（旧系统为“描述文件与设备管理”）→ 开发者 App →
     点你的 Apple ID → **信任**。
7. **iOS 16+ 必须打开开发者模式**（否则 App 闪退/无法启动）：
   - 设置 → 隐私与安全性 → **开发者模式** → 打开 → 重启设备 → 重启后再次确认打开。

### 1.3 方法 B：爱思助手 i4Tools（Windows / macOS，中文界面）

1. 安装爱思助手并连接设备。
2. 工具箱 → **IPA 签名**（或“应用游戏 → 导入安装”）：添加 `ORIPA-unsigned.ipa`，
   勾选“使用 Apple ID 签名”，输入 Apple ID，开始签名。
3. 签名完成后安装到设备。
4. 同样需要第 1.2 步的第 6、7 点：信任开发者证书 + 打开开发者模式。

### 1.4 方法 C：TrollStore（永久安装，无 7 天限制）

TrollStore 利用系统漏洞实现“永久签名”，安装后不会过期，也不需要 Apple ID。
**但只支持特定 iOS 版本**（大致为 iOS 14.0–16.6.1，以及部分设备的 17.0；不支持的版本
装不了，例如已升级到 iOS 17.0.1+ / 18 / 26 的设备）。安装前请先查 TrollStore 兼容性列表
（<https://github.com/opa334/TrollStore>）：

1. 用对应版本的安装方式装好 TrollStore。
2. 把 `ORIPA-unsigned.ipa` 传到设备（AirDrop / 文件 App / 网页下载均可）。
3. 在文件 App 中长按 IPA → 共享 → **用 TrollStore 打开**（或在 TrollStore 里点 `+`
   选择该文件）→ Install。
4. 不需要开发者模式，也不会 7 天过期。

### 1.5 方法 D：AltStore / SideStore / Esign / Scarlet 等

原理同 Sideloadly：用你的 Apple ID 或自备证书重签。免费账号同样是 **7 天有效期**，
到期后重新签名即可。按各工具说明操作，并同样完成“信任证书 + 开发者模式”。

### 1.6 免费 Apple ID 的 7 天限制（重要）

* 免费 Apple ID 签名（Sideloadly / AltStore / 爱思助手等）的有效期是 **7 天**；到期后
  App 打不开，**重新执行一次签名安装即可**（数据仍在，不会丢）。
* 同一免费账号 7 天内最多签名 10 个 App ID、同时最多 3 个 App。
* 加入 Apple Developer Program（99 美元/年）后签名有效期为 1 年。
* 重新签名时**请继续使用同一个 Apple ID**：这样是“覆盖安装”，App 内的工程数据保留。

---

## 2. 在 Files（文件）App 中访问工程文件

这是本项目的硬性需求之一：工程文件以真实文件形式保存在 App 的 `Documents` 目录下，
可在 **文件 App → 我的 iPhone/iPad → ORIPA** 中看到/拷贝：

```
ORIPA/
  project_data/<name>       # 工程文件（OPXC 格式）
  project_thumbs/<name>     # 工程缩略图（PNG）
  import_data/              # 导入暂存（临时）
  temp_save_file            # 崩溃恢复用的自动保存文件
```

* 用“文件”App 可以直接把工程文件拷出备份、或从 iCloud/“我的 iPhone”拷入其他作品。
* App 内也提供系统文档选择器（导入）和分享面板（导出 SVG/PNG/OPX/CP），见 App 内菜单。

---

## 3. 安装到 macOS

1. 解压 `ORIPA-macOS.zip`，得到 `ORIPA.app`。
2. 拖到“应用程序”文件夹（或任意目录）。
3. 首次打开：在 Finder 中**右键 → 打开**（系统会提示来自“未识别的开发者”；本 App 仅
   ad-hoc 签名、未经过 Apple 公证）。或者执行：

   ```bash
   xattr -dr com.apple.quarantine /Applications/ORIPA.app
   ```

4. 系统要求 **macOS 13 Ventura 或更高**。

> 从 GitHub Actions 下载的 zip 会被打上 quarantine 标记，所以“右键 → 打开”或上面的
> `xattr` 命令是必须的；这不是 App 损坏。

---

## 4. 从旧版升级 / 数据保留（iPad 用户务必阅读）

旧版 ORIPA（WKWebView 版）与新原生版的 Bundle ID 相同 (`com.origamitoolbox.oripa`)，
工程文件保存在 App 容器内的 `Documents/project_data`。覆盖安装能否保留数据取决于
**签名证书是否相同**：

* **推荐**：用**同一个 Apple ID**（同一个免费账号签名）覆盖安装 → iOS 视为“升级” →
  `Documents` 原样保留，直接能看到以前的工程。
* 若用不同 Apple ID / 不同证书签名：iOS 可能拒绝覆盖安装，或要求先卸载旧 App——卸载会
  **删除容器内所有工程文件**。此时请先备份：

  1. 打开 **文件 App → 我的 iPad → ORIPA**；
  2. 把 `project_data` 和 `project_thumbs` 两个文件夹拷贝到“我的 iPad”其他位置或
     iCloud Drive 备份；
  3. 卸载旧 App、安装新 App；
  4. 再通过“文件”App 把两个文件夹拷回 `ORIPA` 目录；或使用 App 内“导入”功能。

> 数据安全第一：升级前建议无论如何先做一次上面第 2 步的备份。

---

## 5. 常见问题

| 现象 | 处理 |
|---|---|
| “无法安装 / Unable to Install” | 证书不匹配或描述文件失效。用 Sideloadly 重新签名安装；确认设备已信任该 Apple ID。 |
| 打开即闪退（iOS 16+） | 未开启 **开发者模式**：设置 → 隐私与安全性 → 开发者模式 → 打开并重启。 |
| 安装后图标是白图标/找不到 | 重新安装一次；若仍异常，检查是否是空间不足或描述文件被移除。 |
| App 打不开了（用了几天后） | 免费签名 7 天过期。重新用同一 Apple ID 签名安装即可，数据不会丢。 |
| macOS 提示“已损坏，无法打开” | 未公证 + quarantine：右键 → 打开，或 `xattr -dr com.apple.quarantine ORIPA.app`。 |
| 以前的工程不见了 | 检查是否用了不同 Apple ID 覆盖安装；按第 4 节用文件 App 备份/恢复。 |
| 下载的 artifact 里没有 `.ipa` | GitHub 的 artifact 下载下来是 ZIP，解压后才是 `ORIPA-unsigned.ipa`（见 `PUBLISH.md`）。 |
| 想获得最新构建 | GitHub 仓库 → Actions → CI → 最新一次运行；artifact 保留 14 天，过期后重新运行 workflow。 |

---

## 6. 安全与法律提示

* 本项目 **不分发** 原始 Android APK 或反编译源码；构建产物由你自己或 GitHub Actions
  从本仓库源码编译，再用你自己的 Apple ID 签名。
* 未签名 IPA 只能在你自己拥有/授权的设备上安装。
* 项目代码为 **GPL-3.0**（见 `LICENSE`），源自 ORIPA（Jun Mitani）、ORIPA S（Ouchi Koji）、
  ORIPA for Android（Michelle Fung）。请遵守 GPL-3.0 再分发条款。

---

## English quick start

ORIPA's GitHub Actions workflow produces **unsigned/unnotarised** artifacts — not an App
Store build (see [`PUBLISH.md`](PUBLISH.md) for how to download them):

* **iOS/iPadOS 16+**: `ORIPA-unsigned.ipa`. Sign it with your own Apple ID using
  [Sideloadly](https://sideloadly.io) (Windows/macOS), i4Tools, or install permanently with
  TrollStore on supported iOS versions (roughly 14.0–16.6.1). After signing:
  **Settings → General → VPN & Device Management → Developer App → Trust**, and on
  iOS 16+ **Settings → Privacy & Security → Developer Mode → On** (reboot required).
  Free Apple ID signatures expire after **7 days** — just re-sign with the same Apple ID;
  your files survive. (Paid developer account: 1 year.)
* **macOS 13+**: `ORIPA-macOS.zip` → unzip → drag `ORIPA.app` to Applications →
  first launch via **right-click → Open**, or
  `xattr -dr com.apple.quarantine /Applications/ORIPA.app`. The app is ad-hoc signed,
  not notarised.
* **Project files** live in the app's Documents folder and are visible in
  **Files.app → On My iPhone/iPad → ORIPA** (`project_data/`, `project_thumbs/`).
  Back them up there before uninstalling anything.
* **Upgrading from the previous WKWebView port**: install over it signed with the **same
  Apple ID** to keep the app container (same bundle id
  `com.origamitoolbox.oripa`); otherwise back up `project_data` + `project_thumbs` in
  Files.app first — uninstalling deletes them.
