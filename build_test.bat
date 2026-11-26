cd C:\games\SLRROPENCLEAN\SLRR-NEWAGE\SLLR-NEW-AGE
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat" -arch=x64 -no_logo
cmake --build build --config Release --target slrr_host --parallel 8 2>build_errors.txt
echo BUILD_EXIT_CODE=%errorlevel%
if exist build_errors.txt (
  echo ERRORS FOUND:
  findstr /i "error C" build_errors.txt | find /v "warning" | head -60
) else (
  echo NO ERRORS - build succeeded
)