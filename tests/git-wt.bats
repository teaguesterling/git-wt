#!/usr/bin/env bats
#
# Regression tests for issue #1:
#   1. Spaces-in-path porcelain parsing — `git worktree list --porcelain`
#      must not be whitespace-split, or any repo living under a spaced
#      path breaks resume/finish/list (and submodule auto-detection).
#   2. Shared-path guard — `.git-worktree-shared` entries that are
#      absolute, contain a `..` component, or resolve outside the
#      worktree must be rejected BEFORE the `rm -rf` in the symlink
#      linker, so a config typo can't delete anything outside the tree.
#
# All tests are hermetic: everything happens under a mktemp dir, and the
# `..`/symlink tests point at canary files inside that dir so a failing
# guard is detected without ever touching real paths.

setup() {
    TEST_DIR="$(mktemp -d)"
    export GIT_CONFIG_GLOBAL=/dev/null
    export GIT_CONFIG_SYSTEM=/dev/null
    export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
    export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
    source "${BATS_TEST_DIRNAME}/../git-wt.sh"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# Create a git repo at $1 (parent dirs may contain spaces), commit a file,
# and restructure it with `git-wt init`. Leaves PWD in the main/ worktree.
make_wt_repo() {
    mkdir -p "$1"
    git init -q -b main "$1"
    echo hello > "$1/file.txt"
    git -C "$1" add file.txt
    git -C "$1" commit -q -m init
    git-wt init "$1"
}

# --- Finding 1: spaces-in-path porcelain parsing -------------------------

@test "resume resolves a worktree under a path containing spaces" {
    make_wt_repo "$TEST_DIR/spaced dir/repo"
    git-wt start -C feature/spacetest

    run git-wt resume spacetest
    [ "$status" -eq 0 ]
    [[ "$output" == *"Switched to worktree"* ]]
}

@test "finish removes a worktree under a path containing spaces" {
    make_wt_repo "$TEST_DIR/spaced dir/repo"
    git-wt start -C feature/spacetest
    [ -d "$TEST_DIR/spaced dir/repo/trees/feature/spacetest" ]

    run git-wt finish -P --keep-branch feature/spacetest
    [ "$status" -eq 0 ]
    [ ! -d "$TEST_DIR/spaced dir/repo/trees/feature/spacetest" ]
}

@test "list shows the full worktree path when it contains spaces" {
    make_wt_repo "$TEST_DIR/spaced dir/repo"
    git-wt start -C feature/spacetest

    run git-wt list
    [ "$status" -eq 0 ]
    [[ "$output" == *"$TEST_DIR/spaced dir/repo/trees/feature/spacetest"* ]]
}

@test "completion helper lists branches from a spaced-path repo" {
    make_wt_repo "$TEST_DIR/spaced dir/repo"
    git-wt start -C feature/spacetest

    run _git_wt_get_worktree_branches
    [ "$status" -eq 0 ]
    [[ "$output" == *"feature/spacetest"* ]]
}

@test "init records submodule paths containing spaces in shared config" {
    repo="$TEST_DIR/repo"
    mkdir -p "$repo/my sub"
    git init -q -b main "$repo"
    printf '[submodule "sub"]\n\tpath = my sub\n\turl = https://example.invalid/sub.git\n' > "$repo/.gitmodules"
    touch "$repo/my sub/.git"   # simulate an initialized submodule
    echo hi > "$repo/file.txt"
    git -C "$repo" add file.txt .gitmodules
    git -C "$repo" commit -q -m init

    git-wt init "$repo"
    run grep -Fx "my sub" "$TEST_DIR/repo/.git-worktree-shared"
    [ "$status" -eq 0 ]
}

# --- Finding 2: shared-path guard before rm -rf --------------------------

@test "shared-path guard rejects absolute and .. paths, allows simple relative" {
    run _git_wt_shared_path_is_safe ".cache"
    [ "$status" -eq 0 ]
    run _git_wt_shared_path_is_safe "logs/app"
    [ "$status" -eq 0 ]
    run _git_wt_shared_path_is_safe "/etc"
    [ "$status" -eq 1 ]
    run _git_wt_shared_path_is_safe ".."
    [ "$status" -eq 1 ]
    run _git_wt_shared_path_is_safe "../x"
    [ "$status" -eq 1 ]
    run _git_wt_shared_path_is_safe "foo/../../bar"
    [ "$status" -eq 1 ]
    run _git_wt_shared_path_is_safe "foo/.."
    [ "$status" -eq 1 ]
}

@test "shared path with .. is rejected and does not rm outside the worktree" {
    make_wt_repo "$TEST_DIR/proj"
    # Source canary: what main/../../canary resolves to, so pre-guard code
    # gets past its "source exists" check and reaches the rm -rf.
    mkdir -p "$TEST_DIR/canary"
    echo src > "$TEST_DIR/canary/src.txt"
    # Victim canary: what <worktree>/../../canary resolves to.
    mkdir -p "$TEST_DIR/proj/trees/canary"
    echo precious > "$TEST_DIR/proj/trees/canary/precious.txt"
    echo '../../canary' >> "$TEST_DIR/proj/.git-worktree-shared"

    run git-wt start -C feature/guard
    [ "$status" -eq 0 ]
    [[ "$output" == *"Skipping unsafe shared path"* ]]
    # The canary outside the worktree must be untouched
    [ -f "$TEST_DIR/proj/trees/canary/precious.txt" ]
    [ ! -L "$TEST_DIR/proj/trees/canary" ]
}

@test "absolute shared path is rejected with a warning" {
    make_wt_repo "$TEST_DIR/proj"
    echo "$TEST_DIR/abs-canary" >> "$TEST_DIR/proj/.git-worktree-shared"

    run git-wt start -C feature/absguard
    [ "$status" -eq 0 ]
    [[ "$output" == *"Skipping unsafe shared path"* ]]
}

@test "shared path resolving through a symlink outside the worktree is rejected" {
    make_wt_repo "$TEST_DIR/proj"
    mkdir -p "$TEST_DIR/outside/sub"
    echo precious > "$TEST_DIR/outside/sub/keep.txt"
    # Commit a symlink pointing outside the tree; worktree checkout recreates it.
    (cd "$TEST_DIR/proj/main" && ln -s "$TEST_DIR/outside" link \
        && git add link && git commit -q -m link)
    echo 'link/sub' >> "$TEST_DIR/proj/.git-worktree-shared"

    run git-wt start -C feature/symguard
    [ "$status" -eq 0 ]
    [[ "$output" == *"resolves outside the worktree"* ]]
    [ -f "$TEST_DIR/outside/sub/keep.txt" ]
}

@test "legitimate relative shared path still links (no over-rejection)" {
    make_wt_repo "$TEST_DIR/proj"
    mkdir -p "$TEST_DIR/proj/main/.cache"
    echo cached > "$TEST_DIR/proj/main/.cache/x"
    echo '.cache' >> "$TEST_DIR/proj/.git-worktree-shared"

    run git-wt start -C feature/link
    [ "$status" -eq 0 ]
    [ -L "$TEST_DIR/proj/trees/feature/link/.cache" ]
    [ -f "$TEST_DIR/proj/trees/feature/link/.cache/x" ]
}
