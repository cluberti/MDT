﻿#Enable Microsoft Update provider
$MicrosoftUpdate = New-Object -ComObject Microsoft.Update.ServiceManager -Strict
$MicrosoftUpdate.AddService2("7971f918-a847-4430-9279-4a52d1efe18d",7,"")