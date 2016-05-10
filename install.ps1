$dir = (Split-Path -Path $profile)+"`\Modules`\"
gci -dir | select Name | foreach -Process {
	cp $_.Name $dir -recurse
	$ips1 = "$dir$($_.Name)`\install.ps1"
	if (Test-Path $ips1) {
		powershell.exe -file $ips1
	}
}
$pf86 = ${Env:ProgramFiles(x86)}
If ($env:PSModulePath -contains $pf86) {
	$env:PSModulePath = $env:PSModulePath + ";C:\$pf86\AWS Tools\PowerShell"
}
gci -dir | select Name | foreach -Process { ipmo -name $_.Name }