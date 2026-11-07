# 给 AI Lead 开通 GitHub 权限（推送 + Actions）· Repository access guide

本文档说明**你（仓库所有者）如何把 `wiorigami/oripa-swift` 的推送和 GitHub Actions
权限交给 Lead**（运行在本机的 AI 代理），让它能 push 代码、触发 CI、下载构建产物。
按安全性从高到低给出三种方案，**推荐方案 A（SSH，不需要 token）**。

> 目标仓库：<https://github.com/wiorigami/oripa-swift>
> 本地已有完整的 git 仓库（`/Users/william/Desktop/hns/apps/oripa-swift`，含初始提交），
> 只差一个远端和一个可推送的凭据。
>
> **绝对不要把 token 写进代码、提交、README、聊天记录或 shell 历史文件（如 `.zsh_history`）。**
> 本机与 Lead 共享同一个终端环境，凭据只应放在环境变量或 git/gh 的凭据存储中。

---

## 方案 A（推荐）：SSH 密钥 —— 无需 token，只给 push 权限

GitHub 的 SSH 推送不需要 Personal Access Token；CI（Actions）由 push 自动触发，
下载 artifact 也不需要 token（见方案 B/C 的 `gh` 用法）。

### A1. 创建空仓库

1. 打开 <https://github.com/new>。
2. Repository name 填 `oripa-swift`；Owner 选 `wiorigami`。
3. **不要**勾选 README / .gitignore / license —— 保持完全空仓库（否则首次推送会有冲突）。
4. 点 **Create repository**。

### A2. 配置 SSH 密钥（如果本机已有可用的 GitHub SSH key 可跳过）

```bash
# 1) 检查是否已有密钥
ls ~/.ssh/id_ed25519.pub ~/.ssh/id_rsa.pub 2>/dev/null

# 2) 如果没有，生成一个（一路回车，passphrase 可留空）
ssh-keygen -t ed25519 -C "oripa@$(hostname)" -f ~/.ssh/id_ed25519

# 3) 把公钥内容复制出来
cat ~/.ssh/id_ed25519.pub
```

1. 打开 GitHub → 右上角头像 → **Settings** → **SSH and GPG keys** → **New SSH key**。
2. Title 随便填（如 `MacBook ORIPA`），Key type 选 `Authentication Key`，粘贴公钥。
3. 验证：

```bash
ssh -T git@github.com
# 首次会问 Are you sure you want to continue connecting? -> yes
# 成功输出：Hi wiorigami! You've successfully authenticated...
```

### A3. 添加远端并推送（Lead 执行）

```bash
cd /Users/william/Desktop/hns/apps/oripa-swift
git remote add origin git@github.com:wiorigami/oripa-swift.git   # 已存在则 git remote set-url
git branch -M main
git push -u origin main
```

之后每次 `git push` 都会自动触发 CI（`.github/workflows/ci.yml`）。
SSH 权限等价于“仓库 Contents 读写”，但**没有** API/Actions 管理权限；若只是让 Lead
push 并等 CI 自动跑，这已足够。

---

## 方案 B：GitHub CLI 登录（`gh auth login`，浏览器授权）

适合希望 Lead 还能用 `gh run list` / `gh run watch` / `gh run download` 查看和下载
Actions 产物的情况。**不给 token 文件，走浏览器设备码登录。**

```bash
brew install gh          # 如未安装
gh auth login
# ? What account do you want to log into?            GitHub.com
# ? What is your preferred protocol for Git operations? SSH   (或 HTTPS)
# ? Authenticate Git with your GitHub credentials?     Yes
# ? How would you like to authenticate?               Login with a web browser
#   复制一次性代码，在浏览器打开 https://github.com/login/device 并粘贴，授权
```

登录完成后：

```bash
gh auth status           # 确认已登录、scope 正确
cd /Users/william/Desktop/hns/apps/oripa-swift
git remote add origin git@github.com:wiorigami/oripa-swift.git 2>/dev/null || true
git push -u origin main
gh run list              # 查看 CI 运行
gh run watch             # 实时跟踪当前运行
```

**关于 workflow 权限**：如果推送包含 `.github/workflows/**` 的修改时被拒绝
（`refusing to allow a Personal Access Token to create or update workflow`），
说明当前凭据缺少 `workflow` scope，执行：

```bash
gh auth refresh -s workflow
```

> `gh auth login` 的默认授权通常已包含 `repo`、`read:org`、`gist`，部分版本还包含
> `workflow`；上面命令用于补权。登录凭据由 `gh` 保存在系统钥匙串（macOS Keychain），
> 不落盘到仓库。

---

## 方案 C：细粒度 Personal Access Token（Fine-grained PAT）

当无法使用 SSH / 交互式登录（例如只给 Lead 一个受限 token）时使用。这是**权限最小化**
的方案：只授权这一个仓库、只给需要的权限。

### C1. 创建 token

1. GitHub → 头像 → **Settings** → **Developer settings** → **Personal access tokens**
   → **Fine-grained tokens** → **Generate new token**。
2. 填写：
   * **Token name**：`oripa-swift-lead`（任意）
   * **Expiration**：7 天或 30 天（**不要选 No expiration**）
   * **Resource owner**：`wiorigami`
   * **Repository access**：`Only select repositories` → 选择 `oripa-swift`
3. **Permissions**（Repository permissions）：

   | Permission | 级别 | 用途 |
   |---|---|---|
   | **Contents** | Read and write | 推送代码（必需） |
   | **Workflows** | Read and write | 推送/修改 `.github/workflows/**`（必需） |
   | **Actions** | Read（如需 Lead 触发 workflow 则 Write） | 查看运行、下载 artifact、`gh workflow run` |
   | **Metadata** | Read（强制，自动勾选） | 基础读取 |

   其余权限一律保持 **No access**。
4. 点 **Generate token**，复制 `github_pat_...`（只显示一次）。

> 等价的老式 Classic PAT：勾选 `repo` + `workflow` 两个 scope 即可，但权限范围是
> 该账号的**所有**仓库，不如细粒度安全，建议优先用 fine-grained。

### C2. 把 token 交给 Lead 使用（三选一）

**方式 1：环境变量（推荐，仅当前会话有效）**

```bash
# 在启动 Lead / 当前终端会话中设置；不要写进 .zshrc 等持久文件
export GH_TOKEN=github_pat_xxxxxxxxxxxxxxxxxxxx
export GITHUB_TOKEN=$GH_TOKEN        # 部分工具读取这个变量名

# Lead 的推送可以直接用 HTTPS URL + token（或先 gh auth login --with-token）
cd /Users/william/Desktop/hns/apps/oripa-swift
git remote add origin https://github.com/wiorigami/oripa-swift.git 2>/dev/null || true
git push -u origin main
```

若用 `gh`：

```bash
echo "$GH_TOKEN" | gh auth login --with-token
gh auth status
```

**方式 2：一次性粘贴给 Lead**：在对话中把 token 发给 Lead，并明确“只用于本次推送，
用后请从环境移除”。注意聊天记录可能留存，务必设置短过期时间并在完成后立即撤销。
（**不推荐**，仅临时使用。）

**方式 3：系统钥匙串 / git credential helper**（适合长期在本机开发）：

```bash
git config --global credential.helper osxkeychain
git push -u origin main    # 首次输入用户名 + token 作为密码，之后钥匙串记住
```

### C3. 完成后

* 验证：`gh auth status` / `git push --dry-run` 成功即可。
* 用完即撤销：Settings → Developer settings → Fine-grained tokens → 该 token →
  **Delete**；或把 Expiration 设为最短。
* 如果 token 曾经出现在聊天/日志/文件中，**立即撤销并重新生成**。

---

## 三种方案对比

| | A. SSH（推荐） | B. gh auth login | C. Fine-grained PAT |
|---|---|---|---|
| 需要 token | 否 | 否（走浏览器） | 是 |
| push 代码 | ✅ | ✅ | ✅ |
| 修改 workflows | ✅ | ✅（可能需 `-s workflow`） | ✅（需 Workflows 权限） |
| 触发/查看/下载 Actions | ❌（只用网页） | ✅ | ✅（需 Actions 权限） |
| 权限范围 | 账号级 SSH（可推送该账号所有仓库） | 账号级 | 仅单个仓库、按权限 |
| 推荐场景 | 只要求 Lead 推送、CI 自动跑 | 希望 Lead 全流程操作 CI | 需要最小权限/临时授权 |

---

## 给 Lead 的最小操作清单

1. 用户创建**空**仓库 `wiorigami/oripa-swift`（方案 A1）。
2. 用户配置 SSH key 或 `gh auth login` 或提供细粒度 PAT。
3. Lead 执行：
   ```bash
   cd /Users/william/Desktop/hns/apps/oripa-swift
   git remote add origin git@github.com:wiorigami/oripa-swift.git
   git push -u origin main
   ```
4. 验证：GitHub 仓库页面出现代码，**Actions** 标签页出现一次 `CI` 运行（`test` / `ios` /
   `macos` 三个 job 并行）。构建产物下载方法见 [`PUBLISH.md`](PUBLISH.md)。
