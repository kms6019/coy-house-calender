# Orca/git worktree 초기 세팅 스크립트
# 새 worktree 터미널에서 실행: powershell -ExecutionPolicy Bypass -File <메인레포>\scripts\setup-worktree.ps1
# 또는 worktree 안에서: ..\..\test_calender\scripts\setup-worktree.ps1

param(
    # 메인 체크아웃 경로 (gitignore된 설정 파일 원본 위치)
    [string]$MainRepo = "C:\Users\pup99\StudioProjects\test_calender"
)

$ErrorActionPreference = "Stop"
$dest = git rev-parse --show-toplevel
if (-not $dest) { throw "git 레포 안에서 실행하세요." }
$dest = $dest -replace '/', '\'

if ($dest -eq $MainRepo) {
    Write-Host "메인 레포입니다. worktree에서만 실행하세요." -ForegroundColor Yellow
    exit 0
}

# 1. gitignore된 필수 설정 파일 복사
$ignoredFiles = @(
    "android\local.properties",
    "android\key.properties"
)
foreach ($f in $ignoredFiles) {
    $src = Join-Path $MainRepo $f
    $dst = Join-Path $dest $f
    if (Test-Path $src) {
        New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
        Copy-Item $src $dst -Force
        Write-Host "복사됨: $f"
    } else {
        Write-Host "원본 없음(건너뜀): $f" -ForegroundColor Yellow
    }
}

# 2. 의존성 설치
$env:PATH += ";C:\flutter_windows_3.41.6-stable\flutter\bin"
Set-Location $dest
flutter pub get

Write-Host ""
Write-Host "worktree 세팅 완료: $dest" -ForegroundColor Green
Write-Host "개발 실행: flutter run -d chrome  (실기기 테스트는 한 worktree씩만!)"
