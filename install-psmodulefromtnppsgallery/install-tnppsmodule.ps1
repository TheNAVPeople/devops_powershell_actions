param (
    [string] $Url,
    [string] $ApiKey,
    [string] $ModuleName
)

function Download-NuGetPackage {
    param (
        [string] $Url,
        [string] $ApiKey,
        [string] $FilePath
    )

    # Construct the headers with the NuGet API key
    $headers = @{
        "X-NuGet-ApiKey" = $ApiKey
    }

    # Use Invoke-WebRequest to download data
    Invoke-WebRequest -Uri $Url -Headers $headers -OutFile $FilePath
}

function Get-NuGetJsonResponse {
    param (
        [string] $Url,
        [string] $ApiKey
    )

    # Construct the headers with the NuGet API key
    $headers = @{
        "X-NuGet-ApiKey" = $ApiKey
    }

    # Use Invoke-WebRequest to download data
    Write-Host "Downloading data from $Url"


    $Content = Invoke-WebRequest -Uri $Url -Headers $headers
    $data = ConvertFrom-Json $Content

    return $data
}

function Get-NuGetServiceUrl {
    param (
        [string] $Url,
        [string] $ApiKey,
        [string] $ServiceName
    )

    $nuGetIndex = Get-NuGetJsonResponse -Url $Url -ApiKey $ApiKey

    for ($i = 0; $i -lt $nuGetIndex.resources.Count; $i++) {
        if ($nuGetIndex.resources[$i].'@type' -eq $ServiceName) {
            return $nuGetIndex.resources[$i].'@id'
        }
    }

    for ($i = 0; $i -lt $nuGetIndex.resources.Count; $i++) {
        if ($nuGetIndex.resources[$i].'@type'.StartsWith($ServiceName)) {
            return $nuGetIndex.resources[$i].'@id'
        }
    }

    return $null
}

function Find-LastNuGetPackageVersion {
    param (
        [string] $Url,
        [string] $ApiKey,
        [string] $PackageId
    )

    $searchUrl = Get-NuGetServiceUrl -Url $Url -ApiKey $ApiKey -ServiceName "SearchQueryService"
    
    $searchUrl = $searchUrl + "?q=" + $PackageId
    $packagesList = Get-NuGetJsonResponse -Url $searchUrl -ApiKey $ApiKey

    $version = $null
    $package = $null
    for ($i = 0; $i -lt $packagesList.data.versions.Count; $i++) {
        $item = $packagesList.data.versions[$i]
        $itemVersion = [System.Version]::Parse($item.version)
        if (($null -eq $version) -or ($itemVersion -gt $version)) {
            $version = $itemVersion
            $package = $item
        }
    }

    if ($null -ne $package) {
        $packageDetails = Get-NuGetJsonResponse -Url $package.'@id' -ApiKey $ApiKey
    
        return @{
            ContentUrl = $packageDetails.packageContent
            Version = $itemVersion
            VersionText = $package.version
        }
    }

    return $null
}

function Install-NuGetPackage {
    param (
        [string] $Url,
        [string] $ApiKey,
        [string] $PackageId,
        [string] $Path
    )

    $packageVersion = Find-LastNuGetPackageVersion -Url $Url -ApiKey $ApiKey -PackageId $PackageId

    if ($null -ne $packageVersion) {
        $packageFolder = Join-Path -Path $Path -ChildPath $PackageId
        $packageVersionFolder = Join-Path -Path $packageFolder -ChildPath $packageVersion.VersionText

        if (!(Test-Path -Path $packageVersionFolder -PathType Container)) {
            
            #delete all other versions
            if (Test-Path -Path $packageFolder -PathType Container) {
                Remove-Item -Path $packageFolder -Recurse -Force
            }

            #make folder
            New-Item -ItemType Directory $packageVersionFolder

            #download and extract content
            $tmpZipPath = [System.IO.Path]::GetTempFileName() | Rename-Item -NewName { $_ -replace 'tmp$', 'zip' } -PassThru
            try {
                Download-NuGetPackage -Url $packageVersion.ContentUrl -ApiKey $ApiKey -FilePath $tmpZipPath

                Expand-Archive -LiteralPath $tmpZipPath -DestinationPath $packageVersionFolder
            }
            catch {
            }

            Remove-Item $tmpZipPath

        }

        return $packageFolder
    }

    return $null    
}


function Install-T3PPSModule {
    param (
        [string] $Url,
        [string] $ApiKey,
        [string] $PackageId
    )
    
    # get modules path
    $modulePaths = $env:PSModulePath -split ';'
    $userModulePath = $modulePaths[0]

    #download and install package
    $installedModulePath = Install-NuGetPackage -Url $Url -ApiKey $ApiKey -PackageId $PackageId -Path $userModulePath

    return $installedModulePath
}

$mtx = New-Object System.Threading.Mutex($false, "T3PDevOpsPSModuleInstallation")

try {
    if ($mtx.WaitOne()) {
        Install-T3PPSModule -Url $Url -ApiKey $ApiKey -PackageId $ModuleName
    }
} finally {
    if ($mtx -ne $null) {
        $mtx.ReleaseMutex()
        $mtx.Dispose()
    }
}
