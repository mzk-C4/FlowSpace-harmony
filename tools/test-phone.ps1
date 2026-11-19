[CmdletBinding()]
param(
  [string]$Hap,
  [string]$DeviceId,
  [string]$Toolchain='E:\harmony system\command-line-tools',
  [string]$JavaHome=$env:JAVA_HOME,
  [string]$HdcPath,
  [int]$GatewayPort=8787,
  [switch]$MapGateway,
  [switch]$DryRun
)
$ErrorActionPreference='Stop'

function Test-FlowSpaceAbilityRecord([string]$Dump) {
  # Official AbilityRecord::Dump / DumpAbilityState format:
  # https://github.com/openharmony/ability_ability_runtime/blob/master/services/abilitymgr/src/ability_record.cpp
  # AbilityRecord ID #N -> app name [...] -> main name [...] -> bundle name [...].
  # Require the adjacent identity fields inside one explicitly headed record.
  # Unknown layouts fail closed; never join names found anywhere in the dump.
  $lines=@($Dump -split '\r?\n')
  $inRecord=$false
  for ($index=0; $index -lt $lines.Count; $index++) {
    $line=$lines[$index]
    if ($line -cmatch '^[ \t]*AbilityRecord ID #[0-9]+[ \t]*$') { $inRecord=$true; continue }
    if ($line -cmatch '^[ \t]*(?:MissionList|Mission|User ID|AbilityRecord)(?:[ \t:#]|$)') { $inRecord=$false; continue }
    if (-not $inRecord -or $index+1 -ge $lines.Count) { continue }
    if ($line -cmatch '^[ \t]*main name \[(?<ability>[^\]\r\n]+)\][ \t]*$') {
      $ability=$Matches.ability
      if ($lines[$index+1] -cmatch '^[ \t]*bundle name \[(?<bundle>[^\]\r\n]+)\][ \t]*$') {
        if ($ability -ceq 'EntryAbility' -and $Matches.bundle -ceq 'com.mzk.flowspace') { return $true }
      }
    }
  }
  return $false
}

$root=Split-Path -Parent $PSScriptRoot
if (-not $HdcPath) { $HdcPath=Join-Path $Toolchain 'sdk/default/openharmony/toolchains/hdc.exe' }
if (-not (Test-Path -LiteralPath $HdcPath)) { throw '未找到hdc，请指定-Toolchain。' }
if ($GatewayPort -lt 1024 -or $GatewayPort -gt 65535) { throw '网关端口应为1024–65535。' }
if ($DeviceId -and $DeviceId -notmatch '^[A-Za-z0-9_.:-]+$') { throw '设备ID含不支持字符，请复制hdc list targets中的connect key。' }
$help=(& $HdcPath -h 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0 -or $help -notmatch 'install.*-r') { throw 'hdc不支持预期的更新安装参数，请检查本机-h。' }
$listing=(& $HdcPath list targets 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0) { throw '无法枚举设备，请检查USB驱动和hdc授权。' }
$targets=@($listing -split '\r?\n' | ForEach-Object {$_.Trim()} | Where-Object { $_ -and $_ -notmatch 'Empty|No connected|\[Fail\]' -and $_ -match '^[A-Za-z0-9_.:-]+$' })
$pending=[Collections.Generic.List[string]]::new()
if ($targets.Count -eq 0) { $pending.Add('连接手机，开启开发者选项和USB调试，并在解锁手机上允许本电脑。') }
elseif (-not $DeviceId -and $targets.Count -eq 1) { $DeviceId=$targets[0] }
elseif (-not $DeviceId) { $pending.Add('检测到多个设备，必须传-DeviceId，避免安装到错误设备。') }
if ($DeviceId -and $DeviceId -notin $targets) { $pending.Add('指定设备不在当前hdc设备列表中。') }
if (-not $Hap) { $pending.Add('传入本项目已签名HAP的绝对路径-Hap；文件名含signed不能证明有效。') }
elseif (-not (Test-Path -LiteralPath $Hap -PathType Leaf)) { $pending.Add('指定HAP不存在。') }
if (-not $JavaHome -or -not (Test-Path (Join-Path $JavaHome 'bin/java.exe'))) {
  foreach ($candidate in @('D:/projects/tools/jdk17/jdk-17.0.19+10','E:/Program Files/PyCharm 2026.2.2/jbr')) { if (Test-Path (Join-Path $candidate 'bin/java.exe')) { $JavaHome=$candidate; break } }
}
$signTool=Join-Path $Toolchain 'sdk/default/openharmony/toolchains/lib/hap-sign-tool.jar'
if (-not $JavaHome -or -not (Test-Path $signTool)) { $pending.Add('需要可用JDK和官方hap-sign-tool.jar验证实际HAP。') }
$verified=$false
if ($Hap -and (Test-Path -LiteralPath $Hap -PathType Leaf) -and $JavaHome -and (Test-Path $signTool)) {
  $Hap=(Resolve-Path -LiteralPath $Hap).Path
  # Check the actual package identity, not its name or caller-supplied flags.
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip=[IO.Compression.ZipFile]::OpenRead($Hap)
  try {
    $entry=$zip.GetEntry('module.json'); if (-not $entry) { throw 'HAP缺少module.json。' }
    $reader=[IO.StreamReader]::new($entry.Open())
    try { $metadata=$reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
    if ($metadata.app.bundleName -ne 'com.mzk.flowspace') { throw 'HAP不是当前FlowSpace应用，拒绝安装。' }
  } finally { $zip.Dispose() }
  $verifyDir=Join-Path $env:TEMP ('FlowSpace-hap-verify-'+[Guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $verifyDir | Out-Null
  try {
    $privateOutput=& (Join-Path $JavaHome 'bin/java.exe') -jar $signTool verify-app -inFile $Hap -outCertChain (Join-Path $verifyDir 'chain.cer') -outProfile (Join-Path $verifyDir 'profile.p7b') 2>&1
    $verified=$LASTEXITCODE -eq 0 -and (Test-Path (Join-Path $verifyDir 'profile.p7b'))
    if (-not $verified) { $pending.Add('官方verify-app未通过：请使用同一bundleName和当前设备授权的合法DevEco签名构建；不要安装unsigned包。') }
  } finally {
    $absolute=[IO.Path]::GetFullPath($verifyDir); $tempBase=[IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\'
    if ($absolute.StartsWith($tempBase,[StringComparison]::OrdinalIgnoreCase) -and (Split-Path $absolute -Leaf).StartsWith('FlowSpace-hap-verify-')) { Remove-Item -LiteralPath $absolute -Recurse -Force }
    $privateOutput=$null
  }
}
if ($DryRun) {
  [pscustomobject]@{Status=$(if($pending.Count){'Pending'}else{'ReadyForDevicePreflight'}); DeviceId=$DeviceId; SignedHapVerified=$verified; Pending=$pending.ToArray(); DeviceMutated=$false; BackendAddress="http://127.0.0.1:$GatewayPort"}
  return
}
if ($pending.Count) { throw ('真机测试待办：'+($pending -join '；')) }
function Invoke-Device([string[]]$Arguments) {
  $result=(& $HdcPath -t $DeviceId @Arguments 2>&1 | Out-String)
  if ($LASTEXITCODE -ne 0 -or $result -match '\[Fail\]|error:|Error:') { throw '设备命令失败；保留现有应用及数据，请先检查设备授权/签名/API。' }
  return $result
}
$api=(Invoke-Device -Arguments @('shell','param','get','const.ohos.apiversion')).Trim()
if ($api -notmatch '^\d+$' -or [int]$api -lt 24) { throw '设备API版本无法核对或低于24，停止安装。' }
$deviceType=(Invoke-Device -Arguments @('shell','param','get','const.product.devicetype')).Trim()
if ($deviceType -notin @('phone','default')) { throw '目标不是已识别的手机，请确认设备类型；未安装应用。' }
# Device-side command capabilities are inspected before performing mutations.
$aaHelp=Invoke-Device -Arguments @('shell','aa','help')
$bmHelp=Invoke-Device -Arguments @('shell','bm','help')
if ($aaHelp -notmatch 'start' -or $aaHelp -notmatch 'dump' -or $bmHelp -notmatch 'dump') { throw '设备aa/bm帮助与预期不符，停止并请手动核对命令。' }
if ($MapGateway) {
  if ($help -notmatch 'rport remotenode localnode') { throw 'hdc不支持已核对的rport格式。' }
  $null=Invoke-Device -Arguments @('rport',"tcp:$GatewayPort","tcp:$GatewayPort")
}
$installation=Invoke-Device -Arguments @('install','-r',$Hap)
if ($installation -notmatch '(?i)success') { throw '安装未返回成功证据，停止启动；不会卸载或清数据。' }
$bundle=Invoke-Device -Arguments @('shell','bm','dump','-n','com.mzk.flowspace')
if ($bundle -notmatch 'com\.mzk\.flowspace' -or $bundle -notmatch 'EntryAbility') { throw '安装后的包/Ability无法核对。' }
$started=Invoke-Device -Arguments @('shell','aa','start','-a','EntryAbility','-b','com.mzk.flowspace')
if ($started -notmatch '(?i)success|start ability successfully') { throw 'Ability启动未返回成功证据。' }
$running=$false
for ($attempt=0; $attempt -lt 5; $attempt++) {
  $active=Invoke-Device -Arguments @('shell','aa','dump','-a')
  if (Test-FlowSpaceAbilityRecord -Dump $active) { $running=$true; break }
  Start-Sleep -Milliseconds 500
}
if (-not $running) { throw '启动命令已执行，但未在同一AbilityRecord中核对到包与EntryAbility；输出格式也可能不受支持，请检查实际aa输出及手机界面；未清数据。' }
[pscustomobject]@{Status='InstalledAndAbilityObserved'; DeviceId=$DeviceId; ApiVersion=[int]$api; Bundle='com.mzk.flowspace'; Ability='EntryAbility'; SignedHapVerified=$verified; UpdateInstall=$true; GatewayMapped=[bool]$MapGateway; BackendAddress="http://127.0.0.1:$GatewayPort"; Note='已核对包和Ability运行；实际点击、导图/AI/导入导出仍需在手机验收。'}
