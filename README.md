# ctask

A generic tmux-based interactive task launcher.

`ctask` directly replaces the old `codex-interactive-mode` workflow: one task name maps to one tmux socket and one tmux session. If SSH disconnects or a terminal closes, running the same task name attaches you back to the same working context.

## What It Does

- Starts or reattaches a persistent tmux session for each task name.
- Uses a configurable work directory, socket directory, and session prefix.
- Supports route rules so task names can launch different tools.
- Includes the original Codex/Gemini task modes by default.
- Keeps migration compatibility with existing `task-runner` and `codex-interactive-mode` env files.

## Installation

```bash
sudo ./scripts/install.sh /usr/local/bin
```

This installs a single command:

```bash
ctask
```

The installer also creates `~/.config/ctask/env.sh`. If the old
`~/.config/codex-interactive-mode/env.sh` exists, its workdir, socket dir, and
session prefix are migrated into the new config. Command fallback is not
migrated; unmatched task names intentionally open a plain tmux shell.

To overwrite an existing config:

```bash
sudo CTASK_OVERWRITE_CONFIG=1 ./scripts/install.sh /usr/local/bin
```

## Usage

```bash
ctask <task-name>
ctask --list
ctask --help
```

Task names must use lowercase letters and `-`, for example:

```bash
ctask review
ctask long-job
ctask danger-maintenance
```

Built-in modes:

| Task Name Pattern | Command |
| :--- | :--- |
| `codex`, `codex-*` | `codex --full-auto` |
| `danger`, `danger-*`, `codex-danger`, `codex-danger-*` | `codex --sandbox danger-full-access --ask-for-approval never` |
| `gemini`, `gemini-*` | `gemini` |
| `gemini-yolo`, `gemini-yolo-*` | `gemini --yolo` |

If no user route or built-in mode matches, `ctask` starts a plain tmux shell.

## Configuration

Create `~/.config/ctask/env.sh`:

```bash
export CTASK_WORKDIR="$HOME/WorkSpace"
export CTASK_SOCKET_DIR="/tmp/ctask-tmux"
export CTASK_SESSION_PREFIX="ctask"
```

You can point to another env file:

```bash
CTASK_CONFIG=/path/to/env.sh ctask review
```

For migration, if `~/.config/ctask/env.sh` does not exist, `ctask` will also look for:

```text
~/.config/task-runner/env.sh
~/.config/codex-interactive-mode/env.sh
```

These older variables still work:

```bash
TASK_RUNNER_WORKDIR
TASK_RUNNER_SOCKET_DIR
TASK_RUNNER_SESSION_PREFIX
CODEX_WORKDIR
CODEX_SOCKET_DIR
CODEX_SESSION_PREFIX
```

## Routes

Routes keep `ctask` generic while letting task names launch different tools. Create `~/.config/ctask/routes.conf`:

```conf
build*=npm run build
test*=npm test
deploy*=./scripts/deploy.sh
```

Each line is:

```conf
<task-name-glob>=<command>
```

The first matching user route wins. If no user route matches, built-in Codex/Gemini routes are checked. If no built-in route matches, the task opens an interactive shell.

Disable built-in routes when you want every task name to come only from your route file or a plain shell:

```bash
export CTASK_ENABLE_BUILTIN_ROUTES=0
```

## Environment Variables

| Variable | Default |
| :--- | :--- |
| `CTASK_CONFIG` | `~/.config/ctask/env.sh`, then migration configs |
| `CTASK_WORKDIR` | `$HOME/WorkSpace` |
| `CTASK_SOCKET_DIR` | `/tmp/ctask-tmux` |
| `CTASK_SESSION_PREFIX` | `ctask` |
| `CTASK_ROUTES` | `~/.config/ctask/routes.conf` |
| `CTASK_ENABLE_BUILTIN_ROUTES` | `1` |

## License

MIT
