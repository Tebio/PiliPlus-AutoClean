$ErrorActionPreference = 'Stop'

function Assert-FileContains {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Pattern,
    [Parameter(Mandatory = $true)][string]$Message
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Missing file: $Path"
  }

  $content = Get-Content -LiteralPath $Path -Raw
  if ($content -notmatch $Pattern) {
    throw $Message
  }
}

function Assert-FileNotContains {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Pattern,
    [Parameter(Mandatory = $true)][string]$Message
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "Missing file: $Path"
  }

  $content = Get-Content -LiteralPath $Path -Raw
  if ($content -match $Pattern) {
    throw $Message
  }
}

Assert-FileContains `
  -Path 'android/app/build.gradle.kts' `
  -Pattern 'applicationId\s*=\s*"com\.tebio\.piliplus\.autoclean"' `
  -Message 'AutoClean applicationId was lost.'

Assert-FileContains `
  -Path 'android/app/build.gradle.kts' `
  -Pattern 'abiFilters\s*\+=\s*"arm64-v8a"' `
  -Message 'Android build is no longer restricted to arm64-v8a.'

Assert-FileContains `
  -Path 'android/app/build.gradle.kts' `
  -Pattern 'PiliPlus_AutoClean_android_\$\{flutter\.versionName\}_arm64-v8a\.apk' `
  -Message 'AutoClean APK filename rule was lost.'

Assert-FileContains `
  -Path 'android/app/src/main/java/com/example/piliplus/MediaHelper.java' `
  -Pattern 'package com\.tebio\.piliplus\.autoclean;' `
  -Message 'MediaHelper package no longer matches the AutoClean Android namespace.'

Assert-FileContains `
  -Path 'lib/common/constants.dart' `
  -Pattern 'PiliPlus AutoClean' `
  -Message 'AutoClean app name constant was lost.'

Assert-FileContains `
  -Path 'lib/http/api.dart' `
  -Pattern 'https://api\.github\.com/repos/Tebio/PiliPlus-AutoClean/releases/latest' `
  -Message 'Update check no longer points to the AutoClean fork releases.'

Assert-FileContains `
  -Path 'lib/pages/video/controller.dart' `
  -Pattern 'markWatchLaterAutoRemoveIfNeeded' `
  -Message 'Watch later autoclean marker logic was lost.'

Assert-FileNotContains `
  -Path 'lib/pages/video/view.dart' `
  -Pattern 'void positionListener\(Duration position\)\s*\{[^}]*markWatchLaterAutoRemoveIfNeeded' `
  -Message 'Watch later autoclean is armed by playback progress again.'

Assert-FileContains `
  -Path 'lib/pages/video/controller.dart' `
  -Pattern 'autoRemoveWatchedLaterPending' `
  -Message 'Persistent pending removal queue was lost.'

Assert-FileContains `
  -Path 'lib/pages/video/controller.dart' `
  -Pattern "parts\.length < 7 \|\| parts\[6\] != 'completed'" `
  -Message 'Legacy progress-based pending removals are accepted again.'

Assert-FileContains `
  -Path 'lib/pages/later/controller.dart' `
  -Pattern '_shouldAutoRemoveViewedItem' `
  -Message 'Server-side watched item cleanup was lost.'

Assert-FileContains `
  -Path '.github/workflows/sync-upstream.yml' `
  -Pattern 'Guard AutoClean customizations' `
  -Message 'Upstream sync no longer guards AutoClean customizations.'

Assert-FileContains `
  -Path '.github/workflows/sync-upstream.yml' `
  -Pattern 'Flutter analyze' `
  -Message 'Upstream sync no longer validates merged Dart code.'

Assert-FileContains `
  -Path '.github/workflows/build.yml' `
  -Pattern 'Report build failure' `
  -Message 'Build failure issue reporting was lost.'

Assert-FileContains `
  -Path 'lib/pages/video/controller.dart' `
  -Pattern 'autoRemoveWatchedLaterTitleKeywords' `
  -Message 'Watch later title keyword protection was lost.'

Assert-FileContains `
  -Path 'lib/pages/video/controller.dart' `
  -Pattern 'autoRemoveWatchedLaterUpMids' `
  -Message 'Watch later UP protection was lost.'

Assert-FileContains `
  -Path 'lib/pages/video/controller.dart' `
  -Pattern 'autoRemoveWatchedLaterMinDuration' `
  -Message 'Watch later duration protection was lost.'

Assert-FileNotContains `
  -Path 'lib/pages/later/view.dart' `
  -Pattern "clean_type:\s*null" `
  -Message 'Dangerous watch later clear-all action is visible again.'

Write-Host 'AutoClean guard checks passed.'
