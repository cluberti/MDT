# Connect to the ProviderHostQuotaConfiguration base class of the root namespace
$oWMI=get-wmiobject -Namespace root -Class __ProviderHostQuotaConfiguration

# Set memory per WMI process to a max of 1GB (default is 512MB)
$oWMI.MemoryPerHost=1024*1024*1024

# Set max memory in use by WMI across all processes on the same machine to top off at 4GB (default is 1GB)
$oWMI.MemoryAllHosts=4096*1024*1024

# Commit changes back to the system
$oWMI.put()

# Move WMI into the COM Infrastructure startup group - this will improve WMI startup performance
Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\Winmgmt -Name 'Group' -Value 'COM Infrastructure'

# Set WMI to run in it's own svchost process in the event it needs to be debugged or restarted
winmgmt /standalonehost
