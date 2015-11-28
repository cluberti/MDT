#Set UAC parameters - no prompt for Admin, unfilter Admin tokens for remote admin tasks
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

$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
New-RegKey $RegPath
New-ItemProperty -Path $RegPath -Name "ConsentPromptBehaviorAdmin" -Value 0 -PropertyType "DWORD" -Force
New-ItemProperty -Path $RegPath -Name "LocalAccountTokenFilterPolicy" -Value 1 -PropertyType "DWORD" -Force