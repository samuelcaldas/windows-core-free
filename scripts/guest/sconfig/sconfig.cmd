@echo off
title Windows Core Developer Edition - Server Control Center
color 17
cls

set SCONFIG_VBS=%SystemRoot%\System32\sconfig.vbs
if not exist "%SCONFIG_VBS%" set SCONFIG_VBS=%SystemRoot%\System32\en-US\sconfig.vbs

if exist "%SCONFIG_VBS%" (
    pushd "%SystemRoot%\System32"
    cscript //nologo "%SCONFIG_VBS%"
    popd
) else (
    echo [ERROR] sconfig.vbs not found in %SystemRoot%\System32.
    pause
)
color
