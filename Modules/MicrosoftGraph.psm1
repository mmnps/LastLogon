function Initialize-MailConfig {
    param (
        [string]$TenantId,
        [string]$ClientId,
        [string]$ClientSecret,
        [string]$FromUser,
        [string]$ToUser
    )


    $script:TenantId = $TenantId
    $script:ClientId = $ClientId
    $script:ClientSecret = $ClientSecret
    $script:FromUser = $FromUser
    $script:ToUser = $ToUser

}

function Send-GraphMail {
    param (
        [Parameter(Mandatory)][string]$Subject,
        [Parameter(Mandatory)][string]$Body,
        [string]$AttachmentPath
    )
    $body = @{
        grant_type = 'client_credentials'
        scope = 'https://graph.microsoft.com/.default'
        client_id = $script:ClientId
        client_secret = $script:ClientSecret
    }

    $TokenResponse = Invoke-RestMethod -Method Post `
        -Uri "https://login.microsoftonline.com/$script:TenantId/oauth2/v2.0/token" `
        -Body $body

    $AccessToken = $TokenResponse.access_token

    $Message = @{
        subject = $Subject
        importance = 'high'
        body = @{
            contentType = 'HTML'
            content = $Body
        }
        toRecipients = @(
            @{ emailAddress = @{ address = $script:ToUser } }
        )
    }

    if ($AttachmentPath) {
        $FileBytes = [System.IO.File]::ReadAllBytes($AttachmentPath)
        $FileName  = [System.IO.Path]::GetFileName($AttachmentPath)
        $Base64    = [System.Convert]::ToBase64String($FileBytes)

        $Message.attachments = @(
            @{
                "@odata.type" = "#microsoft.graph.fileAttachment"
                name          = $FileName
                contentType   = "application/octet-stream"
                contentBytes  = $Base64
            }
        )
    }

    $MailBody = @{
        message = $Message
        saveToSentItems = $true
    } | ConvertTo-Json -Depth 6

    Invoke-RestMethod -Method Post `
        -Uri "https://graph.microsoft.com/v1.0/users/$script:FromUser/sendMail" `
        -Headers @{ Authorization = "Bearer $AccessToken" } `
        -Body $MailBody `
        -ContentType 'application/json'
}