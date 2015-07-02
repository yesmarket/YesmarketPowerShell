Write-Host "Loading Test Module"
Function Start-Test {"Test"}
$test = $MyInvocation.MyCommand.ScriptBlock.Module
$test.OnRemove = {Write-Host "Removed Test Module"}
