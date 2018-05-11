param (
  [string]
  [ValidateSet("WIM", "VHD", "Update")]
  $Workflow
)

No.

#region Functions/Variables
$OSData = @{
  VMVersionDefault = $null
  Generations = @()
  Editions = @()
  OperatingSystems = @()
}

function New-GenerationObj ([byte]$Number, [string]$PartitionStyle, [string[]]$VHDFormats) {
  $script:OSData.Generations += [PSCustomObject]@{
    Number          = $Number
    PartitionStyle  = $PartitionStyle
    VHDFormats      = $VHDFormats
  }
}

function New-EditionObj ([string]$Name, [string[]]$Targeting) {
  $script:OSData.Editions += [PSCustomObject]@{
    Name      = $Name
    Targeting = $Targeting
  }
}

function New-OSObj {
  param(
    [string]
    $FilePrefix,
    
    [string]
    $Name,
    
    [string[]]
    $Editions,
    
    [byte[]]
    $Generations,
    
    [string[]]
    $Targeting,
    
    [string[]]
    [ValidateSet("WIM", "VHD", "Update")]
    $Workflows,

    [string]
    $WsusProductName
  )
  $outObj = [PSCustomObject]@{
    FilePrefix      = $FilePrefix
    Name            = $Name
    Editions        = $Editions
    Generations     = $Generations
    Targeting       = $Targeting
    Workflows       = $Workflows
    WsusProductName = $Name
  }

  if ($PSBoundParameters.ContainsKey("WsusProductName")) {
    $outObj.WsusProductName = $WsusProductName
  }

  $script:OSData.OperatingSystems += $outObj
}
#endregion

#region OTHER ATTRIBUTES

# Best practice is to update this value instead of clearing it, as this will
# ensure that I never unwittingly build a VM export I cannot deploy, due to
# (e.g.) a feature update that has not propagated to all of our classroom
# workstations.
$OSData.VMVersionDefault = "8.0"

#endregion

#region GENERATIONS
New-GenerationObj -Number 1 -PartitionStyle MBR -VHDFormats vhdx,vhd
New-GenerationObj -Number 2 -PartitionStyle GPT -VHDFormats vhdx
#endregion

#region EDITIONS
New-EditionObj -Name ServerStandard -Targeting "Standard","Std"
New-EditionObj -Name ServerStandardCore -Targeting "Core"
#endregion

#region SERVER DEFINITIONS

# Required to translate S2008R2-era Hyper-V exports into XML files that can be
# imported by subsequent operating systems. Superceded for all other uses, and
# thus must be targeted using the fictitious "R1" identifier.
New-OSObj -FilePrefix "S2012" `
          -Name "Windows Server 2012" `
          -Editions ServerStandard,ServerStandardCore `
          -Generations 1,2 `
          -Targeting "S2012 R1","S2012R1" `
          -Workflows WIM,VHD

# Legacy OS for classroom server loads.
New-OSObj -FilePrefix "S2012 R2" `
          -Name "Windows Server 2012 R2" `
          -Editions ServerStandard,ServerStandardCore `
          -Generations 1,2 `
          -Targeting "S2012 R2","S2012R2","S2012" `
          -Workflows WIM,VHD,Update

# Primary OS for classroom server loads.
New-OSObj -FilePrefix "S2016" `
          -Name "Windows Server 2016" `
          -Editions ServerStandard,ServerStandardCore `
          -Generations 1,2 `
          -Targeting "S2016" `
          -Workflows WIM,VHD,Update
#endregion

#region CLIENT DEFINITIONS

# Provides a legacy OS environment for certain classes.
New-OSObj -FilePrefix "W7 SP1" `
          -Name "Windows 7 Service Pack 1" `
          -Editions Enterprise `
          -Generations 1 `
          -Targeting "W7 SP1","W7SP1","W7" `
          -Workflows WIM,VHD

# Used to create 2041X-series "Mock" loads for testing purposes. Is
# incompatible with Update workflow for unknown reason; updates will
# not apply offline.
New-OSObj -FilePrefix "W8.1" `
          -Name "Windows 8.1" `
          -Editions Enterprise `
          -Generations 1,2 `
          -Targeting "W8.1" `
          -Workflows WIM,VHD

# Primary OS for classroom client loads.
New-OSObj -FilePrefix "W10 v1703" `
          -Name "Windows 10 v1703" `
          -Editions Enterprise `
          -Generations 1,2 `
          -Targeting "W10 v1703","W10" `
          -Workflows WIM,VHD,Update `
          -WsusProductName "Windows 10"

# Evaluation OS for classroom client loads.
New-OSObj -FilePrefix "W10 v1709" `
          -Name "Windows 10 v1709" `
          -Editions Enterprise `
          -Generations 1,2 `
          -Targeting "W10 v1709" `
          -Workflows WIM,VHD,Update `
          -WsusProductName "Windows 10"

# Evaluation OS for classroom client loads.
New-OSObj -FilePrefix "W10 v1803" `
          -Name "Windows 10 v1803" `
          -Editions Enterprise `
          -Generations 1,2 `
          -Targeting "W10 v1803" `
          -Workflows WIM,VHD,Update `
          -WsusProductName "Windows 10"
#endregion

#region DISABLED DEFINITIONS
# No current use case. Is widely used in enterprises due to the longevity of
# server builds, but I have only *once* been asked to load it here.
New-OSObj -FilePrefix "S2008 R2 SP1" `
          -Name "Windows Server 2008 R2 Service Pack 1" `
          -Editions ServerStandard,ServerStandardCore `
          -Generations 1 `
          -Targeting "S2008 R2","S2008R2","S2008" `
          -Workflows WIM

# No current use case. I have never been *specifically* asked to load this OS,
# and nobody seemed to notice when I switched it out for SP1. If it ever *is*
# needed again, it must be targeted using the fictitious "SP0" identifier.
New-OSObj -FilePrefix "W7" `
          -Name "Windows 7" `
          -Editions Enterprise `
          -Generations 1 `
          -Targeting "W7 SP0","W7SP0" `
          -Workflows WIM

# Legacy W10 OS; no longer supported by MS.
New-OSObj -FilePrefix "W10 v1511" `
          -Name "Windows 10 v1511" `
          -Editions Enterprise `
          -Generations 1,2 `
          -Targeting "W10 v1511" `
          -Workflows WIM

# Legacy W10 OS; no longer supported by MS.
New-OSObj -FilePrefix "W10 v1607" `
          -Name "Windows 10 v1607" `
          -Editions Enterprise `
          -Generations 1,2 `
          -Targeting "W10 v1607" `
          -Workflows WIM

#endregion

if ($Workflow.Length -gt 0) {
  $OSData.OperatingSystems = @(
    $OSData.OperatingSystems |
      Where-Object Workflows -contains $Workflow
  )
}

$OSData