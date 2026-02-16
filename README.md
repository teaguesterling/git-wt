# git-wt

A streamlined git worktree workflow wrapper that makes working with feature branches fast and safe.

## Features

- **Simple commands** for common worktree operations
- **Smart cleanup** - no accidental data loss
- **Shared paths** - symlink directories (databases, caches, logs) between worktrees
- **Auto-push and PR creation** integration
- **Interactive menus** when multiple options exist
- **Bash completion** for all commands
- **Works from anywhere** in your repo structure

## Installation

### 1. Set up the script

If using as a submodule in your dotfiles:

```bash
cd ~/.dotfiles
git submodule add <url> git-wt
```

Or clone directly:

```bash
git clone <url> ~/.dotfiles/git-wt
```

### 2. Add to your `.bashrc`

```bash
# Source git-wt
if [ -f ~/.dotfiles/git-wt/git-wt.sh ]; then
    source ~/.dotfiles/git-wt/git-wt.sh
fi

# Make sure git-worktree-init is in your PATH
export PATH="$HOME/.dotfiles/bin:$PATH"
```

### 3. Reload your shell

```bash
source ~/.bashrc
```

## Quick Start

```bash
# Initialize a repo for worktree workflow
cd ~/projects/my-repo
git-wt init

# This restructures your repo:
# my-repo/
# ├── main/                     # your original repo
# ├── trees/                    # worktrees go here
# └── .git-worktree-shared      # config for shared paths

# Configure shared paths (optional but recommended)
# Edit .git-worktree-shared to list paths to symlink between worktrees
# Examples: .lq, .cache, logs, *.duckdb
nano .git-worktree-shared

# Start a new feature
git-wt start feature/new-thing

# Work on it...
cd ../trees/feature/new-thing

# Switch between worktrees
git-wt resume feature/new-thing
git-wt back  # return to main

# Finish (auto-push, smart branch cleanup)
git-wt finish

# Or create a PR first
git-wt finish --pr
```

## Repository Structure

After running `git-wt init`, your repository is restructured:

```
my-repo/
├── main/              # Main worktree (your original repo)
└── trees/             # Feature worktrees
    ├── feature-1/
    ├── feature-2/
    └── bugfix/
```

This structure:
- Keeps your main branch clean
- Allows multiple features in parallel
- Makes it easy to switch contexts
- Prevents merge conflicts from switching branches

## Shared Paths

git-wt supports **shared paths** - directories that are symlinked from main to all worktrees. This is perfect for:

- **Databases** - `.lq/`, `*.duckdb`, `*.db`
- **Caches** - `.cache/`, `node_modules/.cache/`
- **Logs** - `logs/`, `.logs/`
- **Build outputs** - `dist/`, `build/`

### Configuration

Edit `.git-worktree-shared` in your repository root:

```bash
# .git-worktree-shared
.lq
.cache
logs
dist
```

When you create a worktree with `git-wt start`, these paths are automatically symlinked from main.

**See [SHARED-PATHS.md](SHARED-PATHS.md) for detailed documentation.**

## Commands

### `git-wt init [path]`

Initialize worktree structure for a repository.

```bash
git-wt init                    # Initialize current repo
git-wt init ~/projects/myapp   # Initialize specific repo
```

**Alias:** `i`

---

### `git-wt start [options] BRANCH_NAME`

Create a new feature branch worktree.

**Options:**
- `-s, --source SOURCE` - Source branch (default: current branch)
- `-c, --cd` - Automatically cd to new worktree

```bash
git-wt start feature/auth                    # From current branch
git-wt start -s main feature/auth            # From main
git-wt start -s main -c feature/auth         # From main, auto-cd
```

**Alias:** `s`, `gwts`

---

### `git-wt resume [filter]`

Switch to an existing worktree. Shows interactive menu if multiple matches.

```bash
git-wt resume                  # Show all worktrees
git-wt resume feature          # Filter by name
git-wt resume auth             # Partial match
```

**Alias:** `r`, `gwtr`

---

### `git-wt back`

Return to the main worktree.

```bash
git-wt back
```

**Alias:** `b`, `gwtb`

---

### `git-wt finish [options] [branch]`

Finish a worktree with smart cleanup.

**Default behavior:**
1. Push branch to remote
2. Remove worktree
3. Delete branch if PR is merged
4. Keep branch if PR not merged

**Options:**
- `--pr` - Create pull request before finishing
- `--keep-branch` - Don't delete branch
- `-P, --no-push` - Don't push to remote
- `--rm` - Force delete branch

```bash
git-wt finish                          # Smart cleanup
git-wt finish --pr                     # Create PR first
git-wt finish --keep-branch            # Remove worktree, keep branch
git-wt finish feature/old-thing        # Finish specific worktree
git-wt finish --rm                     # Force delete branch
```

**Alias:** `f`

**Safety features:**
- Checks for uncommitted changes
- Warns before force operations
- Only deletes branches that are merged or explicitly requested

---

### `git-wt cancel [options] [branch]`

Remove a worktree without the smart cleanup of finish.

**Options:**
- `--delete-branch` - Also delete the branch (with confirmation)

```bash
git-wt cancel                          # Remove current worktree
git-wt cancel feature/abandoned        # Remove specific worktree
git-wt cancel --delete-branch          # Remove worktree and branch
```

**Alias:** `c`

**Safety features:**
- Warns about uncommitted changes
- Confirms before deleting unmerged branches
- Keeps branch by default

---

### `git-wt list`

Show all worktrees with their branches and paths.

```bash
git-wt list
```

**Alias:** `l`, `gwtl`

**Output example:**
```
Git worktrees:

  main                 /home/user/projects/myapp/main [main]
  feature/auth         /home/user/projects/myapp/trees/feature/auth
  bugfix/login         /home/user/projects/myapp/trees/bugfix/login
```

---

### `git-wt status`

Show current worktree information.

```bash
git-wt status
```

**Alias:** `st`, `gwtst`

**Output example:**
```
Git worktree status:

  Current: feature/auth worktree
  Branch:  feature/auth
  Path:    /home/user/projects/myapp/trees/feature/auth

  Total worktrees: 3 (1 main + 2 feature)
```

---

### `git-wt prune`

Clean up deleted worktrees from git's internal tracking.

```bash
git-wt prune
```

**Alias:** `p`

Use this if you manually deleted a worktree directory.

---

### `git-wt sync`

Fetch and pull updates in the main worktree.

```bash
git-wt sync
```

Updates the main branch with latest changes from remote.

---

### `git-wt help`

Show help message with all commands.

```bash
git-wt help
```

**Alias:** `h`

## Aliases

Convenient shortcuts:

- `gwt` - `git-wt`
- `gwts` - `git-wt start`
- `gwtr` - `git-wt resume`
- `gwtb` - `git-wt back`
- `gwtl` - `git-wt list`
- `gwtst` - `git-wt status`

## Workflows

### Basic Feature Development

```bash
# Start new feature
git-wt start -s main -c feature/user-auth

# Work on feature...
# (you're already in the worktree)

# Commit your changes
git add .
git commit -m "Add user authentication"

# Finish and create PR
git-wt finish --pr

# After PR is merged, the branch is automatically cleaned up
```

### Multiple Features in Parallel

```bash
# Start feature 1
git-wt start -s main feature/auth
cd ../trees/feature/auth
# work...

# Start feature 2 (from main directory)
git-wt back
git-wt start -s main feature/dashboard
cd ../trees/feature/dashboard
# work...

# Switch between them
git-wt resume auth        # Back to auth
git-wt resume dashboard   # To dashboard
git-wt back               # To main
```

### Quick Bug Fix

```bash
# From main
git-wt start -s main -c bugfix/login-error

# Fix and commit
git add .
git commit -m "Fix login error"

# Quick finish without PR (if hotfix)
git-wt finish

# Or with PR
git-wt finish --pr
```

### Abandoned Work

```bash
# You started something but don't want to keep it
git-wt resume old-experiment

# Just remove everything
git-wt cancel --delete-branch
```

### Working on Long-Lived Branch

```bash
# Start work
git-wt start -s develop feature/big-refactor

# Work over several days...

# Finish but keep branch (not ready to delete)
git-wt finish --keep-branch

# Later, manually delete when ready
git branch -d feature/big-refactor
```

## Configuration

Environment variables (optional):

```bash
# Directory names (defaults shown)
export GIT_WT_MAIN_DIR="main"
export GIT_WT_TREES_DIR="trees"

# Marker file name
export GIT_WT_MARKER=".git-worktree"

# Colors (defaults shown)
export GIT_WT_COLOR_BRANCH="\033[32m"     # Green
export GIT_WT_COLOR_PATH="\033[36m"       # Cyan
export GIT_WT_COLOR_WARNING="\033[33m"    # Yellow
export GIT_WT_COLOR_ERROR="\033[31m"      # Red
```

## Bash Completion

Completion is automatically enabled when you source the script.

```bash
git-wt <TAB>              # Show all commands
git-wt start <TAB>        # Show options (-s, -c, --source, --cd)
git-wt resume <TAB>       # Show available worktrees
git-wt finish <TAB>       # Show worktree branches and options
```

## Tips

1. **Always use `git-wt back`** to return to main - it works from anywhere
2. **Use `git-wt list`** to see what's active before starting new work
3. **Use `git-wt status`** if you forget where you are
4. **Use filters with resume** - `git-wt resume auth` is faster than the menu
5. **Let finish be smart** - the default behavior is usually what you want
6. **Use cancel for experiments** - removes worktree but keeps branch by default

## Comparison with Plain Git Worktree

| Task | Plain Git | git-wt |
|------|-----------|--------|
| Create worktree | `git worktree add ../feature feature` | `gwts -c feature` |
| Switch worktree | `cd ../feature` | `gwtr feature` |
| List worktrees | `git worktree list` | `gwtl` |
| Remove worktree | `git worktree remove ../feature && git branch -d feature` | `gwt finish` |
| Go to main | `cd ../main` | `gwtb` |

## Requirements

- Git with worktree support (Git 2.5+)
- Bash 4.0+
- Optional: `gh` CLI for PR creation

## License

MIT

## Contributing

Issues and pull requests welcome!
