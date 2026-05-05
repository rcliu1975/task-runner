# Task Runner

A versatile, tmux-based task execution interface that routes commands based on task names.

## Overview

`task-runner` simplifies project management by automatically selecting the appropriate execution mode based on the task name you provide. It leverages `tmux` to manage persistent background task sessions.

## Task Routing Logic

When you start a task, `task-runner` automatically routes it to the correct command based on the following naming conventions:

| Task Name Pattern | Command Executed |
| :--- | :--- |
| `danger`, `danger-*`, `codex-danger`, `codex-danger-*` | `codex --sandbox danger-full-access --ask-for-approval never` |
| `codex`, `codex-*` | `codex --full-auto` |
| `gemini-yolo`, `gemini-yolo-*` | `gemini --yolo` |
| Other | Default (User defined via `CODEX_CMD`) |

## Installation

To install `codex-task` to your system path:

```bash
sudo ./scripts/install.sh /usr/local/bin
```

## Usage

### Prerequisites
- `tmux` installed on your system.

### Starting a Task
```bash
codex-task <task-name>
```

### Listing Active Tasks
```bash
codex-task --list
```

## Environment Variables

- `CODEX_WORKDIR`: Working directory for the tmux session (default: `$HOME/WorkSpace`).
- `CODEX_SOCKET_DIR`: Directory that stores per-task tmux sockets (default: `/tmp/codex-tmux`).
- `CODEX_SESSION_PREFIX`: Prefix for tmux session names (default: `codex`).
- `CODEX_CMD`: Fallback command started inside tmux when creating a generic task.

## License

MIT
