$rootDir = "c:/Users/omarnour1/Nawaqs"
$runnerPath = "c:/Users/omarnour1/Nawaqs/tests/E2ETestSuiteRunner.cs"
if (-not (Test-Path $runnerPath)) {
    $runnerPath = Join-Path $PSScriptRoot "E2ETestSuiteRunner.cs"
}
$code = [System.IO.File]::ReadAllText($runnerPath, [System.Text.Encoding]::UTF8)
Add-Type -TypeDefinition $code -Language CSharp
[Nawakes.E2ETestSuite.E2ERunner]::SetRootDir($rootDir)
$exitCode = [Nawakes.E2ETestSuite.E2ERunner]::RunAll()
exit $exitCode
