# Shared Paths Between Worktrees

## Overview

When working with multiple worktrees, you often have directories that should be shared across all worktrees rather than duplicated. This feature allows you to configure paths that will be symlinked from the main worktree to all feature worktrees.

## Common Use Cases

### Database Files
```
.lq/
*.duckdb
*.db
*.sqlite
```

Development databases should typically be shared so all worktrees see the same data.

### Cache Directories
```
.cache/
node_modules/.cache/
.pytest_cache/
__pycache__/
```

Cache directories don't need to be duplicated and can be safely shared.

### Log Directories
```
logs/
.logs/
*.log
```

Logs from all worktrees can go to the same location for easier debugging.

### Build Artifacts
```
dist/
build/
.next/
```

Build outputs don't need to be per-worktree and sharing saves disk space.

### IDE/Editor Directories
```
.vscode/
.idea/
.vim/
```

IDE configurations and caches can be shared.

## Configuration

### Setup

When you run `git-wt init`, a configuration file `.git-worktree-shared` is created in the repository root. Edit this file to specify paths to share.

### Example Configuration

```bash
# .git-worktree-shared

# Database directories
.lq
data/*.duckdb

# Cache directories
.cache
node_modules/.cache

# Logs
logs

# Build outputs
dist
build
```

### Syntax

- **One path per line** - Each line should contain a single path
- **Relative paths** - Paths are relative to the repository root
- **Comments** - Lines starting with `#` are comments
- **Blank lines** - Empty lines are ignored
- **Wildcards** - Currently not supported (each exact path must be listed)

## How It Works

### When Creating Worktrees

When you run `git-wt start`, the tool:

1. Creates the worktree normally using `git worktree add`
2. Reads paths from `.git-worktree-shared`
3. For each path:
   - Checks if it exists in the main worktree
   - Removes the path from the new worktree (if it was created by git)
   - Creates a symlink from the new worktree to the main worktree

### Symlink Behavior

```
my-repo/
├── main/
│   ├── .lq/              # Original directory
│   ├── logs/             # Original directory
│   └── src/              # Regular files
└── trees/
    └── feature-branch/
        ├── .lq -> ../../main/.lq/     # Symlink
        ├── logs -> ../../main/logs/   # Symlink
        └── src/                       # Separate copy
```

### What Gets Shared

- **Directory contents** - If a directory is symlinked, all its contents are automatically shared
- **Files** - Individual files can also be symlinked
- **New files** - Any new files created in a symlinked directory in any worktree appear in all worktrees

## Examples

### Example 1: Shared Database

You have a DuckDB database for development:

**`.git-worktree-shared`:**
```
.lq
```

**Result:**
```
my-repo/
├── main/
│   └── .lq/
│       ├── blobs/
│       ├── blq.duckdb
│       └── logs/
└── trees/
    ├── feature-1/
    │   └── .lq -> ../../main/.lq/    # Symlink
    └── feature-2/
        └── .lq -> ../../main/.lq/    # Symlink
```

All worktrees share the same database state.

### Example 2: Shared Caches and Logs

**`.git-worktree-shared`:**
```
# Development caches
.cache
node_modules/.cache

# Application logs
logs

# Build outputs
dist
```

**Workflow:**
```bash
# Create first feature
git-wt start feature/auth
# .cache, node_modules/.cache, logs, dist are all symlinked

# Create second feature
git-wt start feature/dashboard
# Same directories symlinked from main

# Run build in either worktree
cd ../trees/feature/auth
npm run build
# Output goes to main/dist, visible in all worktrees
```

### Example 3: IDE Settings

**`.git-worktree-shared`:**
```
.vscode
.idea
```

All worktrees share the same IDE configuration and workspace settings.

## Best Practices

### Do Share

✅ **Database files** - Development databases, local data stores
✅ **Cache directories** - Dependency caches, build caches
✅ **Log directories** - Application logs, development logs
✅ **Build artifacts** - Compiled outputs, bundled assets
✅ **IDE configurations** - Workspace settings (if team uses same IDE)

### Don't Share

❌ **Source code** - Should be different per worktree
❌ **Git files** - .git is handled automatically by git worktree
❌ **Environment configs** - .env files might differ per feature
❌ **Dependencies** - node_modules, venv, vendor (unless cache subdirs)

### When to Use

Use shared paths when:
- Multiple features need the same development data
- You want to save disk space
- Changes in one worktree should affect all worktrees
- The path contains generated or temporary data

Don't use shared paths when:
- Each feature needs isolated state
- Path contains source code or configuration
- Concurrent access might cause conflicts

## Troubleshooting

### Symlink Not Created

**Problem:** Path isn't being symlinked

**Solutions:**
1. Check `.git-worktree-shared` exists and path is listed
2. Verify path exists in main worktree
3. Ensure path is relative to repository root
4. Check for typos or extra whitespace

### Path Already Exists

**Problem:** Warning "Failed to link: path"

**Cause:** Git worktree created the path before symlinking

**Solution:** The tool should automatically remove and symlink, but if not:
```bash
cd trees/feature-name
rm -rf .lq          # Remove the directory
ln -s ../../main/.lq .lq   # Create symlink manually
```

### Editing Config for Existing Worktrees

**Problem:** Changed `.git-worktree-shared` but existing worktrees not updated

**Solution:** Shared paths only apply when creating new worktrees. For existing:
```bash
# Manual approach
cd trees/feature-name
rm -rf logs
ln -s ../../main/logs logs

# Or recreate the worktree
git-wt finish --keep-branch feature-name
git-wt start -s feature-name -c feature-name
```

### Conflicts in Shared Directories

**Problem:** Two worktrees modifying shared files simultaneously

**Solution:**
- This is expected behavior for shared paths
- Only share paths where concurrent modification is safe
- For databases, use SQLite/DuckDB WAL mode for concurrent access
- For logs, ensure log files are named uniquely per worktree

## Advanced Usage

### Per-Project Configuration

Different projects can have different shared paths:

**Web App:**
```
.cache
node_modules/.cache
dist
.next
```

**Python Data Science:**
```
.duckdb
data/*.db
.cache
__pycache__
```

**Monorepo:**
```
node_modules
.turbo
dist
```

### Testing Configuration

To test your shared paths configuration:

```bash
# View current config
cat .git-worktree-shared

# Create test worktree
git-wt start test-shared-paths

# Verify symlinks
cd trees/test-shared-paths
ls -la .lq    # Should show: .lq -> ../../main/.lq

# Clean up
git-wt cancel --delete-branch test-shared-paths
```

### Migrating Existing Worktrees

If you have worktrees created before setting up shared paths:

```bash
#!/bin/bash
# migrate-to-shared.sh - Add shared symlinks to existing worktrees

MAIN="main"
CONFIG=".git-worktree-shared"

# Read shared paths
while IFS= read -r path; do
    # Skip comments and empty lines
    [[ "$path" =~ ^#.*$ ]] && continue
    [[ -z "$path" ]] && continue

    # For each feature worktree
    for worktree in trees/*; do
        [ ! -d "$worktree" ] && continue

        echo "Linking $path in $worktree"
        rm -rf "$worktree/$path"
        ln -s "../../$MAIN/$path" "$worktree/$path"
    done
done < "$CONFIG"
```

## See Also

- [Git Worktree Documentation](https://git-scm.com/docs/git-worktree)
- [Symbolic Links](https://en.wikipedia.org/wiki/Symbolic_link)
- [QUICKSTART.md](QUICKSTART.md) - Quick reference for git-wt commands
