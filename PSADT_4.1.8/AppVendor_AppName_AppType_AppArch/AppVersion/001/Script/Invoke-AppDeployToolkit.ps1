<#

.PARAMETER DeployMode
Specifies whether the installation should be run in Interactive (shows dialogs), Silent (no dialogs), NonInteractive (dialogs without prompts) mode, or Auto (shows dialogs if a user is logged on, device is not in the OOBE, and there's no running apps to close).

Silent mode is automatically set if it is detected that the process is not user interactive, no users are logged on, the device is in Autopilot mode, or there's specified processes to close that are currently running.

.PARAMETER SuppressRebootPassThru
Suppresses the 3010 return code (requires restart) from being passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.

.EXAMPLE
powershell.exe -File Invoke-AppDeployToolkit.ps1

.EXAMPLE
powershell.exe -File Invoke-AppDeployToolkit.ps1 -DeployMode Silent

.EXAMPLE
powershell.exe -File Invoke-AppDeployToolkit.ps1 -DeploymentType Uninstall

.EXAMPLE
Invoke-AppDeployToolkit.exe -DeploymentType Install -DeployMode Silent

.LINK
https://psappdeploytoolkit.com

#>

[CmdletBinding()]
param
(
    # Default is 'Install'.
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [System.String]$DeploymentType,

    # Default is 'Auto'. Don't hard-code this unless required.
    [Parameter(Mandatory = $false)]
    [ValidateSet('Auto', 'Interactive', 'NonInteractive', 'Silent')]
    [System.String]$DeployMode,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$SuppressRebootPassThru,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$TerminalServerMode,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$DisableLogging
)


##================================================
## MARK: Variables
##================================================

$adtSession = @{
    # App variables.
    AppVendor = '' # TODO AppVendor - Example: Mozilla
    AppName = '' # TODO AppName - Example Firefox
    AppVersion = '' # TODO AppVersion - Exmaple: 1.0.0
    AppArch = '' # TODO AppArch - Exmaple: x86 or x64
    AppLang = 'EN'
    AppRevision = '001'
    AppSuccessExitCodes = @(0)
    AppRebootExitCodes = @(1641, 3010)
    AppProcessesToClose = @() # TODO AppProcessesToClose - Example: @('excel', @{ Name = 'winword'; Description = 'Microsoft Word' })
    AppScriptVersion = '1.0.0'
    AppScriptDate = '2026-01-14' # TODO AppScriptDate - Example: YYYY-MM-DD
    AppScriptAuthor = '' # TODO AppScriptAuthor - Example: Firstname Lastname
    RequireAdmin = $true

    # Custom variables
    AppType = 'Default'
    RegistryDetectionPath = 'HKLM:\SOFTWARE\CUSTOMER'

    # Install Titles (Only set here to override defaults set by the toolkit).
    InstallName = ''
    InstallTitle = ''

    # Script variables.
    DeployAppScriptFriendlyName = $MyInvocation.MyCommand.Name
    DeployAppScriptParameters = $PSBoundParameters
    DeployAppScriptVersion = '4.1.8'
}

function Install-ADTDeployment
{
    [CmdletBinding()]
    param
    (
    )

    ##================================================
    ## MARK: Pre-Install
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ## If processes to close, show Welcome Message with a 900 second countdown before automatically closing.
    if ($adtSession.AppProcessesToClose.Count -gt 0)
    {
        Show-ADTInstallationWelcome -CloseProcesses $adtSession.AppProcessesToClose -CloseProcessesCountdown 900
    }

    ## <Perform Pre-Installation tasks here>

    # TODO Pre-Install


    ##================================================
    ## MARK: Install
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ## <Perform Installation tasks here>

    # TODO Installation


    ##================================================
    ## MARK: Post-Install
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Installation tasks here>

    # TODO Post-Install


    # Check if registry detection key exists, if not create it
    if (Test-Path -Path $adtSession.RegistryDetectionPath)
    {
        Write-ADTLogEntry "Software registry root key already exists"
    } else
    {
        Set-ADTRegistryKey -Key $adtSession.RegistryDetectionPath
        Write-ADTLogEntry "Created registry key: $($adtSession.RegistryDetectionPath)"
    }

    # Remove detection registry keys for prior versions (AppVendor_AppName_AppType_AppVersion_AppRevision_AppArch)
    $regKeyPSADT4Pattern = "$($adtSession.AppVendor.Replace(' ', ''))_$($adtSession.AppName.Replace(' ', ''))_$($adtSession.AppType)_*_*_$($adtSession.AppArch)"
    Remove-RegistryKeysWithPattern -Path "$($adtSession.RegistryDetectionPath)\" -Pattern $regKeyPSADT4Pattern

    # Set new registry keys for application detection (SCCM /Intune)
    $RegKey = Join-Path -Path $adtSession.RegistryDetectionPath -ChildPath "$($adtSession.AppVendor.Replace(' ', ''))_$($adtSession.AppName.Replace(' ', ''))_$($adtSession.AppType)_$($adtSession.AppVersion)_$($adtSession.AppRevision)_$($adtSession.AppArch)"
    Set-ADTRegistryKey -Key $RegKey -Name 'AppVersion' -Value $adtSession.AppVersion
    Set-ADTRegistryKey -Key $RegKey -Name 'AppArchitecture' -Value $adtSession.AppArch
    Set-ADTRegistryKey -Key $RegKey -Name 'AppType' -Value $adtSession.AppType
    Set-ADTRegistryKey -Key $RegKey -Name 'AppLanguage' -Value $adtSession.AppLang
    Set-ADTRegistryKey -Key $RegKey -Name 'PackageRevision' -Value $adtSession.AppRevision
    Set-ADTRegistryKey -Key $RegKey -Name 'ScriptVersion' -Value $adtSession.AppScriptVersion
    Set-ADTRegistryKey -Key $RegKey -Name 'InstallStartTime' -Value (Get-Date $adtSession.CurrentDateTime -format "dd/MM/yyyy HH:mm:ss") # Current date & time when the toolkit was launched
    Set-ADTRegistryKey -Key $RegKey -Name 'InstallEndTime' -Value (Get-Date -format "dd/MM/yyyy HH:mm:ss") # date & time when post installation is done
    Set-ADTRegistryKey -Key $RegKey -Name 'ScriptAuthor' -Value $adtSession.AppScriptAuthor
}

function Uninstall-ADTDeployment
{
    [CmdletBinding()]
    param
    (
    )

    ##================================================
    ## MARK: Pre-Uninstall
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ## If there are processes to close, show Welcome Message with a 60 second countdown before automatically closing.
    if ($adtSession.AppProcessesToClose.Count -gt 0)
    {
        Show-ADTInstallationWelcome -CloseProcesses $adtSession.AppProcessesToClose -CloseProcessesCountdown 60
    }

    ## <Perform Pre-Uninstallation tasks here>

    # TODO Pre-Uninstall


    ##================================================
    ## MARK: Uninstall
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ## <Perform Uninstallation tasks here>

    # TODO Uninstall


    ##================================================
    ## MARK: Post-Uninstallation
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Uninstallation tasks here>

    # TODO Post-Uninstall


    # Remove Registry Keys of Detection Method
    $RegKey = Join-Path -Path $adtSession.RegistryDetectionPath -ChildPath "$($adtSession.AppVendor.Replace(' ', ''))_$($adtSession.AppName.Replace(' ', ''))_$($adtSession.AppType)_$($adtSession.AppVersion)_$($adtSession.AppRevision)_$($adtSession.AppArch)"
    Remove-ADTRegistryKey -Key "$($RegKey)"
}

function Repair-ADTDeployment
{
    [CmdletBinding()]
    param
    (
    )

    ##================================================
    ## MARK: Pre-Repair
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ## If processes to close, show Welcome Message with a 90 second countdown before automatically closing.
    if ($adtSession.AppProcessesToClose.Count -gt 0)
    {
        Show-ADTInstallationWelcome -CloseProcesses $adtSession.AppProcessesToClose -CloseProcessesCountdown 90
    }


    ##================================================
    ## MARK: Repair
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ## <Perform Repair tasks here>


    ##================================================
    ## MARK: Post-Repair
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## <Perform Post-Repair tasks here>


}


##================================================
## MARK: Initialization
##================================================

# Set strict error handling across entire operation.
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
Set-StrictMode -Version 1

# Import the module and instantiate a new session.
try
{
    # Import the module locally if available, otherwise try to find it from PSModulePath.
    if (Test-Path -LiteralPath "$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit.psd1" -PathType Leaf)
    {
        Get-ChildItem -LiteralPath "$PSScriptRoot\PSAppDeployToolkit" -Recurse -File | Unblock-File -ErrorAction Ignore
        Import-Module -FullyQualifiedName @{ ModuleName = "$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit.psd1"; Guid = '8c3c366b-8606-4576-9f2d-4051144f7ca2'; ModuleVersion = '4.1.8' } -Force
    } else
    {
        Import-Module -FullyQualifiedName @{ ModuleName = 'PSAppDeployToolkit'; Guid = '8c3c366b-8606-4576-9f2d-4051144f7ca2'; ModuleVersion = '4.1.8' } -Force
    }

    # Open a new deployment session, replacing $adtSession with a DeploymentSession.
    $iadtParams = Get-ADTBoundParametersAndDefaultValues -Invocation $MyInvocation
    $adtSession = Remove-ADTHashtableNullOrEmptyValues -Hashtable $adtSession
    $adtSession = Open-ADTSession @adtSession @iadtParams -PassThru
} catch
{
    $Host.UI.WriteErrorLine((Out-String -InputObject $_ -Width ([System.Int32]::MaxValue)))
    exit 60008
}


##================================================
## MARK: Invocation
##================================================

# Commence the actual deployment operation.
try
{
    # Import any found extensions before proceeding with the deployment.
    Get-ChildItem -LiteralPath $PSScriptRoot -Directory | & {
        process
        {
            if ($_.Name -match 'PSAppDeployToolkit\..+$')
            {
                Get-ChildItem -LiteralPath $_.FullName -Recurse -File | Unblock-File -ErrorAction Ignore
                Import-Module -Name $_.FullName -Force
            }
        }
    }

    # Invoke the deployment and close out the session.
    & "$($adtSession.DeploymentType)-ADTDeployment"
    Close-ADTSession
} catch
{
    # An unhandled error has been caught.
    $mainErrorMessage = "An unhandled error within [$($MyInvocation.MyCommand.Name)] has occurred.`n$(Resolve-ADTErrorRecord -ErrorRecord $_)"
    Write-ADTLogEntry -Message $mainErrorMessage -Severity 3

    ## Error details hidden from the user by default. Show a simple dialog with full stack trace:
    # Show-ADTDialogBox -Text $mainErrorMessage -Icon Stop -NoWait

    ## Or, a themed dialog with basic error message:
    # Show-ADTInstallationPrompt -Message "$($adtSession.DeploymentType) failed at line $($_.InvocationInfo.ScriptLineNumber), char $($_.InvocationInfo.OffsetInLine):`n$($_.InvocationInfo.Line.Trim())`n`nMessage:`n$($_.Exception.Message)" -ButtonRightText OK -Icon Error -NoWait

    Close-ADTSession -ExitCode 60001
}
