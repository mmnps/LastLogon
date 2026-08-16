<#
.SYNOPSIS
    The script determines when an Active Directory user last logged in.

.DESCRIPTION
    The script determines when an Active Directory user last logged in and 
    sends an email with an overview to the administrator.

.NOTES
    Version:        1.1
    Author:         https://github.com/mmnps
    Requirements:   PowerShell 5.1, Active Directory module
#>

#Requires -Version 5.1

#########################
###   Configuration   ###
#########################
$Config = Import-PowerShellDataFile (Join-Path $PSScriptRoot "Config\Config.psd1")

$NotifyAdmin =      [bool]$Config.NotifyAdmin
$CheckForUpdates =  [bool]$Config.CheckForUpdates

# Log config
$LogEnabled =       [bool]$Config.LogConfig.Enabled
$LogDelete =        [bool]$Config.LogConfig.Delete
$LogKeepDays =      [int]$Config.LogConfig.KeepDays
$LogPath =          (Join-Path $PSScriptRoot "Logs")

# Mail config
$MailTenantId =     [string]$Config.MailConfig.TenantId
$MailClientId =     [string]$Config.MailConfig.ClientId
$MailClientSecret = if ($Config.MailConfig.ClientSecret) { [string]$Config.MailConfig.ClientSecret } else { $env:LASTLOGON_CLIENT_SECRET }
$MailFromUser =     [string]$Config.MailConfig.FromUser
$MailAdminMail =    [string]$Config.MailConfig.AdminMail

if (-not (Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path (Join-Path $PSScriptRoot "Logs") -Force | Out-Null
}


#########################
###   Local modules   ###
#########################
Import-Module (Join-Path $PSScriptRoot "Modules\MicrosoftGraph.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "Modules\Logging.psm1") -Force


#############################
###   Configure modules   ###
#############################
Initialize-MailConfig -TenantId $MailTenantId -ClientId $MailClientId -ClientSecret $MailClientSecret -FromUser $MailFromUser -ToUser $MailAdminMail
Initialize-Logging -Path $LogPath -Enabled $LogEnabled


#############################
###   Check for updates   ###
#############################
if ($CheckForUpdates) {
    try {
        if (-not (Test-Path (Join-Path $PSScriptRoot '.git'))) {
            throw "No .git directory found in '$PSScriptRoot'. The script was probably not installed via 'git clone'."
        }

        $LocalCommit = git -C $PSScriptRoot rev-parse HEAD
        $RemoteCommit = git -C $PSScriptRoot ls-remote origin HEAD | Select-Object -First 1 | ForEach-Object { ($_ -split "`t")[0] }

        if (-not $LocalCommit -or -not $RemoteCommit) {
            throw "Could not determine local or remote commit hash."
        }

        if ($LocalCommit -ne $RemoteCommit) {
            Write-Log -Level INFO -Text "A new version of the script is available. Visit https://github.com/mmnps/LastLogon for infos."
            if ($NotifyAdmin -and $MailAdminMail -and $MailTenantId -and $MailClientId -and $MailClientSecret -and $MailFromUser) {
                try {
                    $Body = Get-Content -Path (Join-Path $PSScriptRoot 'Templates\MailUpdateTemplate.html') -Raw -Encoding UTF8
                    Send-GraphMail -Subject "A new version of the LastLogon script is available!" -Body $Body
                }
                catch {
                    Write-Log -Level ERROR -Text "The update email cannot be sent, check the configuration: $($_.Exception.Message)"
                }
            }
        }
        else {
            Write-Log -Level INFO -Text "The script is up to date."
        }
    }
    catch {
        Write-Log -Level WARN -Text "Update check failed, skipping: $($_.Exception.Message)"
    }
}


###########################
###   Check AD module   ###
###########################
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Log -Level ERROR -Text 'The Active Directory module is not installed.'
    Write-Log -Level INFO -Text 'Install it using: Install-WindowsFeature RSAT-AD-PowerShell'
    exit 1
}

Import-Module ActiveDirectory -Force


########################
###   Get AD users   ###
########################
try {
    $Users = Get-ADUser -Properties SamAccountName, Name, LastLogon, EmailAddress, DistinguishedName -Filter { (Enabled -eq $true) }
}
catch {
    Write-Log -Level ERROR -Text "Failed to query Active Directory: $($_.Exception.Message)"
    exit 1
}


############################
###   Processing users   ###
############################
function ConvertTo-SafeHtml {
    param([string]$Value)
    if ([string]::IsNullOrEmpty($Value)) { return "" }
    return [System.Net.WebUtility]::HtmlEncode($Value)
}
 
$RowTemplate = @"
<tr data-username="{{USERNAME}}" data-displayname="{{DISPLAYNAME}}" data-ou="{{OU}}" data-lastlogon="{{LASTLOGON}}" data-dayssince="{{DAYSSINCE}}">
  <td class="username">{{USERNAME}}</td>
  <td>{{DISPLAYNAME}}</td>
  <td class="ou">{{OU}}</td>
  <td class="mono">{{LASTLOGON_DISPLAY}}</td>
  <td class="days">{{DAYSSINCE_DISPLAY}}</td>
  <td class="status-cell"></td>
</tr>
"@
 
Write-Log -Level INFO -Text "Getting users..."
$Rows = foreach ($User in $Users) {
    Write-Log -Level INFO -Text "Processing $($User.SamAccountName)..."
    $LastLogonDate = if ($User.LastLogon -gt 0) { [DateTime]::FromFileTime($User.LastLogon) } else { $null }
    $DaysSince     = if ($LastLogonDate) { (New-TimeSpan -Start $LastLogonDate -End (Get-Date)).Days } else { $null }
 
    $Row = $RowTemplate
    $Row = $Row.Replace('{{USERNAME}}', (ConvertTo-SafeHtml $User.SamAccountName))
    $Row = $Row.Replace('{{DISPLAYNAME}}', (ConvertTo-SafeHtml $User.Name))
    $Row = $Row.Replace('{{OU}}', (ConvertTo-SafeHtml $User.DistinguishedName))
    $Row = $Row.Replace('{{LASTLOGON}}', $(if ($LastLogonDate) { $LastLogonDate.ToString("s") } else { "" }))
    $Row = $Row.Replace('{{LASTLOGON_DISPLAY}}', $(if ($LastLogonDate) { $LastLogonDate.ToString("yyyy-MM-dd HH:mm") } else { "-" }))
    $Row = $Row.Replace('{{DAYSSINCE}}', $(if ($null -ne $DaysSince) { $DaysSince } else { "" }))
    $Row = $Row.Replace('{{DAYSSINCE_DISPLAY}}', $(if ($null -ne $DaysSince) { $DaysSince } else { "-" }))
    $Row
}
 
 
#########################
###   Generate HTML   ###
#########################
Write-Log -Level INFO -Text "Creating the report..."
$TemplatePath = Join-Path $PSScriptRoot "Templates\Dashboard.html"
$OutputPath   = Join-Path $PSScriptRoot "$(Get-Date -Format "yyyy-MM-dd")_Report.html"
 
$Html = Get-Content $TemplatePath -Raw
$Html = $Html -replace '\{\{TABLE_ROWS\}\}',     ($Rows -join "`n")
$Html = $Html -replace '\{\{DOMAIN_NAME\}\}',    $env:USERDNSDOMAIN
$Html = $Html -replace '\{\{GENERATED_DATE\}\}', (Get-Date -Format "yyyy-MM-dd HH:mm")
$Html = $Html -replace '\{\{SOURCE_HOST\}\}',    $env:COMPUTERNAME
 
$Html | Set-Content -Path $OutputPath -Encoding UTF8


#####################
###   Send mail   ###
#####################
if ($NotifyAdmin -and $MailAdminMail -and $MailTenantId -and $MailClientId -and $MailClientSecret -and $MailFromUser) {
    try {
        $Body = Get-Content (Join-Path $PSScriptRoot "Templates\MailTemplate.html") -Raw -Encoding UTF8
        Send-GraphMail -Subject "User's last logon report" -Body $Body -AttachmentPath $OutputPath
    }
    catch {
        Write-Log -Level ERROR -Text "An error occurred while sending the email, check the configuration: $($_.Exception.Message)"
    }

    if (Test-Path $OutputPath) {
        try {
            Remove-Item -Path $OutputPath -Force
        }
        catch {
            Write-Log -Level WARN -Text "Could not delete the local report file: $($_.Exception.Message)"
        }
    }
}
else {
    Write-Log -Level INFO -Text "No email will be sent because this feature is disabled."
}


########################
###   Cleanup logs   ###
########################
if ($LogDelete -and (Test-Path -Path $LogPath)) {
    Get-ChildItem -Path $LogPath -Filter '*.log' -File | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$LogKeepDays) } | Remove-Item -Force
}
