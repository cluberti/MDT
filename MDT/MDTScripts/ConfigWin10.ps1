<#
.SYNOPSIS
    This script reconfigures Windows 10.

.DESCRIPTION
    This script makes considerable changes to Windows 10.

    // *************
    // *  CAUTION  *
    // *************

    THIS SCRIPT MAKES CONSIDERABLE CHANGES TO THE DEFAULT CONFIGURATION OF WINDOWS 10.

    Please review this script THOROUGHLY before applying, and disable changes below as necessary to suit your current environment.

    This script is provided AS-IS - usage of this source assumes that you are at the very least familiar with PowerShell, and the
    tools used to create and debug this script.

    In other words, if you break it, you get to keep the pieces.


.EXAMPLE
    .\ConfigWin10.ps1
.NOTES
    Author:       Carl Luberti
    Last Update:  18th November 2015
    Version:      1.0.1
.LOG
    1.0.1: Updated for TH2
#>


# Remove OneDrive (not guaranteed to be permanent - see https://support.office.com/en-US/article/Turn-off-or-uninstall-OneDrive-f32a17ce-3336-40fe-9c38-6efb09f944b0)
# Note - best to run this after installing Office 2013/2016/365, as those may update or reinstall OneDrive:
Write-Host "Removing OneDrive..." -ForegroundColor Yellow
C:\Windows\SysWOW64\OneDriveSetup.exe /uninstall
Start-Sleep -Seconds 30
New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null
New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\' -Name 'Skydrive' | Out-Null
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Skydrive' -Name 'DisableFileSync' -PropertyType DWORD -Value '1' | Out-Null
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Skydrive' -Name 'DisableLibrariesDefaultSaveToSkyDrive' -PropertyType DWORD -Value '1' | Out-Null 
Remove-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{A52BBA46-E9E1-435f-B3D9-28DAA648C0F6}' -Recurse
Remove-Item -Path 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{A52BBA46-E9E1-435f-B3D9-28DAA648C0F6}' -Recurse
Set-ItemProperty -Path 'HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}' -Name 'System.IsPinnedToNameSpaceTree' -Value '0'
Set-ItemProperty -Path 'HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}' -Name 'System.IsPinnedToNameSpaceTree' -Value '0'


# Set PeerCaching to Local Network PCs only (1):
Write-Host "Configuring PeerCaching..." -ForegroundColor Cyan
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config' -Name 'DODownloadMode' -Value '1'


# Configure Services:
Write-Host "Configuring Network List Service to start Automatic..." -ForegroundColor Green
Set-Service netprofm -StartupType Automatic


# Disable System Restore
Write-Host "Disabling System Restore..." -ForegroundColor Green
Disable-ComputerRestore -Drive "C:\"


# Remove Previous Versions:
Write-Host "Removing Previous Versions Capability..." -ForegroundColor Green
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' -Name 'NoPreviousVersionsPage' -Value '1'


# Change Explorer Default View to Windows 7 defaults:
Write-Host "Configuring Windows Explorer..." -ForegroundColor Green
New-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'LaunchTo' -PropertyType DWORD -Value '1' | Out-Null


# Configure Search Options:
Write-Host "Configuring Search Options..." -ForegroundColor Green
New-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' -Name 'SearchboxTaskbarMode' -PropertyType DWORD -Value '1' | Out-Null