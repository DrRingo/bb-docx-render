#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# release.sh — Build fill-docx Linux binary locally và tạo GitHub Release
#
# Yêu cầu:
#   - Python >= 3.10 + uv  (https://docs.astral.sh/uv/)
#   - gh CLI  (https://cli.github.com/)
#     HOẶC đặt biến GITHUB_TOKEN để dùng API trực tiếp
#
# Cách dùng:
#   ./release.sh v0.2.0
#   ./release.sh v0.2.0 --draft
#   ./release.sh v0.2.0 --skip-build
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST="$ROOT/dist"

# Phát hiện OS để đặt tên binary đúng
caseOS=$(uname -s | tr '[:upper:]' '[:lower:]')
if [[ "$caseOS" == *darwin* ]]; then
    EXE_NAME="fill-docx-macos"
else
    EXE_NAME="fill-docx-linux"
fi

# ── Màu ──────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; GRAY='\033[0;90m'; NC='\033[0m'

step()  { echo -e "\n${CYAN}▶ $*${NC}"; }
ok()    { echo -e "  ${GREEN}✅ $*${NC}"; }
fail()  { echo -e "  ${RED}❌ $*${NC}"; exit 1; }
info()  { echo -e "  ${GRAY}ℹ  $*${NC}"; }

# ── Args ─────────────────────────────────────────────────────────────────────
TAG=""
DRAFT=false
SKIP_BUILD=false

for arg in "$@"; do
    case "$arg" in
        v*)          TAG="$arg" ;;
        --draft)     DRAFT=true ;;
        --skip-build) SKIP_BUILD=true ;;
        *) fail "Tham số không hợp lệ: $arg" ;;
    esac
done

if [[ -z "$TAG" ]]; then
    read -rp "Nhập tag version (ví dụ: v0.2.0): " TAG
fi

if [[ ! "$TAG" =~ ^v[0-9]+\.[0-9]+ ]]; then
    fail "Tag không hợp lệ: '$TAG'. Phải có định dạng vX.Y.Z"
fi

echo -e "\n${YELLOW}╔══════════════════════════════════════════╗"
echo    "║   fill-docx Local Release Builder       ║"
printf  "║   Tag: %-34s║\n" "$TAG"
echo -e "╚══════════════════════════════════════════╝${NC}\n"

# ── Kiểm tra môi trường ───────────────────────────────────────────────────────
step "Kiểm tra môi trường"

if ! command -v uv &>/dev/null; then
    fail "Không tìm thấy 'uv'. Cài tại: https://docs.astral.sh/uv/"
fi
ok "uv: $(uv --version)"

USE_GH_CLI=false
if command -v gh &>/dev/null; then
    USE_GH_CLI=true
    ok "gh CLI: $(gh --version | head -1)"
elif [[ -n "${GITHUB_TOKEN:-}" ]]; then
    ok "Dùng GITHUB_TOKEN để upload qua API"
else
    fail "Không tìm thấy 'gh' CLI và GITHUB_TOKEN chưa được đặt.

Chọn một trong hai:
  A) Cài gh CLI: https://cli.github.com  (sau đó: gh auth login)
  B) Export biến: export GITHUB_TOKEN=ghp_xxx..."
fi

# ── Lấy remote repo ───────────────────────────────────────────────────────────
REMOTE_URL="$(git -C "$ROOT" remote get-url origin)"
if [[ "$REMOTE_URL" =~ github\.com[:/](.+?)(\.git)?$ ]]; then
    REPO="${BASH_REMATCH[1]}"
else
    fail "Không đọc được remote GitHub URL: $REMOTE_URL"
fi
ok "Repo: $REPO"

# ── Build Linux binary ────────────────────────────────────────────────────────
if [[ "$SKIP_BUILD" == false ]]; then
    step "Build Linux binary (PyInstaller)"

    info "uv sync --all-groups ..."
    uv sync --all-groups

    info "Chạy PyInstaller ..."
    uv run pyinstaller \
        --onefile \
        --name fill-docx \
        --clean \
        --distpath "$DIST" \
        --hidden-import docxtpl \
        --hidden-import docx \
        --hidden-import jinja2 \
        --hidden-import yaml \
        --hidden-import tomli \
        --hidden-import PIL \
        --hidden-import lxml \
        --hidden-import lxml.etree \
        --hidden-import lxml._elementpath \
        fill_docx_main.py

    # Đổi tên sang fill-docx-linux
    mv -f "$DIST/fill-docx" "$DIST/$EXE_NAME"
    SIZE=$(du -sh "$DIST/$EXE_NAME" | cut -f1)
    ok "Binary: $DIST/$EXE_NAME  ($SIZE)"
else
    info "Bỏ qua build (--skip-build)"
fi

# ── Kiểm tra binary ───────────────────────────────────────────────────────────
EXE_PATH="$DIST/$EXE_NAME"
if [[ ! -f "$EXE_PATH" ]]; then
    fail "Không tìm thấy binary: $EXE_PATH"
fi

# ── Git tag ───────────────────────────────────────────────────────────────────
step "Tạo git tag $TAG"
if git -C "$ROOT" tag -l "$TAG" | grep -q "$TAG"; then
    info "Tag $TAG đã tồn tại, bỏ qua"
else
    git -C "$ROOT" tag -a "$TAG" -m "Release $TAG"
    ok "Đã tạo tag $TAG"
fi

info "Push tag lên remote ..."
git -C "$ROOT" push origin "$TAG"
ok "Đã push tag $TAG"

# ── Tạo GitHub Release ────────────────────────────────────────────────────────
step "Tạo GitHub Release $TAG"

if [[ "$USE_GH_CLI" == true ]]; then
    GH_ARGS=(release create "$TAG" "$EXE_PATH" \
        --repo "$REPO" \
        --title "Release $TAG" \
        --generate-notes)
    if [[ "$DRAFT" == true ]]; then GH_ARGS+=(--draft); fi

    info "gh ${GH_ARGS[*]}"
    gh "${GH_ARGS[@]}"
    ok "Release tạo thành công"

else
    # Dùng GitHub API
    HEADERS=(
        -H "Authorization: Bearer $GITHUB_TOKEN"
        -H "Accept: application/vnd.github+json"
        -H "X-GitHub-Api-Version: 2022-11-28"
    )

    # Kiểm tra release đã tồn tại chưa
    EXISTING=$(curl -sf "${HEADERS[@]}" \
        "https://api.github.com/repos/$REPO/releases/tags/$TAG" || true)

    if [[ -n "$EXISTING" ]]; then
        UPLOAD_URL=$(echo "$EXISTING" | python3 -c \
            "import sys,json,re; d=json.load(sys.stdin); print(re.sub(r'\{.*\}','',d['upload_url']))")
        info "Release đã tồn tại, tiến hành upload binary"
    else
        # Tạo release mới
        DRAFT_VAL=$([ "$DRAFT" == true ] && echo true || echo false)
        PAYLOAD=$(python3 -c "
import json
print(json.dumps({
    'tag_name': '$TAG',
    'name': 'Release $TAG',
    'draft': $DRAFT_VAL,
    'generate_release_notes': True
}))")
        RELEASE=$(curl -sf -X POST "${HEADERS[@]}" \
            -H "Content-Type: application/json" \
            -d "$PAYLOAD" \
            "https://api.github.com/repos/$REPO/releases")
        UPLOAD_URL=$(echo "$RELEASE" | python3 -c \
            "import sys,json,re; d=json.load(sys.stdin); print(re.sub(r'\{.*\}','',d['upload_url']))")
        info "Release id=$(echo "$RELEASE" | python3 -c 'import sys,json; print(json.load(sys.stdin)["id"])')"
        ok "Đã tạo Release"
    fi

    # Upload binary
    info "Upload $EXE_NAME ..."
    curl -sf -X POST "${HEADERS[@]}" \
        -H "Content-Type: application/octet-stream" \
        --data-binary "@$EXE_PATH" \
        "${UPLOAD_URL}?name=$EXE_NAME" > /dev/null
    ok "Đã upload $EXE_NAME"
    ok "Release URL: https://github.com/$REPO/releases/tag/$TAG"
fi

echo -e "\n${GREEN}✨ Hoàn tất! Release $TAG đã được tạo trên GitHub.${NC}"
