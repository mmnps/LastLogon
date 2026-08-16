# LastLogon - O365 version

PowerShell script that finds when Active Directory users last logged in and writes them into an HTML report.

## Requirements
- Windows with PowerShell 5.1 or higher
- RSAT module `ActiveDirectory` (`Install-WindowsFeature RSAT-AD-PowerShell`)
- Azure AD app registration with the application permission **`Mail.Send`**
- Network access to login.microsoftonline.com and graph.microsoft.com

## Installation

If git isn't installed, install it using:

```powershell
winget install --id Git.Git -e --source winget
```

Start a new powershell and execute the following commands:

```powershell
mkdir C:\Scripts
cd C:\Scripts\
git clone --depth 1 https://github.com/mmnps/LastLogon
cd LastLogon
Copy-Item .\Config\Config.psd1.example .\Config\Config.psd1
```

Then fill in `Config\Config.psd1` with your own values.

## Update

Update the script using the following commands:

```powershell
cd C:\Scripts\LastLogon
git pull
```

### Client secret without plaintext in the file

Instead of entering the secret in `Config.psd1`, it can be set as environment variable:

```powershell
[Environment]::SetEnvironmentVariable("LASTLOGON_CLIENT_SECRET", "XXX", "Machine")
```

## Usage

For regular operation, a daily task in Windows Task Scheduler is recommended.


## Security notes
- `Config\Config.psd1` is excluded from version control via .gitignore because it can contain secrets.
- Grant the app registration only the minimally required permission (`Mail.Send`).
- Prefer providing the client secret via the `LASTLOGON_CLIENT_SECRET` environment variable.

## Changelog

### 16.08.2026
- Log output and module settings have been adjusted