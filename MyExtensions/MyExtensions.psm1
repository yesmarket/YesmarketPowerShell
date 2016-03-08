# MyExtensions.psm1
Write-Host "Loading my powershell extensions"

function Reload-Module
{
	<#
	.SYNOPSIS
		Reloads a powershell module.
	.DESCRIPTION
		Reloads a powershell module.
	.Example
		Reload-Module TfsExtensions
	#>
	Param(
		[Parameter(Mandatory=$true)][string] $module
	)
	Remove-Module $module
	Import-Module $module
	Get-Command -Module $module
}

function Get-Paths
{
	<#
	.SYNOPSIS
		Gets all paths in the Path environment variable with each individual displayed on a new line.
	.DESCRIPTION
		Gets all paths in the Path environment variable with each individual displayed on a new line.
	.Example
		Get-Paths
	#>
	$env:Path -split ';'
}

$myExtensions = $MyInvocation.MyCommand.ScriptBlock.Module
$myExtensions.OnRemove = {Write-Host "Removed my extensions"}