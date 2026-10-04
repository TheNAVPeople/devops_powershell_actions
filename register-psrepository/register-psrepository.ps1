param (
    [string] $Name,
    [string] $Location,
    [string] $PublishLocation,
    [string] $ApiKey,
    [string] $User,
    [string] $Password
)

if (([System.String]::IsNullOrWhiteSpace($User)) -and (![System.String]::IsNullOrWhiteSpace($ApiKey))) {
    $User = "ApiKey"
    $Password = $ApiKey
}

if (![System.String]::IsNullOrWhiteSpace($User)) {
    $SecurePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $SecurePassword
}

if ([System.String]::IsNullOrWhiteSpace($PublishLocation)) {
    $PublishLocation = $Location
}

# Try to update NuGet.exe first

#"$env:LOCALAPPDATA\Microsoft\Windows\PowerShell\PowerShellGet\NuGet.exe"
$Profilepowershellget = "$env:userprofile\AppData\Local\Microsoft\Windows\PowerShell\PowerShellGet\"
 
if(-Not(Test-Path $Profilepowershellget)){
    New-Item $Profilepowershellget -ItemType Directory
}

$UpdateLogFile = Join-Path -Path $Profilepowershellget -ChildPath "NuGet_FIleUpdated.log"
if(-Not(Test-Path $UpdateLogFile)){
    $OutputFile = Join-Path -Path $Profilepowershellget -ChildPath "NuGet.exe"
    Invoke-WebRequest -Uri https://dist.nuget.org/win-x86-commandline/latest/nuget.exe -OutFile $OutputFile
    Unblock-File $OutputFile
    "NuGetUpdated" | Out-File -FilePath $UpdateLogFile
    Write-Host "NuGet.exe updated to the latest version"
}

# Register repository
if(!(Get-PackageSource -Name $Name -ProviderName PowerShellGet -ErrorAction Ignore )) {
    Register-PackageSource -Name $Name -Location $Location -PublishLocation $PublishLocation -ProviderName PowerShellGet -Credential $Credential -Trusted -Force
}
# Update disabled for performance reasons
#else {
#    Set-PackageSource -Name $Name -Location $Location -PublishLocation $PublishLocation -ProviderName PowerShellGet -Credential $Credential -Trusted -Force
#}
