REM This script will get the executables for you and dump them in the appropriate folder

powershell curl "https://raw.githubusercontent.com/Foxenfurter/inguz-InguzDSP/Upgrade2Net6/publishWin32/InguzDSP.dll.config" -Outfile "..\..\Bin\MSWin32-x86-multi-thread\InguzDSP.dll.config"
powershell curl "https://github.com/Foxenfurter/inguz-InguzDSP/raw/Upgrade2Net6/publishWin32/InguzDSP.exe" -Outfile "..\..\Bin\MSWin32-x86-multi-thread\InguzDSP.exe"