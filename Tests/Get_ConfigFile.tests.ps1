﻿$isVerbose=($VerbosePreference -eq 'Continue')

Describe "Get_ConfigFile helper" {
    # Function to test
    . (Join-Path $PSScriptRoot '..\Functions\Get_ConfigFile.ps1')
    $webConfigFolder = Join-Path $PSScriptRoot 'ConfigTests'
    $webConfigFile = Join-Path $webConfigFolder 'web.config'

    It "Should be able to find web.config files recursively" {
        $files = Get_ConfigFile -Path $webConfigFolder -AsFileName:$true -Recurse:$true -Verbose:$isVerbose
        $files | Should Not BeNullOrEmpty
        $files.GetType().Name | Should Be "String"
    }

    It "Should be able to return XML content" {
        $xml = Get_ConfigFile -Path $webConfigFile -Verbose:$isVerbose
        $xml | Should Not BeNullOrEmpty
        $xml.configuration.GetType().Name | Should Be "XmlElement"
    }

    It "Should be able to read the file content" {
        $content = Get_ConfigFile -Path $webConfigFile -AsText:$true -Verbose:$isVerbose
        $content | Should Not BeNullOrEmpty
        $content.GetType().Name | Should Be "String"
    }
}
