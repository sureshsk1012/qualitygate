<#
.SYNOPSIS
    Script to automate validation of the quality gates at each of the deployment targets/environments before application deployment.

.DESCRIPTION
    The PowerShell script automates evaluation of the quality gates/validation matrices, through results of the various test executions and open defects, before deploying application in a target platform/environment.
    Quality gates/validation matrices information are scattered across different platforms as follows;
        1. Test plans reside in multiple team projects.
        2. Web tests results are retained in the Azure DevOps Pipeline private agent pool/servers.
        3. System integration details are managed by Application Insights in Azure.
    The script collects results of these aforementioned validation matrices using Azure DevOps REST APIs to evaluate the quality gates.

.NOTES
    Version:        1.0
    Author:         Arun P Nair
    Creation Date:  20-Nov-2019
    Purpose/Change: Initial script development
#>

[CmdletBinding()]
Param
(
    [String]$FunctionName,   
    [String]$OrganizationName,
    [String]$ProjectName,
    [String]$TestingData,
    [String]$SearchQuery,
    [String]$QualityGateName,
    [String]$PersonalAccessToken
)

Function Get-TestResultsBasedOnTestPlans {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory, Position = 0)]
        [String]$OrganizationName,
        [Parameter(Mandatory, Position = 1)]
        [String]$ProjectName,
        [Parameter(Mandatory, Position = 2)]
        [String]$TestingData,
        [Parameter(Mandatory, Position = 3)]
        [String]$QualityGateName,
        [Parameter(Mandatory, Position = 4)]
        [String]$PersonalAccessToken
    )

    Begin {
        $BasicAuthentication = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f '', $PersonalAccessToken)))
    }
    Process {
        Try {

            $TotalTestCases = 0
            $TotalTestCasesPassed = 0

            $TestingData.Split(",") | ForEach-Object {
                $TestPlanId = $_

                $Params = @{
                    Uri = "https://dev.azure.com/$($OrganizationName)/$($ProjectName)/_apis/test/Plans/$($TestPlanId)/suites?api-version=5.0"
                    Headers = @{
                        Authorization = "Basic $BasicAuthentication"
                    }
                }

                $Params.Method = "Get"
                $Params.ContentType = "application/json"

                $TestSuitesJson = Invoke-RestMethod @Params

                # Uncomment this section for reporting.
                <#
                Write-Host "----------------------------------------------"
                Write-Host "Test Plan Id: $($TestPlanId) - Test Suites Count: $($TestSuitesJson.value.Count)"
                Write-Host "----------------------------------------------"
                #>

                $TestSuitesJson.value | ForEach-Object {
                    $TestSuite = $_

                    $Params.Uri = "https://dev.azure.com/$($OrganizationName)/$($ProjectName)/_apis/test/Plans/$($TestPlanId)/Suites/$($TestSuite.id)/points?api-version=5.1"

                    $TestPointsJson = Invoke-RestMethod @Params

                    $TestPointsPassed = $TestPointsJson.value | Where-Object{ $_.outcome -eq "Passed" } | Select-Object -ExpandProperty outcome

                    $TotalTestCases += $TestPointsJson.value.Count
                    $TotalTestCasesPassed += $TestPointsPassed.Count
                    
                    # Uncomment this section for reporting.
                    <#
                    Write-Host "Total Test Cases: $($TestPointsJson.value.Count) - Total Test Cases Passed: $($TestPointsPassed.Count)"

                    # Loop through each of the test cases and display the test case name along with the outcome/result.
                    $TestPointsJson.value | ForEach-Object {
                        $TestPoint = $_
                        Write-Host "$($TestPoint.testCase.name) ($($TestPoint.outcome))"
                    }

                    # Loop through each of the test cases and display test suite URL and test case id for those failed/active(unspecified).
                    $TestPointsJson.value | ForEach-Object {
                        $TestPoint = $_
                        If($TestPoint.outcome -ne "Passed") {
                            Write-Host "https://dev.azure.com/$($OrganizationName)/$($ProjectName)/_apis/test/Plans/$($TestPlanId)/Suites/$($TestSuite.id) - Test Case Id: $($TestPoint.testCase.name) ($($TestPoint.outcome))"
                        }
                    }
                    #>
                }
            }

            If($TotalTestCases -ne $TotalTestCasesPassed) {
                Write-Host "##vso[task.logissue type=warning;]Total Test Cases: $($TotalTestCases) - Total Test Cases Passed: $($TotalTestCasesPassed)."
                Write-Host "##vso[task.logissue type=warning;]$($QualityGateName) - Failed."
                Write-Host "##vso[task.logissue type=error;]$($QualityGateName) - Failed."
                Exit 1
            }
            Else {
                Write-Host "##vso[task.logissue type=warning;]$($QualityGateName) - Succeeded."
            }
        }
        Catch {
            Throw $_
        }
    }
}

Function Get-TestResultsBasedOnTestPlansAndTestSuites {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory, Position = 0)]
        [String]$OrganizationName,
        [Parameter(Mandatory, Position = 1)]
        [String]$ProjectName,
        [Parameter(Mandatory, Position = 2)]
        [String]$TestingData,
        [Parameter(Mandatory, Position = 3)]
        [String]$QualityGateName,
        [Parameter(Mandatory, Position = 4)]
        [String]$PersonalAccessToken
    )

    Begin {
        $BasicAuthentication = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f '', $PersonalAccessToken)))
    }
    Process {
        Try {

            $TotalTestCases = 0
            $TotalTestCasesPassed = 0

            $TestingData.Split(",") | ForEach-Object {
                $Values = $_.Split(":")
                $TestPlanId = $Values[0]
                $TestSuiteId = $Values[1]

                $Params = @{
                    Uri = "https://dev.azure.com/$($OrganizationName)/$($ProjectName)/_apis/test/Plans/$($TestPlanId)/Suites/$($TestSuiteId)/points?api-version=5.1"
                    Headers = @{
                        Authorization = "Basic $BasicAuthentication"
                    }
                }

                $Params.Method = "Get"
                $Params.ContentType = "application/json"

                $TestPointsJson = Invoke-RestMethod @Params

                $TestPointsPassed = $TestPointsJson.value | Where-Object{ $_.outcome -eq "Passed" } | Select-Object -ExpandProperty outcome

                $TotalTestCases += $TestPointsJson.value.Count
                $TotalTestCasesPassed += $TestPointsPassed.Count

                # Uncomment this section for reporting.
                <#
                Write-Host "Total Test Cases: $($TestPointsJson.value.Count) - Total Test Cases Passed: $($TestPointsPassed.Count)"

                # Loop through each of the test cases and display the test case name along with the outcome/result.
                $TestPointsJson.value | ForEach-Object {
                    $TestPoint = $_
                    Write-Host "$($TestPoint.testCase.name) ($($TestPoint.outcome))"
                }

                # Loop through each of the test cases and display test suite URL and test case id for those failed/active(unspecified).
                $TestPointsJson.value | ForEach-Object {
                    $TestPoint = $_
                    If($TestPoint.outcome -ne "Passed") {
                        Write-Host "https://dev.azure.com/$($OrganizationName)/$($ProjectName)/_apis/test/Plans/$($TestPlanId)/Suites/$($TestSuiteId) - Test Case Id: $($TestPoint.testCase.name) ($($TestPoint.outcome))"
                    }
                }
                #>
            }

            If($TotalTestCases -ne $TotalTestCasesPassed) {
                Write-Host "##vso[task.logissue type=warning;]Total Test Cases: $($TotalTestCases) - Total Test Cases Passed: $($TotalTestCasesPassed)."
                Write-Host "##vso[task.logissue type=warning;]$($QualityGateName) - Failed."
                Write-Host "##vso[task.logissue type=error;]$($QualityGateName) - Failed."
                Exit 1
            }
            Else {
                Write-Host "##vso[task.logissue type=warning;]$($QualityGateName) - Succeeded."
            }
        }
        Catch {
            Throw $_
        }
    }
}

Function Get-SearchQueryResults {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory, Position = 0)]
        [String]$OrganizationName,
        [Parameter(Mandatory, Position = 1)]
        [String]$ProjectName,
        [Parameter(Mandatory, Position = 2)]
        [String]$SearchQuery,
        [Parameter(Mandatory, Position = 3)]
        [String]$QualityGateName,
        [Parameter(Mandatory, Position = 4)]
        [String]$PersonalAccessToken
    )

    Begin {
        $BasicAuthentication = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f '', $PersonalAccessToken)))
    }
    Process {
        Try {
                
            $Params = @{
               Uri = "https://dev.azure.com/$($OrganizationName)/$($ProjectName)/_apis/wit/wiql?api-version=5.1"
               Headers = @{
                   Authorization = "Basic $BasicAuthentication"
               }
            }

            $Params.Body = $SearchQuery

            $Params.Method = "Post"
            $Params.ContentType = "application/json"

            $QueryResultsJson = Invoke-RestMethod @Params

            $TotalDefects = $QueryResultsJson.workItems.Count

            If($TotalDefects -gt 0) {
                Write-Host "##vso[task.logissue type=warning;]Total Defects Found: $($TotalDefects)."
                Write-Host "##vso[task.logissue type=warning;]$($QualityGateName) - Failed."
                Write-Host "##vso[task.logissue type=error]$($QualityGateName) - Failed."
                Exit 1
            }
            Else {
                Write-Host "##vso[task.logissue type=warning;]No Defects Found."
                Write-Host "##vso[task.logissue type=warning;]$($QualityGateName) - Succeeded."
            }
        }
        Catch {
            Throw $_
        }
    }
}

If ($FunctionName -eq "Get-TestResultsBasedOnTestPlans") {
    Get-TestResultsBasedOnTestPlans -OrganizationName $OrganizationName -ProjectName $ProjectName -TestingData $TestingData -QualityGateName $QualityGateName -PersonalAccessToken $PersonalAccessToken
}
ElseIf ($FunctionName -eq "Get-TestResultsBasedOnTestPlansAndTestSuites") {
    Get-TestResultsBasedOnTestPlansAndTestSuites -OrganizationName $OrganizationName -ProjectName $ProjectName -TestingData $TestingData -QualityGateName $QualityGateName -PersonalAccessToken $PersonalAccessToken
}
Else {
    Get-SearchQueryResults -OrganizationName $OrganizationName -ProjectName $ProjectName -SearchQuery $SearchQuery -QualityGateName $QualityGateName -PersonalAccessToken $PersonalAccessToken
}