# rotate_and_crop.tcl - rotation and cropping script - processes all standard images in current dir

set SCRIPT_DIR [file dirname [info script]]

# TODO: make locally arrangements to find the package(s) instead
# TODO: for instance use the setup file from StereoPairs if found in ../
source [file join $SCRIPT_DIR "setup_goodies.tcl"]

package require ok_utils;   namespace import -force ::ok_utils::*
package require img_proc;   namespace import -force ::img_proc::*


# set IM_DIR "C:\Program Files (x86)\ImageMagick-6.8.7-3"
# set IM_DIR "$::SCRIPT_DIR\ImageMagick"


set g_convertSaveParams "-depth 16 -compress LZW"
# set g_convertSaveParams "-depth 8 -compress LZW"



################################################################################

proc _rotate_and_crop_set_defaults {}  {
  set ::STS(toolsPathsFile)   "" ;  # full path or relative to this script
  set ::STS(finalDepth)       8  ;  # color depth of final images; 8 or 16
  set ::STS(imgExt)           "" ;  # extension of input images (output is always TIF)
  set ::STS(inpDirPath)       "" ;  # input dir path - absolute or relative to the current directory
  set ::STS(buDirName)        "" ;  # backup dir - relative to the input directory - to be created under it
  set ::STS(rotAngle)         0  ;  # rotation angle - clockwise
  set ::STS(cropRatio)        0  ;  # 0 == no crop; otherwise width/height AFTER rotation
  set ::STS(imSaveParams)     "" ;  # compression and quality; should match type
}
################################################################################
_rotate_and_crop_set_defaults ;  # load only;  do call it in a function for repeated invocations
################################################################################

proc rotate_and_crop_main {cmdLineAsStr}  {
  global SCRIPT_DIR
  _rotate_and_crop_set_defaults ;  # calling it in a function for repeated invocations
  
  if { 0 == [rotate_and_crop_cmd_line $cmdLineAsStr cml] }  {
    return  0;  # error or help already printed
  }
  if { 0 == [_rotate_and_crop_set_ext_tool_paths_from_csv $::STS(toolsPathsFile)] } {
    return  0;  # error already printed
  }
  # TODO: custom _verify_external_tools
  if { 0 == [_rotate_and_crop_verify_external_tools] }  { return  0  };  # error already printed

  set nInpDirs [llength $::STS(inpDirPaths)]
  ok_info_msg "Start processing image file(s) under $nInpDirs input directory(ies)"
  set cntDone 0
  foreach inDir $::STS(inpDirPaths) {
    incr cntDone 1
    if { 0 == [_do_job_in_one_dir $inDir] }  {
      ok_err_msg "Rotate-and-crop aborted at directory #$cntDone out of $nInpDirs"
      return  0
    }
    ok_info_msg "Done rotate-and-crop in directory #$cntDone out of $nInpDirs"
  }
  ok_info_msg "Done rotate-and-crop image file(s) under $cntDone out of $nInpDirs input directory(ies)"
  return  1
}


proc rotate_and_crop_cmd_line {cmdLineAsStr cmlArrName}  {
  upvar $cmlArrName      cml
  # create the command-line description
[list \
  -help {"" "print help"}                                                      \
  -tools_paths_file {val	"path of the CSV file with external tool locations - absolute or relative to this script; example: ../ext_tool_dirs.csv"} \
  -final_depth {val	"color-depth of the final images (bit); 8 or 16"}         \
  -img_ext {val "extension of image files; example: jpg"}                      \
  -inp_dir {val "input directory path; absolute or relative to the current directory"} \
  -bu_subdir_name {val	"name of backup directory (for original images); created under the input directory; empty string means no backup"} \
  -rot_angle   {val "rotation angle - clockwise"}  \
  -crop_ratio  {val "width-to-height ratio AFTER rotation; 0 means do not crop"} \
 ]
  array unset cmlD
  ok_new_cmd_line_descr cmlD $descrList
  # create dummy command line with the default parameters and copy it
  # (if an argument inexistent by default, don't provide dummy value)
  array unset defCml
  ok_set_cmd_line_params defCml cmlD { \
    {-final_depth "8"} {-rot_angle "0"} {-crop_ratio "0"} \
    {-bu_subdir_name "Orig"} }
  ok_copy_array defCml cml;    # to preset default parameters
  # now parse the user's command line
  if { 0 == [ok_read_cmd_line $cmdLineAsStr cml cmlD] } {
    ok_err_msg "Aborted because of invalid command line";	return  0
  }
  if { [info exists cml(-help)] } {
    set cmdHelp [ok_help_on_cmd_line defCml cmlD "\n"]
    ok_info_msg "================================================================"
    ok_info_msg "    Rotation and cropping of images."
    ok_info_msg "========= Command line parameters (in random order): =============="
    ok_info_msg $cmdHelp
    ok_info_msg "================================================================"
    ok_info_msg "========= Example 1 - rotation only (note TCL-style directory separators): ======="
    ok_info_msg " rotate_and_crop_main \"-rot_angle 90 -crop_ratio 0 -final_depth 8 -inp_dir L -bu_subdir_name "" -img_ext TIF -tools_paths_file ../ext_tool_dirs.csv\""
    ok_info_msg "================================================================"
    ok_info_msg "========= Example 2 - rotate and crop: ======="
    ok_info_msg " rotate_and_crop_main \"-rot_angle 90 -crop_ratio 1 -final_depth 8 -inp_dir R -bu_subdir_name "BU" -img_ext JPG -tools_paths_file ../ext_tool_dirs.csv\""
    ok_info_msg "================================================================"
    return  0
  }
  if { 0 == [_rotate_and_crop_parse_cmdline cml] }  {
    ok_err_msg "Error(s) in command parameters. Aborting..."
    return  0
  }
  set cmdStrNoHelp [ok_cmd_line_str cml cmlD "\n" 0]
  if { "-ERROR-" == [set ::STS(imSaveParams) [choose_im_img_save_params \
                                      $::STS(imgExt) $::STS(finalDepth)]] }  {
    return  0;  # error already printed
  }

  ok_info_msg "==== Now run rotate-and-crop by the following spec: ===="
  ok_info_msg "==== \n$cmdStrNoHelp\n===="
  return  1
}


proc _rotate_and_crop_parse_cmdline {cmlArrName}  {
  upvar $cmlArrName      cml
  set errCnt 0
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
##   -img_ext {val "extension of image files; example: jpg"}                      \
 #   -inp_dir {val "input directory path; absolute or relative to the current directory"} \
 #   -bu_subdir_name {val	"name of backup directory (for original images); created under the input directory; empty string means no backup"} \
 #   -rot_angle   {val "rotation angle - clockwise"}  \
 #   -crop_ratio  {val "width-to-height ratio AFTER rotation; 0 means do not crop"} \
 ##
##   set ::STS(imgExt)           "" ;  # extension of input images (output is always TIF)
 #   set ::STS(inpDirPath)       "" ;  # input dir path - absolute or relative to the current directory
 #   set ::STS(buDirName)        "" ;  # backup dir - relative to the input directory - to be created under it
 #   set ::STS(rotAngle)         0  ;  # rotation angle - clockwise
 #   set ::STS(cropRatio)        0  ;  # 0 == no crop; otherwise width/height AFTER rotation
 ##
  if { [info exists cml(-img_ext)] }  {
    set ::STS(imgExt) $cml(-img_ext)
  } else {
    ok_err_msg "Please specify extension for image files; example: -img_ext TIF"
    incr errCnt 1
  } 
  if { 0 == [info exists cml(-inp_dir)] }  {
    ok_err_msg "Please specify the input directory; example: -inp_dir L"
    incr errCnt 1
  } else {
    set inDir $cml(-inp_dir)
    if { 0 == [ok_filepath_is_existent_dir $inDir] }  {
      ok_err_msg "Non-directory '$inDir' specified as the input directory"
      incr errCnt 1
    } else {
      set ::STS(inpDirPath) [file normalize $inDir]
    }
  }
  if { 1 == [info exists cml(-bu_subdir_name)] }  {
    if { (1 == [file exists $cml(-bu_subdir_name)]) && \
             (0 == [file isdirectory $cml(-bu_subdir_name)]) }  {
    ok_err_msg "Non-directory '$cml(-bu_subdir_name)' specified as backup directory"
    incr errCnt 1
    } else {
      set ::STS(buDirName)      $cml(-bu_subdir_name)
    }
  }
  if { 0 != $cml(-rot_angle)] }  { ;  # =0 (default) if not given
    if { [ok_isnumeric ($cml(-rot_angle)] }  {
      set ::STS(rotAngle) $cml(-rot_angle)
    } else {
      ok_err_msg "Parameter telling rotation angle (-rot_angle); should be numeric"
      incr errCnt 1
    }
  } else {  ok_info_msg "Rotation not requested"  }
  if { 0 != $cml(-crop_ratio)] }  { ;  # =0 (default) if not given
    if { [ok_isnumeric ($cml(-crop_ratio)] }  {
      set ::STS(cropRatio) $cml(-crop_ratio)
    } else {
      ok_err_msg "Parameter telling crop ratio (-crop_ratio); should be numeric"
      incr errCnt 1
    }
  }  else {  ok_info_msg "Cropping not requested"  }
  if { (0 == $cml(-rot_angle)]) && (0 == $cml(-crop_ratio)]) } 
    ok_info_msg "Please specify rotation angle and/or crop ratio; example: -rot_angle 270 -crop_ratio 1"
    incr errCnt 1
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
proc _do_job_in_one_dir {dirPath}  {
  set oldWD [pwd];  # save the old cwd, cd to dirPath, restore before return
  set tclResult [catch { set res [cd $dirPath] } execResult]
  if { $tclResult != 0 } {
    ok_err_msg "Failed changing work directory to '$dirPath': $execResult!"
    return  0
  }
  ok_info_msg "Success changing work directory to '$dirPath'"

  if { 0 == [_arrange_dirs_in_current_dir] }  {
    ok_err_msg "Aborting because of failure to create a temporary output directory"
    return  0
  }
  if { 0 == [_rotate_crop_all_in_current_dir $::STS(rawExt)] }  {
    return  0;  # errors already printed
  }
 
  set tclResult [catch { set res [cd $oldWD] } execResult]
  if { $tclResult != 0 } {
    ok_err_msg "Failed restoring work directory to '$oldWD': $execResult!"
    return  0
  }
  return  1
}

proc _arrange_dirs_in_current_dir {} {
  if { 0 == [ok_create_absdirs_in_list \
          [list $::STS(buDirName)] \
          {"backup-folder-for-original-images"}] }  {
    return  0
  }
  return  1
}

# Performs rotations and croppings; returns num of processed files, 0 if none, -1 on error.
proc _rotate_crop_all_in_current_dir {imgExt} {
  puts "====== Begin rotations and croppings in '[pwd]' ========"
  set imgPaths [glob -nocomplain "*.$imgExt"]
  if { 0 == [llength $imgPaths] }  {
    ok_warn_msg "No images (*.$imgExt) found in '[pwd]'"
    return  0
  }
  foreach imgPath $imgPaths {
    if { 0 == [_rotate_crop_one_img \
                                  $imgPath $::STS(rotAngle) $::STS(cropRatio) \
                                  $imSaveParams $::STS(buDirName)] } {
      return  -1;  # error already printed
    }
  }
  puts "====== Finished rotations and croppings in '[pwd]'; [llength $imgPaths] image(s) processed ========"
  return  [llength $imgPaths]
}


# ============== Subroutines =======================

# Returns ImageMagick file-save compression and quality parameters.
# On error returns "-ERROR-".
proc choose_im_img_save_params {imgExt finalDepth }  {
  TODO
}


proc _fuse_one_hdr {rawName outDir fuseOpt} {
  if { 0 == [file exists $outDir]  }  {  file mkdir $outDir  }
  set outPath  [file join $outDir "$rawName.TIF"]
  if { 0 == [ok_filepath_is_writable $outPath] }  {
    ok_err_msg "Cannot write into '$outPath'";    return 0
  }
  set inPathLow  [file join $::STS(dirLow)  "$rawName.TIF"]
  set inPathNorm [file join $::STS(dirNorm) "$rawName.TIF"]
  set inPathHigh [file join $::STS(dirHigh) "$rawName.TIF"]
  foreach p [list $inPathLow $inPathNorm $inPathHigh]  {
    if { ![ok_filepath_is_readable $p] }  {
      ok_err_msg "Inexistent or unreadable intermediate image '$p'";    return 0
    }
  }
  set cmdListFuse [concat $::_ENFUSE  $fuseOpt  --depth=$::STS(finalDepth) \
                          --compression=lzw "--output=$outPath"  \
                          "$inPathLow" "$inPathNorm" "$inPathHigh"]
  ok_info_msg "enfuse cmd-line (rawName='$rawName', outDir='$outDir'):  {$cmdListFuse}"
  if { 0 == [ok_run_loud_os_cmd $cmdListFuse _is_enfuse_result_ok] }  {
    return  0; # error already printed
  }

  if { ![file exists $outPath] }  {
    ok_err_msg "Missing output HDR image '$outPath'";     return 0
  }
##   %ENFUSE%  %g_fuseOpt%  --depth=%::STS(finalDepth)% --compression=lzw --output=$::g_dirHDR\%%~nf.TIF  $::g_dirLow\%%~nf.TIF $::g_dirNorm\%%~nf.TIF $::g_dirHigh\%%~nf.TIF
 #   if NOT EXIST "$::g_dirHDR\%%~nf.TIF" (echo * Missing "$::g_dirHDR\%%~nf.TIF". Aborting... & exit /B -1)
 ##
  # TODO
  # remove alpha channel
  eval exec $::_IMMOGRIFY -alpha off -depth $::STS(finalDepth) -compress LZW $outPath
##  $::_IMMOGRIFY -alpha off -depth %::STS(finalDepth)% -compress LZW $::g_dirHDR\%%~nf.TIF
 ok_info_msg "Success fusing HDR image '$outPath'"
 return  1
}


## # Raw-converts 'inpPath' into temp dir
 # # and returns path of the output or 0 on error.
 # proc _raw_conv_only {inpPath} {
 #   #  _ext1 is lossless extension for intermediate files and maybe for output;
 # 	set fnameNoExt [file rootname [file tail $inpPath]]
 # 	ok_info_msg "Converting RAW file '$inpPath'; output into folder '[pwd]'"
 #   set outName "$fnameNoExt.$::_ext1"
 #   set outPath [file join $::_temp_dir $outName]
 #   set nv_inpPath [format "{%s}" [file nativename $inpPath]]
 #   set nv_outPath [format "{%s}" [file nativename $outPath]]
 #   set cmdListRawConv [concat $::_DCRAW $::_def_rawconv -o $::_raw_colorspace \
 #                       -O $nv_outPath $nv_inpPath]
 #   if { 0 == [ok_run_loud_os_cmd $cmdListRawConv "_is_dcraw_result_ok"] }  {
 #     return  0; # error already printed
 #   }
 # 
 # 	ok_info_msg "Done RAW conversion of '$inpPath' into '$outPath'"
 # 	return  $outPath
 # }
 ##


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


# Verifies whether enfuse command line ended OK through the test it printed.
# Returns 1 if it was good, 0 otherwise.
proc _is_enfuse_result_ok {execResultText} {
    # 'execResultText' tells how enfuse-based command ended
    # - OK if noone of 'errKeys' appears
    set result 1;    # as if it ended OK
    set errKeys [list {enfuse: no input files specified} {require arguments} {enfuse: unrecognized} {enfuse: error opening output file}]
#     puts ">>> Check for error keys '$errKeys' the following string:"
#     puts "--------------------------------------------"
#     puts "'$execResultText'"
#     puts "--------------------------------------------"
    foreach key $errKeys {
      ok_trace_msg "Look for '$key' in command output"
      if { [string first "$key" $execResultText] >= 0 } {
        ok_err_msg "Error indicator detected in command output: '$key'"
        set result 0
      }
    }
    return  $result
}


# Reads the system-dependent paths from 'csvPath',
# then assigns ultimate tool paths
proc _rotate_and_crop_set_ext_tool_paths_from_csv {csvPath}  {
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


proc _rotate_and_crop_verify_external_tools {} {
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


# Returns 1 if 'nameAndMultsAsList' obeys the following format:
#     {<filename> <float> <float> <float> <float>}
# Otherwise returns 0
proc _ColorMultLineCheckCB {nameAndMultsAsList}  {
  if { 5 != [llength $nameAndMultsAsList] }  {
    return  "Wrong number of fields - should be 5"
  }
  set fieldNames {"file-name" "red" "green" "blue" "green-2"}
  for {set i 1}  {$i < [llength $nameAndMultsAsList]}  {incr i}  {
    set mult [lindex $nameAndMultsAsList $i]
    set name [lindex $fieldNames $i]
    if { 0 == [ok_validate_string_by_given_format "%f" $mult] }  {
      return  "Invalid value '$mult' for $name multiplier"
    }
  }
  return  "";  # OK
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
