@echo off
setlocal

set "THE_SH_FILE=%~dp0dsh.desktop.startup.gitbash.sh"
set "THE_SH_FILE_2=%THE_SH_FILE:\=/%"

if not defined DSH_GIT_BASH_PATH (
    echo [dsh.desktop.startup.gitbash.bat]  the env var  DSH_GIT_BASH_PATH  is not defined.
    echo [dsh.desktop.startup.gitbash.bat]  set it to your own Git for Windows bash.exe.
    exit /b 1
)
if not exist "%DSH_GIT_BASH_PATH%" (
    echo [dsh.desktop.startup.gitbash.bat]  Git Bash Not Found:  DSH_GIT_BASH_PATH : %DSH_GIT_BASH_PATH%
    exit /b 1
)

if not exist "%THE_SH_FILE%" (
    echo [dsh.desktop.startup.gitbash.bat]  .sh File Not Found: %THE_SH_FILE%
    exit /b 1
)

"%DSH_GIT_BASH_PATH%" --login "%THE_SH_FILE_2%" %*
set "THE_RETURN_CODE=%ERRORLEVEL%"

if not "%THE_RETURN_CODE%"=="0" (
    echo [dsh.desktop.startup.gitbash.bat]  bash exited with code: %THE_RETURN_CODE%
)
endlocal & exit /b %THE_RETURN_CODE%
