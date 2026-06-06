# ctask

一個基於 tmux 的通用互動式任務啟動器。

一個任務名稱對應一個 tmux socket 與一個 tmux session。即使 SSH 斷線或終端機關閉，只要用相同的任務名稱再次執行，即可重新接回原本的工作環境。

## 功能說明

- 為每個任務名稱建立或重新接入持久的 tmux session。
- 工作目錄、socket 目錄、session 前綴均可自訂。
- 支援路由規則，讓不同的任務名稱可以啟動不同的工具。
- 預設包含原有的 Codex / Gemini 任務模式。
- 保持對既有 `task-runner` 與 `codex-interactive-mode` env 檔案的遷移相容性。

## 安裝（手動）

### 1. 複製主程式

```bash
cp scripts/ctask.sh ~/.local/bin/ctask
chmod 755 ~/.local/bin/ctask
```

### 2. 建立設定目錄及設定檔

```bash
# 建立設定目錄
mkdir -p ~/.config/ctask
# 建立設定檔
cat > ~/.config/ctask/env.sh <<EOF
export CTASK_WORKDIR="$HOME/WorkSpace"
export CTASK_SOCKET_DIR="/tmp/ctask-tmux"
export CTASK_SESSION_PREFIX="ctask"
EOF
```

### 3. 確認 PATH

確保 `~/.local/bin` 已加入 `PATH`：

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## 使用方式

```bash
ctask <task-name>
ctask --list
ctask --help
```

任務名稱只能使用小寫英文字母與 `-`，例如：

```bash
ctask review
ctask long-job
ctask danger-maintenance
```

內建模式：

| 任務名稱規則 | 執行指令 |
| :--- | :--- |
| `codex`、`codex-*` | `codex --full-auto` |
| `danger`、`danger-*`、`codex-danger`、`codex-danger-*` | `codex --sandbox danger-full-access --ask-for-approval never` |
| `gemini`、`gemini-*` | `gemini` |
| `gemini-yolo`、`gemini-yolo-*` | `gemini --yolo` |

若沒有符合的使用者路由或內建模式，`ctask` 會開啟一個普通的 tmux shell。

## 設定

建立 `~/.config/ctask/env.sh`：

```bash
export CTASK_WORKDIR="$HOME/WorkSpace"
export CTASK_SOCKET_DIR="/tmp/ctask-tmux"
export CTASK_SESSION_PREFIX="ctask"
```

## 環境變數

| 變數 | 預設值 |
| :--- | :--- |
| `CTASK_CONFIG` | `~/.config/ctask/env.sh`，接著尋找遷移設定檔 |
| `CTASK_WORKDIR` | `$HOME/WorkSpace` |
| `CTASK_SOCKET_DIR` | `/tmp/ctask-tmux` |
| `CTASK_SESSION_PREFIX` | `ctask` |
| `CTASK_ROUTES` | `~/.config/ctask/routes.conf` |
| `CTASK_ENABLE_BUILTIN_ROUTES` | `1` |

## 授權

MIT
