#requires -version 3.0
#requires -module Hyper-V

<#
.SYNOPSIS
Export virtual machines
.DESCRIPTION
This utility will export virtual machines to a target destination. By default
it will create a folder using the format:

Weekly_Year_Month_Day_HourSecond

The script will delete the oldest folder once 4 subfolders have been created.
Use the -Monthly parameter to do the same thing but for folders that begin
with Monthly, i.e. Monthly_Year_Month_Day_HourSecond.

Because the export process can be time consuming, you can use the -AsJob parameter
which will be passed to Export-VM. You will then get PowerShell background jobs
which you can manage with the standard job cmdlets.

This script must be run as an administrator in an elevated session.

.PARAMETER VM
A comma separated list of virtual machines. You can also pipe Get-VM into
this command. This parameter has an alias of Name.
.PARAMETER Path
The path to the top level backup or export folder.
.PARAMETER Monthly
Run the script in Monthly mode
.PARAMETER AsJob
Export virtual machines using background jobs
.EXAMPLE
PS C:\> get-vm chi-dc01,chi-dc02 | c:\scripts\ScheduledExport.ps1 -path e:\export

Get the virtual machines, CHI-DC01 and CHI-DC02 and pipe them to the script which will
export them to the given folder.

.EXAMPLE
PS C:\> c:\scripts\ScheduledExport.ps1 "CHI-DC01","CHI-FP01" -path E:\Export -asjob

Export virtual machines CHI-DC01 and CHI-FP01 to a weekly folder under E:\Export.

.EXAMPLE
PS C:\> get-content c:\work\vms.txt | c:\scripts\ScheduledExport.ps1 -asjob -monthly

Read the text file, vms.txt, and pass each virtual machine name to the script. This will
use the Monthly backup folders. Exports will be done as jobs.

.LINK
Get-VM
Export-VM

.NOTES
Last Updated:  3/11/2014
Version     :  1.1
Originally sourced from: http://www.infoworld.com/article/2610395/windows-server/two-tricks-to-automate-the-export-of-live-vms-in-windows-server.html

Learn more from Jeff Hicks:
 PowerShell in Depth: An Administrator's Guide
 PowerShell Deep Dives 
 Learn PowerShell 3 in a Month of Lunches 
 Learn PowerShell Toolmaking in a Month of Lunches 
 

  ****************************************************************
  * DO NOT USE IN A PRODUCTION ENVIRONMENT UNTIL YOU HAVE TESTED *
  * THOROUGHLY IN A LAB ENVIRONMENT. USE AT YOUR OWN RISK.  IF   *
  * YOU DO NOT UNDERSTAND WHAT THIS SCRIPT DOES OR HOW IT WORKS, *
  * DO NOT USE IT OUTSIDE OF A SECURE, TEST SETTING.             *
  ****************************************************************
#>

[cmdletbinding(SupportsShouldProcess=$True)]

Param([Parameter(Position=0,Mandatory=$True,
      HelpMessage="Enter the virtual machine name or names",
      ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
      [ValidateNotNullorEmpty()]
      [Alias("name")]
      [string[]]$VM,

      [Parameter(Position=1)]
      [ValidateNotNullorEmpty()]
      [string]$Path = "E:\VMBackups",

      [Parameter(Position=2)]
      [switch]$Monthly,

      [Parameter(Position=3)]
      [switch]$AsJob
)

Begin {

  #define some variables if we are doing weekly or monthly backups
  if ($monthly) {
    $type = "Monthly"
    $retain = 2
  }
  else {
     $type = "Weekly"
     $retain = 2
  }

  Write-Verbose "Processing $type backups. Retaining last $retain."

  #get backup directory list
  Try {
   Write-Verbose "Checking $path for subfolders"
   
   #get only directories under the path that start with Weekly or Monthly
   $subFolders =  dir -Path $path\$type* -Directory -ErrorAction Stop
  }
  Catch {
      Write-Warning "Failed to enumerate folders from $path"
      #bail out of the script
      return
  }

  #check if any backup folders
  if ($subFolders) {
      #if found, get count
      Write-Verbose "Found $($subfolders.count) folder(s)"
      
      #if more than the value of $retain, delete oldest one
      if ($subFolders.count -ge $retain ) {
         #get oldest folder based on its CreationTime property
         $oldest = $subFolders | sort CreationTime | Select -first 1 
         Write-Verbose "Deleting oldest folder $($oldest.fullname)"
         #delete it
         $oldest | Remove-Item -Recurse -Force
      }
        
   } #if $subfolders
  else {
      #if none found, create first one
      Write-Verbose "No matching folders found. Creating the first folder"    
  }

  #create the folder
  #get the current date
  $now = Get-Date

  #name format is Type_Year_Month_Day_HourMinute
  $childPath = "{0}_{1}_{2:D2}_{3:D2}_{4:D2}{5:D2}" -f $type,$now.year,$now.month,$now.day,$now.hour,$now.minute

  #create a variable that represents the new folder path
  $new = Join-Path -Path $path -ChildPath $childPath

  Try {
      Write-Verbose "Creating $new"
      #Create the new backup folder
      $BackupFolder = New-Item -Path $new -ItemType directory -ErrorAction Stop 
  }
  Catch {
    Write-Warning "Failed to create folder $new. $($_.exception.message)"
    #failed to create folder so bail out of the script
    Return
  }
} #end begin

Process {

#only process if a backup folder was created
if ($BackupFolder) {
  #export VMs
  #define a hashtable of parameters to splat to Export-VM
  $exportParam = @{
   Path = $new
   Name=$Null
   ErrorAction="Stop"
  }
  if ($asjob) {
    Write-Verbose "Exporting as background job"
    $exportParam.Add("AsJob",$True)
  }

  Write-Verbose "Exporting virtual machines"
  <#
   Go through each virtual machine name, and export it using Export-VM
  #>
  foreach ($name in $VM) {
    $exportParam.Name=$name
    #if the user did not include -WhatIf then the machine will be exported
    #otherwise they will get a WhatIf message
    if ($PSCmdlet.shouldProcess($name)) {
       Try {
            Export-VM @exportParam
       }
       Catch {
        Write-Warning "Failed to export virtual machine(s). $($_.Exception.Message)"
       }
      } #whatif
    } #close foreach
  } #if backup folder exists 
} #Process
End {
    Write-Host "Export script finished." -ForegroundColor Green
}
