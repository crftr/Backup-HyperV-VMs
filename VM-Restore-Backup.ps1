#requires -version 3.0
#requires -module Hyper-V

<#
.SYNOPSIS
Returns details about the most recent backup of a specific VM.

.PARAMETER VMname
The name of the virtual machine.

.PARAMETER BaseFolder
(optional) Where the VM backups are stored.

.EXAMPLE
PS C:\> Get-Latest-VM-Backup('STAGING-Web02')

#>
Function Get-Latest-VM-Backup()
{
  Param([string]$VMname,
        [string]$BaseFolder = 'E:\VMBackups')
  
  Get-ChildItem ($BaseFolder + '\*\' + $VMname) |
    select name, 
           FullName,
           *time,
           @{Name = "DateString";
             Expression = {
              [regex]::match($_.FullName, '(Monthly|Weekly)_(\d{4}_\d{2}_\d{2}_\d{4})').Groups[2] }} |
    Sort-Object DateString -Descending |
    Select-Object -first 1
}

<#
.SYNOPSIS
Import a virtual machine backup that was generated using the VM-Backup script.

.PARAMETER VMname
The name of the virtual machine to be imported.

.EXAMPLE
PS C:\> Import-Latest-VM-Backup('STAGING-Web02')

#>
Function Import-Latest-VM-Backup()
{
  Param([string]$VMname)

  $baseFolder = Get-Latest-VM-Backup($VMname) | select FullName
  $xmlConfig = Get-ChildItem -Path ($baseFolder.FullName + '\Virtual Machines') -Filter *.xml
  Import-VM -Path ($xmlConfig.FullName) -Copy -GenerateNewId
}