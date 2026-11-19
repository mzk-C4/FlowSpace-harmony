$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$phone=Join-Path $root 'tools/test-phone.ps1'
$build=Join-Path $root 'tools/build-harmony.ps1'
$stage=Join-Path $env:TEMP ('FlowSpace-phone-test-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $stage | Out-Null
$previousMode=$env:FLOWSPACE_TEST_HDC_MODE; $previousLog=$env:FLOWSPACE_TEST_HDC_LOG
$env:FLOWSPACE_TEST_HDC_MODE=Join-Path $stage 'mode.txt'
$env:FLOWSPACE_TEST_HDC_LOG=Join-Path $stage 'calls.txt'
$mock=Join-Path $stage 'hdc.ps1'
@'
$global:LASTEXITCODE=0
Add-Content -LiteralPath $env:FLOWSPACE_TEST_HDC_LOG -Value ($args -join '|')
if ($args[0] -eq '-h') { 'install [-r] src'; 'rport remotenode localnode'; return }
if ($args[0] -eq 'list' -and $args[1] -eq 'targets') {
  switch ((Get-Content -LiteralPath $env:FLOWSPACE_TEST_HDC_MODE -Raw).Trim()) {
    'none' { '[Empty]' }
    'many' { 'PHONE_A'; 'PHONE_B' }
    'one' { 'PHONE_A' }
  }
  return
}
throw 'Unexpected device mutation during blocked preflight'
'@ | Set-Content -LiteralPath $mock -Encoding utf8
$passed=0
function Assert-True([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Expect-Throw([scriptblock]$Action,[string]$Pattern) {
  $caught=$false
  try { & $Action | Out-Null } catch { $caught=$_.Exception.Message -match $Pattern }
  Assert-True $caught "Expected rejection: $Pattern"
}
try {
  foreach ($path in @($phone,$build)) {
    $errors=$null; $null=[Management.Automation.Language.Parser]::ParseFile($path,[ref]$null,[ref]$errors)
    Assert-True ($errors.Count -eq 0) 'PowerShell syntax error'
  }; $passed++
  $result=& $build -DryRun
  Assert-True ($result.Status -eq 'ReadyForUnsignedBuild' -and -not $result.SignedHapVerified) 'Unsigned dryrun mislabeled'; $passed++
  Set-Content $env:FLOWSPACE_TEST_HDC_MODE none
  $result=& $phone -HdcPath $mock -DryRun
  Assert-True ($result.Status -eq 'Pending' -and -not $result.DeviceMutated -and $result.Pending.Count -ge 2) 'Missing-device preflight not actionable'; $passed++
  Expect-Throw { & $phone -HdcPath $mock } '真机测试待办'; $passed++
  Set-Content $env:FLOWSPACE_TEST_HDC_MODE many
  $result=& $phone -HdcPath $mock -DryRun
  Assert-True (($result.Pending -join '') -match '多个设备') 'Multiple devices were automatically chosen'; $passed++
  $result=& $phone -HdcPath $mock -DeviceId OTHER -DryRun
  Assert-True (($result.Pending -join '') -match '不在当前') 'Missing requested device ignored'; $passed++
  Expect-Throw { & $phone -HdcPath $mock -DeviceId 'phone; bad' -DryRun } '设备ID'; $passed++
  Expect-Throw { & $phone -HdcPath $mock -GatewayPort 1 -DryRun } '端口'; $passed++
  $result=& $phone -HdcPath $mock -Hap (Join-Path $stage 'absent.hap') -DryRun
  Assert-True (($result.Pending -join '') -match '不存在') 'Missing HAP ignored'; $passed++
  $unsigned=Join-Path $root 'artifacts/entry-default-unsigned.hap'
  if (-not (Test-Path $unsigned)) { throw 'Unsigned build artifact required for real verifier rejection regression.' }
  Set-Content $env:FLOWSPACE_TEST_HDC_MODE one
  $result=& $phone -HdcPath $mock -Hap $unsigned -DryRun
  Assert-True (-not $result.SignedHapVerified -and ($result.Pending -join '') -match 'verify-app未通过') 'Official verifier accepted unsigned HAP'; $passed++
  Expect-Throw { & $phone -HdcPath $mock -Hap $unsigned } 'verify-app未通过'; $passed++
  $external=Join-Path $stage 'external'; New-Item -ItemType Directory (Join-Path $external 'AppScope') -Force | Out-Null
  '{"app":{"bundleName":"different.bundle"}}' | Set-Content (Join-Path $external 'AppScope/app.json5')
  '{"app":{"signingConfigs":[]}}' | Set-Content (Join-Path $external 'build-profile.json5')
  Expect-Throw { & $build -SigningProject $external -DryRun } '签名预检'; $passed++
  '{"app":{"bundleName":"com.mzk.flowspace"}}' | Set-Content (Join-Path $external 'AppScope/app.json5')
  Expect-Throw { & $build -SigningProject $external -DryRun } '签名预检'; $passed++
  $calls=Get-Content -LiteralPath $env:FLOWSPACE_TEST_HDC_LOG
  Assert-True (-not ($calls | Where-Object {$_ -notin @('-h','list|targets')})) 'Blocked workflow performed a device mutation'; $passed++
  [pscustomobject]@{Passed=$passed; Failed=0; Scope='Native script logic + strict hdc boundary; real Java verifier rejects existing unsigned HAP. No actual device/install/signature created.'}
} finally {
  $env:FLOWSPACE_TEST_HDC_MODE=$previousMode; $env:FLOWSPACE_TEST_HDC_LOG=$previousLog
  $absolute=[IO.Path]::GetFullPath($stage); $tempBase=[IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\'
  if ($absolute.StartsWith($tempBase,[StringComparison]::OrdinalIgnoreCase) -and (Split-Path $absolute -Leaf).StartsWith('FlowSpace-phone-test-')) { Remove-Item -LiteralPath $absolute -Recurse -Force }
}
