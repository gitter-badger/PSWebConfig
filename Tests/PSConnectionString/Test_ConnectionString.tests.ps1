. (Join-Path $PSScriptRoot '../Import-LocalModule.ps1')

$isVerbose=($VerbosePreference -eq 'Continue')

Describe "Test_ConnectionString helper function" {
    # Function to test
    . (Join-Path $script:FunctionPath 'PSConnectionString/Test_ConnectionString.ps1')

    @{
        Invalid='IvServer=localhost;IvDatabase=##DB##;Connection Timeout=1'
        NonExisting="Server=localhost;Database=##DB##ThatShouldNotExist;User Id=uname;Password=4bCd;Connection Timeout=1;"
        NonExistingWithPasswordEnd="Server=localhost;Database=##DB##ThatShouldNotExist;User Id=uname;Connection Timeout=1;Password=4bCd"
    }.GetEnumerator() |
    ForEach-Object {
        context "$($_.Key) SqlConnectionString" {
            $failingConnectionString=$_.Value

            It "Should have failed test result properties" {
                $result = Test_ConnectionString -ConnectionString $failingConnectionString -Verbose:$isVerbose -ShowPassword $true -EA 0
                $result | Should Not BeNullOrEmpty
                $result.ComputerName | Should Be ([System.Net.Dns]::GetHostByName($env:COMPUTERNAME).HostName)
                $result.TestType | Should Be 'SqlTest'
                $result.Test | Should Be $failingConnectionString
                $result.ConnectionString | Should Be $failingConnectionString
                $result.Passed | Should Be $false
                $result.Result | Should Not BeNullOrEmpty
                $result.Status | Should Match 'Failed'
            }

            It "Should replace ConnectionString with ReplaceRules" {
                $replacedFailingConnectionString=$failingConnectionString -replace '##DB##','DB_SUBST'
                $replaceRule = @{'##DB##'='DB_SUBST'}
                $result = Test_ConnectionString -ConnectionString $failingConnectionString -ReplaceRules $replaceRule -Verbose:$isVerbose -ShowPassword $true -EA 0

                $result.Test | Should Be $failingConnectionString
                $result.ConnectionString | Should Be $replacedFailingConnectionString
            }

            if ($failingConnectionString -imatch "Password=") {
                It "Should replace replace Password= field to ***" {
                    $result = Test_ConnectionString -ConnectionString $failingConnectionString -Verbose:$isVerbose -EA 0

                    $result.Test | Should Match 'Password=\*\*\*'
                    $result.ConnectionString | Should Match 'Password=\*\*\*'
                }
            }
        }
    }
}
