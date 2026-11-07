$rootDir = "c:/Users/omarnour1/Nawaqs"
$runnerPath = "c:/Users/omarnour1/Nawaqs/tests/Tier5AdversarialStressHarness.cs"
if (-not (Test-Path $runnerPath)) {
    $runnerPath = Join-Path $PSScriptRoot "Tier5AdversarialStressHarness.cs"
}
$code = [System.IO.File]::ReadAllText($runnerPath, [System.Text.Encoding]::UTF8)
Add-Type -TypeDefinition $code -Language CSharp
[Nawakes.Tier5StressTest.Tier5Harness]::SetRootDir($rootDir)
$exitCode = [Nawakes.Tier5StressTest.Tier5Harness]::Run()
exit $exitCode
