[CmdletBinding()]
param(
  [string]$Toolchain='E:\harmony system\command-line-tools',
  [string]$JavaHome=$env:JAVA_HOME,
  [string]$SigningProject,
  [string]$SigningConfigName='default',
  [string]$OutputDirectory,
  [switch]$DryRun
)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$toolchainPath=(Resolve-Path -LiteralPath $Toolchain).Path
$hvigorPath=Join-Path $toolchainPath 'hvigor/bin/hvigorw.bat'
$node=Join-Path $toolchainPath 'tool/node/node.exe'
$json5=Join-Path $toolchainPath 'hvigor/hvigor-ohos-plugin/node_modules/json5'
$signTool=Join-Path $toolchainPath 'sdk/default/openharmony/toolchains/lib/hap-sign-tool.jar'
if (-not (Test-Path $hvigorPath)) { throw '未找到 Hvigor，请设置 -Toolchain。' }
if (-not $JavaHome -or -not (Test-Path (Join-Path $JavaHome 'bin/java.exe'))) {
  foreach ($candidate in @('D:/projects/tools/jdk17/jdk-17.0.19+10','E:/Program Files/PyCharm 2026.2.2/jbr')) {
    if (Test-Path (Join-Path $candidate 'bin/java.exe')) { $JavaHome=$candidate; break }
  }
}
if (-not $JavaHome -or -not (Test-Path (Join-Path $JavaHome 'bin/java.exe'))) { throw '请用 -JavaHome 指定 JDK。' }
$java=Join-Path $JavaHome 'bin/java.exe'
if (-not $OutputDirectory) { $OutputDirectory=Join-Path $projectRoot 'artifacts' }
$output=[IO.Path]::GetFullPath($OutputDirectory)
$external=''
if ($SigningProject) {
  $external=(Resolve-Path -LiteralPath $SigningProject).Path
  if ($external -eq $projectRoot -or $external.StartsWith($projectRoot.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) { throw '签名工程应位于当前仓库外，避免凭据进入 Git。' }
  if (-not (Test-Path $signTool)) { throw '缺少官方 hap-sign-tool.jar。' }
}
# Only the requested existing app's DevEco signing config is imported; never print its contents.
$prepare=@'
const fs=require('fs'),path=require('path');
const [root,external,stage,name,json5path]=process.argv.slice(2),JSON5=require(json5path);
const read=p=>JSON5.parse(fs.readFileSync(p,'utf8').replace(/^\uFEFF/,''));
try {
 const profile=read(path.join(root,'build-profile.json5'));
 if(external) {
  const bundle=read(path.join(root,'AppScope/app.json5')).app.bundleName;
  if(read(path.join(external,'AppScope/app.json5')).app.bundleName!==bundle) throw Error();
  const cfg=read(path.join(external,'build-profile.json5')).app.signingConfigs.find(c=>c.name===name);
  if(!cfg || !cfg.material || !cfg.material.keyAlias || !cfg.material.signAlg) throw Error();
  for(const key of ['storeFile','certpath','profile']) {
   if(typeof cfg.material[key]!=='string' || !cfg.material[key]) throw Error();
   const p=path.resolve(external,cfg.material[key]); if(!fs.statSync(p).isFile()) throw Error(); cfg.material[key]=p;
  }
  profile.app.signingConfigs=[cfg]; profile.app.products.forEach(p=>p.signingConfig=name);
 } else { profile.app.signingConfigs=[];profile.app.products.forEach(p=>delete p.signingConfig); }
 if(stage) fs.writeFileSync(path.join(stage,'build-profile.json5'),JSON.stringify(profile,null,2));
} catch (_) {console.error('签名配置不可用：请确认同一bundleName、配置名与材料路径；未输出任何配置内容。');process.exit(1);}
'@
$prepare | & $node - $projectRoot $external '' $SigningConfigName $json5
if ($LASTEXITCODE -ne 0) { throw '签名预检失败，不会生成或借用证书。' }
if ($DryRun) {
  [pscustomobject]@{Status=$(if($external){'ReadyForSignedBuild'}else{'ReadyForUnsignedBuild'}); SignedHapVerified=$false; OutputDirectory=$output; NextStep=$(if($external){'去掉-DryRun构建，并由verify-app核验。'}else{'在外部DevEco工程配置本应用签名后传-SigningProject；unsigned不能用于手机安装。'})}
  return
}
$stage=Join-Path $env:TEMP ('FlowSpace-build-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage | Out-Null
$oldSdk=$env:DEVECO_SDK_HOME; $oldNode=$env:NODE_HOME; $oldJava=$env:JAVA_HOME; $oldPath=$env:PATH
try {
  if ($external) {
    $account=[Security.Principal.WindowsIdentity]::GetCurrent().Name
    & icacls.exe $stage /inheritance:r /grant:r "${account}:(OI)(CI)F" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw '无法保护临时签名目录。' }
  }
  foreach ($name in @('AppScope','hvigor')) { Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination $stage -Recurse }
  New-Item -ItemType Directory -Path (Join-Path $stage 'entry') | Out-Null
  Copy-Item -LiteralPath (Join-Path $projectRoot 'entry/src') -Destination (Join-Path $stage 'entry') -Recurse
  foreach ($name in @('build-profile.json5','oh-package.json5','hvigorfile.ts')) { Copy-Item -LiteralPath (Join-Path $projectRoot "entry/$name") -Destination (Join-Path $stage 'entry') }
  foreach ($name in @('oh-package.json5','hvigorfile.ts')) { Copy-Item -LiteralPath (Join-Path $projectRoot $name) -Destination $stage }
  $prepare | & $node - $projectRoot $external $stage $SigningConfigName $json5
  if ($LASTEXITCODE -ne 0) { throw '准备配置失败。' }
  Set-Content -LiteralPath (Join-Path $stage 'local.properties') -Value ('hwsdk.dir='+(Join-Path $toolchainPath 'sdk').Replace('\','\\')) -Encoding utf8
  $env:DEVECO_SDK_HOME=Join-Path $toolchainPath 'sdk'; $env:NODE_HOME=Join-Path $toolchainPath 'tool/node'
  $env:JAVA_HOME=$JavaHome; $env:PATH=(Join-Path $JavaHome 'bin')+';'+$env:PATH
  Push-Location -LiteralPath $stage
  try {
    if ($external) { $privateOutput=& $hvigorPath --mode module -p product=default -p module=entry@default -p buildMode=debug assembleHap --no-daemon 2>&1 }
    else { & $hvigorPath --mode module -p product=default -p module=entry@default -p buildMode=debug assembleHap --no-daemon }
    if ($LASTEXITCODE -ne 0) { throw '构建失败。签名构建请在本机DevEco检查，脚本不输出可能含凭据的原始日志。' }
  } finally { Pop-Location }
  $haps=@(Get-ChildItem -LiteralPath (Join-Path $stage 'entry/build') -Filter '*.hap' -Recurse)
  if ($haps.Count -eq 0) { throw '没有产出HAP。' }
  New-Item -ItemType Directory -Path $output -Force | Out-Null
  $verified=@()
  foreach ($hap in $haps) {
    if ($external) {
      $dir=Join-Path $stage ('verify-'+[Guid]::NewGuid().ToString('N')); New-Item -ItemType Directory $dir | Out-Null
      $privateOutput=& $java -jar $signTool verify-app -inFile $hap.FullName -outCertChain (Join-Path $dir 'chain.cer') -outProfile (Join-Path $dir 'profile.p7b') 2>&1
      if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $dir 'profile.p7b'))) { continue }
      $verified+=Join-Path $output $hap.Name
    }
    Copy-Item -LiteralPath $hap.FullName -Destination $output
  }
  if ($external -and $verified.Count -eq 0) { throw '没有通过官方verify-app的HAP，不能用于真机安装。' }
  [pscustomobject]@{Status=$(if($external){'SignedVerified'}else{'UnsignedBuilt'}); OutputDirectory=$output; VerifiedSignedHaps=$verified}
} finally {
  $env:DEVECO_SDK_HOME=$oldSdk; $env:NODE_HOME=$oldNode; $env:JAVA_HOME=$oldJava; $env:PATH=$oldPath
  if ($external) {
    $absolute=[IO.Path]::GetFullPath($stage); $tempBase=[IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\'
    if ($absolute.StartsWith($tempBase,[StringComparison]::OrdinalIgnoreCase) -and (Split-Path $absolute -Leaf).StartsWith('FlowSpace-build-')) { Remove-Item -LiteralPath $absolute -Recurse -Force }
    $privateOutput=$null
  } else { Write-Output "编译工程：$stage" }
}
