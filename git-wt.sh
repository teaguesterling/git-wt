#!/bin/bash
# git-wt.sh - Git worktree workflow wrapper
# Source this file in your .bashrc

# Configuration
: ${GIT_WT_MAIN_DIR:="main"}
: ${GIT_WT_TREES_DIR:="trees"}
: ${GIT_WT_MARKER:=".git-worktree"}

# Color definitions
: ${GIT_WT_COLOR_BRANCH:="\033[32m"}      # Green for branches
: ${GIT_WT_COLOR_PATH:="\033[36m"}        # Cyan for paths
: ${GIT_WT_COLOR_WARNING:="\033[33m"}     # Yellow for warnings
: ${GIT_WT_COLOR_ERROR:="\033[31m"}       # Red for errors
: ${GIT_WT_COLOR_RESET:="\033[0m"}
: ${GIT_WT_COLOR_DIM:="\033[90m"}         # Dim for secondary info

# Helper: Find the worktree root (parent directory containing main/ and trees/)
_git_wt_find_root() {
    local current_dir="$PWD"

    # Check if we're in a worktree-structured repo
    while [ "$current_dir" != "/" ]; do
        if [ -f "$current_dir/$GIT_WT_MARKER" ]; then
            echo "$current_dir"
            return 0
        fi

        # Check if current dir has main/ and trees/
        if [ -d "$current_dir/$GIT_WT_MAIN_DIR" ] && [ -d "$current_dir/$GIT_WT_TREES_DIR" ]; then
            echo "$current_dir"
            return 0
        fi

        # Check if we're inside main/ or trees/
        local parent=$(dirname "$current_dir")
        if [ -d "$parent/$GIT_WT_MAIN_DIR" ] && [ -d "$parent/$GIT_WT_TREES_DIR" ]; then
            echo "$parent"
            return 0
        fi

        current_dir="$parent"
    done

    return 1
}

# Helper: Get main repo path
_git_wt_main_path() {
    local root=$(_git_wt_find_root)
    if [ -n "$root" ]; then
        echo "$root/$GIT_WT_MAIN_DIR"
    fi
}

# Helper: Get trees directory path
_git_wt_trees_path() {
    local root=$(_git_wt_find_root)
    if [ -n "$root" ]; then
        echo "$root/$GIT_WT_TREES_DIR"
    fi
}

# Helper: Get current branch name
_git_wt_current_branch() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null
}

# Helper: Check if in a worktree-managed repo
_git_wt_check_repo() {
    if ! _git_wt_find_root >/dev/null; then
        echo -e "${GIT_WT_COLOR_ERROR}Error: Not in a git worktree-managed repository${GIT_WT_COLOR_RESET}" >&2
        echo "Run 'git-wt init' to set up worktree structure" >&2
        return 1
    fi
    return 0
}

# Main git-wt function
git-wt() {
    local cmd=$1
    shift

    case "$cmd" in
        init|i)
            _git_wt_init "$@"
            ;;
        start|s)
            _git_wt_start "$@"
            ;;
        resume|r)
            _git_wt_resume "$@"
            ;;
        back|b)
            _git_wt_back "$@"
            ;;
        finish|f)
            _git_wt_finish "$@"
            ;;
        cancel|c)
            _git_wt_cancel "$@"
            ;;
        list|l)
            _git_wt_list "$@"
            ;;
        status|st)
            _git_wt_status "$@"
            ;;
        prune|p)
            _git_wt_prune "$@"
            ;;
        sync)
            _git_wt_sync "$@"
            ;;
        help|h|--help|-h)
            _git_wt_help
            ;;
        *)
            if [ -z "$cmd" ]; then
                _git_wt_help
            else
                echo -e "${GIT_WT_COLOR_ERROR}Error: Unknown command '$cmd'${GIT_WT_COLOR_RESET}" >&2
                echo "Run 'git-wt help' for usage information" >&2
                return 1
            fi
            ;;
    esac
}

# Initialize worktree structure
_git_wt_init() {
    local project_path="${1:-.}"

    # Use the existing git-worktree-init script if available
    if command -v git-worktree-init &>/dev/null; then
        git-worktree-init "$project_path"
        local ret=$?

        # Add marker file if successful
        if [ $ret -eq 0 ]; then
            local parent_dir=$(dirname "$(cd "$project_path" && pwd)")
            local project_name=$(basename "$(cd "$project_path" && pwd)")
            touch "$parent_dir/$project_name/$GIT_WT_MARKER"
            echo "Created worktree marker file"
        fi

        return $ret
    else
        echo -e "${GIT_WT_COLOR_ERROR}Error: git-worktree-init not found${GIT_WT_COLOR_RESET}" >&2
        echo "Please ensure git-worktree-init is in your PATH" >&2
        return 1
    fi
}

# Start a new feature branch worktree
_git_wt_start() {
    local branch_name=""
    local source_branch=""
    local auto_cd=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--source)
                source_branch="$2"
                shift 2
                ;;
            -c|--cd)
                auto_cd=true
                shift
                ;;
            -*)
                echo -e "${GIT_WT_COLOR_ERROR}Error: Unknown option '$1'${GIT_WT_COLOR_RESET}" >&2
                return 1
                ;;
            *)
                if [ -z "$branch_name" ]; then
                    branch_name="$1"
                else
                    echo -e "${GIT_WT_COLOR_ERROR}Error: Too many arguments${GIT_WT_COLOR_RESET}" >&2
                    return 1
                fi
                shift
                ;;
        esac
    done

    # Validate branch name
    if [ -z "$branch_name" ]; then
        echo -e "${GIT_WT_COLOR_ERROR}Error: Branch name required${GIT_WT_COLOR_RESET}" >&2
        echo "Usage: git-wt start [-s|--source SOURCE_BRANCH] [-c|--cd] BRANCH_NAME" >&2
        return 1
    fi

    _git_wt_check_repo || return 1

    local main_path=$(_git_wt_main_path)
    local trees_path=$(_git_wt_trees_path)

    # Determine source branch
    if [ -z "$source_branch" ]; then
        source_branch=$(_git_wt_current_branch)
        if [ -z "$source_branch" ]; then
            source_branch="main"
        fi
    fi

    # Check if branch already exists
    if git -C "$main_path" show-ref --verify --quiet "refs/heads/$branch_name"; then
        echo -e "${GIT_WT_COLOR_WARNING}Warning: Branch '$branch_name' already exists${GIT_WT_COLOR_RESET}" >&2
        echo -e "Use ${GIT_WT_COLOR_BRANCH}git-wt resume $branch_name${GIT_WT_COLOR_RESET} to switch to it" >&2
        return 1
    fi

    # Create worktree
    local worktree_path="$trees_path/$branch_name"
    echo -e "Creating worktree for branch ${GIT_WT_COLOR_BRANCH}$branch_name${GIT_WT_COLOR_RESET} from ${GIT_WT_COLOR_BRANCH}$source_branch${GIT_WT_COLOR_RESET}"

    if ! git -C "$main_path" worktree add -b "$branch_name" "$worktree_path" "$source_branch"; then
        echo -e "${GIT_WT_COLOR_ERROR}Error: Failed to create worktree${GIT_WT_COLOR_RESET}" >&2
        return 1
    fi

    echo -e "${GIT_WT_COLOR_PATH}Worktree created at: $worktree_path${GIT_WT_COLOR_RESET}"

    if [ "$auto_cd" = true ]; then
        cd "$worktree_path"
        echo -e "${GIT_WT_COLOR_DIM}Changed directory to worktree${GIT_WT_COLOR_RESET}"
    else
        echo -e "${GIT_WT_COLOR_DIM}To switch to this worktree, run: ${GIT_WT_COLOR_RESET}cd $worktree_path"
        echo -e "${GIT_WT_COLOR_DIM}Or use: ${GIT_WT_COLOR_RESET}git-wt resume $branch_name"
    fi
}

# Resume (cd to) an existing worktree
_git_wt_resume() {
    _git_wt_check_repo || return 1

    local main_path=$(_git_wt_main_path)
    local trees_path=$(_git_wt_trees_path)
    local filter="$1"

    # Get list of worktrees (excluding main)
    local worktrees=()
    local worktree_paths=()

    while IFS='|' read -r path branch; do
        # Skip main worktree
        if [ "$path" = "$main_path" ]; then
            continue
        fi

        # Apply filter if provided
        if [ -n "$filter" ]; then
            if [[ "$branch" == *"$filter"* ]] || [[ "$path" == *"$filter"* ]]; then
                worktrees+=("$branch")
                worktree_paths+=("$path")
            fi
        else
            worktrees+=("$branch")
            worktree_paths+=("$path")
        fi
    done < <(git -C "$main_path" worktree list --porcelain | awk '/^worktree/ {path=$2} /^branch/ {branch=$2; sub("refs/heads/", "", branch); print path "|" branch}')

    if [ ${#worktrees[@]} -eq 0 ]; then
        if [ -n "$filter" ]; then
            echo -e "${GIT_WT_COLOR_WARNING}No worktrees matching '$filter' found${GIT_WT_COLOR_RESET}" >&2
        else
            echo -e "${GIT_WT_COLOR_WARNING}No worktrees found${GIT_WT_COLOR_RESET}" >&2
            echo "Use 'git-wt start BRANCH_NAME' to create one" >&2
        fi
        return 1
    elif [ ${#worktrees[@]} -eq 1 ]; then
        cd "${worktree_paths[0]}"
        echo -e "Switched to worktree: ${GIT_WT_COLOR_BRANCH}${worktrees[0]}${GIT_WT_COLOR_RESET}"
    else
        # Multiple worktrees - show menu
        echo "Multiple worktrees found:"
        local i=1
        for wt in "${worktrees[@]}"; do
            echo -e "  $i) ${GIT_WT_COLOR_BRANCH}$wt${GIT_WT_COLOR_RESET} ${GIT_WT_COLOR_DIM}(${worktree_paths[$((i-1))]})${GIT_WT_COLOR_RESET}"
            ((i++))
        done
        echo -n "Select worktree (1-${#worktrees[@]}): "
        read -r choice

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#worktrees[@]} ]; then
            cd "${worktree_paths[$((choice-1))]}"
            echo -e "Switched to worktree: ${GIT_WT_COLOR_BRANCH}${worktrees[$((choice-1))]}${GIT_WT_COLOR_RESET}"
        else
            echo -e "${GIT_WT_COLOR_ERROR}Invalid choice${GIT_WT_COLOR_RESET}" >&2
            return 1
        fi
    fi
}

# Go back to main worktree
_git_wt_back() {
    _git_wt_check_repo || return 1

    local main_path=$(_git_wt_main_path)
    cd "$main_path"
    echo -e "Switched to main worktree: ${GIT_WT_COLOR_PATH}$main_path${GIT_WT_COLOR_RESET}"
}

# Finish a worktree (smart cleanup)
_git_wt_finish() {
    local create_pr=false
    local keep_branch=false
    local no_push=false
    local force_remove=false
    local branch_name=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --pr)
                create_pr=true
                shift
                ;;
            --keep-branch)
                keep_branch=true
                shift
                ;;
            -P|--no-push)
                no_push=true
                shift
                ;;
            --rm)
                force_remove=true
                shift
                ;;
            -*)
                echo -e "${GIT_WT_COLOR_ERROR}Error: Unknown option '$1'${GIT_WT_COLOR_RESET}" >&2
                return 1
                ;;
            *)
                if [ -z "$branch_name" ]; then
                    branch_name="$1"
                else
                    echo -e "${GIT_WT_COLOR_ERROR}Error: Too many arguments${GIT_WT_COLOR_RESET}" >&2
                    return 1
                fi
                shift
                ;;
        esac
    done

    _git_wt_check_repo || return 1

    local main_path=$(_git_wt_main_path)

    # Determine which worktree to finish
    if [ -z "$branch_name" ]; then
        # Use current branch if in a worktree
        branch_name=$(_git_wt_current_branch)
        local current_path=$(git rev-parse --show-toplevel 2>/dev/null)

        if [ "$current_path" = "$main_path" ]; then
            echo -e "${GIT_WT_COLOR_ERROR}Error: Cannot finish main worktree${GIT_WT_COLOR_RESET}" >&2
            echo "Please specify a branch name or run from a feature worktree" >&2
            return 1
        fi
    fi

    # Find the worktree
    local worktree_path=""
    while IFS='|' read -r path branch; do
        if [ "$branch" = "$branch_name" ]; then
            worktree_path="$path"
            break
        fi
    done < <(git -C "$main_path" worktree list --porcelain | awk '/^worktree/ {path=$2} /^branch/ {branch=$2; sub("refs/heads/", "", branch); print path "|" branch}')

    if [ -z "$worktree_path" ]; then
        echo -e "${GIT_WT_COLOR_ERROR}Error: Worktree for branch '$branch_name' not found${GIT_WT_COLOR_RESET}" >&2
        return 1
    fi

    # Check for uncommitted changes
    if ! git -C "$worktree_path" diff-index --quiet HEAD -- 2>/dev/null; then
        echo -e "${GIT_WT_COLOR_ERROR}Error: Worktree has uncommitted changes${GIT_WT_COLOR_RESET}" >&2
        git -C "$worktree_path" status --short
        return 1
    fi

    # Push branch unless --no-push
    if [ "$no_push" = false ]; then
        echo -e "Pushing branch ${GIT_WT_COLOR_BRANCH}$branch_name${GIT_WT_COLOR_RESET}..."
        if ! git -C "$worktree_path" push -u origin "$branch_name" 2>/dev/null; then
            echo -e "${GIT_WT_COLOR_WARNING}Warning: Failed to push branch${GIT_WT_COLOR_RESET}" >&2
            echo -n "Continue anyway? (y/N): "
            read -r response
            if [[ ! "$response" =~ ^[Yy]$ ]]; then
                return 1
            fi
        fi
    fi

    # Create PR if requested
    if [ "$create_pr" = true ]; then
        if command -v gh &>/dev/null; then
            echo -e "Creating pull request for ${GIT_WT_COLOR_BRANCH}$branch_name${GIT_WT_COLOR_RESET}..."
            cd "$worktree_path"
            if ! gh pr create; then
                echo -e "${GIT_WT_COLOR_WARNING}Warning: Failed to create PR${GIT_WT_COLOR_RESET}" >&2
                echo -n "Continue with cleanup? (y/N): "
                read -r response
                if [[ ! "$response" =~ ^[Yy]$ ]]; then
                    return 1
                fi
            fi
        else
            echo -e "${GIT_WT_COLOR_WARNING}Warning: gh CLI not found, skipping PR creation${GIT_WT_COLOR_RESET}" >&2
        fi
    fi

    # Move to main before removing worktree
    cd "$main_path"

    # Remove worktree
    echo -e "Removing worktree ${GIT_WT_COLOR_PATH}$worktree_path${GIT_WT_COLOR_RESET}..."
    git -C "$main_path" worktree remove "$worktree_path"

    # Decide whether to delete branch
    local should_delete=false

    if [ "$keep_branch" = true ]; then
        should_delete=false
    elif [ "$force_remove" = true ]; then
        should_delete=true
    else
        # Check if PR is merged (if gh is available)
        if command -v gh &>/dev/null; then
            local pr_state=$(gh pr list --state merged --head "$branch_name" --json state --jq '.[0].state' 2>/dev/null)
            if [ "$pr_state" = "MERGED" ]; then
                echo -e "${GIT_WT_COLOR_DIM}PR for branch $branch_name is merged${GIT_WT_COLOR_RESET}"
                should_delete=true
            fi
        fi
    fi

    # Delete branch if appropriate
    if [ "$should_delete" = true ]; then
        echo -e "Deleting branch ${GIT_WT_COLOR_BRANCH}$branch_name${GIT_WT_COLOR_RESET}..."
        git -C "$main_path" branch -d "$branch_name"

        # Also delete remote branch if pushed
        if [ "$no_push" = false ]; then
            git -C "$main_path" push origin --delete "$branch_name" 2>/dev/null || true
        fi
    else
        echo -e "${GIT_WT_COLOR_DIM}Branch ${GIT_WT_COLOR_BRANCH}$branch_name${GIT_WT_COLOR_RESET}${GIT_WT_COLOR_DIM} kept (use --rm to force delete)${GIT_WT_COLOR_RESET}"
    fi

    echo -e "${GIT_WT_COLOR_BRANCH}Finished worktree for $branch_name${GIT_WT_COLOR_RESET}"
}

# Cancel a worktree (remove worktree, optionally delete branch)
_git_wt_cancel() {
    local delete_branch=false
    local branch_name=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --delete-branch)
                delete_branch=true
                shift
                ;;
            -*)
                echo -e "${GIT_WT_COLOR_ERROR}Error: Unknown option '$1'${GIT_WT_COLOR_RESET}" >&2
                return 1
                ;;
            *)
                if [ -z "$branch_name" ]; then
                    branch_name="$1"
                else
                    echo -e "${GIT_WT_COLOR_ERROR}Error: Too many arguments${GIT_WT_COLOR_RESET}" >&2
                    return 1
                fi
                shift
                ;;
        esac
    done

    _git_wt_check_repo || return 1

    local main_path=$(_git_wt_main_path)

    # Determine which worktree to cancel
    if [ -z "$branch_name" ]; then
        branch_name=$(_git_wt_current_branch)
        local current_path=$(git rev-parse --show-toplevel 2>/dev/null)

        if [ "$current_path" = "$main_path" ]; then
            echo -e "${GIT_WT_COLOR_ERROR}Error: Cannot cancel main worktree${GIT_WT_COLOR_RESET}" >&2
            return 1
        fi
    fi

    # Find the worktree
    local worktree_path=""
    while IFS='|' read -r path branch; do
        if [ "$branch" = "$branch_name" ]; then
            worktree_path="$path"
            break
        fi
    done < <(git -C "$main_path" worktree list --porcelain | awk '/^worktree/ {path=$2} /^branch/ {branch=$2; sub("refs/heads/", "", branch); print path "|" branch}')

    if [ -z "$worktree_path" ]; then
        echo -e "${GIT_WT_COLOR_ERROR}Error: Worktree for branch '$branch_name' not found${GIT_WT_COLOR_RESET}" >&2
        return 1
    fi

    # Warn about uncommitted changes
    if ! git -C "$worktree_path" diff-index --quiet HEAD -- 2>/dev/null; then
        echo -e "${GIT_WT_COLOR_WARNING}Warning: Worktree has uncommitted changes:${GIT_WT_COLOR_RESET}" >&2
        git -C "$worktree_path" status --short
        echo -n "Continue with removal? (y/N): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi

    # Move to main before removing
    cd "$main_path"

    # Remove worktree
    echo -e "Removing worktree ${GIT_WT_COLOR_PATH}$worktree_path${GIT_WT_COLOR_RESET}..."
    git -C "$main_path" worktree remove --force "$worktree_path"

    # Handle branch deletion
    if [ "$delete_branch" = true ]; then
        # Check if branch is merged
        if git -C "$main_path" branch --merged | grep -q "^\s*$branch_name$"; then
            echo -e "Deleting merged branch ${GIT_WT_COLOR_BRANCH}$branch_name${GIT_WT_COLOR_RESET}..."
            git -C "$main_path" branch -d "$branch_name"
        else
            echo -e "${GIT_WT_COLOR_WARNING}Warning: Branch '$branch_name' is not fully merged${GIT_WT_COLOR_RESET}" >&2
            git -C "$main_path" log --oneline main.."$branch_name" | head -5
            echo -n "Force delete anyway? (y/N): "
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                git -C "$main_path" branch -D "$branch_name"
                echo -e "Force deleted branch ${GIT_WT_COLOR_BRANCH}$branch_name${GIT_WT_COLOR_RESET}"
            else
                echo -e "${GIT_WT_COLOR_DIM}Branch ${GIT_WT_COLOR_BRANCH}$branch_name${GIT_WT_COLOR_RESET}${GIT_WT_COLOR_DIM} kept${GIT_WT_COLOR_RESET}"
            fi
        fi
    else
        echo -e "${GIT_WT_COLOR_DIM}Branch ${GIT_WT_COLOR_BRANCH}$branch_name${GIT_WT_COLOR_RESET}${GIT_WT_COLOR_DIM} kept (use --delete-branch to remove)${GIT_WT_COLOR_RESET}"
    fi

    echo -e "${GIT_WT_COLOR_BRANCH}Cancelled worktree for $branch_name${GIT_WT_COLOR_RESET}"
}

# List all worktrees
_git_wt_list() {
    _git_wt_check_repo || return 1

    local main_path=$(_git_wt_main_path)

    echo "Git worktrees:"
    echo ""

    git -C "$main_path" worktree list --porcelain | awk -v main="$main_path" -v color_path="$GIT_WT_COLOR_PATH" -v color_branch="$GIT_WT_COLOR_BRANCH" -v color_dim="$GIT_WT_COLOR_DIM" -v color_reset="$GIT_WT_COLOR_RESET" '
    /^worktree/ {
        path=$2
    }
    /^branch/ {
        branch=$2
        sub("refs/heads/", "", branch)
    }
    /^$/ {
        if (path) {
            is_main = (path == main) ? " " color_dim "[main]" color_reset : ""
            printf "  %s%-20s%s %s%s%s%s\n", color_branch, branch, color_reset, color_path, path, color_reset, is_main
            path = ""
            branch = ""
        }
    }
    END {
        if (path) {
            is_main = (path == main) ? " " color_dim "[main]" color_reset : ""
            printf "  %s%-20s%s %s%s%s%s\n", color_branch, branch, color_reset, color_path, path, color_reset, is_main
        }
    }'
}

# Show current worktree status
_git_wt_status() {
    _git_wt_check_repo || return 1

    local main_path=$(_git_wt_main_path)
    local current_path=$(git rev-parse --show-toplevel 2>/dev/null)
    local current_branch=$(_git_wt_current_branch)

    echo "Git worktree status:"
    echo ""

    if [ "$current_path" = "$main_path" ]; then
        echo -e "  Current: ${GIT_WT_COLOR_BRANCH}main${GIT_WT_COLOR_RESET} worktree"
    else
        echo -e "  Current: ${GIT_WT_COLOR_BRANCH}$current_branch${GIT_WT_COLOR_RESET} worktree"
    fi

    echo -e "  Branch:  ${GIT_WT_COLOR_BRANCH}$current_branch${GIT_WT_COLOR_RESET}"
    echo -e "  Path:    ${GIT_WT_COLOR_PATH}$current_path${GIT_WT_COLOR_RESET}"
    echo ""

    # Count worktrees
    local total=$(git -C "$main_path" worktree list | wc -l)
    local feature=$((total - 1))

    echo -e "  ${GIT_WT_COLOR_DIM}Total worktrees: $total (1 main + $feature feature)${GIT_WT_COLOR_RESET}"
}

# Prune deleted worktrees
_git_wt_prune() {
    _git_wt_check_repo || return 1

    local main_path=$(_git_wt_main_path)

    echo "Pruning deleted worktrees..."
    git -C "$main_path" worktree prune -v
    echo "Done"
}

# Sync main worktree
_git_wt_sync() {
    _git_wt_check_repo || return 1

    local main_path=$(_git_wt_main_path)

    echo -e "Syncing main worktree: ${GIT_WT_COLOR_PATH}$main_path${GIT_WT_COLOR_RESET}"

    cd "$main_path"

    # Fetch updates
    echo "Fetching updates..."
    git fetch --all --prune

    # Check current branch
    local current_branch=$(_git_wt_current_branch)
    echo -e "Current branch: ${GIT_WT_COLOR_BRANCH}$current_branch${GIT_WT_COLOR_RESET}"

    # Pull if on a tracking branch
    if git rev-parse --abbrev-ref --symbolic-full-name @{u} &>/dev/null; then
        echo "Pulling updates..."
        git pull
    else
        echo -e "${GIT_WT_COLOR_DIM}No tracking branch configured${GIT_WT_COLOR_RESET}"
    fi

    echo "Sync complete"
}

# Show help
_git_wt_help() {
    cat << 'EOF'
git-wt - Git worktree workflow wrapper

USAGE:
  git-wt <command> [options] [args]

COMMANDS:
  init|i [path]                  Initialize worktree structure
                                 (Creates main/ and trees/ directories)

  start|s [options] BRANCH       Create new feature branch worktree
    -s, --source SOURCE          Source branch (default: current branch)
    -c, --cd                     Auto-cd to new worktree

  resume|r [filter]              Switch to existing worktree
                                 (Shows menu if multiple matches)

  back|b                         Return to main worktree

  finish|f [options] [branch]    Remove worktree with smart cleanup
    --pr                         Create PR before finishing
    --keep-branch                Don't delete branch
    -P, --no-push                Don't push before finishing
    --rm                         Force delete branch

  cancel|c [options] [branch]    Remove worktree without cleanup
    --delete-branch              Also delete the branch (with confirmation)

  list|l                         Show all worktrees

  status|st                      Show current worktree info

  prune|p                        Clean up deleted worktrees

  sync                           Fetch and pull in main worktree

  help|h                         Show this help message

EXAMPLES:
  # Initialize a repo for worktrees
  git-wt init

  # Create a feature branch from current branch
  git-wt start feature/new-thing

  # Create a feature from main and cd to it
  git-wt start -s main -c feature/fix-bug

  # Switch to a worktree
  git-wt resume feature/new-thing

  # Go back to main
  git-wt back

  # Finish and create PR
  git-wt finish --pr

  # Cancel a worktree and delete branch
  git-wt cancel --delete-branch feature/old

ALIASES:
  gwt   - Shortcut for git-wt
  gwts  - git-wt start
  gwtr  - git-wt resume
  gwtb  - git-wt back
  gwtl  - git-wt list
EOF
}

# Aliases for convenience
alias gwt='git-wt'
alias gwts='git-wt start'
alias gwtr='git-wt resume'
alias gwtb='git-wt back'
alias gwtl='git-wt list'
alias gwtst='git-wt status'

# Bash completion
_git_wt_completion() {
    local cur prev commands
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    commands="init start resume back finish cancel list status prune sync help"

    # Complete main commands
    if [ $COMP_CWORD -eq 1 ]; then
        COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
        return 0
    fi

    # Complete subcommand options
    local cmd="${COMP_WORDS[1]}"
    case "$cmd" in
        start|s)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=( $(compgen -W "-s --source -c --cd" -- "$cur") )
            fi
            ;;
        finish|f)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=( $(compgen -W "--pr --keep-branch -P --no-push --rm" -- "$cur") )
            else
                # Complete with branch names from worktrees
                local branches=$(_git_wt_get_worktree_branches)
                COMPREPLY=( $(compgen -W "$branches" -- "$cur") )
            fi
            ;;
        cancel|c)
            if [[ "$cur" == -* ]]; then
                COMPREPLY=( $(compgen -W "--delete-branch" -- "$cur") )
            else
                local branches=$(_git_wt_get_worktree_branches)
                COMPREPLY=( $(compgen -W "$branches" -- "$cur") )
            fi
            ;;
        resume|r)
            local branches=$(_git_wt_get_worktree_branches)
            COMPREPLY=( $(compgen -W "$branches" -- "$cur") )
            ;;
    esac
}

# Helper for completion: get worktree branch names
_git_wt_get_worktree_branches() {
    local main_path=$(_git_wt_main_path 2>/dev/null)
    if [ -n "$main_path" ]; then
        git -C "$main_path" worktree list --porcelain 2>/dev/null | awk '/^branch/ {branch=$2; sub("refs/heads/", "", branch); print branch}'
    fi
}

complete -F _git_wt_completion git-wt gwt
