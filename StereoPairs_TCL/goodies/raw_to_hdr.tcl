# raw_to_hdr.tcl - pseudo-HDR RAW conversion script - processes all RAWs in current dir

set SCRIPT_DIR [file dirname [info script]]

# TODO: make locally arrangements to find the package(s) instead
# TODO: for instance use the setup file from StereoPairs if found in ../
source [file join $SCRIPT_DIR   ".." "setup_stereopairs.tcl"]

package require ok_utils;   namespace import -force ::ok_utils::*


# set ENFUSE "C:\Program Files\enblend-enfuse-4.1.4\bin\enfuse.exe"
# set IM_DIR "C:\Program Files (x86)\ImageMagick-6.8.7-3"
# set ENFUSE "$::SCRIPT_DIR\enblend-enfuse-4.1.4-win32\bin\enfuse.exe"
# set IM_DIR "$::SCRIPT_DIR\ImageMagick"

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


################################################################################

proc raw_to_hdr_set_defaults {}  {
  set ::STS(toolsPathsFile)   "" ;  # full path or relative to this script
  set ::STS(finalDepth)       "" ;  # color depth of final images; 8 or 16
  set ::STS(rawExt)           "" ;  # extension of RAW iamges
  set ::STS(inpDirPaths)      [list] ;  # list of inp. dir paths - absolute or relative to the current directory
  set ::STS(outDirName)       "" ;  # relative to the input directory - to be created under it
  set ::STS(doRawConv)        1  ;  # whether to perform RAW-conversion step
  set ::STS(doBlend)          1  ;  # whether to perform blending (fusing) step
}
################################################################################
raw_to_hdr_set_defaults ;  # load only;  do call it in a function for repeated invocations
################################################################################

proc raw_to_hdr_main {cmdLineAsStr}  {
  global SCRIPT_DIR
  _raw_to_hdr_set_defaults ;  # calling it in a function for repeated invocations
  # TODO: custom _verify_external_tools
  if { 0 == [_raw_to_hdr_verify_external_tools] }  { return  0  };  # error already printed
  
  if { 0 == [raw_to_hdr_cmd_line $cmdLineAsStr cml] }  {
    return  0;  # error or help already printed
  }
  if { 0 == [set_ext_tool_paths_from_csv $::STS(toolsPathsFile)] }  {
    return  0;  # error already printed
  }
  set nInpDirs [llength $::STS(inpDirPaths)]
  ok_pri_info "Start processing RAW files under $nInpDirs input directory(ies)"
  set cntDone 0
  foreach inDir $::STS(inpDirPaths) {
    incr cntDone 1
    if { 0 == [do_job_in_one_dir $inDir] }  {
      ok_err_msg "RAW processing aborted at directory #$cntDone out of $nInpDirs"
      return  0
    }
    ok_err_msg "Done RAW processing in directory #$cntDone out of $nInpDirs"
  }
  ok_pri_info "Done processing RAW files under $cntDone out of $nInpDirs input directory(ies)"
  return  1
}


proc raw_to_hdr_cmd_line {cmdLineAsStr cmlArrName}  {
  upvar $cmlArrName      cml
  # create the command-line description
  # TODO: parameter with list of dir-s
  set descrList \
[list \
  -help {"" "print help"} \
  -tools_paths_file {val	"path of the CSV file with external tool locations - absolute or relative to this script; example: ../ext_tool_dirs.csv"}         \
  -final_depth {val	"color-depth of the final images (bit); 8 or 16"}        \
  -raw_ext {val "extension of RAW images; example: arw"}                     \
  -inp_dirs {list "list of input directories' paths; absolute or relative to the current directory"} \
  -out_subdir_name {val	"name of output directory (for HDR images); created under the input directory"} \
  -do_raw_conv {val "1 means do perform RAW-conversion step; 0 means do not" \
  -do_blend    {val "1 means do perform blending (fusing) step; 0 means do not" \
 ]
  array unset cmlD
  ok_new_cmd_line_descr cmlD $descrList
  # create dummy command line with the default parameters and copy it
  # (if an argument inexistent by default, don't provide dummy value)
  array unset defCml
  ok_set_cmd_line_params defCml cmlD { \
    {-final_depth "8"} {-do_raw_conv "1"} {-do_blend "1"} }
  ok_copy_array defCml cml;    # to preset default parameters
  # now parse the user's command line
  if { 0 == [ok_read_cmd_line $cmdLineAsStr cml cmlD] } {
    ok_err_msg "Aborted because of invalid command line";	return  0
  }
  if { [info exists cml(-help)] } {
    set cmdHelp [ok_help_on_cmd_line defCml cmlD "\n"]
    ok_info_msg "================================================================"
    ok_info_msg "    RAW-to-HDR converter makes RAW image conversions with accent of preserving maximal color-brightness range."
    ok_info_msg "========= Command line parameters (in random order): =============="
    ok_info_msg $cmdHelp
    ok_info_msg "================================================================"
    ok_info_msg "========= Example (note TCL-style directory separators): ======="
    ok_info_msg " raw_to_hdr_main \"-tools_paths_file ../ext_tool_dirs.csv -final-depth 8 -inp_dirs {L R}\""
    ok_info_msg "================================================================"
    return  0
  }
  if { 0 == [_raw_to_hdr_parse_cmdline cml] }  {
    ok_err_msg "Error(s) in command parameters. Aborting..."
    return  0
  }
  set cmdStrNoHelp [ok_cmd_line_str cml cmlD "\n" 0]
  ok_info_msg "==== Now run RAW conversions by the following spec: ===="
  ok_info_msg "==== \n$cmdStrNoHelp\n===="
  return  1
}


proc _raw_to_hdr_parse_cmdline {cmlArrName}  {
  upvar $cmlArrName      cml
  set errCnt 0

##   set ::STS(toolsPathsFile)   "" ;  # full path or relative to this script
 #   set ::STS(finalDepth)       "" ;  # color depth of final images; 8 or 16
 #   set ::STS(rawExt)           "" ;  # extension of RAW iamges
 #   set ::STS(inpDirPaths)      [list] ;  # list of inp. dir paths - absolute or relative to the current directory
 #   set ::STS(outDirName)       "" ;  # relative to the input directory - to be created under it
 #   set ::STS(doRawConv)        1  ;  # whether to perform RAW-conversion step
 #   set ::STS(doBlend)          1  ;  # whether to perform blending (fusing) step
 #   -tools_paths_file {val	"path of the CSV file with external tool locations - absolute or relative to this script; example: ../ext_tool_dirs.csv"}         \
 #   -final_depth {val "color-depth of the final images (bit); 8 or 16"}        \
 #   -raw_ext {val "extension of RAW images; example: arw"}                     \
 #   -inp_dirs {list "list of input directories' paths; absolute or relative to the current directory"} \
 #   -out_subdir_name {val	"output directory"} \
 #   -do_raw_conv {val "1 means do perform RAW-conversion step; 0 means do not" \
 #   -do_blend    {val "1 means do perform blending (fusing) step; 0 means do not" \
 ##

  if { 0 == [info exists cml(-tools_paths_file)] }  {
    ok_err_msg "Please specify path of the CSV file with external tool locations; example: ../ext_tool_dirs.csv"
    incr errCnt 1
  } elseif { 0 == [ok_filepath_is_readable $cml(-tools_paths_file)] }  {
    ok_err_msg "Inexistent or invalid file '$cml(-tools_paths_file)' specified as file with external tool locations"
    incr errCnt 1
  } else {
    set ::STS(toolsPathsFile) $cml(-tools_paths_file)
  }
  if { [info exists cml(-final_depth)] }  {
    if { ($cml(-final_depth) == 8) || ($cml(-final_depth) == 16) }  {
      set ::STS(finalDepth) $cml(-final_depth)
    } else {
      ok_err_msg "Invalid value specified for final images color depth (-final_depth); should be 8 or 16"
      incr errCnt 1
    }
  } 
  if { [info exists cml(-raw_ext)] }  {
    set ::STS(rawExt) $cml(-raw_ext)
  } else {
    ok_err_msg "Please specify extension for RAW images; example: -raw_ext ARW"
    incr errCnt 1
  } 
  if { 0 == [info exists cml(-inp_dirs)] }  {
    ok_err_msg "Please specify list of input directories; example: -inp_dirs L R"
    incr errCnt 1
  } else {
    set ::STS(inpDirPaths) [list]
    foreach inDir $cml(-inp_dirs) {
      if { 0 == [ok_filepath_is_existent_dir $inDir]) }  {
        ok_err_msg "Non-directory '$inDir' specified as one of input directories"
        incr errCnt 1
      } else {
        lappend ::STS(inpDirPaths)      [file normalize $inDir)]
      }
    }
  }
  if { 0 == [info exists cml(-out_subdir_name)] }  {
    ok_err_msg "Please specify output subdirectory name; example: -out_subdir_name HDR"
    incr errCnt 1
  } elseif { (1 == [file exists $cml(-out_subdir_name)]) && \
             (0 == [file isdirectory $cml(-out_subdir_name)]) }  {
    ok_err_msg "Non-directory '$cml(-out_subdir_name)' specified as output directory"
    incr errCnt 1
  } else {
    set ::STS(outDirName)      [file normalize $cml(-out_subdir_name)]
  }
  if { [info exists cml(-do_raw_conv)] }  {
    if { ($cml(-do_raw_conv) == 0) || ($cml(-do_raw_conv) == 1) }  {
      set ::STS(doRawConv) $cml(-do_raw_conv)
    } else {
      ok_err_msg "Parameter telling whether to perform RAW-conversion step (-do_raw_conv); should be 0 or 1"
      incr errCnt 1
    }
  } 
  if { [info exists cml(-do_blend)] }  {
    if { ($cml(-do_blend) == 0) || ($cml(-do_blend) == 1) }  {
      set ::STS(doBlend) $cml(-do_blend)
    } else {
      ok_err_msg "Parameter telling whether to perform blending (fusing) step (-do_blend); should be 0 or 1"
      incr errCnt 1
    }
  } 
  if { $errCnt > 0 }  {
    #ok_err_msg "Error(s) in command parameters!"
    return  0
  }
  #ok_info_msg "Command parameters are valid"
  return  1
}


# Does conversion and blending for all inputs in 'dirPath'
# Assumes 'dirPath' is a valid directory
proc do_job_in_one_dir {dirPath}  {
  # TODO: save the old cwd, cd to dirPath
  set oldWD [pwd]
  set tclResult [catch { set res [cd $dirPath] } execResult]
  if { $tclResult != 0 } {
    ok_err_msg "Failed changing work directory to '$dirPath': $execResult!"
    return  0
  }

  if { $::STS(doRawConv) } {
    if { 0 == [_arrange_dirs]  {
      ok_err_msg "Aborting because of failure to create a temporary output directory"
      return  0
    }
    if { 0 == [_convert_all_raws_in_current_dir $::STS(rawExt)] }  {
      return  0;  # errors already printed
    }
    #TODO: impement
  }
  if { $::STS(doBlend) } {
    #TODO: impement
  }
  set tclResult [catch { set res [cd $oldWD] } execResult]
  if { $tclResult != 0 } {
    ok_err_msg "Failed restoring work directory to '$oldWD': $execResult!"
    return  0
  }
  return  1
}

proc _arrange_dirs {} {
  if { 0 == [ok_create_absdirs_in_list \
          [list $::g_dirLow $::g_dirNorm $::g_dirHigh $::STS(outDirName)] \
          {"folder-for-darker-images" "folder-for-normal-images" \
           "folder-for-brighter-images" "folder-for-final-HDR-images"}] }  {
    return  0
  }
  return  1
}

# Makes RAW conversions; returns num of processed files, 0 if none, -1 on error
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
      ##$::_DCRAW  $::g_dcrawParamsMain -b 0.3 %%f |$::_IMCONVERT ppm:- %g_convertSaveParams% $::g_dirLow\%%~nf.TIF
      ##if NOT EXIST "$::g_dirLow\%%~nf.TIF" (echo * Missing "$::g_dirLow\%%~nf.TIF". Aborting... & exit /B -1)
    }
  }
  puts "====== Finished RAW conversions in '[pwd]'; [llength $rawPaths] RAWs processed ========"
  return  [llength $rawPaths]
}

proc _fuse_converted_images_in_current_dir {}  {

# ######### Enfuse ###########
###  md $::STS(outDirName)
set rawPaths [glob -nocomplain "*.$rawExt"];  # browse by original names
if { 0 == [llength $rawPaths] }  {
  ok_warn_msg "No RAW images (*.$rawExt) found in '[pwd]'"
  return  0
}

puts "====== Begin fusing HDR versions in '[pwd]' ========"

foreach rawPath $rawPaths {
  %ENFUSE%  %g_fuseOpt%  --depth=%_finalDepth% --compression=lzw --output=$::g_dirHDR\%%~nf.TIF  $::g_dirLow\%%~nf.TIF $::g_dirNorm\%%~nf.TIF $::g_dirHigh\%%~nf.TIF
  if NOT EXIST "$::g_dirHDR\%%~nf.TIF" (echo * Missing "$::g_dirHDR\%%~nf.TIF". Aborting... & exit /B -1)
  # #ove alpha channel
  $::_IMMOGRIFY -alpha off -depth %_finalDepth% -compress LZW $::g_dirHDR\%%~nf.TIF
)
echo ====== Done  fusing HDR versions ========
}


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

  #exec dcraw  -r $mR $mG $mB $mG  -o 2  -q 3  -h  -k 10   -c  $rawPath | $::_IMCONVERT ppm:- -quality 95 $outPath
  #exec dcraw  -r $mR $mG $mB $mG  -o 1  -q 3  -h   -k 10   -c  $rawPath | $::_IMCONVERT ppm:- -quality 95 $outPath
  exec $_DCRAW  $::g_dcrawParamsMain $dcrawParamsAdd $colorSwitches  $rawPath | $::_IMCONVERT ppm:- $::g_convertSaveParams $outPath
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


# Reads the system-dependent paths from 'csvPath',
# then assigns ultimate tool paths
proc _set_ext_tool_paths_from_csv {csvPath}  {
  if { 0 ==[ok_read_variable_values_from_csv $csvPath "external tool path(s)"]} {
    return  0;  # error already printed
  }
  if { 0 == [info exists ::_IM_DIR] }  {
    ok_err_msg "Imagemagick directory path not assigned to variable _IM_DIR by '$csvPath'"
    return  0
  }
  if { 0 == [info exists ::_ENFUSE_DIR] }  {
    ok_err_msg "Enfuse directory path not assigned to variable _ENFUSE_DIR by '$csvPath'"
    return  0
  }
  set ::_IMCONVERT  [format "{%s}"  [file join $::_IM_DIR "convert.exe"]]
  set ::_IMMOGRIFY  [format "{%s}"  [file join $::_IM_DIR "mogrify.exe"]]
  # - DCRAW:
  #set _DCRAW "dcraw.exe"
  # TMP: use custom-build OK_dcraw.exe
  set ::_DCRAW      [format "{%s}"  [file join $::_IM_DIR "OK_dcraw.exe"]]
  set ::_ENFUSE     [format "{%s}"  [file join $::_ENFUSE_DIR "enfuse.exe"]]
  return  1
}


proc _raw_to_hdr_verify_external_tools {} {
  set errCnt 0
  if { 0 == [file isdirectory $::_IM_DIR] }  {
    ok_err_msg "Inexistent or invalid Imagemagick directory '$::_IM_DIR'"
    incr errCnt 1
  }
  if { 0 == [file exists [string trim $::_IMCONVERT " {}"]] }  {
    ok_err_msg "Inexistent ImageMagick 'convert' tool '$::_IMCONVERT'"
    incr errCnt 1
  }
  if { 0 == [file exists [string trim $::_IMMOGRIFY " {}"]] }  {
    ok_err_msg "Inexistent ImageMagick 'montage' tool '$::_IMMONTAGE'"
    incr errCnt 1
  }
  if { 0 == [file exists [string trim $::_DCRAW " {}"]] }  {
    ok_err_msg "Inexistent 'dcraw' tool '$::_DCRAW'"
    incr errCnt 1
  }
  if { 0 == [file exists [string trim $::_ENFUSE " {}"]] }  {
    ok_err_msg "Inexistent 'enfuse' tool '$::_ENFUSE'"
    incr errCnt 1
  }
  if { $errCnt == 0 }  {
    ok_info_msg "All external tools are present"
    return  1
  } else {
    ok_err_msg "Some or all external tools are missing"
    return  0
  }
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
