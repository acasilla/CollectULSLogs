﻿<# =====================================================================
## Title       : Get-UlsLogs
## Description : This script will collect Individual ULS logs from specified servers or all servers in the farm. It will compress them into <servername>.zip files
## Authors      : Jeremy Walker | Anthony Casillas
## Date        : 12-20-2017
## Input       : 
## Output      : 
## Usage       : .\Get-UlsLogs.ps1 -Servers "server1", "server2" -startTime "12/18/2023 09:00" -endTime "12/18/2023 13:00"
## Notes       :  If no '-Servers' switch is passed, it will grab ULS from all SP servers in the farm.. 
## Tag         :  ULS, Logging, Sharepoint, Powershell
## 
## =====================================================================
#>

[CmdletBinding()]
param
(
    [Parameter(Mandatory=$false)][AllowNull()]
    [string[]]$Servers,
 
    # name of list
    [Parameter(Mandatory=$true, HelpMessage='Enter time format like: "01/01/2017 20:30" ')]
    [string] $startTime,
 
    # name of field
    [Parameter(Mandatory=$true, HelpMessage='Enter time format like: "01/01/2017 22:30" ')]
    [string] $endTime
)

[Void][System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint")
[Reflection.Assembly]::LoadWithPartialName( "System.IO.Compression.FileSystem" )
 Add-PSSnapin Microsoft.SharePoint.PowerShell -EA SilentlyContinue
 Start-SPAssignment -Global

$spDiag = get-spdiagnosticconfig
$global:ulsPath = $spDiag.LogLocation
$global:LogCutInterval = $spDiag.LogCutInterval

 #########################################
 function grabULS2($serv)
 {
    $localPath = "\\" + $serv + "\" + $defLogPath
    "Getting ready to copy logs from: " + $localPath
    ""

    # subtracting the 'LogCutInterval' value to ensure that we grab enough ULS data 
    $startTime = $startTime.Replace('"', "")
    $startTime = $startTime.Replace("'", "")
    $sTime = (Get-Date $startTime).AddMinutes(-$LogCutInterval)

    # setting the endTime variable
    $endTime = $endTime.Replace('"', "")
    $endTime = $endTime.Replace("'", "")
    $eTime = Get-Date $endTime
    
    $files = get-childitem -path $localPath -Filter "*-??????*-????.log" | Select-Object Name, CreationTime
    $specfiles = $files | Where-Object{$_.CreationTime -lt $eTime -and $_.CreationTime -ge $sTime}
    if($specfiles.Length -eq 0)
    {
        " We did not find any ULS logs for server, " + $serv +  ", within the given time range"
        $rmvDir = $outputdir + "\" + $serv
        Remove-Item $rmvDir -Recurse -Force
        return;
    }
    foreach($file in $specfiles)
    {
        $filename = $file.name
        "Copying file:  " + $filename
        copy-item "$localpath\$filename" $outputdir\$serv
    }

    $timestamp = $(Get-Date -format "yyyyMMdd_HHmm")
    $sourceDir = $tempSvrPath
    $zipfilename = $tempSvrPath + "_" + $timestamp + ".zip"
    ""
    Write-Host ("Compressing ULS logs to location: " + $zipfilename) -ForegroundColor DarkYellow
    
    $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
    [System.IO.Compression.ZipFile]::CreateFromDirectory( $tempSvrPath, $zipfilename, $compressionLevel, $false )
    Write-Host ("Cleaning up the ULS logs and temp directory at: " + $tempSvrPath) -ForegroundColor DarkYellow
    Remove-Item $sourcedir -Recurse -Force
 }
 ######################
 #Get Destination Path#
 ######################
 Write-Host "Enter a folder path where you want the ULS files copied"
 $outputDir = Read-Host "(For Example: C:\Temp)"

if(test-path -Path $outputDir)
 {Write-Host}

else
 {
 Write-Host "The path you provided could not be found" -foregroundcolor Yellow
 Write-Host "Path Specified: " $outputDir -ForegroundColor Yellow
 Write-Host
 $outputDir = Read-Host "Enter a folder path where you want the ULS files copied (For Example: C:\Temp\)"
 $checkPath = test-path $outputDir

if($checkPath -ne $true)
 {
 Write-Host "Path was not found - Exiting Script" -ForegroundColor Yellow
 Return
 }

else
 {Write-Host "Path is now valid and will continue"}
 }

########################################
 #Get SharePoint Servers and SP Version##
 ########################################

$spVersion = (Get-PSSnapin Microsoft.Sharepoint.Powershell).Version.Major

if((($spVersion -ne 14) -and ($spVersion -ne 15) -and ($spVersion -ne 16)))
 {
     Write-Host "Supported version of SharePoint not Detected" -ForegroundColor Yellow
     Write-Host "Script is supported for SharePoint 2010, 2013, or 2016" -ForegroundColor Yellow
     Write-Host "Exiting Script" -ForegroundColor Yellow
     Return
 }

 else
 {
     $defLogPath = (get-spdiagnosticconfig).LogLocation -replace "%CommonProgramFiles%", "C$\Program Files\Common Files"
     $defLogPath = $defLogPath -replace ":", "$"
    "Default ULS Log Path:  " + $defLogPath
    ""
    " **We will copy files from each server into a temp directory in the defined Output Folder and then compress those files into a .zip file. This can take several minutes to complete depending on network speed, number of files and size of files."
    ""
 }

 ######################################
 ######################################
 if($null -eq $Servers)
 {
  
   $Servers = get-spserver | Where-Object{$_.Role -ne "Invalid"} | ForEach-Object{$_.Address}
  } 
    foreach($server in $Servers)
    {
        $serverName = $server
        $tempSvrPath = $outputDir + "\" +$servername
        ""
        "Creating a temp directory at: " + $tempSvrPath
        mkdir $tempSvrPath | Out-Null
        grabULS2 $serverName
    }
    ""
     Write-Host ("Finished Copying\Zipping files.. Please upload the zip files located at:  " + $outputDir) -ForegroundColor Green