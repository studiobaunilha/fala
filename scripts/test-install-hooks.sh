#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/fala hooks.XXXXXX")"
TEST_ROOT="$(cd "$TEST_ROOT" && pwd -P)"
trap 'rm -rf "$TEST_ROOT"' EXIT
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL=/dev/null

MAIN="$TEST_ROOT/regular repo"
LINKED="$TEST_ROOT/linked tree"
mkdir -p "$MAIN/scripts/hooks" "$TEST_ROOT/empty template"
git init --quiet --template="$TEST_ROOT/empty template" "$MAIN"
mkdir -p "$MAIN/.git/hooks"
git -C "$MAIN" config user.name 'Hook Fixture'
git -C "$MAIN" config user.email 'fixture@example.invalid'
cp "$REPO_DIR/scripts/install-hooks.sh" "$MAIN/scripts/install-hooks.sh"
cat > "$MAIN/scripts/hooks/pre-commit" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
root="$(git rev-parse --show-toplevel)"
printf '%s\n' "$root" >> "$root/hook-invoked"
if [[ $# -gt 0 ]]; then
    printf '%s' "$1" > "$root/hook-argument"
    cat > "$root/hook-stdin"
fi
if [[ "${FALA_HOOK_FIXTURE_FAIL:-0}" == 1 ]]; then exit 23; fi
HOOK
cp "$MAIN/scripts/hooks/pre-commit" "$TEST_ROOT/source-before"
git -C "$MAIN" add scripts
git -C "$MAIN" commit --quiet -m fixture
git -C "$MAIN" worktree add --quiet -b fixture-linked "$LINKED"

assert_hook_runs() {
    local checkout="$1"
    git -C "$checkout" commit --quiet --allow-empty -m smoke
    [[ "$(tail -n 1 "$checkout/hook-invoked")" == "$checkout" ]]
}

ln -s '../../scripts/hooks/pre-commit' "$MAIN/.git/hooks/pre-commit"
bash "$MAIN/scripts/install-hooks.sh"
cmp "$TEST_ROOT/source-before" "$MAIN/scripts/hooks/pre-commit"
assert_hook_runs "$MAIN"
bash "$LINKED/scripts/install-hooks.sh"
assert_hook_runs "$LINKED"
assert_hook_runs "$MAIN"
git -C "$MAIN" worktree remove --force "$LINKED"
assert_hook_runs "$MAIN"

HOOKS="$(git -C "$MAIN" rev-parse --path-format=absolute --git-path hooks)"
(cd "$MAIN" && printf 'fixture input' | "$HOOKS/pre-commit" 'argument with spaces')
[[ "$(cat "$MAIN/hook-argument")" == 'argument with spaces' ]]
[[ "$(cat "$MAIN/hook-stdin")" == 'fixture input' ]]
if FALA_HOOK_FIXTURE_FAIL=1 git -C "$MAIN" commit --quiet --allow-empty -m rejected; then
    printf 'FAIL: hook rejection did not stop the commit\n' >&2
    exit 1
fi
cat > "$HOOKS/pre-commit" <<'HOOK'
#!/usr/bin/env bash
exit 23
HOOK
cp "$HOOKS/pre-commit" "$TEST_ROOT/custom-before"
if bash "$MAIN/scripts/install-hooks.sh"; then
    printf 'FAIL: installer overwrote an unmanaged hook\n' >&2
    exit 1
fi
cmp "$TEST_ROOT/custom-before" "$HOOKS/pre-commit"

mkdir -p "$TEST_ROOT/custom hooks"
cp "$TEST_ROOT/custom-before" "$TEST_ROOT/custom hooks/pre-commit"
git -C "$MAIN" config core.hooksPath "$TEST_ROOT/custom hooks"
if bash "$MAIN/scripts/install-hooks.sh"; then
    printf 'FAIL: installer modified a custom hooksPath\n' >&2
    exit 1
fi
cmp "$TEST_ROOT/custom-before" "$TEST_ROOT/custom hooks/pre-commit"

printf 'PASS: normal/worktree, spaces, removed installer, legacy symlink, args/stdin/rejection, custom hook and hooksPath\n'
