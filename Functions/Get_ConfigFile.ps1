function Get_ConfigFile {
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [string]$Path,

        [Parameter(Position=1)]
        [string[]]$Sections = @('connectionStrings', 'appSettings', 'system.web'),

        [Parameter(Position=2)]
        [bool]$AsFileName=$false,

        [Parameter(Position=3)]
        [bool]$AsText=$false,

        [Parameter(Position=4)]
        [bool]$Recurse=$false
    )

    function Copy_WebConfig([string]$config) {
        if (-Not (Test-Path $config)) {
            Write-Warning "Could not find '$config'"
            return $null
        }

        # Copy the original file to temp for non-intrusive decryptions
        $tempFolder = [System.IO.Path]::GetTempPath()
        $appGuid = [guid]::NewGuid().Guid
        $tempAppFolder = Join-Path $tempFolder $appGuid
        $tempAppConfig = Join-Path $tempAppFolder 'web.config'

        Write-Verbose "Creating $tempAppFolder"
        mkdir $tempAppFolder -Force | Out-Null

        Write-Verbose "Copying $c to $tempAppFolder"
        Copy-Item -Path $config -Destination $tempAppFolder

        return $tempAppConfig
    }

    function Detect_AspNetRegIIS {
        $paths = @(
            "$($env:SystemRoot)\Microsoft.NET\Framework\v4.0.30319\aspnet_regiis.exe"
            "$($env:SystemRoot)\Microsoft.NET\Framework\v2.0.50727\aspnet_regiis.exe"
        )
        foreach ($path in $paths) {
            if (Test-Path -Path $path) {
                Write-Verbose "$paths is found"
                return $path
            }
        }
        Write-Warning "Cannot find aspnet_regiis.exe in any known folders"
        return $null
    }

    function Decypt_WebConfig {
        param(
            [string]$folder,
            [string]$aspnet_regiis = $(Detect_AspNetRegIIS),
            [string[]]$sections
        )
        $webConfigFile = Join-Path $folder 'web.config'
        if (Test-Path $webConfigFile) {
            $xmlContent = [xml](Get-Content $webConfigFile)
            if (-Not $xmlContent) {
                Write-Warning "'$webConfigFile' is not a valid XML file."
            }

            foreach ($s in $sections) {
                $encryptedSection = ($xmlContent -and ($xmlContent.configuration.$s.EncryptedData -or $s -match '/'))
                if ($encryptedSection -and $aspnet_regiis) {
                    $cryptArgs = "-pdf $s $folder"
                    Write-Verbose "Decrypting > $aspnet_regiis $cryptArgs"
                    Start-Process -FilePath $aspnet_regiis -ArgumentList $cryptArgs -WindowStyle Hidden -Wait
                } else {
                    Write-Verbose "Skipping decryption of '$s' section"
                }
            }
        }
    }

    # Expand and Test Path
    $Path = [Environment]::ExpandEnvironmentVariables($Path)
    if ([String]::IsNullOrEmpty($Path) -or -Not (Test-Path $Path)) {
        Write-Verbose "Path '$Path' is not found."
        return
    }

    Write-Verbose "Looking for config files at '$Path'.."
    $configs = $()
    foreach ($f in @("web.config","*.exe.config")) {
        $found = $null
        $found = Get-ChildItem $Path -Filter $f -Recurse:$Recurse -ErrorAction SilentlyContinue
        if ($found) { $configs += @($found) }
    }
    $configs =  $configs | Select-Object -Unique

    if ($AsFileName) { $configs.FullName }
    else {
        foreach ($c in ($configs | Select -Unique)) {
            $content = $null
            Write-Verbose "File '$($c.FullName)'.."
            $isWebConfig = ($c.Name -eq 'web.config')

            if ($isWebConfig) {
                # Create a copy of web.config's and decrypt it
                $tempAppFolder = $null

                Write-Verbose "Cloning $($c.FullName) ..."
                $tempAppConfig = Copy_WebConfig -config $c.FullName
                $tempAppFolder = Split-Path $tempAppConfig -Parent

                if (Test-Path $tempAppConfig) {
                    Decypt_WebConfig -folder $tempAppFolder -sections $Sections

                    Write-Verbose "Reading web.config content"
                    $content = Get-Content $tempAppConfig | Out-String
                }

                Write-Verbose "Deleting $tempAppFolder"
                rmdir $tempAppFolder -Force -Recurse
            } else {
                # App.config
                Write-Verbose "Reading app config content"
                $content = Get-Content $c.FullName | Out-String
            }

            if (!$AsText) {
                $content = [xml]$content
                $content | Add-Member -NotePropertyName File -NotePropertyValue $c.FullName
                $content
            }
            else { $content }
        }
    }
}
