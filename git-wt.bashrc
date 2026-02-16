# git-wt configuration for .bashrc
# Add this to your .bashrc to enable git-wt

# Ensure git-worktree-init is in PATH
if [ -d "$HOME/.dotfiles/bin" ]; then
    export PATH="$HOME/.dotfiles/bin:$PATH"
fi

# Source git-wt
if [ -f "$HOME/.dotfiles/git-wt/git-wt.sh" ]; then
    source "$HOME/.dotfiles/git-wt/git-wt.sh"
fi
