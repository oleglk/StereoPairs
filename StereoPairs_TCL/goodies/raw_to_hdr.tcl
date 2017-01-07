# raw_to_hdr.tcl - pseudo-HDR RAW conversion script - processes all RAWs in current dir

set SCRIPT_DIR [file dirname [info script]]

# TODO: make locally arrangements to find the package(s)
package require ok_utils;   namespace import -force ::ok_utils::*


set ENFUSE "C:\Program Files\enblend-enfuse-4.1.4\bin\enfuse.exe"
set IM_DIR "C:\Program Files (x86)\ImageMagick-6.8.7-3"
# set ENFUSE "$::SCRIPT_DIR\enblend-enfuse-4.1.4-win32\bin\enfuse.exe"
# set IM_DIR "$::SCRIPT_DIR\ImageMagick"
set DCRAW $::IM_DIR\OK_dcraw.exe
set CONVERT $::IM_DIR\convert.exe
set MOGRIFY $::IM_DIR\mogrify.exe

set _tmpDir TMP
# directories for RAW conversions
set g_dirNorm $::_tmpDir\OUT_NORM
set g_dirLow $::_tmpDir\OUT_LOW
set g_dirHigh $::_tmpDir\OUT_HIGH
set _outdirPattern $::_tmpDir\OUT_*
set g_dirHDR HDR

# g_dcrawParamsMain and g_convertSaveParams control intermediate files - 8b or 16b
##### "Blend" approach looks the best for varied-exposure RAW conversions ######
set g_dcrawParamsMain "-v -c -w -H 2 -o 1 -q 3 -6"
set g_convertSaveParams "-depth 16 -compress LZW"
# set g_dcrawParamsMain "-v -c -w -H 2 -o 1 -q 3"
# set g_convertSaveParams "-depth 8 -compress LZW"

# set g_fuseOpt "--exposure-weight=1 --saturation-weight=0.2 --contrast-weight=0 --exposure-cutoff=0%%:100%% --exposure-mu=0.5"
# set g_fuseOpt "--exposure-weight=1 --saturation-weight=0.2 --contrast-weight=0 --exposure-cutoff=3%%:90%% --exposure-mu=0.6"
# set g_fuseOpt "--exposure-weight=1 --saturation-weight=0.01 --contrast-weight=0 --exposure-cutoff=3%%:90%% --exposure-mu=0.6"
# set g_fuseOpt "--exposure-weight=1 --saturation-weight=0.01 --contrast-weight=0 --exposure-cutoff=1%%:99%% --exposure-mu=0.6"
# set g_fuseOpt "--exposure-weight=1 --saturation-weight=0.01 --contrast-weight=0 --exposure-cutoff=1%%:95%% --exposure-mu=0.6"
# set g_fuseOpt "--exposure-weight=1 --saturation-weight=0.01 --contrast-weight=0 --exposure-cutoff=1%%:95%% --exposure-mu=0.6"
# set g_fuseOpt "--exposure-weight=1 --saturation-weight=0.01 --contrast-weight=0 --exposure-cutoff=0%%:95%% --exposure-mu=0.6"
set g_fuseOpt "--exposure-weight=1 --saturation-weight=0.01 --contrast-weight=0 --exposure-cutoff=0%%:95%% --exposure-mu=0.7"

set _finalDepth 8


proc do_job_in_current_dir {rawExt {doRawConv 1} {doBlend 1}}  {
  if { $doRawConv } {
    if { 0 == [_arrange_dirs]  {
      ok_err_msg "Aborting because of failure to create a temporary output directory"
      return  0
    }
    #TODO: impement
  }
  if { $doBlend } {
    #TODO: impement
  }
  return  1
}


proc _arrange_dirs {} {
  if { 0 == [ok_create_absdirs_in_list \
          [list $::g_dirLow $::g_dirNorm $::g_dirHigh] \
          {"folder-for-darker-images" "folder-for-normal-images" \
           "folder-for-brighter-images"}] }  {
    return  0
  }
  return  1
}

# Makes RAW conversions; returnsnm of processed files, 0 if none, -1 on error
proc _convert_all_raws_in_current_dir {rawExt} {
  puts "====== Begin RAW conversions in '[pwd]' ========"
  set rawPaths [glob -nocomplain "*.$rawExt"]
  if { 0 == [llength $rawPaths] }  {
    ok_warn_msg "No RAW images (*.$rawExt) found in '[pwd]'"
    return  0
  }
  set brightValToOutDir [dict create \
                            0.3 $::g_dirLow  1.0 $::g_dirNorm  1.7 $::g_dirHigh]
  dict for {brightVal outDir} $brightValToOutDir {
    foreach rawPath $rawPaths {
      if { 0 == [_convert_one_raw $rawPath $outDir "-b $brightVal"] } {
        return  -1;  # error already printed
      }
      ##$::DCRAW  $::g_dcrawParamsMain -b 0.3 %%f |$::CONVERT ppm:- %g_convertSaveParams% $::g_dirLow\%%~nf.TIF
      ##if NOT EXIST "$::g_dirLow\%%~nf.TIF" (echo * Missing "$::g_dirLow\%%~nf.TIF". Aborting... & exit /B -1)
    }
  }
  puts "====== Finished RAW conversions in '[pwd]'; [llength $rawPaths] RAWs processed ========"
  return  [llength $rawPaths]
}

:__fuseLbl

# ######### Enfuse ###########
md $::g_dirHDR
echo ====== Begin fusing HDR versions ========
for %%f in (*.arw) DO (
  %ENFUSE%  %g_fuseOpt%  --depth=%_finalDepth% --compression=lzw --output=$::g_dirHDR\%%~nf.TIF  $::g_dirLow\%%~nf.TIF $::g_dirNorm\%%~nf.TIF $::g_dirHigh\%%~nf.TIF
  if NOT EXIST "$::g_dirHDR\%%~nf.TIF" (echo * Missing "$::g_dirHDR\%%~nf.TIF". Aborting... & exit /B -1)
  # #ove alpha channel
  $::MOGRIFY -alpha off -depth %_finalDepth% -compress LZW $::g_dirHDR\%%~nf.TIF
)
echo ====== Done  fusing HDR versions ========

exit /B 0


# ============== Subroutines =======================

proc _convert_one_raw {rawPath outDir dcrawParamsAdd {rgbMultList 0}} {
  if { 0 == [file exists $outDir]  }  {  file mkdir $outDir  }
  set outPath  [file join $outDir "[file rootname [file tail $rawPath]].TIF"]
  if { 0 == [CanWriteFile $outPath] }  {
    ok_err_msg "Cannot write into '$outPath'";    return 0
  }

  if { $rgbMultList != 0 }  {
    set mR [lindex $rgbMultList 0];    set mG [lindex $rgbMultList 1];
    set mB [lindex $rgbMultList 2];    set colorSwitches "-r $mR $mG $mB $mG"
  } else {
    set mR "";   set mG "";   set mB "";    set colorSwitches ""
  }
  set colorInfo [expr {($rgbMultList != 0)? "{$mR $mG $mB}" : "as-shot"}]
  ok_info_msg "Start RAW-converting '$rawPath';  colors: $colorInfo; output into '$outPath'..."

  #exec dcraw  -r $mR $mG $mB $mG  -o 2  -q 3  -h  -k 10   -c  $rawPath | $CONVERT ppm:- -quality 95 $outPath
  #exec dcraw  -r $mR $mG $mB $mG  -o 1  -q 3  -h   -k 10   -c  $rawPath | $CONVERT ppm:- -quality 95 $outPath
  exec $DCRAW  $::g_dcrawParamsMain $dcrawParamsAdd $colorSwitches  $rawPath | $CONVERT ppm:- $::g_convertSaveParams $outPath
  # TODO: catch and check result by _is_dcraw_result_ok
	ok_info_msg "Done RAW conversion of '$rawPath' into '$outPath'"
  return  1
}


# Raw-converts 'inpPath' into temp dir
# and returns path of the output or 0 on error.
proc _raw_conv_only {inpPath} {
  #  _ext1 is lossless extension for intermediate files and maybe for output;
	set fnameNoExt [file rootname [file tail $inpPath]]
	ok_info_msg "Converting RAW file '$inpPath'; output into folder '[pwd]'"
  set outName "$fnameNoExt.$::_ext1"
  set outPath [file join $::_temp_dir $outName]
  set nv_inpPath [format "{%s}" [file nativename $inpPath]]
  set nv_outPath [format "{%s}" [file nativename $outPath]]
  set cmdListRawConv [concat $::_DCRAW $::_def_rawconv -o $::_raw_colorspace \
                      -O $nv_outPath $nv_inpPath]
  if { 0 == [ok_run_loud_os_cmd $cmdListRawConv "_is_dcraw_result_ok"] }  {
    return  0; # error already printed
  }

	ok_info_msg "Done RAW conversion of '$inpPath' into '$outPath'"
	return  $outPath
}


# Copy-pasted from Lazyconv "::dcraw::is_dcraw_result_ok"
# Verifies whether dcraw command line ended OK through the test it printed.
# Returns 1 if it was good, 0 otherwise.
proc _is_dcraw_result_ok {execResultText} {
    # 'execResultText' tells how dcraw-based command ended
    # - OK if noone of 'errKeys' appears
    set result 1;    # as if it ended OK
    set errKeys [list {Improper} {No such file} {missing} {unable} {unrecognized} {Non-numeric}]
#     puts ">>> Check for error keys '$errKeys' the following string:"
#     puts "--------------------------------------------"
#     puts "'$execResultText'"
#     puts "--------------------------------------------"
    foreach key $errKeys {
	if { [string first "$key" $execResultText] >= 0 } {    set result 0  }
    }
    return  $result
}


# Bad attempt at DCRAW with redirection:
#~ TMP> set DCRAW "C:/Program Files (x86)/ImageMagick-6.8.7-3/OK_dcraw.exe"
#~ C:/Program Files (x86)/ImageMagick-6.8.7-3/OK_dcraw.exe
#~ TMP> set CONVERT "C:/Program Files (x86)/ImageMagick-6.8.7-3/convert.exe"
#~ C:/Program Files (x86)/ImageMagick-6.8.7-3/convert.exe
#~ dict dir dump
#~ TMP> set inF "./Img/DSC01745.ARW"
#~ ./Img/DSC01745.ARW
#~ TMP> set cmdList [list $DCRAW -v -c -w -H 2 -o 1 -q 3 -6 $inF |$CONVERT ppm:- -quality 90 outfile.jpg]
#~ {C:/Program Files (x86)/ImageMagick-6.8.7-3/OK_dcraw.exe} -v -c -w -H 2 -o 1 -q 3 -6 ./Img/DSC01745.ARW {|C:/Program Files (x86)/ImageMagick-6.8.7-3/convert.exe} ppm:- -quality 90 outfile.jpg
#~ TMP> set tclExecResult1 [catch { set result [eval exec $cmdList] } cmdExecResult]
#~ 1
