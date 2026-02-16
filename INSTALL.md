# Installation Guide

## Quick Setup

### 1. If using as part of dotfiles (recommended)

The git-wt tool is already set up as a submodule. Just source it in your `.bashrc`:

```bash
# Add to ~/.bashrc

# Ensure git-worktree-init is in PATH
export PATH="$HOME/.dotfiles/bin:$PATH"

# Source git-wt
if [ -f "$HOME/.dotfiles/git-wt/git-wt.sh" ]; then
    source "$HOME/.dotfiles/git-wt/git-wt.sh"
fi
```

Or use the provided configuration snippet:

```bash
# Add to ~/.bashrc
source "$HOME/.dotfiles/git-wt/git-wt.bashrc"
```

### 2. Reload your shell

```bash
source ~/.bashrc
```

### 3. Verify installation

```bash
git-wt help
```

## Standalone Installation

If you want to use git-wt without the dotfiles setup:

### 1. Clone the repository

```bash
git clone <url> ~/.git-wt
```

### 2. Add to your `.bashrc`

```bash
# Add to ~/.bashrc

# Source git-wt
if [ -f "$HOME/.git-wt/git-wt.sh" ]; then
    source "$HOME/.git-wt/git-wt.sh"
fi

# Add git-worktree-init to PATH or copy it to ~/bin
```

### 3. Install git-worktree-init

Either:
- Copy `bin/git-worktree-init` to a directory in your PATH
- Or add the bin directory to your PATH

### 4. Reload your shell

```bash
source ~/.bashrc
```

## Publishing to GitHub (for maintainers)

To make this submodule properly cloneable:

### 1. Create a GitHub repository

```bash
# On GitHub, create a new repository called 'git-wt'
```

### 2. Add remote and push

```bash
cd ~/.dotfiles/git-wt
git remote add origin git@github.com:YOUR_USERNAME/git-wt.git
git push -u origin main
```

### 3. Update submodule URL in dotfiles

```bash
cd ~/.dotfiles
git config -f .gitmodules submodule.git-wt.url git@github.com:YOUR_USERNAME/git-wt.git
git add .gitmodules
git commit -m "Update git-wt submodule URL to GitHub"
git push
```

### 4. For others to clone your dotfiles

```bash
git clone --recursive git@github.com:YOUR_USERNAME/dotfiles.git ~/.dotfiles
```

Or if already cloned:

```bash
git submodule update --init --recursive
```

## Updating git-wt

To get the latest version:

```bash
cd ~/.dotfiles/git-wt
git pull origin main
```

Or from the dotfiles directory:

```bash
cd ~/.dotfiles
git submodule update --remote git-wt
```

## Uninstallation

### 1. Remove from `.bashrc`

Remove the git-wt sourcing lines from your `.bashrc`.

### 2. Remove submodule (if using dotfiles)

```bash
cd ~/.dotfiles
git submodule deinit git-wt
git rm git-wt
rm -rf .git/modules/git-wt
git commit -m "Remove git-wt submodule"
```

### 3. Remove standalone installation

```bash
rm -rf ~/.git-wt
```
