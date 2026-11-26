@echo off
pushd "C:\games\SLRROPENCLEAN\SLRR-NEWAGE\SLLR-NEW-AGE"
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat" -arch=x64 -no_logo
cmake --build build --config Release --target slrr_host --parallel 8
exit %ERRORLEVEL%