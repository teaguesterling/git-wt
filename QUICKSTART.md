# git-wt Quick Start

A cheat sheet for the most common git-wt workflows.

## First Time Setup

```bash
# Add to your ~/.bashrc
source "$HOME/.dotfiles/git-wt/git-wt.bashrc"

# Reload shell
source ~/.bashrc

# Initialize a repo
cd ~/projects/my-repo
git-wt init
```

## Daily Workflow

### Start new feature
```bash
# From main worktree
gwts -s main -c feature/user-login
# Now in trees/feature/user-login

# Make changes...
git add .
git commit -m "Add login feature"
```

### Switch between features
```bash
gwtr feature/user-login    # Go to user-login worktree
gwtr dashboard             # Go to dashboard worktree (partial match)
gwtb                       # Back to main
```

### Finish feature
```bash
# From feature worktree or main
gwt finish --pr            # Auto-push, create PR, smart cleanup
gwt finish                 # Auto-push, smart cleanup (no PR)
gwt finish --keep-branch   # Remove worktree but keep branch
```

### Quick status check
```bash
gwtl        # List all worktrees
gwt st      # Show current worktree info
```

### Cancel abandoned work
```bash
gwt cancel                    # Remove worktree, keep branch
gwt cancel --delete-branch    # Remove worktree and branch (with warnings)
```

## Command Cheatsheet

| Command | Alias | What it does |
|---------|-------|--------------|
| `git-wt init` | `gwt i` | Set up repo for worktrees |
| `git-wt start` | `gwts` | Create new feature worktree |
| `git-wt resume` | `gwtr` | Switch to worktree |
| `git-wt back` | `gwtb` | Return to main |
| `git-wt finish` | `gwtf` | Smart cleanup & remove |
| `git-wt cancel` | `gwtx` | Remove worktree only |
| `git-wt list` | `gwtl` | Show all worktrees |
| `git-wt status` | `gwt st` | Current worktree info |
| `git-wt sync` | - | Update main from remote |
| `git-wt prune` | `gwt p` | Clean deleted worktrees |

## Flags Reference

### start flags
- `-s, --source BRANCH` - Source branch (default: current)
- `-c, --cd` - Auto cd to new worktree

### finish flags
- `--pr` - Create PR before finishing
- `--keep-branch` - Don't delete branch
- `-P, --no-push` - Skip push to remote
- `--rm` - Force delete branch

### cancel flags
- `--delete-branch` - Also delete branch (with warnings)

## Examples

### Hotfix workflow
```bash
gwtb                           # Go to main
gwts -s main -c hotfix/bug-42  # Create hotfix from main
# fix bug...
gwt finish --pr                # Push, PR, cleanup
```

### Multiple features in parallel
```bash
# Start feature 1
gwts feature/auth
cd ../trees/feature/auth
# work...

# Start feature 2 (go to main first)
gwtb
gwts feature/dashboard
# work...

# Switch between them
gwtr auth
gwtr dashboard
```

### Experiment that didn't work out
```bash
gwts experiment/new-idea
# Try something...
# Nope, didn't work
gwt cancel --delete-branch     # Remove everything
```

### Long-lived feature branch
```bash
gwts -s develop feature/big-refactor
# Work for days/weeks...
gwt finish --keep-branch       # Remove worktree but keep branch
# Branch stays for later work or manual cleanup
```

## Tips

1. **Use tab completion** - Type `gwt <TAB>` to see all commands
2. **Partial matches work** - `gwtr auth` finds `feature/auth`
3. **Let finish be smart** - Default behavior is usually correct
4. **Use list often** - `gwtl` shows what you have active
5. **Safe by default** - Warnings before any data loss

## Troubleshooting

### "Not in a git worktree-managed repository"
Run `git-wt init` first in your repo.

### Manually deleted a worktree directory
Run `gwt prune` to clean up git's tracking.

### Want to see what a command does
Run `git-wt help` for detailed help.

### Forgot where you are
Run `gwt st` to see current worktree and branch.
