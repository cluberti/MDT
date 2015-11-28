Place 32bit powercfg.exe from a Windows 10 64bit install (\Windows\SysWOW64\) here to change the power scheme to high perf during deployment:
http://blogs.technet.com/b/deploymentguys/archive/2015/03/27/reducing-windows-deployment-time-using-power-management.aspx


Call from MDT task sequence as a "Run command" step during WinPE to execute (run after "Gather Local" steps):
%SCRIPTROOT%\%PROCESSOR_ARCHITECTURE%\powercfg.exe /s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c