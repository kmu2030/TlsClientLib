param(
    [Parameter(Mandatory=$false, Position=0)][int[]]$Ports = @(12101, 12102, 13101, 13102),
    [Parameter(Mandatory=$false, Position=1)][string]$Mode = 'jsonl',
    [Parameter(Mandatory=$false, Position=3)][string]$CertFriendlyName = 'TlsClientLibTest'
)

$scriptFile = "simple-tls-monitor.ps1"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$scriptPath = Join-Path $scriptDir $scriptFile
if (-not (Test-Path $scriptPath)) {
    Write-Error "error: Not fount '${scriptFile}' in '${scriptPath}'"
    exit 1
}

$wtCommandString = "pwsh.exe -NoExit -Command ""&{ & `"${scriptPath}`" -Port $($Ports[0]) -Mode `"${Mode}`" -CertFriendlyName `"${CertFriendlyName}`" }"" ; " + `
                   "split-pane -H pwsh.exe -NoExit -Command ""&{ & `"${scriptPath}`" -Port $($Ports[1]) -Mode `"${Mode}`" -CertFriendlyName `"${CertFriendlyName}`" }"" ; " + `
                   "split-pane -V pwsh.exe -NoExit -Command ""&{ & `"${scriptPath}`" -Port $($Ports[2]) -Mode `"${Mode}`" -CertFriendlyName `"${CertFriendlyName}`" }"" ; " + `
                   "split-pane -H pwsh.exe -NoExit -Command ""&{ & `"${scriptPath}`" -Port $($Ports[3]) -Mode `"${Mode}`" -CertFriendlyName `"${CertFriendlyName}`" }"""

# For debug.
# Write-Host "command: wt.exe $wtCommandString"

Start-Process -FilePath "wt.exe" -ArgumentList $wtCommandString
