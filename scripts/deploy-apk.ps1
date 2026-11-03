# APK 릴리스 배포: 빌드 → hosting_public 갱신(APK + version.json) → Firebase Hosting 배포
#
# version.json 의 buildNumber 는 pubspec.yaml 의 "version: x.y.z+N" 에서 N 을 읽는다.
# 새 버전을 내보낼 때는 pubspec 의 N 을 먼저 올릴 것 — 안 올리면 앱이 업데이트를 감지 못 한다.
#
# 사용: pwsh scripts/deploy-apk.ps1 -Notes "이번에 바뀐 것"

param(
  [string]$Notes = ''
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

$flutter = 'C:\flutter_windows_3.41.6-stable\flutter\bin\flutter.bat'
$env:JAVA_HOME = 'C:\Program Files\Android\openjdk\jdk-21.0.8'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH;C:\Users\PUP99\AppData\Local\Pub\Cache\bin"

# pubspec 에서 버전 파싱
$versionLine = (Select-String -Path "$root\pubspec.yaml" -Pattern '^version:\s*(.+)$').Matches[0].Groups[1].Value.Trim()
if ($versionLine -notmatch '^(?<name>[\d.]+)\+(?<build>\d+)$') {
  throw "pubspec.yaml 의 version 형식을 읽지 못했습니다: $versionLine"
}
$versionName = $Matches['name']
$buildNumber = [int]$Matches['build']
Write-Host "배포 버전: $versionName (build $buildNumber)"

& $flutter build apk --release
if ($LASTEXITCODE -ne 0) { throw 'APK 빌드 실패' }

Copy-Item "$root\build\app\outputs\flutter-apk\app-release.apk" "$root\hosting_public\coyhouse.apk" -Force

$manifest = [ordered]@{
  buildNumber = $buildNumber
  versionName = $versionName
  # ?v=빌드번호: 배포 직후 CDN 이 옛 APK 를 잠깐 돌려주는 일이 있어 주소를 빌드마다 다르게 한다.
  # 앱은 다 받은 APK 를 재사용하므로 옛 파일을 새 빌드로 잘못 저장하면 계속 그걸 깐다.
  apkUrl      = "https://coy-house-calender.web.app/coyhouse.apk?v=$buildNumber"
  notes       = $Notes
}
$manifest | ConvertTo-Json -Depth 3 | Set-Content "$root\hosting_public\version.json" -Encoding UTF8

firebase deploy --only hosting --project coy-house-calender
if ($LASTEXITCODE -ne 0) { throw 'Hosting 배포 실패' }

Write-Host "`n완료 → https://coy-house-calender.web.app"
Write-Host "version.json → build $buildNumber / $versionName"
