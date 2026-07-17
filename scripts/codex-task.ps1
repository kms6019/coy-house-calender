# Codex를 Orca 터미널 서브에이전트로 실행하는 디스패치 스크립트
# 사용: .\scripts\codex-task.ps1 -PromptFile <프롬프트파일> [-Title 이름] [-Write] [-TimeoutSec 600]
#  -Write: 파일 수정 허용 (codex exec --full-auto). 없으면 읽기 전용 분석.
# 완료 시 터미널 출력 꼬리를 stdout으로 반환. Orca UI에서 세션 실시간 관찰 가능.

param(
    [Parameter(Mandatory)][string]$PromptFile,
    [string]$Title = "codex-task",
    [switch]$Write,
    [int]$TimeoutSec = 600,
    [string]$Worktree = "path:C:/Users/pup99/StudioProjects/test_calender"
)

$ErrorActionPreference = "Stop"
$orca = "$env:LOCALAPPDATA\Programs\orca\resources\bin\orca.exe"
$marker = "__CODEX_TASK_DONE_$([guid]::NewGuid().ToString('N').Substring(0,8))__"
$mode = if ($Write) { "--full-auto" } else { "" }
$promptPath = (Resolve-Path $PromptFile).Path

# Orca 터미널 생성 (pwsh에서 프롬프트 파일을 codex exec stdin으로)
$cmd = "Get-Content '$promptPath' -Raw | codex exec $mode -; Write-Host '$marker'"
$res = & $orca terminal create --worktree $Worktree --title $Title --command $cmd --json | ConvertFrom-Json
if (-not $res.ok) { throw "terminal create failed: $($res | ConvertTo-Json -Depth 5)" }
$handle = $res.result.terminal.handle
Write-Host "[codex-task] terminal: $handle ($Title)"

# 완료 마커 폴링
$deadline = (Get-Date).AddSeconds($TimeoutSec)
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 10
    $out = & $orca terminal read --terminal $handle --limit 400 2>$null
    if ($out -match [regex]::Escape($marker)) {
        # 마커 이전 출력 반환 + 터미널 정리
        $text = ($out -join "`n")
        $text.Substring(0, $text.IndexOf($marker))
        & $orca terminal close --terminal $handle 2>$null | Out-Null
        return
    }
}
Write-Warning "[codex-task] timeout ($TimeoutSec s) — 터미널 유지: $handle (Orca에서 확인)"
& $orca terminal read --terminal $handle --limit 100 2>$null
