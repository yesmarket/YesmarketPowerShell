# TfsMigrationExtensions.psm1
Write-Host "Loading TFS powershell extensions"

function Clear-TfsCache
{
	<#
	.SYNOPSIS
		Removes all files from the the TFS cache.
	.DESCRIPTION
		Removes all files from the the TFS cache.
	.Example
		Clear-TfsCache
	#>

	$username = [Environment]::UserName
	$v4path = "C:\Users\$username\AppData\Local\Microsoft\Team Foundation\4.0\Cache"
	$v6path = "C:\Users\$username\AppData\Local\Microsoft\Team Foundation\6.0\Cache"

	If ((Test-Path $v4path) -eq $TRUE) { rm -recurse -force "$v4path\*" }
	If ((Test-Path $v6path) -eq $TRUE) { rm -recurse -force "$v6path\*" }
}

function Remove-TeamProject
{
	<#
	.SYNOPSIS
		Completely removes a team project from a team project collection.
	.DESCRIPTION
		Completely removes a team project from a team project collection.
	.PARAMETER collection
		URL of team project collection.
	.PARAMETER teamprojectname
		Name of the team project to be created.
	.Example
		Initialize-TeamProject -collection http://servername:8080/tfs/defaultcollection -teamprojectname XXX
	#>
	Param(
		[Parameter(Mandatory=$true)][string] $collection,
		[Parameter(Mandatory=$true)][string] $teamprojectname
	)

	echo "Removing team project '$teamprojectname'"
	TFSDeleteProject /collection:$collection $teamprojectname /q /force
}

function Register-Workspace
{
	<#
	.SYNOPSIS
		Registers a new workspace for the specified collection. 
	.DESCRIPTION
		Registers a new workspace for the specified collection.
	.PARAMETER collection
		URL of team project collection.
	.PARAMETER workspacename
		The name of the workspace.
	.Example
		Register-Workspace -collection http://servername:8080/tfs/defaultcollection -workspacename migration
	#>
	Param(
		[Parameter(Mandatory=$true)][string] $collection,
		[Parameter(Mandatory=$true)][string] $workspacename
	)

	tf workspace /new /noprompt /collection:$collection $workspacename /permission:Private | Out-Null
	tf vc workfold /unmap $/ /collection:$collection /workspace:$workspacename | Out-Null
}

function Initialize-TeamProject
{
	<#
	.SYNOPSIS
		Registers a new workspace for the specified collection.
	.DESCRIPTION
		Registers a new workspace for the specified collection.
	.PARAMETER collection
		URL of team project collection.
	.PARAMETER teamprojectname
		Name of the team project to be created.
	.PARAMETER workspacename
		The name of the workspace.
	.PARAMETER processtemplate
		The name of the process template.
	.PARAMETER branchname
		The name of the branch.
	.Example
		Initialize-TeamProject -collection http://servername:8080/tfs/defaultcollection -name XXX -workspacename tfs
	#>
	Param(
		[Parameter(Mandatory=$true)][string] $collection,
		[Parameter(Mandatory=$true)][string] $teamprojectname,
		[Parameter(Mandatory=$true)][string] $workspacename,
		[string] $processtemplate = 'scrum',
		[string] $branchname = 'Master'
	)

	$username = [Environment]::UserName
	$commitMessage = "Creation of $branchname branch."

	echo "Clearing TFS cache"
	Clear-TfsCache | Out-Null

	$exists = tf workspaces /collection:$collection | foreach-object { $_ -like "$workspacename*" } | where { $_ } | select -first 1
	If ($exists -ne $TRUE) {
		echo "Creating workspace '$workspacename'"
		Register-Workspace -collection $collection -workspacename $workspacename
	}

	echo "Creating '$teamprojectname' team-project..."
	tfpt createteamproject /collection:$collection /teamproject:$teamprojectname /processtemplate:$processtemplate /sourcecontrol:New /noportal | Out-Null

	echo "Mapping local workspace for '$teamprojectname'"
	ni -ItemType Directory -Force -Path ".\$teamprojectname" | Out-Null

	tf workfold /map "`$/$teamprojectname" ./$teamprojectname /collection:$collection /workspace:$workspacename | Out-Null
	cd $teamprojectname | Out-Null

	echo "Creating '$branchname' root directory"
	Add-TfsFolder -name $branchname

	echo "Checking-in changes"
	tf checkin /author:$username /comment:$commitMessage /noprompt $branchname | Out-Null

	echo "Converting '$branchname' directory to a branch"
	tfpt branches /convertToBranch /collection:$collection "`$/$teamprojectname/$branchname" | Out-Null

	#clean-up
	cd .. | Out-Null
	rm -recurse -force ".\$teamprojectname" | Out-Null
}

function Copy-TeamProject
{
	<#
	.SYNOPSIS
		Copies a team project from one TFS collection to another.
	.DESCRIPTION
		Copies a team project from one TFS collection to another.
	.PARAMETER sourcecollection
		URL of the source team project collection.
	.PARAMETER sourcename
		Name of the team project to copy from the source team project collection.
	.PARAMETER sourcebranch
		Name of the branch to copy from the source team project.
	.PARAMETER destinationcollection
		URL of the destination team project collection.
	.PARAMETER destinationname
		Name of the team project to in the destination team project collection.
	.PARAMETER usermappath
		The path the USERMAP file used by git-tf checkin.
	.Example
		Copy-TeamProject -sourcecollection http://servername1:8080/tfs/defaultcollection -sourcename XXX -sourceBranch Trunk -destinationCollection http://servername2:8080/tfs/defaultcollection -destinationname YYY
	#>
	Param(
		[Parameter(Mandatory=$true)][string] $sourcecollection,
		[Parameter(Mandatory=$true)][string] $sourcename,
		[Parameter(Mandatory=$true)][string] $sourcebranch,
		[Parameter(Mandatory=$true)][string] $destinationcollection,
		[Parameter(Mandatory=$true)][string] $destinationname,
		[string] $usermappath = 'USERMAP'
	)
	
	$username = [Environment]::UserName
	$localSource = "git-$sourcename-source"
	$localDestination = "git-$destinationname-destination"
	$usermapabsolutepath = (gci . -fi $usermappath).FullName

	echo "Clearing TFS cache"
	Clear-TfsCache | Out-Null

	echo "Cloning source into '$localSource'..."
	git-tf clone --deep $sourcecollection "`$/$sourcename/$sourcebranch" $localSource | Out-Null

	echo "Cloning destination into '$localDestination'..."
	git-tf clone --deep $destinationcollection "`$/$destinationname/Master" $localDestination | Out-Null

	echo "Migrating commits from source to destination..."
	cd $localDestination | Out-Null
	git remote add $localSource "..\$localSource\.git\" | Out-Null
	git fetch $localSource -q
	git checkout "remotes/$localSource/master" -b $localSource -q
	git rebase master -q
	git checkout master -q
	git merge $localSource -q
	If ($usermapabsolutepath.Length -eq 0) { git-tf checkin --deep --keep-author --user-map=USERMAP | Out-Null } 
	Else { git-tf checkin --deep --keep-author | Out-Null }

	# clean-up
	git branch -D $localSource | Out-Null
	git remote rm $localSource | Out-Null
	cd .. | Out-Null
	rm -recurse -force ".\$localSource" | Out-Null
	rm -recurse -force ".\$localDestination" | Out-Null
}

function Set-GitFlow
{
	<#
	.SYNOPSIS
		Sets up the folder and branching structure for gitflow.
	.DESCRIPTION
		Sets up the folder and branching structure for gitflow.
	.PARAMETER collection
		URL of the team project collection.
	.PARAMETER teamprojectname
		Name of the team project.
	.Example
		Set-GitFlow -collection http://servername1:8080/tfs/defaultcollection -teamprojectname XXX
	#>
	Param(
		[Parameter(Mandatory=$true)][string] $collection,
		[Parameter(Mandatory=$true)][string] $teamprojectname
	)

	$username = [Environment]::UserName

	tf workspaces /collection:$collection | Out-Null

	echo "Creating Develop branch from Master"
	ni -ItemType Directory -Force -Path ".\$teamprojectname" | Out-Null
	cd $teamprojectname | Out-Null
	tf branch "`$/$teamprojectname/Master" "`$/$teamprojectname/Develop" /noprompt /silent /checkin /comment:"Creation of Develop branch." /author:$username | Out-Null

	Add-TfsFolder -name "Features"
	Add-TfsFolder -name "HotFixes"
	Add-TfsFolder -name "Releases"

	echo "Checking-in changes"
	tf checkin /author:$username /comment:"Creation of folder structure for gitflow" /noprompt .\* | Out-Null

	# clean-up
	cd .. | Out-Null
	rm -recurse -force ".\$teamprojectname" | Out-Null
}

function Add-TfsFolder
{
	Param([Parameter(Mandatory=$true)][string] $name)
	ni -ItemType Directory -Force -Path ".\$name" | Out-Null
	tf add $name /noprompt | Out-Null
}

$tfsMigrationExtensions = $MyInvocation.MyCommand.ScriptBlock.Module
$tfsMigrationExtensions.OnRemove = {Write-Host "Removed TFS extensions"}