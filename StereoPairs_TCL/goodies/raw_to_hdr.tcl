# raw_to_hdr.tcl - pseudo-HDR RAW conversion script

set SCRIPT_DIR [file dirname [info script]]


set ENFUSE "C:\Program Files\enblend-enfuse-4.1.4\bin\enfuse.exe"
set IM_DIR "C:\Program Files (x86)\ImageMagick-6.8.7-3"
# set ENFUSE "$::SCRIPT_DIR\enblend-enfuse-4.1.4-win32\bin\enfuse.exe"
# set IM_DIR "$::SCRIPT_DIR\ImageMagick"
set DCRAW $::IM_DIR\OK_dcraw.exe
set CONVERT $::IM_DIR\convert.exe
set MOGRIFY $::IM_DIR\mogrify.exe

set _tmpDir TMP
# directories for RAW conversions
set _dirNorm $::_tmpDir\OUT_NORM
set _dirLow $::_tmpDir\OUT_LOW
set _dirHigh $::_tmpDir\OUT_HIGH
set _outdirPattern $::_tmpDir\OUT_*
set _dirHDR HDR

# _dcrawParamsMain and _convertSaveParams control intermediate files - 8b or 16b
set _dcrawParamsMain "-v -c -w -H 2 -o 1 -q 3 -6"
set _convertSaveParams=-depth 16 -compress LZW
# set _dcrawParamsMain=-v -c -w -H 2 -o 1 -q 3
# set _convertSaveParams=-depth 8 -compress LZW

# set _fuseOpt=--exposure-weight=1 --saturation-weight=0.2 --contrast-weight=0 --exposure-cutoff=0%%:100%% --exposure-mu=0.5
# set _fuseOpt=--exposure-weight=1 --saturation-weight=0.2 --contrast-weight=0 --exposure-cutoff=3%%:90%% --exposure-mu=0.6
# set _fuseOpt=--exposure-weight=1 --saturation-weight=0.01 --contrast-weight=0 --exposure-cutoff=3%%:90%% --exposure-mu=0.6
# set _fuseOpt=--exposure-weight=1 --saturation-weight=0.01 --contrast-weight=0 --exposure-cutoff=1%%:99%% --exposure-mu=0.6
# set _fuseOpt=--exposure-weight=1 --saturation-weight=0.01 --contrast-weight=0 --exposure-cutoff=1%%:95%% --exposure-mu=0.6
# set _fuseOpt=--exposure-weight=1 --saturation-weight=0.01 --contrast-weight=0 --exposure-cutoff=1%%:95%% --exposure-mu=0.6
# set _fuseOpt=--exposure-weight=1 --saturation-weight=0.01 --contrast-weight=0 --exposure-cutoff=0%%:95%% --exposure-mu=0.6
set _fuseOpt=--exposure-weight=1 --saturation-weight=0.01 --contrast-weight=0 --exposure-cutoff=0%%:95%% --exposure-mu=0.7

set _finalDepth=8


# Uncomment the below in order to perform only the blending stage
# goto __fuseLbl


# ########### Make RAW conversions
md $::_dirLow
md %_dirNorm%
md $::_dirHigh
# ########### "Blend" approach looks the best for varied-exposure RAW conversions ##########
echo ====== Begin RAW conversions ========
for %%f in (*.arw) DO  (
  $::DCRAW  $::_dcrawParamsMain -b 0.3 %%f |$::CONVERT ppm:- %_convertSaveParams% $::_dirLow\%%~nf.TIF
  if NOT EXIST "$::_dirLow\%%~nf.TIF" (echo * Missing "$::_dirLow\%%~nf.TIF". Aborting... & exit /B -1)
)
for %%f in (*.arw) DO  (
  $::DCRAW  $::_dcrawParamsMain -b 1.0 %%f |$::CONVERT ppm:- %_convertSaveParams% %_dirNorm%\%%~nf.TIF
  if NOT EXIST %_dirNorm%\%%~nf.TIF (echo * Missing "%_dirNorm%\%%~nf.TIF". Aborting... & exit /B -1)
)
for %%f in (*.arw) DO  (
  $::DCRAW  $::_dcrawParamsMain -b 1.7 %%f |$::CONVERT ppm:- %_convertSaveParams% $::_dirHigh\%%~nf.TIF
  if NOT EXIST $::_dirHigh\%%~nf.TIF (echo * Missing "$::_dirHigh\%%~nf.TIF". Aborting... & exit /B -1)
)
echo ====== Done  RAW conversions ========


:__fuseLbl

# ######### Enfuse ###########
md $::_dirHDR
echo ====== Begin fusing HDR versions ========
for %%f in (*.arw) DO (
  %ENFUSE%  %_fuseOpt%  --depth=%_finalDepth% --compression=lzw --output=$::_dirHDR\%%~nf.TIF  $::_dirLow\%%~nf.TIF %_dirNorm%\%%~nf.TIF $::_dirHigh\%%~nf.TIF
  if NOT EXIST "$::_dirHDR\%%~nf.TIF" (echo * Missing "$::_dirHDR\%%~nf.TIF". Aborting... & exit /B -1)
  # #ove alpha channel
  $::MOGRIFY -alpha off -depth %_finalDepth% -compress LZW $::_dirHDR\%%~nf.TIF
)
echo ====== Done  fusing HDR versions ========

exit /B 0


# ============== Subroutines =======================

# Subroutine that assigns SCRIPT_DIR to full dir path of the script source code
# Invocation:  call :assign_SCRIPT_DIR %0
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
  echo -L- Script source code located in "$::SCRIPT_DIR"
exit /B 0
