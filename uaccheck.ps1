<#
.SYNOPSIS
    Check UAC status of a host or list of hosts
.DESCRIPTION
    Uses remote registry connection to determine if UAC is active and whether Administrator users are prompted ("AdminConsent")
.PARAMETER ComputerName
    Host name of single computer to check
.PARAMETER HostsList
    Path to text file containing list of computers to check
.PARAMETER output
    Path to output comma-seperavated values output of result
#>

param(
    # Specifies singal computer to check
    [Parameter(Mandatory=$true,
        ParameterSetName="Single",
        HelpMessage="Computer name to check UAC status for.")]
    [ValidateNotNullOrEmpty()]
    [string]
    $ComputerName,

    # Specifies path to list of computer anmes
    [Parameter(Mandatory=$true,
               ParameterSetName="Path",
               ValueFromPipeline=$true,
               ValueFromPipelineByPropertyName=$true,
               HelpMessage="Path to one or more locations.")]
    [ValidateNotNullOrEmpty()]
    [string[]]
    $HostsList,

    # Specifies path to output results
    [Parameter(Mandatory=$false,
               ParameterSetName="Path",
               ValueFromPipeline=$true,
               ValueFromPipelineByPropertyName=$true,
               HelpMessage="Path to one or more locations.")]
    [ValidateNotNullOrEmpty()]
    [string]
    $Output
)

if ($ComputerName) {
    Write-Host "Checking single computer: $ComputerName"
    $UAC, $Consent = Check-UAC $ComputerName
    Write-Host "UAC: $UAC, Administrator Consent: $Consent"
}

if ($HostsList) {
    Write-Host "Checking list"
    $ComputerNames = Get-Content $HostsList
    $Count = $ComputerNames.Count
    Write-Host "Checking $Count hosts"
    $result = CheckListOfComputersForUAC $ComputerNames

    if($Output) {
        $result | Export-Csv -NoTypeInformation -Path $Output
    } else {
        Write-Host ($result | ConvertTo-Csv -notype)
    }
}

function CheckListOfComputersForUAC($ComputerNames) {
  $results = New-Object System.Collections.ArrayList
    foreach ($ComputerName in $ComputerNames | Get-Unique) {      
        $UAC, $Consent = Check-UAC $ComputerName
        $result = Make-UACResult $ComputerName $UAC $Consent
        $results += $result
    }
    return $results
}

function Make-UACResult($ComputerName, $UACStatus, $ConsentStatus) {
  $result = New-Object PSObject
  $result | Add-Member -Name "ComputerName" -Value $ComputerName   -MemberType NoteProperty
  $result | Add-Member -Name "UAC"          -Value $UACStatus      -MemberType NoteProperty 
  $result | Add-Member -Name "AdminConsent" -Value $ConsentStatus  -MemberType NoteProperty
  return $result
}

function Check-UAC($ComputerName) {
  Try {
    $RegPath = "Software\Microsoft\Windows\CurrentVersion\Policies\System"
    $RegValue1 = "EnableLUA"
    $RegValue2 = "ConsentPromptBehaviorAdmin"
    $AccessReg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,$ComputerName)
    $Subkey = $AccessReg.OpenSubKey($RegPath,$false)
    $Subkey.ToString() | Out-Null
    $UAC = $Subkey.GetValue($RegValue1)
    $AdminConsent = $Subkey.GetValue($RegValue2)
    Switch ($UAC) {
        1  { $UACConfig = "Enabled"  } 
        0  { $UACConfig = "Disabled" } 
        default {$UACConfig = "Unknown"}
    }
    Switch ($AdminConsent) {
        2  { $AdminConsentConfig = "Enabled"  } 
        5  { $AdminConsentConfig = "Disabled" } 
        default {$AdminConsentConfig = "Unknown"}
    }
    return $UACConfig, $AdminConsentConfig
  } Catch [Exception] {
    Write-Host "Error accessing computer $ComputerName (" $_.Exception.GetType().FullName, $_.Exception.Message ")"
    return "Unknown", "Unknown"
  }
  return "Unknown", "Unknown"
} 