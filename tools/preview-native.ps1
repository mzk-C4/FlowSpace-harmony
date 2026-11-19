param(
  [string]$Toolchain = 'E:\harmony system\command-line-tools',
  [string]$JavaHome = 'D:\projects\tools\jdk17\jdk-17.0.19+10',
  [ValidateSet('light', 'dark')][string]$ColorMode = 'light',
  [string]$Page = 'pages/Index',
  [int]$Width = 1080,
  [int]$Height = 2340,
  [switch]$CaptureAll,
  [string]$StepsPath = ''
)
$ErrorActionPreference = 'Stop'
# Actual SDK PreviewBuild + Previewer native render protocol, never a web mock.
# All source and local.properties are copied into an English temporary project.
# Previewer uses SDK-provided API substitutes; database/device/AI are NOT verified.
$projectRoot = Split-Path -Parent $PSScriptRoot
$stage = Join-Path $env:TEMP ('FlowSpace-native-preview-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage | Out-Null
foreach ($name in @('AppScope', 'entry', 'hvigor')) {
  if ($name -eq 'entry') {
    New-Item -ItemType Directory -Path (Join-Path $stage 'entry') | Out-Null
    Copy-Item -LiteralPath (Join-Path $projectRoot 'entry\src') -Destination (Join-Path $stage 'entry') -Recurse
    foreach ($file in @('build-profile.json5', 'oh-package.json5', 'hvigorfile.ts')) {
      Copy-Item -LiteralPath (Join-Path $projectRoot "entry\$file") -Destination (Join-Path $stage 'entry')
    }
  } else { Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination $stage -Recurse }
}
foreach ($name in @('build-profile.json5', 'oh-package.json5', 'hvigorfile.ts')) {
  Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination $stage
}
Set-Content -LiteralPath (Join-Path $stage 'local.properties') -Value ('hwsdk.dir=' + (Join-Path $Toolchain 'sdk').Replace('\', '/')) -Encoding utf8
$savedSdk = $env:DEVECO_SDK_HOME
$savedNode = $env:NODE_HOME
$savedJava = $env:JAVA_HOME
$savedPath = $env:PATH
$savedToolchain = $env:FLOWSPACE_TOOLCHAIN
$savedWidth = $env:FLOWSPACE_PREVIEW_WIDTH
$savedHeight = $env:FLOWSPACE_PREVIEW_HEIGHT
try {
  $env:FLOWSPACE_TOOLCHAIN = $Toolchain
  $env:FLOWSPACE_PREVIEW_WIDTH = $Width.ToString()
  $env:FLOWSPACE_PREVIEW_HEIGHT = $Height.ToString()
  $env:DEVECO_SDK_HOME = Join-Path $Toolchain 'sdk'
  $env:NODE_HOME = Join-Path $Toolchain 'tool\node'
  $env:JAVA_HOME = $JavaHome
  $env:PATH = (Join-Path $JavaHome 'bin') + ';' + $env:PATH
  Push-Location -LiteralPath $stage
  try {
    $buildLog = Join-Path $stage 'preview-build.log'
    $buildErrorLog = Join-Path $stage 'preview-build-error.log'
    $buildArgs = @(('"' + (Join-Path $Toolchain 'hvigor\bin\hvigorw.js') + '"'), '--mode', 'module', '-p', 'product=default', '-p', 'module=entry@default', '-p', 'buildMode=debug', '-p', 'pageType=page', '-p', 'previewMode=true', '-p', 'buildRoot=.preview', 'PreviewBuild', '--no-daemon')
    $buildProcess = Start-Process -FilePath (Join-Path $env:NODE_HOME 'node.exe') -ArgumentList $buildArgs -WorkingDirectory $stage -WindowStyle Hidden -PassThru -RedirectStandardOutput $buildLog -RedirectStandardError $buildErrorLog
    $built = $false
    try {
      for ($attempt = 0; $attempt -lt 240; $attempt++) {
        $buildText = ''
        if (Test-Path -LiteralPath $buildLog) {
          $logStream = [IO.File]::Open($buildLog, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
          $logReader = [IO.StreamReader]::new($logStream)
          try { $buildText = $logReader.ReadToEnd() } finally { $logReader.Dispose() }
        }
        if ($buildText.Contains('BUILD SUCCESSFUL')) { $built = $true; break }
        if ($buildProcess.HasExited) { break }
        Start-Sleep -Milliseconds 250
      }
    } finally {
      # PreviewBuild deliberately leaves its watch worker alive. Stop ONLY this
      # isolated build process tree after the official completed-build marker.
      if (-not $buildProcess.HasExited) { & taskkill /PID $buildProcess.Id /T /F 2>$null | Out-Null }
    }
    if (-not $built) { Get-Content $buildLog -Tail 40; Get-Content $buildErrorLog -Tail 20; throw "Native PreviewBuild failed or timed out. Log: $buildLog" }
  } finally { Pop-Location }
  $output = Join-Path $projectRoot 'artifacts\native-preview'
  New-Item -ItemType Directory -Path $output -Force | Out-Null
  Set-Content -LiteralPath (Join-Path $output 'last-stage.txt') -Value $stage -Encoding utf8
  Copy-Item -LiteralPath (Join-Path $stage 'preview-build.log') -Destination (Join-Path $output 'preview-build.log')
  if ($CaptureAll -and -not $StepsPath) {
    $StepsPath = Join-Path $stage 'capture-steps.json'
    $tabY = $Height - 90
    $diyStep = @{name='diy';tap=@([int]($Width * 3 / 8), $tabY)}
    # At the standard inspected phone viewport, open the actual built-in example.
    # Smaller viewports may need scrolling; navigate by its responsive tab there.
    if ($Width -eq 1080 -and $Height -eq 2340) { $diyStep = @{name='diy';tap=@(915,1490);waitMs=1600} }
    @($diyStep, @{name='library';tap=@([int]($Width * 5 / 8), $tabY)}, @{name='profile';tap=@([int]($Width * 7 / 8), $tabY)}) |
      ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $StepsPath -Encoding utf8
  }
  $captureArgs = @((Join-Path $PSScriptRoot 'preview-native.mjs'), $stage, $Page, $ColorMode)
  if ($StepsPath) { $captureArgs += $StepsPath }
  & node @captureArgs
  if ($LASTEXITCODE -ne 0) { throw "Native render failed. Inspect $output" }
  Write-Output "Native SDK preview only. Staging project: $stage"
} finally {
  $env:DEVECO_SDK_HOME = $savedSdk
  $env:NODE_HOME = $savedNode
  $env:JAVA_HOME = $savedJava
  $env:PATH = $savedPath
  $env:FLOWSPACE_TOOLCHAIN = $savedToolchain
  $env:FLOWSPACE_PREVIEW_WIDTH = $savedWidth
  $env:FLOWSPACE_PREVIEW_HEIGHT = $savedHeight
}
