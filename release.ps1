<#
.SYNOPSIS
    Build fill-docx.exe locally (Windows) và tạo GitHub Release.

.DESCRIPTION
    Script này:
      1. Build Windows binary bằng PyInstaller (qua uv)
      2. Tạo GitHub Release với tag chỉ định
      3. Upload fill-docx-windows.exe lên Release

    Yêu cầu:
      - Python >= 3.10 + uv  (https://docs.astral.sh/uv/)
      - gh CLI  (https://cli.github.com/)  ← để upload release
        HOẶC đặt biến môi trường GITHUB_TOKEN để dùng GitHub API trực tiếp

.PARAMETER Tag
    Tag version, ví dụ: v0.2.0  (mặc định: hỏi lúc chạy)

.PARAMETER Draft
    Tạo release ở chế độ Draft thay vì publish ngay.

.PARAMETER SkipBuild
    Bỏ qua bước build, chỉ upload file đã có trong dist/.

.EXAMPLE
    .\release.ps1 -Tag v0.2.0
    .\release.ps1 -Tag v0.2.0 -Draft
    .\release.ps1 -Tag v0.2.0 -SkipBuild
#>

param(
    [string]$Tag = "",
    [switch]$Draft,
    [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ROOT = $PSScriptRoot
$DIST = Join-Path $ROOT "dist"
$EXE_NAME = "fill-docx-windows.exe"

# ── Màu sắc output ────────────────────────────────────────────────────────────
function Write-Step($msg) { Write-Host "`n▶ $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "  ✅ $msg" -ForegroundColor Green }
function Write-Fail($msg) { Write-Host "  ❌ $msg" -ForegroundColor Red }
function Write-Info($msg) { Write-Host "  ℹ  $msg" -ForegroundColor Gray }

# ── Lấy Tag ───────────────────────────────────────────────────────────────────
if (-not $Tag) {
    $Tag = Read-Host "Nhập tag version (ví dụ: v0.2.0)"
}
if ($Tag -notmatch '^v\d+\.\d+') {
    Write-Fail "Tag không hợp lệ: '$Tag'. Phải có định dạng vX.Y.Z"
    exit 1
}
Write-Host "`n╔══════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║   fill-docx Local Release Builder       ║" -ForegroundColor Yellow
Write-Host "║   Tag: $Tag$((' ' * (33 - $Tag.Length)))║" -ForegroundColor Yellow
Write-Host "╚══════════════════════════════════════════╝`n" -ForegroundColor Yellow

# ── Kiểm tra uv ───────────────────────────────────────────────────────────────
Write-Step "Kiểm tra môi trường"

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    Write-Fail "Không tìm thấy 'uv'. Cài tại: https://docs.astral.sh/uv/"
    exit 1
}
Write-Ok "uv: $(uv --version)"

# ── Kiểm tra gh hoặc GITHUB_TOKEN ─────────────────────────────────────────────
$useGhCli = $false
$ghToken = $env:GITHUB_TOKEN

if (Get-Command gh -ErrorAction SilentlyContinue) {
    $useGhCli = $true
    Write-Ok "gh CLI: $(gh --version | Select-Object -First 1)"
} elseif ($ghToken) {
    Write-Ok "Dùng GITHUB_TOKEN để upload qua API"
} else {
    Write-Fail @"
Không tìm thấy 'gh' CLI và GITHUB_TOKEN chưa được đặt.

Chọn một trong hai:
  A) Cài gh CLI: winget install GitHub.cli  (sau đó: gh auth login)
  B) Đặt biến môi trường: `$env:GITHUB_TOKEN = "ghp_xxx..."
"@
    exit 1
}

# ── Lấy remote repo ───────────────────────────────────────────────────────────
$remoteUrl = git -C $ROOT remote get-url origin 2>$null
if ($remoteUrl -match 'github\.com[:/](.+?)(?:\.git)?$') {
    $REPO = $Matches[1]  # e.g. DrRingo/bb-docx-render
} else {
    Write-Fail "Không đọc được remote GitHub URL: $remoteUrl"
    exit 1
}
Write-Ok "Repo: $REPO"

# ── Build Windows binary ───────────────────────────────────────────────────────
if (-not $SkipBuild) {
    Write-Step "Build Windows binary (PyInstaller)"

    # Đảm bảo deps đã được cài (kể cả dev deps: pyinstaller)
    Write-Info "uv sync --all-groups ..."
    & uv sync --all-groups
    if ($LASTEXITCODE -ne 0) { Write-Fail "uv sync thất bại"; exit 1 }

    # Chạy pyinstaller qua uv run
    Write-Info "Chạy PyInstaller ..."
    $hiddenImports = @(
        "docxtpl","docx","jinja2","yaml","tomli","PIL",
        "lxml","lxml.etree","lxml._elementpath"
    )
    $hiArgs = $hiddenImports | ForEach-Object { "--hidden-import", $_ }

    $pyArgs = @(
        "pyinstaller", "--onefile", "--name", "fill-docx", "--clean",
        "--distpath", $DIST
    ) + $hiArgs + @("fill_docx_main.py")

    & uv run @pyArgs
    if ($LASTEXITCODE -ne 0) { Write-Fail "PyInstaller thất bại"; exit 1 }

    # Đổi tên sang fill-docx-windows.exe
    $src = Join-Path $DIST "fill-docx.exe"
    $dst = Join-Path $DIST $EXE_NAME
    if (Test-Path $dst) { Remove-Item $dst -Force }
    Move-Item $src $dst
    $sizeMB = [math]::Round((Get-Item $dst).Length / 1MB, 1)
    Write-Ok "Binary: $dst  ($sizeMB MB)"
} else {
    Write-Info "Bỏ qua build (--SkipBuild)"
}

# ── Kiểm tra file binary tồn tại ──────────────────────────────────────────────
$exePath = Join-Path $DIST $EXE_NAME
if (-not (Test-Path $exePath)) {
    Write-Fail "Không tìm thấy binary: $exePath"
    exit 1
}

# ── Tạo / cập nhật git tag ────────────────────────────────────────────────────
Write-Step "Tạo git tag $Tag"
$existingTag = git -C $ROOT tag -l $Tag
if ($existingTag) {
    Write-Info "Tag $Tag đã tồn tại, bỏ qua tạo mới"
} else {
    git -C $ROOT tag -a $Tag -m "Release $Tag"
    Write-Ok "Đã tạo tag $Tag"
}

Write-Info "Push tag lên remote ..."
git -C $ROOT push origin $Tag
if ($LASTEXITCODE -ne 0) { 
    Write-Fail "Push tag thất bại. Kiểm tra quyền push lên repo."
    exit 1
}
Write-Ok "Đã push tag $Tag"

# ── Tạo GitHub Release và upload binary ───────────────────────────────────────
Write-Step "Tạo GitHub Release $Tag"

$draftFlag = if ($Draft) { "--draft" } else { "" }

if ($useGhCli) {
    # Dùng gh CLI
    $ghArgs = @(
        "release", "create", $Tag,
        $exePath,
        "--repo", $REPO,
        "--title", "Release $Tag",
        "--generate-notes"
    )
    if ($Draft) { $ghArgs += "--draft" }

    Write-Info "gh $($ghArgs -join ' ')"
    & gh @ghArgs
    if ($LASTEXITCODE -ne 0) { Write-Fail "gh release create thất bại"; exit 1 }

} else {
    # Dùng GitHub API trực tiếp
    $headers = @{
        Authorization = "Bearer $ghToken"
        Accept        = "application/vnd.github+json"
        "X-GitHub-Api-Version" = "2022-11-28"
    }

    # Kiểm tra release đã tồn tại chưa
    $releaseUrl = "https://api.github.com/repos/$REPO/releases/tags/$Tag"
    try {
        $existing = Invoke-RestMethod $releaseUrl -Headers $headers -ErrorAction Stop
        $uploadUrl = $existing.upload_url -replace '\{.*\}', ''
        $releaseId = $existing.id
        Write-Info "Release đã tồn tại (id=$releaseId), tiến hành upload binary"
    } catch {
        # Tạo release mới
        $body = @{
            tag_name         = $Tag
            name             = "Release $Tag"
            draft            = [bool]$Draft
            generate_release_notes = $true
        } | ConvertTo-Json

        $createUrl = "https://api.github.com/repos/$REPO/releases"
        $release = Invoke-RestMethod $createUrl -Method Post -Headers $headers `
                       -ContentType "application/json" -Body $body
        $uploadUrl = $release.upload_url -replace '\{.*\}', ''
        $releaseId = $release.id
        Write-Ok "Đã tạo Release id=$releaseId"
    }

    # Upload binary
    $uploadUri = "${uploadUrl}?name=$EXE_NAME"
    Write-Info "Upload $EXE_NAME ..."
    $fileBytes = [System.IO.File]::ReadAllBytes($exePath)
    Invoke-RestMethod $uploadUri -Method Post -Headers $headers `
        -ContentType "application/octet-stream" -Body $fileBytes | Out-Null
    Write-Ok "Đã upload $EXE_NAME"

    Write-Ok "Release URL: https://github.com/$REPO/releases/tag/$Tag"
}

Write-Host "`n✨ Hoàn tất! Release $Tag đã được tạo trên GitHub." -ForegroundColor Green
