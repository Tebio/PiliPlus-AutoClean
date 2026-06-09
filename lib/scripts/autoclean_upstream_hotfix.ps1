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

$SliderDialog = "lib/pages/setting/widgets/slider_dialog.dart"
if (Test-Path -LiteralPath $SliderDialog) {
    $content = Get-Content -LiteralPath $SliderDialog -Raw
    $fixed = $content
    $fixed = $fixed -replace "final Widget title;", "final Object title;"
    $fixed = $fixed -replace "title: widget\.title,", "title: widget.title is Widget ? widget.title as Widget : Text(widget.title.toString()),"
    if ($fixed -ne $content) {
        Set-Content -LiteralPath $SliderDialog -Value $fixed -Encoding utf8
        Write-Host "Applied AutoClean hotfix: SliderDialog title compatibility."
    }
}
