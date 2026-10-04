param (
    [string] $Name
)

$repo = Get-PSRepository -Name $Name -ErrorAction Ignore
if ($null -ne $repo) {
    Unregister-PSRepository -Name $Name
}
