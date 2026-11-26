# Windows / PowerShell 7 process-level deadline; numerical solver settings are untouched.
param(
    [string[]]$Cases=@('all'),
    [int]$TimeoutSeconds=0,
    [string]$OutputDirectory,
    [string]$Julia='julia'
)

function Invoke-ParityProcess {
    param([string]$Executable,[string[]]$Arguments,[string]$Directory,
          [string]$Output,[int]$Seconds)
    if($Seconds -lt 1 -or $Seconds -gt 86400){throw 'Specify a deadline of 1..86400 seconds'}
    if(Test-Path -LiteralPath $Output){throw 'Choose a new output directory; existing evidence is preserved'}
    $null=New-Item -ItemType Directory -Path $Output -ErrorAction Stop
    $Output=(Resolve-Path -LiteralPath $Output).Path
    $stdout=Join-Path $Output 'stdout.log'; $stderr=Join-Path $Output 'stderr.log'
    # Start-Process joins argument strings on Windows. Reject embedded quotes;
    # quote every argument, including project/script paths containing spaces.
    if(@($Arguments | Where-Object {$_ -match '["\r\n]' -or $_.EndsWith('\')}).Count){throw 'Unsupported quote/newline/trailing backslash in argument'}
    $quoted=@($Arguments | ForEach-Object {'"'+$_+'"'})
    $watch=[Diagnostics.Stopwatch]::StartNew()
    $status='launch_failed'; $exitCode=$null; $failure=$null; $process=$null
    try {
        $process=Start-Process -FilePath $Executable -ArgumentList $quoted -WorkingDirectory $Directory -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru -ErrorAction Stop
        $remaining=[int][Math]::Max(0,$Seconds*1000-$watch.ElapsedMilliseconds)
        if($process.WaitForExit($remaining)){
            $process.WaitForExit()
            $exitCode=$process.ExitCode
            $status=if($exitCode -eq 0){'completed'}else{'failed'}
        }else{
            $status='timed_out'
            if(-not $process.HasExited){$process.Kill($true)}
            if(-not $process.WaitForExit(10000)){throw 'Process did not exit after tree termination'}
            $exitCode=$process.ExitCode
        }
    }catch{
        $failure=$_.Exception.Message
        if($process -and -not $process.HasExited){
            try {$process.Kill($true); $null=$process.WaitForExit(10000)} catch {$failure+='; cleanup: '+$_.Exception.Message}
        }
        if($status -ne 'launch_failed'){$status='runner_error'}
    }finally{
        # Also clean up on interruption, which can bypass the ordinary catch.
        if($process){
            if(-not $process.HasExited){
                try {$process.Kill($true); $null=$process.WaitForExit(10000)}
                catch {$failure='Final cleanup: '+$_.Exception.Message; $status='runner_error'}
            }
            $process.Dispose()
        }
        $watch.Stop()
    }
    $report=[ordered]@{status=$status;exit_code=$exitCode;elapsed_seconds=$watch.Elapsed.TotalSeconds;timeout_seconds=$Seconds;executable=$Executable;arguments=$Arguments;error=$failure}
    $report | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $Output 'process.json') -Encoding utf8
    return [pscustomobject]$report
}

function Get-ParityTimings {
    param([string]$Log)
    if(-not (Test-Path -LiteralPath $Log)){return}
    # Only successful two-count Test summaries. Failed/error summaries stay in
    # raw logs and process status; a partial table never certifies a full run.
    foreach($line in Get-Content -LiteralPath $Log){
        if($line -match '^Cantera parity: (.+?)\s*\|\s*(\d+)\s+(\d+)\s+((?:\d+(?:\.\d+)?[hms])+)$'){
            $name=$Matches[1]; $passed=[int]$Matches[2]; $total=[int]$Matches[3]; $time=$Matches[4]
            $seconds=0.0
            foreach($part in [regex]::Matches($time,'(\d+(?:\.\d+)?)([hms])')){
                $scale=@{h=3600;m=60;s=1}[$part.Groups[2].Value]
                $seconds+=[double]::Parse($part.Groups[1].Value,[Globalization.CultureInfo]::InvariantCulture)*$scale
            }
            [pscustomobject]@{case=$name;passed=$passed;total=$total;testset_seconds=$seconds}
        }
    }
}

if($MyInvocation.InvocationName -ne '.'){
    $ErrorActionPreference='Stop'
    if(-not $IsWindows){throw 'This wrapper requires Windows and PowerShell 7'}
    if(-not $OutputDirectory){throw 'Specify -OutputDirectory (must not already exist)'}
    if(-not $Cases.Count -or @($Cases | Where-Object {$_ -notmatch '^[a-z][a-z0-9_]*$'}).Count){throw 'Invalid case selector'}
    $root=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    $output=[IO.Path]::GetFullPath($OutputDirectory,(Get-Location).Path)
    $oldResults=$env:CANTERA_PARITY_RESULTS
    $oldJuliaThreads=$env:JULIA_NUM_THREADS; $oldBlasThreads=$env:OPENBLAS_NUM_THREADS
    try {
        $env:CANTERA_PARITY_RESULTS=Join-Path $output 'results'
        $env:JULIA_NUM_THREADS='1'; $env:OPENBLAS_NUM_THREADS='1'
        $command=@(('--project='+ (Join-Path $root 'example/reactors')),(Join-Path $PSScriptRoot 'run_solver_regressions.jl')) + $Cases
        $result=Invoke-ParityProcess $Julia $command $root $output $TimeoutSeconds
        $timings=@(Get-ParityTimings (Join-Path $output 'stdout.log'))
        if($timings.Count){$timings | Export-Csv (Join-Path $output 'case_timings.csv') -NoTypeInformation -Encoding utf8}
        $result | Add-Member -NotePropertyName summary_count -NotePropertyValue $timings.Count
        $result | Add-Member -NotePropertyName scope -NotePropertyValue 'One deadline for this Julia process; testset times exclude some startup and may include compilation.'
        if($result.status -eq 'completed' -and (-not $timings.Count -or @($timings | Where-Object {$_.passed -ne $_.total}).Count)){$result.status='invalid_test_output'}
        $result | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $output 'report.json') -Encoding utf8
        $result | ConvertTo-Json -Depth 5
    }finally{
        $env:CANTERA_PARITY_RESULTS=$oldResults
        $env:JULIA_NUM_THREADS=$oldJuliaThreads; $env:OPENBLAS_NUM_THREADS=$oldBlasThreads
    }
    if($result.status -eq 'timed_out'){exit 124}
    if($result.status -ne 'completed'){exit 1}
}
