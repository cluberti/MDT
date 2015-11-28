#Disable Server Manager from opening at logon globally
function New-RegKey {
  param($key)
  
  $key = $key -replace ':',''
  $parts = $key -split '\\'
  
  $tempkey = ''
  $parts | ForEach-Object {
    $tempkey += ($_ + "\")
    if ( (Test-Path "Registry::$tempkey") -eq $false)  {
      New-Item "Registry::$tempkey" | Out-Null
    }
  }
}

$RegPath = "HKLM:\SOFTWARE\Microsoft\ServerManager"
New-RegKey $RegPath
New-ItemProperty -Path $RegPath -Name "DoNotOpenServerManagerAtLogon" -Value 1 -PropertyType "DWORD" -Force