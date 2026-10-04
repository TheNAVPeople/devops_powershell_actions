param (
    [string] $ModuleName,
    [string] $Repository,
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

$mtx = New-Object System.Threading.Mutex($false, "T3PDevOpsPSModuleInstallation")
if ($mtx.WaitOne()) {
    $module = Get-InstalledModule -Name $ModuleName -ErrorAction Ignore

    if ($null -ne $module) {
        $galleryModule = Find-Module -Name $ModuleName -Repository $Repository -Credential $Credential

        if (($null -ne $galleryModule) -and ($galleryModule.Version -ne $module.Version)) {
            Write-Host ("Updating module " + $ModuleName)
            Update-Module $ModuleName -Credential $Credential -Force
        }
    } else {
        Write-Host ("Installing module " + $ModuleName)
        Install-Module $ModuleName -Repository $Repository -Credential $Credential -Force -AllowClobber
    }
    [void]$mtx.ReleaseMutex()
}
$mtx.Dispose()
