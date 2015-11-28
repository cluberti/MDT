<#
.SYNOPSIS
    This script creates an MDT deployment share.

.DESCRIPTION
    This script creates an MDT deployment share with default task sequences.

    Note that you may need to edit the CustomSettings.xml file in MDT\Applications\Microsoft Office 365 C2R 2016\ if adding Office365
    via this script, so that it points to the correct share and folder name in your deployment share.

    You may also need to edit the ChangeWallpaper.ps1 script to point to your deployment share.  You may also wish to replace the file
    \MDT\MDTScripts\img0.jpg with your own wallpaper image.



    // *************
    // *  CAUTION  *
    // *************

    Please review this script THOROUGHLY before applying, and disable changes below as necessary to suit your current environment.

    This script is provided AS-IS - usage of this source assumes that you are at the very least familiar with PowerShell, and the
    tools used to create and debug this script.

    In other words, if you break it, you get to keep the pieces.
    
.EXAMPLE
    .\CreateMDTShare.ps1

.NOTES
    Author:       Carl Luberti
    Last Update:  27th November 2013
    Version:      1.0.0
#>


# Variables

# Share where source will be pulled from
$DataShare = "\\Server\Share"

# Folder locally where deployment share will be created
$MDTFolderPath = "X:\_Build"

# Name of the deployment share in MDT Deployment Workbench
$MDTShareName = "Build"

# Install prereqs (True/False)
$ADK = "True"
$MDT = "True"

# Install WDS (True/False)
$WDS = "False"



# Create folder for Deployment Share
If (Test-Path $MDTFolderPath)
{
    Write-Error "Folder $MDTFolderPath already exists - exiting!" -ForegroundColor Yellow
    Exit
}
Write-Host "Creating $MDTFolderPath..." -ForegroundColor Cyan
New-Item -Path $MDTFolderPath -ItemType directory | Out-Null



# Install ADK/MDT/WDS
#ADK
If ($ADK -eq "True")
{
    $Mount = (Mount-DiskImage -ImagePath "$DataShare\ISO\MDT\ADK10_10240.iso" -StorageType ISO -PassThru | Get-Volume).DriveLetter
    $Drive = $Mount + ":"

    Write-Host "Installing ADK..." -ForegroundColor Cyan
    Start-Process -wait "$Drive\adksetup.exe" -ArgumentList "/features OptionId.DeploymentTools OptionId.WindowsPreinstallationEnvironment OptionId.ImagingAndConfigurationDesigner OptionId.UserStateMigrationTool /norestart /quiet /ceip off"
    Start-Sleep -Seconds 5
    Dismount-DiskImage -ImagePath "$DataShare\ISO\MDT\ADK10_10240.iso"
}

#MDT
If ($MDT -eq "True")
{
    Write-Host "Installing MDT..." -ForegroundColor Cyan
    $Mount = (Mount-DiskImage -ImagePath "$DataShare\ISO\MDT\MDT2013U1.iso" -StorageType ISO -PassThru | Get-Volume).DriveLetter
    $Drive = $Mount + ":"

    Start-Process -wait "msiexec" -ArgumentList "/i $Drive\MicrosoftDeploymentToolkit2013_x64.msi /qb!"
    Start-Sleep -Seconds 5
    Dismount-DiskImage -ImagePath "$DataShare\ISO\MDT\MDT2013U1.iso"
}

#WDS
If ($WDS -eq "True")
{
    Write-Host "Installing WDS..." -ForegroundColor Cyan
    If ((Get-CimInstance Win32_OperatingSystem).Caption -like "*2012*")
    {
        Install-WindowsFeature -Name WDS -IncludeAllSubFeature -IncludeManagementTools
    }
    Else
    {
        Write-Host "MDT 2013 Update 1 requires server 2012 or higher to properly support UEFI, and Server 2012R2 for Windows 10 support" -ForegroundColor Cyan
        Write-Host "Windows Server 2012 or 2012R2 not found, skipping WDS install." -ForegroundColor Cyan
        Write-Host ""
        Write-Host "You may choose to install it via Server Manager or PowerShell after this script completes if this is in error, or" -ForegroundColor Cyan
        Write-Host "You wish to run Server 2008 or 2008R2 WDS." -ForegroundColor Cyan
    }
}


# Import MDT PowerShell module
Import-Module "C:\Program Files\Microsoft Deployment Toolkit\bin\MicrosoftDeploymentToolkit.psd1"



# Create SMB Share
Write-Host "Creating SMB Share $MDTShareName$..." -ForegroundColor Cyan
New-SmbShare -Name "$MDTShareName$" -Path $MDTFolderPath | Out-Null
Grant-SmbShareAccess -Name "$MDTShareName$" -AccountName Everyone -AccessRight Full –Force | Out-Null



# Set Deployment Share as permanent in Deployment Workbench for current user, add custom settings
Write-Host "Copying custom content to $MDTFolderPath\Control and $MDTFolderPath\Scripts..." -ForegroundColor Cyan
New-PSDrive -Name "DS001" -PSProvider "MDTProvider" -Root $MDTFolderPath -Description $MDTShareName -NetworkPath "\\$env:COMPUTERNAME\$MDTShareName$" | Add-MDTPersistentDrive | Out-Null
Copy-Item -Path "$DataShare\MDT\MDTScripts\*" -Recurse -Destination "$MDTFolderPath\Scripts" -Force
Copy-Item -Path "$DataShare\MDT\CustomSettings.ini" -Destination "$MDTFolderPath\Control" -Force
Copy-Item -Path "$DataShare\MDT\Bootstrap.ini" -Destination "$MDTFolderPath\Control" -Force
Copy-Item -Path "$DataShare\MDT\Settings.xml" -Destination "$MDTFolderPath\Control" -Force
Add-Content "$MDTFolderPath\Control\Bootstrap.ini" "`r`n"
Add-Content "$MDTFolderPath\Control\Bootstrap.ini" "DeployRoot=\\$env:COMPUTERNAME\$MDTShareName$"
Add-Content "$MDTFolderPath\Control\CustomSettings.ini" "`r`n"
Add-Content "$MDTFolderPath\Control\CustomSettings.ini" "BackupShare=\\$env:COMPUTERNAME\$MDTShareName$"

# Config WinPE settings
Write-Host "Updating WinPE settings for $MDTShareName share..." -ForegroundColor Cyan
$SettingsXML = "$MDTFolderPath\Control\Settings.xml"
$xml = [xml](Get-Content $SettingsXML)
$xml.Settings.UNCPath="\\$env:COMPUTERNAME\$MDTShareName$"
$xml.Settings.PhysicalPath="$MDTFolderPath"
$xml.Settings."Boot.x86.UseBootWim"="False"
$xml.Settings."Boot.x86.GenerateGenericWIM"="False"
$xml.Settings."Boot.x86.GenerateGenericISO"="False"
$xml.Settings."Boot.x86.GenerateLiteTouchISO"="False"
$xml.Settings."Boot.x86.SelectionProfile"="Nothing"
$xml.Settings."Boot.x86.LiteTouchWIMDescription"="$MDTShareName WinPE (x64)"
$xml.Settings."Boot.x86.LiteTouchISOName"="$MDTShareName-WinPE-x86.iso"
$xml.Settings."Boot.x86.SelectionProfile"="Nothing"
$xml.Settings."Boot.x64.UseBootWim"="False"
$xml.Settings."Boot.x64.GenerateGenericWIM"="False"
$xml.Settings."Boot.x64.GenerateGenericISO"="False"
$xml.Settings."Boot.x64.GenerateLiteTouchISO"="False"
$xml.Settings."Boot.x64.SelectionProfile"="Nothing"
$xml.Settings."Boot.x64.LiteTouchWIMDescription"="$MDTShareName WinPE (x64)"
$xml.Settings."Boot.x64.LiteTouchISOName"="$MDTShareName-WinPE-x64.iso"
$xml.Settings."Boot.x64.SelectionProfile"="Nothing"
$xml.Save($SettingsXML)



# Create PE WIMs
Write-Host "Updating WinPE WIMs for deployment share $MDTShareName..." -ForegroundColor Cyan
Update-MDTDeploymentShare -path "DS001:" -Force



# Add OS from ISO
Function Add-OS {
    param($ISO, $OSVersion, $DestinationFolder, $Architecture, $Template)

    $Mount = (Mount-DiskImage -ImagePath $ISO -StorageType ISO -PassThru | Get-Volume).DriveLetter
    $Drive = $Mount + ":"

    If (!(Test-Path "DS001:\Operating Systems\$OSVersion"))
    {
        New-Item -path "DS001:\Operating Systems" -enable "True" -Name $OSVersion -Comments "" -ItemType "folder" | Out-Null
    }

    If (!(Test-Path "DS001:\Operating Systems\$OSVersion\$Architecture"))
    {
        New-Item -path "DS001:\Operating Systems\$OSVersion" -enable "True" -Name $Architecture -Comments "" -ItemType "folder" | Out-Null
    }
    Import-MdtOperatingSystem -path "DS001:\Operating Systems\$OSVersion\$Architecture" -SourcePath $Drive -DestinationFolder "$DestinationFolder$Architecture" | Out-Null
    Dismount-DiskImage -ImagePath $ISO

    If (!(Test-Path "DS001:\Task Sequences\$OSVersion"))
    {
        New-Item -path "DS001:\Task Sequences" -enable "True" -Name $OSVersion -Comments "" -ItemType "folder"| Out-Null
    }
    $OSWIMs = Get-ChildItem -Path "DS001:\Operating Systems\$OSVersion\$Architecture" -Recurse
    ForEach ($OSWIM in $OSWIMs)
    {
        $TSOS = $OSWIM.Name
        $TSName = $OSWIM.Description
        $Date = Get-Date -Format yyyy.MM.dd.HHmm

        # Server SKUs
        If ($OSWIM.ImageName -like "*SERVERSTANDARDCORE")
        {
            Import-MdtTaskSequence -path "DS001:\Task Sequences\$OSVersion" -Name "$TSName $Architecture" -Template "$Template.xml" -Comments "" -ID "$DestinationFolder-STDCORE-$Architecture" -Version "$Date" -OperatingSystemPath "DS001:\Operating Systems\$OSVersion\$Architecture\$TSOS" -FullName "User" -OrgName "Org" -HomePage "about:blank" -Verbose
        }
        ElseIf ($OSWIM.ImageName -like "*SERVERSTANDARD")
        {
            Import-MdtTaskSequence -path "DS001:\Task Sequences\$OSVersion" -Name "$TSName $Architecture" -Template "$Template.xml" -Comments "" -ID "$DestinationFolder-STD-$Architecture" -Version "$Date" -OperatingSystemPath "DS001:\Operating Systems\$OSVersion\$Architecture\$TSOS" -FullName "User" -OrgName "Org" -HomePage "about:blank" -Verbose
        }
        ElseIf ($OSWIM.ImageName -like "*SERVERDATACENTERCORE")
        {
            Import-MdtTaskSequence -path "DS001:\Task Sequences\$OSVersion" -Name "$TSName $Architecture" -Template "$Template.xml" -Comments "" -ID "$DestinationFolder-DCCORE-$Architecture" -Version "$Date" -OperatingSystemPath "DS001:\Operating Systems\$OSVersion\$Architecture\$TSOS" -FullName "User" -OrgName "Org" -HomePage "about:blank" -Verbose
        }
        ElseIf ($OSWIM.ImageName -like "*SERVERDATACENTER")
        {
            Import-MdtTaskSequence -path "DS001:\Task Sequences\$OSVersion" -Name "$TSName $Architecture" -Template "$Template.xml" -Comments "" -ID "$DestinationFolder-DC-$Architecture" -Version "$Date" -OperatingSystemPath "DS001:\Operating Systems\$OSVersion\$Architecture\$TSOS" -FullName "User" -OrgName "Org" -HomePage "about:blank" -Verbose
        }
        ElseIf ($OSWIM.ImageName -like "*SERVERENTERPRISECORE")
        {
            Import-MdtTaskSequence -path "DS001:\Task Sequences\$OSVersion" -Name "$TSName $Architecture" -Template "$Template.xml" -Comments "" -ID "$DestinationFolder-ENTCORE-$Architecture" -Version "$Date" -OperatingSystemPath "DS001:\Operating Systems\$OSVersion\$Architecture\$TSOS" -FullName "User" -OrgName "Org" -HomePage "about:blank" -Verbose
        }
        ElseIf ($OSWIM.ImageName -like "*SERVERENTERPRISE")
        {
            Import-MdtTaskSequence -path "DS001:\Task Sequences\$OSVersion" -Name "$TSName $Architecture" -Template "$Template.xml" -Comments "" -ID "$DestinationFolder-ENT-$Architecture" -Version "$Date" -OperatingSystemPath "DS001:\Operating Systems\$OSVersion\$Architecture\$TSOS" -FullName "User" -OrgName "Org" -HomePage "about:blank" -Verbose
        }
        ElseIf ($OSWIM.ImageName -like "*SERVERWEBCORE")
        {
            Import-MdtTaskSequence -path "DS001:\Task Sequences\$OSVersion" -Name "$TSName $Architecture" -Template "$Template.xml" -Comments "" -ID "$DestinationFolder-WEBCORE-$Architecture" -Version "$Date" -OperatingSystemPath "DS001:\Operating Systems\$OSVersion\$Architecture\$TSOS" -FullName "User" -OrgName "Org" -HomePage "about:blank" -Verbose
        }
        ElseIf ($OSWIM.ImageName -like "*SERVERWEB")
        {
            Import-MdtTaskSequence -path "DS001:\Task Sequences\$OSVersion" -Name "$TSName $Architecture" -Template "$Template.xml" -Comments "" -ID "$DestinationFolder-WEB-$Architecture" -Version "$Date" -OperatingSystemPath "DS001:\Operating Systems\$OSVersion\$Architecture\$TSOS" -FullName "User" -OrgName "Org" -HomePage "about:blank" -Verbose
        }
        # Client SKUs
        Elseif ($OSWIM.Flags -like "*Enterprise*")
        {
            Import-MdtTaskSequence -path "DS001:\Task Sequences\$OSVersion" -Name "$TSName $Architecture" -Template "$Template.xml" -Comments "" -ID "$DestinationFolder-ENT-$Architecture" -Version "$Date" -OperatingSystemPath "DS001:\Operating Systems\$OSVersion\$Architecture\$TSOS" -FullName "User" -OrgName "Org" -HomePage "about:blank" -Verbose
        }
        Elseif ($OSWIM.Flags -like "*Professional*")
        {
            Import-MdtTaskSequence -path "DS001:\Task Sequences\$OSVersion" -Name "$TSName $Architecture" -Template "$Template.xml" -Comments "" -ID "$DestinationFolder-PRO-$Architecture" -Version "$Date" -OperatingSystemPath "DS001:\Operating Systems\$OSVersion\$Architecture\$TSOS" -FullName "User" -OrgName "Org" -HomePage "about:blank" -Verbose
        }
        # Fallback
        Else
        {
            Import-MdtTaskSequence -path "DS001:\Task Sequences\$OSVersion" -Name "$TSName $Architecture" -Template "$Template.xml" -Comments "" -ID "$DestinationFolder$Architecture" -Version "$Date" -OperatingSystemPath "DS001:\Operating Systems\$OSVersion\$Architecture\$TSOS" -FullName "User" -OrgName "Org" -HomePage "about:blank" -Verbose
        }
    }
}

# Add Hotfixes / Create Selection Profile
Function Add-Packages {
    param($PackagePath, $OSVersion, $Architecture)

    If (!(Test-Path "DS001:\Packages\$OSVersion"))
    {
        New-Item -path "DS001:\Packages" -enable "True" -Name $OSVersion -Comments "" -ItemType "folder" | Out-Null
    }

    If (!(Test-Path "DS001:\Packages\$OSVersion\$Architecture"))
    {
        New-Item -path "DS001:\Packages\$OSVersion" -enable "True" -Name $Architecture -Comments "" -ItemType "folder" | Out-Null
    }
    Import-MdtPackage -path "DS001:\Packages\$OSVersion\$Architecture" -SourcePath $PackagePath | Out-Null
    New-Item -path "DS001:\Selection Profiles" -enable "True" -Name "$OSVersion $Architecture" -Comments "" -Definition "<SelectionProfile><Include path=`"Packages\$OSVersion\$Architecture`" /></SelectionProfile>" -ReadOnly "False" | Out-Null
}

# Add Applications
Function Add-ApplicationWithSource {
    param($Vendor, $Application, $Name, $ShortName, $Architecture, $Command, $AppFolder, $SourcePath)

    If (!(Test-Path "DS001:\Applications\$Vendor"))
    {
        New-Item -path "DS001:\Applications" -enable "True" -Name "$Vendor" -Comments "" -ItemType "folder" | Out-Null
    }

    If (!(Test-Path "DS001:\Applications\$Vendor\$Application"))
    {
        New-Item -path "DS001:\Applications\$Vendor" -enable "True" -Name "$Application" -Comments "" -ItemType "folder" | Out-Null
    }
    Import-MdtApplication -path "DS001:\Applications\$Vendor\$Application" -enable "True" -Name "$Name" -ShortName "$Shortname" -Version $Architecture -Publisher $Vendor -Language "" -CommandLine "$Command" -WorkingDirectory ".\Applications\$AppFolder" -ApplicationSourcePath "$SourcePath" -DestinationFolder "$AppFolder" | Out-Null
}

Function Add-ApplicationWithoutSource {
    param($Vendor, $Application, $Name, $ShortName, $Architecture, $Command, $AppFolder)

    If (!(Test-Path "DS001:\Applications\$Vendor"))
    {
        New-Item -path "DS001:\Applications" -enable "True" -Name "$Vendor" -Comments "" -ItemType "folder" | Out-Null
    }

    If (!(Test-Path "DS001:\Applications\$Vendor\$Application"))
    {
        New-Item -path "DS001:\Applications\$Vendor" -enable "True" -Name "$Application" -Comments "" -ItemType "folder" | Out-Null
    }
    Import-MdtApplication -path "DS001:\Applications\$Vendor\$Application" -enable "True" -Name "$Name" -ShortName "$Shortname" -Version $Architecture -Publisher $Vendor -Language "" -CommandLine "$Command" -WorkingDirectory ".\Applications\$AppFolder" -NoSource | Out-Null
}



# ISOs
$Win7x86ISO = "$DataShare\ISO\Windows\Client\Win7\Win7_Ent_SP1_x86.iso"
$Win7x64ISO = "$DataShare\ISO\Windows\Client\Win7\Win7_Ent_SP1_x64.iso"
$Win81x861ISO = "$DataShare\ISO\Windows\Client\Win81\Win81_Ent_Update1_x86.iso"
$Win81x641ISO = "$DataShare\ISO\Windows\Client\Win81\Win81_Ent_Update1_x64.iso"
$Win10x86ISO = "$DataShare\ISO\Windows\Client\Win10\10586\Win10_Ent_x86.iso"
$Win10x64ISO = "$DataShare\ISO\Windows\Client\Win10\10586\Win10_Ent_x64.iso"
$Win2008R2ISO = "$DataShare\ISO\Windows\Server\2008R2\x64\WindowsServer2008R2SP1.iso"
$Win2012ISO = "$DataShare\ISO\Windows\Server\2012\x64\WindowsServer2012.iso"
$Win2012R2ISO = "$DataShare\ISO\Windows\Server\2012R2\x64\WindowsServer2012R2_Update1.iso"

# Windows 7
Write-Host "Adding Windows 7 to deployment share $MDTShareName..." -ForegroundColor Cyan
Add-OS $Win7x86ISO "Windows 7" "W7ENTSP1" "x86" "Client"
Add-OS $Win7x64ISO "Windows 7" "W7ENTSP1" "x64" "Client"
# Windows 8.1
Write-Host "Adding Windows 8.1 to deployment share $MDTShareName..." -ForegroundColor Cyan
Add-OS $Win81x861ISO "Windows 8.1" "W81ENTU1" "x86" "Client"
Add-OS $Win81x641ISO "Windows 8.1" "W81ENTU1" "x64" "Client"
# Windows 10
Write-Host "Adding Windows 10 to deployment share $MDTShareName..." -ForegroundColor Cyan
Add-OS $Win10x86ISO "Windows 10" "W10ENT10586" "x86" "Client"
Add-OS $Win10x64ISO "Windows 10" "W10ENT10586" "x64" "Client"
# Windows Server 2008R2
Write-Host "Adding Windows Server 2008R2 to deployment share $MDTShareName..." -ForegroundColor Cyan
Add-OS $Win2008R2ISO "Windows Server 2008R2" "W2008R2SP1" "x64" "Server"
# Windows Server 2012
Write-Host "Adding Windows Server 2012 to deployment share $MDTShareName..." -ForegroundColor Cyan
Add-OS $Win2012ISO "Windows Server 2012" "W2012" "x64" "Server"
# Windows Server 2012R2
Write-Host "Adding Windows Server 2012R2 to deployment share $MDTShareName..." -ForegroundColor Cyan
Add-OS $Win2012R2ISO "Windows Server 2012R2" "W2012R2U1" "x64" "Server"


<#
# Patches / packages here
Write-Host "Adding patches/hotfixes for Windows 7 / IE11 to deployment share $MDTShareName..." -ForegroundColor Cyan
Add-Packages "$DataShare\MDT\Packages" "Windows 7" "x64"



# Applications here
##########################
## Internet Explorer 11 ##
##########################
$Vendor = "Microsoft"
$Application = "Internet Explorer"
$Version = "11"
$Architecture = "x64"
$Name = "$Vendor $Application $Version $Architecture"
$ShortName = "$Application $Version"
$InstallCommand = "IE11-Windows6.1-x64-en-us.exe /passive /update-no /norestart"
$AppFolder = "MSIE11x64"
$SourcePath = "$DataShare\MDT\Applications\Microsoft Internet Explorer 11"
Write-Host "Adding IE11 to deployment share $MDTShareName..." -ForegroundColor Cyan
Add-ApplicationWithSource $Vendor $Application $Name $Shortname $Architecture $InstallCommand $AppFolder $SourcePath

#########################
## Office 2016 ProPlus ##
#########################
$Vendor = "Microsoft"
$Application = "Office 2016"
$Version = "ProPlus"
$Architecture = "x86"
$Name = "$Vendor $Application $Version $Architecture"
$ShortName = "$Application $Version"
$InstallCommand = "setup.exe /config proplus.ww\config.xml"
$AppFolder = "MSO2016x86"
$SourcePath = "$DataShare\MDT\Applications\Microsoft Office ProPlus 2016"
Write-Host "Adding Office 2016 to deployment share $MDTShareName..." -ForegroundColor Cyan
Add-ApplicationWithSource $Vendor $Application $Name $ShortName $Architecture $InstallCommand $AppFolder $SourcePath

$Vendor = "Microsoft"
$Application = "Visio 2016"
$Version = "Professional"
$Architecture = "x86"
$Name = "$Vendor $Application $Version $Architecture"
$ShortName = "$Application $Version"
$InstallCommand = "setup.exe /config vispro.ww\config.xml"
$AppFolder = "MSO2016x86"
Write-Host "Adding Visio 2016 Professional to deployment share $MDTShareName..." -ForegroundColor Cyan
Add-ApplicationWithoutSource $Vendor "Office 2016" $Name $ShortName $Architecture $InstallCommand $AppFolder

$Vendor = "Microsoft"
$Application = "Project 2016"
$Version = "Professional"
$Architecture = "x86"
$Name = "$Vendor $Application $Version $Architecture"
$ShortName = "$Application $Version"
$InstallCommand = "setup.exe /config prjpro.ww\config.xml"
$AppFolder = "MSO2016x86"
Write-Host "Adding Project 2016 Professional to deployment share $MDTShareName..." -ForegroundColor Cyan
Add-ApplicationWithoutSource $Vendor "Office 2016" $Name $ShortName $Architecture $InstallCommand $AppFolder

##########################
## Windows Perf Toolkit ##
##########################
$Vendor = "Microsoft"
$Application = "Windows Performance Toolkit"
$Version = "8.1"
$Architecture = "x64"
$Name = "$Vendor $Application $Version $Architecture"
$ShortName = "$Application $Version"
$InstallCommand = "msiexec /i WPTx64-x86_en-us.msi /qb!"
$AppFolder = "WPT81"
$SourcePath = "$DataShare\MDT\Applications\Microsoft Windows Performance Toolkit 8.1"
Write-Host "Adding WPT 8.1 to deployment share $MDTShareName..." -ForegroundColor Cyan
Add-ApplicationWithSource $Vendor $Application $Name $ShortName $Architecture $InstallCommand $AppFolder $SourcePath

$Vendor = "Microsoft"
$Application = "Windows Performance Toolkit"
$Version = "10.0 10240"
$Architecture = "x64"
$Name = "$Vendor $Application $Version $Architecture"
$ShortName = "$Application $Version"
$InstallCommand = "msiexec /i WPTx64-x86_en-us.msi /qb!"
$AppFolder = "WPT10-10240"
$SourcePath = "$DataShare\MDT\Applications\Microsoft Windows Performance Toolkit 10 10240"
Write-Host "Adding WPT 10 (10240) to deployment share $MDTShareName..." -ForegroundColor Cyan
Add-ApplicationWithSource $Vendor $Application $Name $ShortName $Architecture $InstallCommand $AppFolder $SourcePath

$Vendor = "Microsoft"
$Application = "Windows Performance Toolkit"
$Version = "10.0 10586"
$Architecture = "x64"
$Name = "$Vendor $Application $Version $Architecture"
$ShortName = "$Application $Version"
$InstallCommand = "msiexec /i WPTx64-x86_en-us.msi /qb!"
$AppFolder = "WPT10-10586"
$SourcePath = "$DataShare\MDT\Applications\Microsoft Windows Performance Toolkit 10 10586"
Write-Host "Adding WPT 10 (10586) to deployment share $MDTShareName..." -ForegroundColor Cyan
Add-ApplicationWithSource $Vendor $Application $Name $ShortName $Architecture $InstallCommand $AppFolder $SourcePath
#>


# Clean up
Write-Host "Updating WinPE WIMs for deployment share $MDTShareName..." -ForegroundColor Cyan
Update-MDTDeploymentShare -path "DS001:"
Remove-PSDrive -Name "DS001"


# Done
Write-Host ""
Write-Host ""
Write-Host ""
Write-Host "Script complete.  Check $MDTFolderPath and the Deployment Workbench to validate success." -ForegroundColor Cyan