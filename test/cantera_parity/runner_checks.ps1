param([Parameter(Mandatory)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
$destination=[IO.Path]::GetFullPath($OutputDirectory,(Get-Location).Path)
if(Test-Path -LiteralPath $destination){throw 'Choose fresh evidence directory'}
$null=New-Item -ItemType Directory -Path $destination
. (Join-Path $PSScriptRoot 'run_solver_regressions.ps1')
$shell=(Get-Command pwsh).Source
$checks=[Collections.Generic.List[string]]::new()
function Check($condition,$label){if(-not $condition){throw "FAILED: $label"}; $checks.Add($label)}
function Child($name,$body){$path=Join-Path $destination "$name.ps1"; Set-Content $path $body -Encoding utf8; return $path}
$normal=Child 'normal with spaces' 'Write-Output "Cantera parity: fake | 2 2 1m02.5s"; [Console]::Error.WriteLine("diagnostic"); exit 0'
$r=Invoke-ParityProcess $shell @('-NoProfile','-File',$normal) $destination (Join-Path $destination 'normal') 20
Check ($r.status -eq 'completed' -and $r.exit_code -eq 0) 'successful child including space-containing path'
$times=@(Get-ParityTimings (Join-Path $destination 'normal/stdout.log'))
Check ($times.Count -eq 1 -and $times[0].testset_seconds -eq 62.5) 'duration units parsed'
Check ((Get-Content (Join-Path $destination 'normal/stderr.log') -Raw).Contains('diagnostic')) 'stderr retained'
$failed=Child 'failed' 'Write-Output "before failure"; exit 7'
$r=Invoke-ParityProcess $shell @('-NoProfile','-File',$failed) $destination (Join-Path $destination 'failed') 20
Check ($r.status -eq 'failed' -and $r.exit_code -eq 7) 'nonzero child cannot pass'
$r=Invoke-ParityProcess (Join-Path $destination 'missing.exe') @('x') $destination (Join-Path $destination 'missing') 20
Check ($r.status -eq 'launch_failed' -and $null -eq $r.exit_code -and $r.error) 'launch failure recorded without invented exit code'
$rejected=$false
try {Invoke-ParityProcess $shell @('-NoProfile') $destination (Join-Path $destination 'normal') 20} catch {$rejected=$true}
Check $rejected 'existing evidence cannot be overwritten'
$rejected=$false
try {Invoke-ParityProcess $shell @('-NoProfile') $destination (Join-Path $destination 'zero') 0} catch {$rejected=$true}
Check $rejected 'zero timeout rejected before launch'
$leaf=Child 'leaf' 'Start-Sleep -Seconds 120'
$parent=Child 'parent' @'
param($leaf,$marker)
$child=Start-Process -FilePath (Get-Command pwsh).Source -ArgumentList @('-NoProfile','-File',('"'+$leaf+'"')) -WindowStyle Hidden -PassThru
$child.Id | Set-Content $marker
Write-Output 'partial output before timeout'
Start-Sleep -Seconds 120
'@
$marker=Join-Path $destination 'child.pid'
$r=Invoke-ParityProcess $shell @('-NoProfile','-File',$parent,$leaf,$marker) $destination (Join-Path $destination 'timeout') 5
Check ($r.status -eq 'timed_out') 'deadline has distinct timeout status'
Check ((Get-Content (Join-Path $destination 'timeout/stdout.log') -Raw).Contains('partial output')) 'partial output retained'
$childPid=[int](Get-Content $marker)
Check ($null -eq (Get-Process -Id $childPid -ErrorAction SilentlyContinue)) 'timed-out descendant terminated'
$bad=Join-Path $destination 'bad-summary.log'
Set-Content $bad 'Cantera parity: failed | 2 1 3 0.1s'
Check (@(Get-ParityTimings $bad).Count -eq 0) 'failed summary not misread as successful two-count row'
@{passed=$checks.Count;checks=@($checks)} | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $destination 'checks.json') -Encoding utf8
Get-Content (Join-Path $destination 'checks.json')
