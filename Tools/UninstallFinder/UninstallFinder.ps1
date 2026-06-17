<#
.SYNOPSIS
    A modern, view-only WPF GUI for searching installed software and viewing
    its uninstall information from the Windows registry.

.DESCRIPTION
    Replaces the console-only Get-Uninstaller function with a clean, scrollable
    GUI. Search by (partial) name; matching entries are shown as expandable
    cards with full uninstall metadata (UninstallString, QuietUninstallString,
    install location/source/date, and the registry scope they came from).

    Self-contained and dependency-free (XAML embedded inline) so it can be
    wrapped into an .exe. WPF runs on Windows only; the data/logic functions are
    Windows-agnostic and unit-tested separately.

.EXAMPLE
    PS C:\> .\Show-UninstallerGui.ps1
    Launches the Uninstall Finder window.
#>
[CmdletBinding()]
param()

#region Pure logic (cross-platform, unit-testable)

# Registry paths searched for uninstall information.
$script:UninstallKeys = @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

function Resolve-UninstallerScope {
    <#
    .SYNOPSIS
        Maps a registry PSPath/PSParentPath to a human-readable scope label.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $RegistryPath
    )

    if ($RegistryPath -match 'HKEY_CURRENT_USER') { return 'HKCU' }
    if ($RegistryPath -match 'Wow6432Node')       { return 'HKLM (32-bit)' }
    if ($RegistryPath -match 'HKEY_LOCAL_MACHINE') { return 'HKLM (64-bit)' }
    return 'Unknown'
}

function Select-UninstallerEntry {
    <#
    .SYNOPSIS
        Filters raw registry items by name and shapes them into display objects.

    .DESCRIPTION
        Accepts raw registry property objects (as returned by Get-ItemProperty),
        keeps those whose DisplayName or PSChildName contains $Name, and returns
        ordered PSCustomObjects sorted by DisplayName. Entries lacking a
        DisplayName are dropped (registry noise).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # Not Mandatory: a Mandatory [object[]] rejects arrays that contain a
        # $null element. Null items are tolerated and skipped below instead.
        [AllowNull()]
        [object[]] $RawItem = @(),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    $matches = foreach ($item in $RawItem) {
        if ($null -eq $item) { continue }
        $displayName = $item.DisplayName
        $childName   = $item.PSChildName
        if ([string]::IsNullOrWhiteSpace($displayName)) { continue }

        if (($displayName -like "*$Name*") -or ($childName -like "*$Name*")) {
            [pscustomobject]@{
                DisplayName          = $displayName
                DisplayVersion       = $item.DisplayVersion
                UninstallString      = $item.UninstallString
                QuietUninstallString = $item.QuietUninstallString
                InstallLocation      = $item.InstallLocation
                InstallSource        = $item.InstallSource
                InstallDate          = $item.InstallDate
                Scope                = Resolve-UninstallerScope -RegistryPath ([string]$item.PSPath)
            }
        }
    }

    $matches | Sort-Object DisplayName
}

#endregion Pure logic

#region Registry I/O (Windows only)

function Get-UninstallerRaw {
    <#
    .SYNOPSIS
        Reads raw uninstall entries from the Windows registry. Windows only.
    #>
    [CmdletBinding()]
    param()
    Get-ItemProperty -Path $script:UninstallKeys -ErrorAction SilentlyContinue
}

function Get-Uninstaller {
    <#
    .SYNOPSIS
        Returns shaped uninstall entries matching $Name from the registry.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )
    $raw = @(Get-UninstallerRaw)
    Select-UninstallerEntry -RawItem $raw -Name $Name
}

#endregion Registry I/O

#region GUI (Windows / WPF only)

function Get-UninstallerXaml {
    <#
    .SYNOPSIS
        Returns the WPF window XAML as a string. Pure; no WPF assemblies needed.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()
    @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Uninstall Finder" Height="640" Width="780"
        WindowStartupLocation="CenterScreen"
        Background="#F3F4F6"
        FontFamily="Segoe UI" FontSize="13">
    <Window.Resources>
        <!-- Card-styled expander for each result -->
        <Style x:Key="CardExpander" TargetType="Expander">
            <Setter Property="Margin" Value="0,0,0,10"/>
            <Setter Property="Background" Value="White"/>
            <Setter Property="BorderBrush" Value="#E5E7EB"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Expander">
                        <Border CornerRadius="0" Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}">
                            <Border.Effect>
                                <DropShadowEffect Color="#000000" Opacity="0.10"
                                                  BlurRadius="10" ShadowDepth="1"/>
                            </Border.Effect>
                            <DockPanel>
                                <ToggleButton x:Name="HeaderSite" DockPanel.Dock="Top"
                                              Focusable="False" Cursor="Hand"
                                              IsChecked="{Binding IsExpanded,
                                                  RelativeSource={RelativeSource TemplatedParent},
                                                  Mode=TwoWay}"
                                              OverridesDefaultStyle="True">
                                    <ToggleButton.Template>
                                        <ControlTemplate TargetType="ToggleButton">
                                            <Border x:Name="HdrBg" Background="Transparent"
                                                    MinHeight="48"
                                                    Padding="16,10">
                                                <Grid VerticalAlignment="Center">
                                                    <Grid.ColumnDefinitions>
                                                        <ColumnDefinition Width="*"/>
                                                        <ColumnDefinition Width="Auto"/>
                                                        <ColumnDefinition Width="Auto"/>
                                                    </Grid.ColumnDefinitions>
                                                    <TextBlock Grid.Column="0"
                                                               Text="{Binding DisplayName}"
                                                               FontWeight="SemiBold" FontSize="14"
                                                               Foreground="#111827"
                                                               TextTrimming="CharacterEllipsis"
                                                               VerticalAlignment="Center"/>
                                                    <TextBlock Grid.Column="1"
                                                               Text="{Binding DisplayVersionText}"
                                                               Foreground="#6B7280" Margin="16,0,16,0"
                                                               VerticalAlignment="Center"/>
                                                    <Path x:Name="Chevron" Grid.Column="2"
                                                          Data="M 0 0 L 5 5 L 10 0"
                                                          Stroke="#6B7280" StrokeThickness="2"
                                                          VerticalAlignment="Center"
                                                          RenderTransformOrigin="0.5,0.5">
                                                        <Path.RenderTransform>
                                                            <RotateTransform Angle="0"/>
                                                        </Path.RenderTransform>
                                                    </Path>
                                                </Grid>
                                            </Border>
                                            <ControlTemplate.Triggers>
                                                <Trigger Property="IsChecked" Value="True">
                                                    <Setter TargetName="Chevron"
                                                            Property="RenderTransform">
                                                        <Setter.Value>
                                                            <RotateTransform Angle="180"/>
                                                        </Setter.Value>
                                                    </Setter>
                                                </Trigger>
                                                <Trigger Property="IsMouseOver" Value="True">
                                                    <Setter TargetName="HdrBg" Property="Background"
                                                            Value="#F9FAFB"/>
                                                </Trigger>
                                            </ControlTemplate.Triggers>
                                        </ControlTemplate>
                                    </ToggleButton.Template>
                                </ToggleButton>
                                <Border x:Name="ExpandSite" DockPanel.Dock="Bottom"
                                        Padding="16,2,16,18" Visibility="Collapsed">
                                    <ContentPresenter/>
                                </Border>
                            </DockPanel>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsExpanded" Value="True">
                                <Setter TargetName="ExpandSite" Property="Visibility"
                                        Value="Visible"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- One label/value detail row inside an expanded card -->
        <Style x:Key="DetailLabel" TargetType="TextBlock">
            <Setter Property="Foreground" Value="#6B7280"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="Margin" Value="0,6,0,1"/>
        </Style>
        <Style x:Key="DetailValue" TargetType="TextBlock">
            <Setter Property="Foreground" Value="#111827"/>
            <Setter Property="TextWrapping" Value="Wrap"/>
        </Style>

        <!-- Data template for the detail body of each card -->
        <DataTemplate x:Key="DetailTemplate">
            <StackPanel>
                <TextBlock Text="Uninstall string" Style="{StaticResource DetailLabel}"/>
                <TextBlock Text="{Binding UninstallStringText}" Style="{StaticResource DetailValue}"/>
                <TextBlock Text="Quiet uninstall string" Style="{StaticResource DetailLabel}"/>
                <TextBlock Text="{Binding QuietUninstallStringText}" Style="{StaticResource DetailValue}"/>
                <TextBlock Text="Install location" Style="{StaticResource DetailLabel}"/>
                <TextBlock Text="{Binding InstallLocationText}" Style="{StaticResource DetailValue}"/>
                <TextBlock Text="Install source" Style="{StaticResource DetailLabel}"/>
                <TextBlock Text="{Binding InstallSourceText}" Style="{StaticResource DetailValue}"/>
                <TextBlock Text="Install date" Style="{StaticResource DetailLabel}"/>
                <TextBlock Text="{Binding InstallDateText}" Style="{StaticResource DetailValue}"/>
                <TextBlock Text="Registry scope" Style="{StaticResource DetailLabel}"/>
                <TextBlock Text="{Binding ScopeText}" Style="{StaticResource DetailValue}"/>
            </StackPanel>
        </DataTemplate>
    </Window.Resources>

    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <!-- Header band -->
        <Border Grid.Row="0" Background="#2563EB" Padding="20,16">
            <StackPanel>
                <TextBlock Text="Uninstall Finder" Foreground="White"
                           FontSize="20" FontWeight="SemiBold"/>
                <TextBlock Text="Search installed software and view its uninstall details"
                           Foreground="#DBEAFE" FontSize="12" Margin="0,2,0,0"/>
            </StackPanel>
        </Border>

        <!-- Search row -->
        <Grid Grid.Row="1" Margin="20,16,20,8">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <Border Grid.Column="0" Background="White" CornerRadius="6"
                    BorderBrush="#D1D5DB" BorderThickness="1">
                <TextBox x:Name="SearchBox" BorderThickness="0" Background="Transparent"
                         Padding="10,8" VerticalContentAlignment="Center" FontSize="14"/>
            </Border>
            <Button x:Name="SearchButton" Grid.Column="1" Content="Search"
                    Margin="10,0,0,0" Padding="20,0" MinWidth="90"
                    Background="#2563EB" Foreground="White" BorderThickness="0"
                    Cursor="Hand" FontWeight="SemiBold">
                <Button.Resources>
                    <Style TargetType="Border">
                        <Setter Property="CornerRadius" Value="6"/>
                    </Style>
                </Button.Resources>
            </Button>
        </Grid>

        <!-- Status line -->
        <TextBlock x:Name="StatusText" Grid.Row="2" Margin="20,0,20,6"
                   Foreground="#6B7280" FontSize="12"
                   Text="Enter a search term to begin."/>

        <!-- Results -->
        <ScrollViewer Grid.Row="3" Margin="20,0,20,16" VerticalScrollBarVisibility="Auto"
                      Padding="0,0,8,0">
            <Grid>
                <ItemsControl x:Name="ResultsList">
                    <ItemsControl.ItemTemplate>
                        <DataTemplate>
                            <Expander Style="{StaticResource CardExpander}"
                                      ContentTemplate="{StaticResource DetailTemplate}"
                                      Content="{Binding}"/>
                        </DataTemplate>
                    </ItemsControl.ItemTemplate>
                </ItemsControl>
                <TextBlock x:Name="EmptyText" Visibility="Collapsed"
                           Foreground="#9CA3AF" FontSize="14"
                           HorizontalAlignment="Center" Margin="0,40,0,0"/>
            </Grid>
        </ScrollViewer>
    </Grid>
</Window>
'@
}

function ConvertTo-UninstallerViewModel {
    <#
    .SYNOPSIS
        Adds display-friendly *Text properties (with "—" for empty values) so
        the XAML can bind without value converters.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $Entry
    )

    $dash = [char]0x2014  # em dash
    $fmt = {
        param($v)
        if ([string]::IsNullOrWhiteSpace([string]$v)) { return [string]$dash }
        return [string]$v
    }

    [pscustomobject]@{
        DisplayName              = $Entry.DisplayName
        DisplayVersionText       = (& $fmt $Entry.DisplayVersion)
        UninstallStringText      = (& $fmt $Entry.UninstallString)
        QuietUninstallStringText = (& $fmt $Entry.QuietUninstallString)
        InstallLocationText      = (& $fmt $Entry.InstallLocation)
        InstallSourceText        = (& $fmt $Entry.InstallSource)
        InstallDateText          = (& $fmt $Entry.InstallDate)
        ScopeText                = (& $fmt $Entry.Scope)
        IsExpanded               = $false
    }
}

function Show-UninstallerGui {
    <#
    .SYNOPSIS
        Builds and shows the Uninstall Finder window. Windows / WPF only.
    #>
    [CmdletBinding()]
    param()

    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

    [xml] $xaml = Get-UninstallerXaml
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $window = [Windows.Markup.XamlReader]::Load($reader)

    $searchBox    = $window.FindName('SearchBox')
    $searchButton = $window.FindName('SearchButton')
    $statusText   = $window.FindName('StatusText')
    $resultsList  = $window.FindName('ResultsList')
    $emptyText    = $window.FindName('EmptyText')

    $doSearch = {
        try {
            $term = $searchBox.Text
            if ([string]::IsNullOrWhiteSpace($term)) {
                $resultsList.ItemsSource = $null
                $emptyText.Visibility = 'Collapsed'
                $statusText.Text = 'Enter a search term to begin.'
                return
            }

            $term = $term.Trim()
            $statusText.Text = "Searching for `"$term`"..."

            $entries = @(Get-Uninstaller -Name $term)
            $models  = foreach ($e in $entries) { ConvertTo-UninstallerViewModel -Entry $e }
            $models  = @($models)

            $resultsList.ItemsSource = $models
            if ($models.Count -eq 0) {
                $emptyText.Text = "No results for `"$term`"."
                $emptyText.Visibility = 'Visible'
                $statusText.Text = "0 results for `"$term`"."
            }
            else {
                $emptyText.Visibility = 'Collapsed'
                $plural = if ($models.Count -eq 1) { 'result' } else { 'results' }
                $statusText.Text = "$($models.Count) $plural for `"$term`"."
            }
        }
        catch {
            $statusText.Text = "Search failed: $($_.Exception.Message)"
        }
    }

    $searchButton.Add_Click($doSearch)
    $searchBox.Add_KeyDown({
        param($s, $e)
        if ($e.Key -eq 'Return' -or $e.Key -eq 'Enter') { & $doSearch }
    })

    $searchBox.Focus() | Out-Null
    $window.ShowDialog() | Out-Null
}

#endregion GUI

# Launch only when run directly (not when dot-sourced for tests).
if ($MyInvocation.InvocationName -ne '.') {
    Show-UninstallerGui
}
