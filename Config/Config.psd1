@{
    CheckForUpdates =   $true   # If the script should automatically check for updates
    NotifyAdmin =       $true   # If you want to receive email notifications when a new version of the script is available

    MailConfig = @{
        TenantId =      ""      # Microsoft Entra TenantId
        ClientId =      ""      # Microsoft Entra ClientId
        ClientSecret =  ""      # Microsoft Entra ClientSecret; Set here or create the LASTLOGON_CLIENT_SECRET environment variable
        FromUser =      ""      # Username from the sender account
        AdminMail =     ""      # Email address from the administrator
    }

    LogConfig = @{
        Enabled =       $true   # Enables logging
        Delete =        $true   # If the log files will be deleted automatically
        KeepDays =      14      # After how many days the log files will be deleted
    }
}