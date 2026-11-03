param(
  [string]$Toolchain = 'E:\harmony system\command-line-tools',
  [string]$JavaHome = $env:JAVA_HOME
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
${sourceRoot} = $projectRoot
$toolchainPath = (Resolve-Path -LiteralPath $Toolchain).Path
$hvigorPath = Join-Path $toolchainPath 'hvigor\bin\hvigorw.bat'
if (-not (Test-Path -LiteralPath $hvigorPath)) { throw '未找到鸿蒙hvigor，请传入命令行工具目录' }
# Hvigor限制中文路径；复制源码到临时英文路径编译，原工程与已有改动保留。
$stagingRoot = Join-Path $env:TEMP ('FlowSpace-build-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stagingRoot | Out-Null
foreach ($name in @('AppScope', 'entry', 'hvigor')) {
  $destination = Join-Path $stagingRoot $name
  if ($name -eq 'entry') {
    New-Item -ItemType Directory -Path $destination | Out-Null
    Copy-Item -LiteralPath (Join-Path $sourceRoot 'entry\src') -Destination $destination -Recurse
    foreach ($file in @('build-profile.json5', 'oh-package.json5', 'hvigorfile.ts')) { Copy-Item -LiteralPath (Join-Path $sourceRoot "entry\$file") -Destination $destination }
  } else { Copy-Item -LiteralPath (Join-Path $sourceRoot $name) -Destination $stagingRoot -Recurse }
}
foreach ($name in @('build-profile.json5', 'oh-package.json5', 'hvigorfile.ts')) { Copy-Item -LiteralPath (Join-Path $sourceRoot $name) -Destination $stagingRoot }
$sdkPath = (Join-Path $toolchainPath 'sdk').Replace('\', '\\')
Set-Content -LiteralPath (Join-Path $stagingRoot 'local.properties') -Value "hwsdk.dir=$sdkPath" -Encoding utf8
$oldSdk = $env:DEVECO_SDK_HOME
$oldNode = $env:NODE_HOME
$oldJava = $env:JAVA_HOME
$oldPath = $env:PATH
if (-not $JavaHome -or -not (Test-Path -LiteralPath (Join-Path $JavaHome 'bin\java.exe'))) {
  $localJdk = 'D:\projects\tools\jdk17\jdk-17.0.19+10'
  if (Test-Path -LiteralPath (Join-Path $localJdk 'bin\java.exe')) { $JavaHome = $localJdk }
}
if (-not $JavaHome -or -not (Test-Path -LiteralPath (Join-Path $JavaHome 'bin\java.exe'))) {
  foreach ($base in @('C:\Program Files\JetBrains', 'E:\Program Files', 'D:\programs')) {
    $runtime = Get-ChildItem -LiteralPath $base -Filter 'PyCharm*' -Directory -ErrorAction SilentlyContinue |
      ForEach-Object { Join-Path $_.FullName 'jbr' } | Where-Object { Test-Path -LiteralPath (Join-Path $_ 'bin\java.exe') } | Select-Object -First 1
    if ($runtime) { $JavaHome = $runtime; break }
  }
}
if (-not $JavaHome -or -not (Test-Path -LiteralPath (Join-Path $JavaHome 'bin\java.exe'))) { throw '请用-JavaHome传入可用JDK/JBR目录' }
try {
  $env:DEVECO_SDK_HOME = Join-Path $toolchainPath 'sdk'
  $env:NODE_HOME = Join-Path $toolchainPath 'tool\node'
  $env:JAVA_HOME = $JavaHome
  $env:PATH = (Join-Path $JavaHome 'bin') + ';' + $env:PATH
  Push-Location -LiteralPath $stagingRoot
  try {
    & $hvigorPath --mode module -p product=default -p module=entry@default -p buildMode=debug assembleHap --no-daemon
    if ($LASTEXITCODE -ne 0) { throw "鸿蒙编译失败；日志与临时工程保留在 $stagingRoot" }
  } finally { Pop-Location }
  $output = Join-Path $projectRoot 'artifacts'
  New-Item -ItemType Directory -Path $output -Force | Out-Null
  $haps = Get-ChildItem -LiteralPath (Join-Path $stagingRoot 'entry\build') -Filter '*.hap' -Recurse
  if ($haps.Count -eq 0) { throw '编译没有产出HAP' }
  foreach ($hap in $haps) { Copy-Item -LiteralPath $hap.FullName -Destination $output }
  Write-Output "HAP输出：$output"
  Write-Output "编译工程：$stagingRoot"
} finally {
  $env:DEVECO_SDK_HOME = $oldSdk
  $env:NODE_HOME = $oldNode
  $env:JAVA_HOME = $oldJava
  $env:PATH = $oldPath
}
