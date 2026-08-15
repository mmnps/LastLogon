function Initialize-Logging {
    param (
        [Parameter(Mandatory)]$Path,
        [bool]$Enabled
    )

    $Name = "$(Get-Date -Format "yyyy-MM-dd").log"
    $script:LogFile = Join-Path $Path $Name
    $script:LogEnabled = $Enabled
}

function Write-Log {
    param (
        [ValidateSet('INFO','WARN','ERROR')][string]$Level = 'INFO',
        [Parameter(Mandatory)][string]$Text
    )

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $MSG = "[$Timestamp] - $Level - $Text"

    if ($script:LogEnabled) {
        try {
            Add-Content -Path $script:LogFile -Value $MSG -Force
        }
        catch {
            Write-Host "Unable to write to the log file: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    switch ($Level) {
        'INFO'  { Write-Host $MSG -ForegroundColor DarkGray }
        'WARN'  { Write-Host $MSG -ForegroundColor Yellow }
        'ERROR' { Write-Host $MSG -ForegroundColor Red }
    }
}