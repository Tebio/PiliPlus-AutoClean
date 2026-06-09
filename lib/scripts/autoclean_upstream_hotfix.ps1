# AutoClean local hotfixes for temporary upstream issues.
# Keep this file focused on small compatibility fixes that are safe to apply
# after every upstream sync and before Flutter analyze/build.

$GeetestDialog = "lib/pages/login/geetest/geetest_webview_dialog.dart"
if (Test-Path -LiteralPath $GeetestDialog) {
    $content = Get-Content -LiteralPath $GeetestDialog -Raw
    $fixed = $content -replace "return Error\(res\.data\['message'\]\);", "return const Error('获取验证码配置失败');"
    if ($fixed -ne $content) {
        Set-Content -LiteralPath $GeetestDialog -Value $fixed -Encoding utf8
        Write-Host "Applied AutoClean hotfix: Geetest config analyze error."
    }
}
