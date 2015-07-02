# AWSPowerShellExtensions.psm1
Write-Host "Loading Extensions to AWS Tools"

function Get-S3Objects
{
  <#
  .SYNOPSIS
    Gets a list of list of all S3 objects in a bucket.
  .DESCRIPTION
    Gets a list of list of all S3 objects in a bucket.
  .PARAMETER BucketName
    Specifies a S3 bucket name.
  .Example
    Get-S3Objects -BucketName www.ryanbartsch.com
  .NOTES
    Before calling this function, ensure you've set the AWS region by calling the Set-DefaultAWSRegion cmdlet, and you've specified some AWS credentials for the session by calling the Set-AWSCredentials cmdlet.
  #>
  Param([Parameter(Mandatory=$true)][string] $BucketName)
  $s3objects = Get-S3Object -BucketName $BucketName
  foreach($s3object in $s3objects) {
    Write-Host $s3object.Key
  }
}

function Write-S3Objects
{
  <#
  .SYNOPSIS
    Uploads S3 objects to a bucket.
  .DESCRIPTION
    Uploads S3 objects to a bucket.
  .PARAMETER BucketName
    The S3 bucket to upload files to.
  .PARAMETER Path
    The path of the files to upload.
  .Example
    Get-S3Objects -Write www.ryanbartsch.com -Path C:\git\ryanbartsch
  .NOTES
    Before calling this function, ensure you've set the AWS region by calling the Set-DefaultAWSRegion cmdlet, and you've specified some AWS credentials for the session by calling the Set-AWSCredentials cmdlet.
  #>
  Param(
    [Parameter(Mandatory=$true)][string] $BucketName,
    [string] $Path = ".\"
  )
  $childItems = Get-ChildItem -Path $Path
  foreach($childItem in $childItems) {
    $objectName = $childItem.FullName -replace [Regex]::Escape((Get-Item -Path ".\" -Verbose).FullName+"\"), ""
    if ($objectName -like "*.*")
    {
      Write-S3Object -BucketName $BucketName -File $objectName -Key $objectName
    }
    else
    {
      Write-S3Object -BucketName $BucketName -Directory $objectName -KeyPrefix $objectName -Recurse
    }
  }
}

function Remove-S3Objects
{
  <#
  .SYNOPSIS
    Removes all S3 objects from a bucket.
  .DESCRIPTION
    Removes all S3 objects from a bucket.
  .PARAMETER BucketName
    The S3 bucket to remove objects from.
  .Example
    Remove-S3Objects -BucketName www.ryanbartsch.com
  .NOTES
    Before calling this function, ensure you've set the AWS region by calling the Set-DefaultAWSRegion cmdlet, and you've specified some AWS credentials for the session by calling the Set-AWSCredentials cmdlet.
  #>
  Param([Parameter(Mandatory=$true)][string] $BucketName)
  $os = Get-S3Object -BucketName $BucketName
  foreach($s3object in $os) {
    Remove-S3Object -BucketName $BucketName -Key $s3object.Key -Force:$true
  }
}

function Replace-S3Bucket
{
  <#
  .SYNOPSIS
    Removes all S3 objects from a bucket and then uploads all files from the specified path to that bucket.
  .DESCRIPTION
    Removes all S3 objects from a bucket and then uploads all files from the specified path to that bucket.
  .PARAMETER BucketName
    The S3 bucket to use.
  .PARAMETER Path
    The path of the files to upload.
  .Example
    Replace-S3Bucket -BucketName www.ryanbartsch.com -Path C:\git\ryanbartsch
  .NOTES
    Before calling this function, ensure you've set the AWS region by calling the Set-DefaultAWSRegion cmdlet, and you've specified some AWS credentials for the session by calling the Set-AWSCredentials cmdlet.
  #>
  Param(
    [Parameter(Mandatory=$true)][string] $BucketName,
    [string] $Path = ".\"
  )
  Remove-S3Objects -BucketName $BucketName
  Write-S3Objects -BucketName $BucketName -Path $Path
}

$awsPowerShellExtensions = $MyInvocation.MyCommand.ScriptBlock.Module
$awsPowerShellExtensions.OnRemove = {Write-Host "Removed Extensions to AWS Tools"}
