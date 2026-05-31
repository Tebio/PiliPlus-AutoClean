param(
    [string]$Arg = ''
)

try {
    $versionName = $null

    $commitCount = [int](git rev-list --count HEAD).Trim()
    $runNumber = if ($env:GITHUB_RUN_NUMBER) { [int]$env:GITHUB_RUN_NUMBER } else { 0 }
    $versionCode = if ($runNumber -gt 0) { $commitCount * 1000 + $runNumber } else { $commitCount }

    $commitHash = (git rev-parse HEAD).Trim()

    $updatedContent = foreach ($line in (Get-Content -Path 'pubspec.yaml' -Encoding UTF8)) {
        if ($line -match '^\s*version:\s*([^\+\s]+)(?:\+\d+)?') {
            $upstreamVersionName = $matches[1]
            $versionName = "$upstreamVersionName-AutoClean.$($commitHash.Substring(0, 9))"
            if ($Arg -eq 'android') {
                $versionName = "$versionName.b$versionCode"
            }
            "version: $versionName+$versionCode"
        }
        else {
            $line
        }
    }

    if ($null -eq $versionName) {
        throw 'version not found'
    }

    $updatedContent | Set-Content -Path 'pubspec.yaml' -Encoding UTF8

    $buildTime = [int]([DateTimeOffset]::Now.ToUnixTimeSeconds())

    $data = @{
        'pili.name' = $versionName
        'pili.code' = $versionCode
        'pili.hash' = $commitHash
        'pili.time' = $buildTime
    }

    $data | ConvertTo-Json -Compress | Out-File 'pili_release.json' -Encoding UTF8

    Add-Content -Path $env:GITHUB_ENV -Value "version=$versionName+$versionCode"
}
catch {
    Write-Error "Prebuild Error: $($_.Exception.Message)"
    exit 1
}
