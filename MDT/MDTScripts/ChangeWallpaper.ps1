$DeployRoot="\\MDTServer\Build$"
$ScriptRoot="\\MDTServer\Build$\Scripts"
$Source="$ScriptRoot\img0.jpg"
$Destination="C:\Windows\Web\Wallpaper\Windows"

$Filepath = "C:\Windows\Web\wallpaper\windows"
$Filename = $Filepath + "\img0.jpg"

function setaccess
{
    param($FileName)
    &takeown /F $FileName | Out-Null
    $User = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
    $Acl = Get-Acl $FileName
    $Acl.SetOwner($User)
    $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($User, "FullControl", "Allow")
    $User = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
    $Acl.SetAccessRule($AccessRule)
    $Filename = "\\{0}\{1}" -f $env:COMPUTERNAME,($filename -replace ':','$')
    Set-Acl $FileName $Acl
}

function Set-Wallpaper
{
    param(
        [Parameter(Mandatory=$true)]
        $Path,
        
        [ValidateSet('Center', 'Stretch')]
        $Style = 'Stretch'
    )
    
    Add-Type @"
using System;
using System.Runtime.InteropServices;
using Microsoft.Win32;
namespace Wallpaper
{
public enum Style : int
{
Center, Stretch
}
public class Setter {
public const int SetDesktopWallpaper = 20;
public const int UpdateIniFile = 0x01;
public const int SendWinIniChange = 0x02;
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
private static extern int SystemParametersInfo (int uAction, int uParam, string lpvParam, int fuWinIni);
public static void SetWallpaper ( string path, Wallpaper.Style style ) {
SystemParametersInfo( SetDesktopWallpaper, 0, path, UpdateIniFile | SendWinIniChange );
RegistryKey key = Registry.CurrentUser.OpenSubKey("Control Panel\\Desktop", true);
switch( style )
{
case Style.Stretch :
key.SetValue(@"WallpaperStyle", "2") ; 
key.SetValue(@"TileWallpaper", "0") ;
break;
case Style.Center :
key.SetValue(@"WallpaperStyle", "1") ; 
key.SetValue(@"TileWallpaper", "0") ; 
break;
}
key.Close();
}
}
}
"@
    
    [Wallpaper.Setter]::SetWallpaper( $Path, $Style )
}

setaccess $Filename

Rename-Item -Path $Filename -NewName "C:\Windows\Web\Wallpaper\Windows\img1.jpg" -Force
Copy-Item -Path $Source -Destination $Destination -Force

Set-Wallpaper -Path $Filename