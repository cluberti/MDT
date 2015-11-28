#Set IPv6 settings to favor IPv4 and disable all transition interfaces
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

$RegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\TCPIP6\Parameters"
New-RegKey $RegPath
New-ItemProperty -Path $RegPath -Name "DisabledComponents" -Value 174 -PropertyType "DWORD" -Force