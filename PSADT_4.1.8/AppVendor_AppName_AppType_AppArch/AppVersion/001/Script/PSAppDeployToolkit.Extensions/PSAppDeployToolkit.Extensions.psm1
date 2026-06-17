<#

.SYNOPSIS
PSAppDeployToolkit.Extensions - Provides the ability to extend and customize the toolkit by adding your own functions that can be re-used.

.DESCRIPTION
This module is a template that allows you to extend the toolkit with your own custom functions.

This module is imported by the Invoke-AppDeployToolkit.ps1 script which is used when installing or uninstalling an application.

#>

##*===============================================
##* MARK: MODULE GLOBAL SETUP
##*===============================================

# Set strict error handling across entire module.
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
Set-StrictMode -Version 1

<#
.SYNOPSIS
    Removes registry keys based on a given pattern.

.DESCRIPTION
    The function scans for and deletes registry keys based on a provided pattern.
    It utilizes the PowerShell's ability to interface with the Windows Registry
    and regular expressions to achieve pattern-based key deletions. Care should
    be taken when executing this function, as deleting important registry keys can
    cause system instability.

.PARAMETER Path
    Specifies the path in the Windows Registry where the function should start
    its search. E.g., "HKLM:\Software\".

.PARAMETER Pattern
    The pattern of the registry key names you want to search for. Use '*' as
    a wildcard to represent any sequence of characters.
    E.g., "Adobe_AcrobatReaderDC_*_Default_x86".

.EXAMPLE
    Remove-RegistryKeysWithPattern -Path "HKLM:\Software\" -Pattern "Adobe_AcrobatReaderDC_*_Default_x86"

    This example will search for and delete all registry keys under "HKLM:\Software\"
    that match the pattern "Adobe_AcrobatReaderDC_*_Default_x86".

#>
function Remove-RegistryKeysWithPattern
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Pattern
    )

    # Replace the user-friendly wildcard '*' with its regex equivalent '.*'
    # Also, escape any regex special characters in the pattern
    $regexPattern = [regex]::Escape($Pattern) -replace '\\\*', '.*'

    # Retrieve all registry keys that match the specified pattern
    $keysToDelete = Get-ChildItem -Path $Path -Recurse | Where-Object { $_.Name -match $regexPattern }

    # If matching keys are found, proceed to delete them
    if ($keysToDelete)
    {
        foreach ($key in $keysToDelete)
        {
            Write-ADTLogEntry "Deleting registry key: $($key.PSPath)"
            Remove-ADTRegistryKey -Key $key.PSPath
        }
    } else
    {
        Write-ADTLogEntry "No registry keys matching pattern $Pattern found."
    }
}


##*===============================================
##* MARK: SCRIPT BODY
##*===============================================

# Announce successful importation of module.
Write-ADTLogEntry -Message "Module [$($MyInvocation.MyCommand.ScriptBlock.Module.Name)] imported successfully." -ScriptSection Initialization
