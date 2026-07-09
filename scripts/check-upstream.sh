#!/usr/bin/env bash
# 对照 pi-mono 文档变更（相对 UPSTREAM pin / submodule）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SUBMODULE="${UPSTREAM_SUBMODULE:-vendor/pi-mono}"
DOCS_PATH="${UPSTREAM_DOCS_PATH:-packages/coding-agent/docs}"
UPSTREAM_FILE="${UPSTREAM_FILE:-UPSTREAM}"
REMOTE_REF="${UPSTREAM_REMOTE_REF:-refs/heads/main}"

die() { echo "error: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null || die "需要命令: $1"; }

need git
need awk

[[ -f "$UPSTREAM_FILE" ]] || die "找不到 $UPSTREAM_FILE"
[[ -d "$SUBMODULE/.git" || -f "$SUBMODULE/.git" ]] || die "submodule 未初始化。请运行: git submodule update --init $SUBMODULE"

PIN="$(awk '/^commit:/{print $2; exit}' "$UPSTREAM_FILE")"
[[ -n "$PIN" ]] || die "UPSTREAM 中无 commit 字段"

SUB_HEAD="$(git -C "$SUBMODULE" rev-parse HEAD 2>/dev/null)" || die "无法读取 $SUBMODULE HEAD"
URL="$(git config -f .gitmodules --get "submodule.${SUBMODULE}.url" 2>/dev/null || true)"
[[ -n "$URL" ]] || URL="https://github.com/earendil-works/pi-mono.git"

usage() {
  cat <<EOF
用法: $(basename "$0") <命令> [参数]

命令:
  status              pin / submodule / 远端 main 是否一致（默认）
  log                 pin→远端 之间 docs 的提交列表
  files               pin→远端 的 name-status（M/A/D/R）
  diff [文件]         全文或单页 diff（文件名如 settings.md）
  pages               对比本仓与上游 docs 文件名（新增/仅本地）
  fetch               在 submodule 中 fetch 远端（加深历史以便解析 pin）
  sync-pin            将 submodule checkout 到 UPSTREAM.commit
  help

环境变量:
  UPSTREAM_REMOTE_REF  默认 refs/heads/main
  UPSTREAM_SUBMODULE   默认 vendor/pi-mono
  UPSTREAM_DOCS_PATH   默认 packages/coding-agent/docs

示例:
  ./scripts/check-upstream.sh
  ./scripts/check-upstream.sh files
  ./scripts/check-upstream.sh diff settings.md
  ./scripts/check-upstream.sh pages
EOF
}

ensure_commit() {
  local sha="$1"
  if ! git -C "$SUBMODULE" cat-file -t "$sha" >/dev/null 2>&1; then
    echo "fetch $sha …" >&2
    git -C "$SUBMODULE" fetch --depth=1 origin "$sha" 2>/dev/null \
      || git -C "$SUBMODULE" fetch origin "$sha" 2>/dev/null \
      || true
  fi
  git -C "$SUBMODULE" cat-file -t "$sha" >/dev/null 2>&1 \
    || die "submodule 中无法解析 $sha。可先: git -C $SUBMODULE fetch --unshallow 或 fetch origin main"
}

remote_main() {
  git ls-remote "$URL" "$REMOTE_REF" | awk '{print $1; exit}'
}

cmd_fetch() {
  echo "fetch origin ($REMOTE_REF) in $SUBMODULE …"
  git -C "$SUBMODULE" fetch origin "+${REMOTE_REF}:refs/remotes/origin/main" || \
    git -C "$SUBMODULE" fetch origin main
  # 加深以便覆盖旧 pin
  if ! git -C "$SUBMODULE" merge-base --is-ancestor "$PIN" "origin/main" 2>/dev/null; then
    echo "deepen history until pin is reachable …"
    local n=0
    while ! git -C "$SUBMODULE" cat-file -t "$PIN" >/dev/null 2>&1 && [[ $n -lt 20 ]]; do
      git -C "$SUBMODULE" fetch --deepen=100 origin main || break
      n=$((n + 1))
    done
  fi
  ensure_commit "$PIN"
  local r
  r="$(remote_main)"
  ensure_commit "$r"
  echo "ok pin=$(git -C "$SUBMODULE" rev-parse --short "$PIN") remote=$(git -C "$SUBMODULE" rev-parse --short "$r")"
}

cmd_status() {
  local remote
  remote="$(remote_main)"
  [[ -n "$remote" ]] || die "无法解析远端 $URL $REMOTE_REF"

  echo "repo:     $URL"
  echo "docs:     $DOCS_PATH"
  echo "pin:      $PIN"
  echo "submodule:$SUB_HEAD  ($SUBMODULE)"
  echo "remote:   $remote  ($REMOTE_REF)"

  if [[ "$PIN" != "$SUB_HEAD" ]]; then
    echo
    echo "⚠ UPSTREAM.commit 与 submodule HEAD 不一致"
    echo "  对齐 pin → submodule:  ./scripts/check-upstream.sh sync-pin"
  fi

  if [[ "$PIN" == "$remote" ]]; then
    echo
    echo "✓ pin 已与远端 main 相同（整仓 tip；docs 未必有变更）"
    return 0
  fi

  ensure_commit "$PIN"
  ensure_commit "$remote"

  echo
  echo "pin 落后于远端。docs 变更："
  if git -C "$SUBMODULE" rev-list --count "${PIN}..${remote}" -- "$DOCS_PATH" >/dev/null 2>&1; then
    local n
    n="$(git -C "$SUBMODULE" rev-list --count "${PIN}..${remote}" -- "$DOCS_PATH")"
    echo "  commits touching docs: $n"
  fi
  git -C "$SUBMODULE" diff --name-status "${PIN}..${remote}" -- "$DOCS_PATH" || true
  if [[ -z "$(git -C "$SUBMODULE" diff --name-only "${PIN}..${remote}" -- "$DOCS_PATH")" ]]; then
    echo "  （docs 路径无文件变更；可只前移 UPSTREAM/submodule）"
  fi
  echo
  echo "详情: ./scripts/check-upstream.sh log | files | diff [file.md]"
}

cmd_log() {
  local remote
  remote="$(remote_main)"
  ensure_commit "$PIN"
  ensure_commit "$remote"
  git -C "$SUBMODULE" log --oneline "${PIN}..${remote}" -- "$DOCS_PATH"
}

cmd_files() {
  local remote
  remote="$(remote_main)"
  ensure_commit "$PIN"
  ensure_commit "$remote"
  git -C "$SUBMODULE" diff --name-status "${PIN}..${remote}" -- "$DOCS_PATH"
}

cmd_diff() {
  local remote file="${1:-}"
  remote="$(remote_main)"
  ensure_commit "$PIN"
  ensure_commit "$remote"
  if [[ -n "$file" ]]; then
    file="${file#./}"
    file="${file#"$DOCS_PATH"/}"
    git -C "$SUBMODULE" diff "${PIN}..${remote}" -- "$DOCS_PATH/$file"
  else
    git -C "$SUBMODULE" diff "${PIN}..${remote}" -- "$DOCS_PATH"
  fi
}

cmd_pages() {
  ensure_commit "$PIN"
  # 用 pin 树列出上游文件名
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  git -C "$SUBMODULE" ls-tree -r --name-only "$PIN" -- "$DOCS_PATH" \
    | sed "s|^${DOCS_PATH}/||" \
    | grep -E '(\.md$|^docs\.json$)' \
    | sort >"$tmp/up.txt"
  # 本仓文档页（排除工具文件）
  {
    ls -1 ./*.md 2>/dev/null | xargs -n1 basename
    [[ -f docs.json ]] && echo docs.json
  } | grep -Ev '^(AGENTS)\.md$' | sort -u >"$tmp/local.txt"


  echo "=== 仅上游有（可能是新增文档）==="
  comm -13 "$tmp/local.txt" "$tmp/up.txt" || true
  echo
  echo "=== 仅本仓有（工具文件或已删上游页）==="
  comm -23 "$tmp/local.txt" "$tmp/up.txt" || true
}

cmd_sync_pin() {
  ensure_commit "$PIN"
  git -C "$SUBMODULE" checkout --detach "$PIN"
  echo "submodule 现为 $(git -C "$SUBMODULE" rev-parse HEAD)"
  echo "（与 git 索引一致需: git add $SUBMODULE）"
}

CMD="${1:-status}"
shift || true
case "$CMD" in
  status|st) cmd_status "$@" ;;
  log) cmd_log "$@" ;;
  files|name-status) cmd_files "$@" ;;
  diff) cmd_diff "$@" ;;
  pages) cmd_pages "$@" ;;
  fetch) cmd_fetch "$@" ;;
  sync-pin) cmd_sync_pin "$@" ;;
  help|-h|--help) usage ;;
  *) usage; die "未知命令: $CMD" ;;
esac
