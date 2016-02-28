<#
.SYNOPSIS
    Returns ConnectionStrings from an or application/web config
.DESCRIPTION
    The cmdlet takes an application/web configuration as an input and returns
    the connectionstrings from it.

    If -IncludeAppSettings is specified it will try to match any ConnectionString from the
    appSettings sections too.
.PARAMETER ConfigXml
    Mandatory - Pipeline input for Configuration XML
.PARAMETER IncludeAppSettings
    Optional - Parameter to find any connectionStrings from application Settings

.EXAMPLE
    Get-PSWebConfig -Path 'C:\inetpub\wwwroot\myapp' | Get-PSConnectionString
.EXAMPLE
    Get-WebSite mysite | Get-PSWebConfig | Get-PSConnectionString
.EXAMPLE
    Get-WebSite mysite | Get-PSWebConfig | Get-PSConnectionString -IncludeAppSettings
#>
function Get-PSConnectionString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,ValueFromPipeLine=$true)]
        [psobject[]]$ConfigXml,

        [switch]$IncludeAppSettings
    )

    process {
        foreach ($config in $ConfigXml) {
            if ($config -is [string]) { $config = [xml]$config }

            if ($config | Get-Member -Name configuration) {
                if ($config.configuration.connectionStrings.EncryptedData) {
                    Write-Warning "ConnectionStrings section is encrypted. You may not see all relevant entries."
                }

                foreach ($connectionString in $config.configuration.connectionStrings.add) {
                    $connectionString |
                    Add-Member -NotePropertyName Session -NotePropertyValue $config.Session -Force -PassThru |
                    Add-Member -NotePropertyName ComputerName -NotePropertyValue $config.ComputerName -Force -PassThru |
                    Add-Member -NotePropertyName File -NotePropertyValue $config.File -Force -PassThru |
                    Add-Member -NotePropertyName SectionPath -NotePropertyValue "connectionStrings" -Force -PassThru |
                    Set_Type -TypeName "PSWebConfig.ConnectionString"
                }

                if (-Not $IncludeAppSettings) { continue }

                $config | Get-PSAppSetting | ForEach-Object {
                    if ($_.value -match 'data source=') {
                        $_ |
                        Add-Member -MemberType AliasProperty -Name ConnectionString -Value value -Force -PassThru |
                        Add-Member -MemberType AliasProperty -Name Name -Value key -Force -PassThru |
                        Set_Type -TypeName "PSWebConfig.ConnectionString"
                    }
                }
            }
        }
    }
}