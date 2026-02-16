# Example Usage: Setting Up Shared Paths

## Scenario: Development Database Shared Across Worktrees

You have a project with a local DuckDB database in `.lq/` that you want to share across all worktrees.

### Step 1: Initialize the Repository

```bash
cd ~/Projects/my-app
git-wt init
```

Output:
```
Restructuring: /home/user/Projects/my-app
  my-app/ → my-app/main/ + my-app/trees/

Done! Structure is now:
  my-app/
  ├── main/    # your repo
  ├── trees/   # worktrees go here
  └── .git-worktree-shared   # shared paths config

Edit .git-worktree-shared to configure paths shared between worktrees

Create worktrees with:
  git-wt start <branch-name>
```

### Step 2: Configure Shared Paths

Edit the `.git-worktree-shared` file:

```bash
cd ~/Projects/my-app
nano .git-worktree-shared
```

Add your shared paths:

```
# .git-worktree-shared

# Database and data directories
.lq

# Cache directories
.cache
node_modules/.cache

# Logs
logs

# Build outputs
dist
```

### Step 3: Create Your First Worktree

```bash
# Go to main worktree
cd ~/Projects/my-app/main

# Create a feature branch
git-wt start -s main -c feature/user-auth
```

Output:
```
Creating worktree for branch feature/user-auth from main
Preparing worktree (new branch 'feature/user-auth')
HEAD is now at abc1234 Initial commit
Worktree created at: /home/user/Projects/my-app/trees/feature/user-auth

Creating symlinks for shared paths...
  Linked: .lq
  Linked: .cache
  Linked: logs
  Linked: dist

Changed directory to worktree
```

### Step 4: Verify Symlinks

```bash
# You're now in trees/feature/user-auth
ls -la .lq
```

Output:
```
lrwxrwxrwx 1 user user 17 Feb 15 10:30 .lq -> ../../main/.lq/
```

The `.lq` directory is now a symlink to the main worktree's `.lq` directory!

### Step 5: Use the Shared Database

```bash
# Run your application
npm run dev

# The app uses .lq/blq.duckdb
# Any changes to the database are visible in all worktrees
```

### Step 6: Create Another Worktree

```bash
# Go back to main
git-wt back

# Create another feature
git-wt start -s main -c feature/dashboard
```

Now you have two worktrees, both sharing the same database:

```
my-app/
├── main/
│   └── .lq/              # Original database
├── trees/
│   ├── feature/user-auth/
│   │   └── .lq -> ../../main/.lq/    # Symlink
│   └── feature/dashboard/
│       └── .lq -> ../../main/.lq/    # Symlink
└── .git-worktree-shared
```

### Step 7: Switch Between Features

```bash
# Work on auth
git-wt resume auth
# Make changes, database state is shared

# Switch to dashboard
git-wt resume dashboard
# See the same database state

# Back to main
git-wt back
```

## Real-World Workflow Example

### Working on Multiple Features with Shared State

```bash
# Initialize project
cd ~/Projects/data-app
git-wt init

# Configure shared paths for data science project
cat > .git-worktree-shared << 'EOF'
# Data files
.lq
data/*.duckdb
data/*.parquet

# Cache
.cache
__pycache__

# Logs
logs

# Jupyter checkpoints (usually in .ipynb_checkpoints but let's track in one place)
.checkpoints
EOF

# Create main branch worktree
cd main

# Feature 1: New data processing pipeline
git-wt start -s main -c feature/etl-pipeline
# Work in trees/feature/etl-pipeline
# Database in .lq is shared
# Can test queries against same data as other features

# Feature 2: Dashboard updates
git-wt back
git-wt start -s main -c feature/dashboard-ui
# Work in trees/feature/dashboard-ui
# Same database, can see data from both features

# Switch back and forth
git-wt resume etl        # Work on ETL
git-wt resume dashboard  # Work on UI
git-wt back              # Review in main

# Finish features
git-wt resume etl
git-wt finish --pr       # Create PR for ETL

git-wt resume dashboard
git-wt finish --pr       # Create PR for dashboard
```

## Testing Shared Paths Configuration

Before committing to a shared paths setup, test it:

```bash
# Create a test worktree
git-wt start test-shared-config

# Check symlinks
ls -la .lq
ls -la .cache
ls -la logs

# Verify they point to ../../main/...
# If not, check your .git-worktree-shared config

# Create a file in shared directory
echo "test" > .lq/test.txt

# Go to main and verify file exists
git-wt back
cat .lq/test.txt  # Should show "test"

# Clean up test worktree
git-wt cancel --delete-branch test-shared-config
```

## Common Patterns

### Node.js Project

```
# .git-worktree-shared
node_modules/.cache
.next
dist
logs
```

### Python Data Science

```
# .git-worktree-shared
.lq
data/*.db
__pycache__
.pytest_cache
.cache
logs
```

### Web Application

```
# .git-worktree-shared
.cache
public/uploads
storage/logs
node_modules/.cache
```

## Troubleshooting

### Symlink Not Working

```bash
# Check if path exists in main
cd main
ls -la .lq  # Should exist

# Check config file
cat ../.git-worktree-shared  # Should list .lq

# Manually create symlink if needed
cd ../trees/feature-branch
rm -rf .lq
ln -s ../../main/.lq .lq
```

### Update Existing Worktrees

If you add new paths to `.git-worktree-shared`, existing worktrees won't automatically get them:

```bash
# For each existing worktree
cd trees/feature-name
rm -rf .lq
ln -s ../../main/.lq .lq

# Or recreate the worktree
git-wt finish --keep-branch feature-name
git-wt start -s feature-name feature-name
```

## Best Practices

1. **Add shared paths early** - Configure before creating many worktrees
2. **Test with one worktree first** - Verify symlinks work before scaling
3. **Document in README** - Tell team members about shared paths
4. **Commit .git-worktree-shared** - Check it into version control (though git-wt creates it locally)
5. **Be cautious with source files** - Only share generated/data files, not code
