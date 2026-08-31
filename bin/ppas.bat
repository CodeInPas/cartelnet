@echo off
SET THEFILE=D:\KangOz\Development\CodeInPas\Game\CIP-001_CartelNET\CartelNET_MVP\bin\CartelNET.exe
echo Linking %THEFILE%
D:\LazarusIDE\fpc\bin\i386-win32\ld.exe -b pei-i386 -m i386pe  --gc-sections   --subsystem windows --entry=_WinMainCRTStartup    -o D:\KangOz\Development\CodeInPas\Game\CIP-001_CartelNET\CartelNET_MVP\bin\CartelNET.exe D:\KangOz\Development\CodeInPas\Game\CIP-001_CartelNET\CartelNET_MVP\bin\link21988.res
if errorlevel 1 goto linkend
D:\LazarusIDE\fpc\bin\i386-win32\postw32.exe --subsystem gui --input D:\KangOz\Development\CodeInPas\Game\CIP-001_CartelNET\CartelNET_MVP\bin\CartelNET.exe --stack 16777216
if errorlevel 1 goto linkend
goto end
:asmend
echo An error occurred while assembling %THEFILE%
goto end
:linkend
echo An error occurred while linking %THEFILE%
:end
