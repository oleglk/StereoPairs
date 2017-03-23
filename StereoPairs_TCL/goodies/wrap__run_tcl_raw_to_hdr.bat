@REM Example demonstrating invocation of a TCL script in a new interperter

@echo off

VER>NUL
call :Assign_SCRIPT_DIR %0
if ERRORLEVEL 1 (
  echo -E- Failed detecting script source directory
  goto :abort
)


@REM ============ The invocation ======================
@REM start cmd /K ""C:\Program Files (x86)\etcl\bin\etcl.exe" "%SCRIPT_DIR%\trial_tcl.tcl""
@REM cmd /K ""C:\Program Files (x86)\etcl\bin\etcl.exe" "%SCRIPT_DIR%\trial_tcl.tcl""

@REM If the command preceded by "start", the DOS and wish windows aren't closed when finished
cmd /K ""C:\Program Files (x86)\etcl\bin\etcl.exe" "%SCRIPT_DIR%\run__raw_to_hdr_on_l_r.tcl""

@echo on
@exit /B 0


@REM ============== Subroutines =======================

@REM Subroutine that assigns SCRIPT_DIR to full dir path of the script source code
@REM Invocation:  call :assign_SCRIPT_DIR %0
:Assign_SCRIPT_DIR
  if (%1)==() (
   echo -E- :assign_SCRIPT_DIR requires script full path as the 1-st parameter
   exit /B 1
  )
  set SCRIPT_PATH=%1
  for %%f in (%SCRIPT_PATH%) do set SCRIPT_FULL_PATH=%%~ff
  for %%f in (%SCRIPT_FULL_PATH%) do set SCRIPT_DIR=%%~dpf
  set SCRIPT_PATH=
  set SCRIPT_FULL_PATH=
  echo -L- Script source code located in "%SCRIPT_DIR%"
exit /B 0


:abort
