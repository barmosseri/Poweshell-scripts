Install-Module -Name AWS.Tools.Installer -Force
Set-AWSCredential -RoleArn arn:aws:iam::XXX:role/XXX -StoreAs logzio_key
Set-DefaultAWSRegion -Region XXX
$secretValue = (Get-SECSecret -SecretId logzio_key).SecretString
$encryptedValue = ConvertTo-SecureString -String $secretValue -AsPlainText -Force
$encryptedValue | ConvertFrom-SecureString
$logzioUrl = "https://listener.logz.io:8071?token=$encryptedValue"

$updates = Get-WUUpdates
if ($updates) {
    Install-WUUpdates -AcceptAll
    Restart-Computer
}

$bootTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
$currentTime = (Get-Date).ToUniversalTime()
$timeSinceBoot = New-TimeSpan -Start $bootTime -End $currentTime
if ($timeSinceBoot.TotalMinutes -gt 8) {
    $body = "The machine is stuck on the 'Please wait' screen."
    Invoke-WebRequest -Uri $logzioUrl -Method POST -Body $body
}

$bsodEvents = Get-WinEvent -FilterHashtable @{
    ProviderName = "Microsoft-Windows-Kernel-Power"
    Level = 2
}
if ($bsodEvents) {
    $body = "The machine has experienced a Blue Screen of Death."
    Invoke-WebRequest -Uri $logzioUrl -Method POST -Body $body
}

$eventLog = Get-EventLog -LogName System -Source User32 -After (Get-Date).AddMinutes(-5)
$restarted = $eventLog | Where-Object { $_.EventID -eq "1074" }
if ($restarted) {
    $body = "The machine was updated and restarted."
    Invoke-WebRequest -Uri $logzioUrl -Method POST -Body $body
    while (!(Test-Connection -ComputerName $env:COMPUTERNAME -Count 1 -Quiet)) {
        Start-Sleep -Seconds 360
    }
    Invoke-WebRequest -Uri $logzioUrl -Method POST -Body "The machine is now up and running."
}
else {  
    Invoke-WebRequest -Uri $logzioUrl -Method POST -Body "There aren't updates available for the machine."
