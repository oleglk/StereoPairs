# raw_to_hdr.tcl - pseudo-HDR RAW conversion script - processes all RAWs in current dir

################################################################################
# Sample invocation on all .arw files in current dir (will create output dir-s):
################################################################################
## source c:/Oleg/Work/stereopairs/StereoPairs_TCL/goodies/raw_to_hdr.tcl
## raw_to_hdr_main "-final_depth 8 -inp_dirs {.} -out_subdir_name OUT -raw_ext ARW -tools_paths_file  c:/Oleg/Work/Stereopairs/ext_tool_dirs__Yoga.csv"
################################################################################

set SCRIPT_DIR [file dirname [info script]]

# TODO: make locally arrangements to find the package(s) instead
# TODO: for instance use the setup file from StereoPairs if found in ../
source [file join $SCRIPT_DIR "setup_goodies.tcl"]

package require ok_utils;   namespace import -force ::ok_utils::*
package require img_proc;   namespace import -force ::img_proc::*

set ::_WORK_BY_STAGE 0;  # 1 = RAW-convert all, then fuse all

# set ENFUSE "C:\Program Files\enblend-enfuse-4.1.4\bin\enfuse.exe"
# set IM_DIR "C:\Program Files (x86)\ImageMagick-6.8.7-3"
# set ENFUSE "$::SCRIPT_DIR\enblend-enfuse-4.1.4-win32\bin\enfuse.exe"
# set IM_DIR "$::SCRIPT_DIR\ImageMagick"


# g_dcrawParamsMain and g_convertSaveParams control intermediate files - 8b or 16b
##### "Blend" approach looks the best for varied-exposure RAW conversions ######
set g_dcrawParamsMain "-v -c -H 0 -o 1 -q 3 -6 -g 2.4 12.9";  # EXCLUDING WB
set g_convertOutfileExt "TIF"
set g_convertSaveParams "-depth 16 -compress LZW"
# set g_dcrawParamsMain "-v -c -H 2 -o 1 -q 3";  # EXCLUDING WB
# set g_convertSaveParams "-depth 8 -compress LZW"
# dcraw params change for preview mode: "-h" (half-size) instead of "-6" (16bit)
set g_dcrawParamsMain_preview "-v -c -H 0 -o 1 -q 3 -h -g 2.4 12.9";  # EXCLUDING WB
set g_convertOutfileExt_preview "JPG";                  # "TIF"
set g_convertSaveParams_preview "-depth 8 -quality 98"; # "-depth 8 -compress LZW"

# set g_fuseOpt "--exposure-weight=1 --saturation-weight=0.2 --contrast-weight=0 --exposure-cutoff=0%%:100%% --exposure-mu=0.5"
# set g_fuseOpt "--exposure-weight=1 --saturation-weight=0.2 --contrast-weight=0 --exposure-cutoff=3%%:90%% --exposure-mu=0.6"
# set g_fuseOpt "--exposure-weight=1 --saturation-weight=0.01 --contrast-weight=0 --exposure-cutoff=3%%:90%% --exposure-mu=0.6"
# set g_fuseOpt "--exposure-weight=1 --saturation-weight=0.01 --contrast-weight=0 --exposure-cutoff=1%%:99%% --exposure-mu=0.6"
# set g_fuseOpt "--exposure-weight=1 --saturation-weight=0.01 --contrast-weight=0 --exposure-cutoff=1%%:95%% --exposure-mu=0.6"
# set g_fuseOpt "--exposure-weight=1 --saturation-weight=0.01 --contrast-weight=0 --exposure-cutoff=1%%:95%% --exposure-mu=0.6"
# set g_fuseOpt "--exposure-weight=1 --saturation-weight=0.01 --contrast-weight=0 --exposure-cutoff=0%%:95%% --exposure-mu=0.6"
set g_fuseOpt "--exposure-weight=1 --saturation-weight=0.01 --contrast-weight=0 --exposure-cutoff=0%:95% --exposure-mu=0.7"
set g_fuseSaveParams         "--compression=lzw"
set g_fuseSaveParams_preview "--compression=98"


################################################################################
# Runtime global variables to be initialized upon 1st RAW in a directory
# TODO: unset at end
set ::g_rawNamesToWbMults     0
set ::g_brightValToAbsOutDir  0
################################################################################


################################################################################

proc _raw_to_hdr_set_defaults {}  {
  set ::STS(toolsPathsFile)   "" ;  # full path or relative to this script
  set ::STS(finalDepth)       8  ;  # color depth of final images; 8 or 16
  set ::STS(rawExt)           "" ;  # extension of RAW iamges
  set ::STS(inpDirPaths)      [list] ;  # list of inp. dir paths - absolute or relative to the current directory
  set ::STS(outDirName)       "" ;  # relative to the input directory - to be created under it
  set ::STS(tmpDirPath)       "" ;  # absolute or relative to the input directory - to be created or reused
  set ::STS(rotAngle)         -1 ;  # -1 == rotate according to EXIF;  0|90|180|270 - rotation angle clockwise
  set ::STS(doHDR)            1  ;  # 1 == multiple RAW conversions then blend;  0 == single RAW conversion
  set ::STS(doPreview)        1  ;  # 1 == smaller and faster;  0 == full-size, very slow
  set ::STS(doRawConv)        1  ;  # whether to perform RAW-conversion step
  set ::STS(doBlend)          1  ;  # whether to perform blending (fusing) step
  set ::STS(doSkipExisting)   0  ;  # whether to keep pre-existent outputs untouched
  set ::STS(abortOnLowDiskSpace) 1;  # whether to abort if not enough free disk space for conversion
  set ::STS(wbInpFile)        "" ;  # input  file with per-image white balance coefficients
  set ::STS(wbOutFile)        "" ;  # output file with per-image white balance coefficients

  #~ set _tmpDir TMP
  #~ # directories for RAW conversions - relative paths - to use under CWD
  #~ set ::STS(dirNorm) [file join $_tmpDir OUT_NORM]
  #~ set ::STS(dirLow)  [file join $_tmpDir OUT_LOW]
  #~ set ::STS(dirHigh) [file join $_tmpDir OUT_HIGH]
}
################################################################################
_raw_to_hdr_set_defaults ;  # load only;  do call it in a function for repeated invocations
################################################################################


# User command for multiple RAW conversions and HDR blending
proc raw_to_hdr_main {cmdLineAsStr {doHDR 1}}  {
  global SCRIPT_DIR
  _raw_to_hdr_set_defaults ;  # calling it in a function for repeated invocations
  set ::STS(doHDR) $doHDR
  
  if { 0 == [raw_to_hdr_cmd_line $cmdLineAsStr cml] }  {
    return  0;  # error or help already printed
  }
  if { 0 == [_raw_to_hdr_set_ext_tool_paths_from_csv $::STS(toolsPathsFile)] } {
    return  0;  # error already printed
  }
  # TODO: custom _verify_external_tools
  if { 0 == [_raw_to_hdr_verify_external_tools] }  { return  0  };  # error already printed

  ok_reset_start_time_if_needed ;   # the timer to track long activity periods

  set nInpDirs [llength $::STS(inpDirPaths)]
  ok_info_msg "Start processing RAW file(s) under $nInpDirs input directory(ies)"
  set cntDone 0
  foreach inDir $::STS(inpDirPaths) {
    incr cntDone 1
    set dirOK [expr {$::_WORK_BY_STAGE? [_do_job_in_one_dir__by_stages $inDir] \
                                      : [_do_job_in_one_dir__by_inputs $inDir]}]
    if { $dirOK == 0 }  {
      ok_err_msg "RAW processing aborted at directory #$cntDone out of $nInpDirs"
      return  0
    }
    ok_info_msg "Done RAW processing in directory #$cntDone out of $nInpDirs"
  }
  ok_info_msg "Done processing RAW file(s) under $cntDone out of $nInpDirs input directory(ies)"
  return  1
}


# User command for simple RAW conversion
proc raw_to_img_main {cmdLineAsStr}  {
  set ::STS(doHDR) 0
  return  [raw_to_hdr_main $cmdLineAsStr $::STS(doHDR)]
}


proc raw_to_hdr_cmd_line {cmdLineAsStr cmlArrName}  {
  upvar $cmlArrName      cml
  # create the command-line description
  set descrList \
[list \
  -help {"" "print help"}                                                      \
  -tools_paths_file {val	"path of the CSV file with external tool locations - absolute or relative to this script; example: ../ext_tool_dirs.csv"} \
  -final_depth {val	"color-depth of the final images (bit); 8 or 16"}         \
  -raw_ext {val "extension of RAW images; example: arw"}                      \
  -inp_dirs {list "list of input directories' paths; absolute or relative to the current directory"} \
  -out_subdir_name {val	"name of output directory (for HDR images); created under the input directory"} \
  -tmp_dir_path {val	"path of temporary directory; absolute or relative to the current directory - to be created or reused"} \
  -do_raw_conv {val "1 means do perform RAW-conversion step; 0 means do not"}  \
  -rotate {val "1 means rotate according to EXIF (default);  0|90|180|270 - rotation angle clockwise"} \
  -do_blend    {val "1 means do perform blending/fusing step; 0 means do not"} \
  -do_skip_existing {val "1 means keep pre-existent outputs untouched; 0 means perform the conversion and override"} \
  -do_abort_on_low_disk_space {val "1 means exit if available free disk space smaller than estimated need; 0 means continue anyway"} \
  -do_preview  {val "1 means create smaller-size previews; 0 means create full-size images"} \
  -wb_inp_file {val	"name of the CSV file (under the working directory) with white-balance coefficients to be used for RAW images"} \
  -wb_out_file {val	"name of the CSV file (under the working directory) for white-balance coefficients that were used for RAW images"} \
 ]
  array unset cmlD
  ok_new_cmd_line_descr cmlD $descrList
  # create dummy command line with the default parameters and copy it
  # (if an argument inexistent by default, don't provide dummy value)
  array unset defCml
  ok_set_cmd_line_params defCml cmlD {                                    \
    {-final_depth "8"} {-tmp_dir_path "TMP"} {-do_raw_conv "1"} {-rotate "-1"} {-do_blend "1"}  \
    {-do_skip_existing "0"} {-do_abort_on_low_disk_space 1}               \
    {-do_preview "0"} {-wb_out_file "wb_out.csv"} }
  ok_copy_array defCml cml;    # to preset default parameters
  # now parse the user's command line
  if { 0 == [ok_read_cmd_line $cmdLineAsStr cml cmlD] } {
    ok_err_msg "Aborted because of invalid command line";	return  0
  }
  if { [info exists cml(-help)] } {
    set cmdHelp [ok_help_on_cmd_line defCml cmlD "\n"]
    ok_info_msg "================================================================"
    ok_info_msg "    RAW-to-HDR converter makes RAW image conversions with accent of preserving maximal color-brightness range."
    ok_info_msg "========================"
    ok_info_msg "      (use raw_to_img_main \"<arguments>\" for simple RAW conversion instead)"
    ok_info_msg "========================"
    ok_info_msg "========= Command line parameters (in random order): =============="
    ok_info_msg $cmdHelp
    ok_info_msg "================================================================"
    ok_info_msg "========= Example 1 - camera-WB (note TCL-style directory separators): ======="
    ok_info_msg " raw_to_hdr_main \"-final_depth 8 -inp_dirs {L R} -out_subdir_name OUT -raw_ext ARW -tools_paths_file ../ext_tool_dirs.csv\""
    ok_info_msg "================================================================"
    ok_info_msg "========= Example 2 - overrides WB for the two directories: ======="
    ok_info_msg " raw_to_hdr_main \"-final_depth 8 -inp_dirs {L R} -out_subdir_name OUT -raw_ext ARW -tools_paths_file ../ext_tool_dirs.csv -wb_inp_file wb_inp.csv\""
    ok_info_msg "================================================================"
    ok_info_msg "========= Example 3 - use camera-WB from first directory on images in the second one: ======="
    ok_info_msg " raw_to_hdr_main \"-final_depth 8 -inp_dirs {L R} -out_subdir_name OUT -raw_ext ARW -tools_paths_file ../ext_tool_dirs.csv -wb_out_file wb_dir1.csv -wb_inp_file wb_dir1.csv\""
    ok_info_msg "================================================================"
    ok_info_msg "========= Example 4 - small size preview with camera-WB; tool paths file in home directory: ======="
    ok_info_msg " raw_to_hdr_main \"-do_preview 1 -inp_dirs {L R} -out_subdir_name OUT -raw_ext ARW -tools_paths_file ~/dualcam_ext_tool_dirs.csv\""
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
  if { 0 == [info exists cml(-tools_paths_file)] }  {
    ok_err_msg "Please specify path of the CSV file with external tool locations; example: ../ext_tool_dirs.csv"
    incr errCnt 1
  } elseif { 0 == [ok_filepath_is_readable $cml(-tools_paths_file)] }  {
    ok_err_msg "Inexistent or invalid file '$cml(-tools_paths_file)' specified as file with external tool locations"
    incr errCnt 1
  } else {
    set ::STS(toolsPathsFile) $cml(-tools_paths_file)
  }
  if { [info exists cml(-do_preview)] }  {
    if { ($cml(-do_preview) == 0) || ($cml(-do_preview) == 1) }  {
      set ::STS(doPreview) $cml(-do_preview)
    } else {
      ok_err_msg "Parameter telling whether to create only smaller preview images (-do_preview); should be 0 or 1"
      incr errCnt 1
    }
  } 
  if { [info exists cml(-final_depth)] }  {
    if { ($cml(-final_depth) == 8) || ($cml(-final_depth) == 16) }  {
      set ::STS(finalDepth) $cml(-final_depth)
      if { ($::STS(doPreview) == 1) && ($::STS(finalDepth) == 16) }  {
        ok_warn_msg "Final images color depth overriden to 8-bit for preview mode"
        set ::STS(finalDepth) 8
      }
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
      if { 0 == [ok_filepath_is_existent_dir $inDir] }  {
        ok_err_msg "Non-directory '$inDir' specified as one of input directories"
        incr errCnt 1
      } else {
        lappend ::STS(inpDirPaths)      [file normalize $inDir]
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
    set ::STS(outDirName)      $cml(-out_subdir_name)
  }
  if { 0 == [info exists cml(-tmp_dir_path)] }  {
    set ::STS(tmpDirPath)      [file normalize [file join [pwd] "TMP"]]
    ok_err_msg "No temporary directory path specified; will use default directory '$::STS(tmpDirPath)'"
  } elseif { (1 == [file exists $cml(-tmp_dir_path)]) && \
             (0 == [file isdirectory $cml(-tmp_dir_path)]) }  {
    ok_err_msg "Non-directory '$cml(-tmp_dir_path)' specified as output directory"
    incr errCnt 1
  } else {
    set ::STS(tmpDirPath)      [file normalize $cml(-tmp_dir_path)]
  }
  if { [info exists cml(-do_raw_conv)] }  {
    if { $::STS(doHDR) == 0 }  {
      ok_warn_msg "Argument '-do_raw_conv' ignored in simple RAW conversion mode"
    } else {
      if { ($cml(-do_raw_conv) == 0) || ($cml(-do_raw_conv) == 1) }  {
        set ::STS(doRawConv) $cml(-do_raw_conv)
      } else {
        ok_err_msg "Parameter telling whether to perform RAW-conversion step (-do_raw_conv); should be 0 or 1"
        incr errCnt 1
      }
    }
  } 
  if { [info exists cml(-rotate)] }  {
    set permRotAngle [list -1 0 90 180 270]
    if { 0 <= [lsearch -exact $permRotAngle $cml(-rotate)] }  {
      set ::STS(rotAngle) $cml(-rotate)
    } else {
      ok_err_msg "Parameter telling how to rotate images (-rotate); should be one of {$permRotAngle}; -1 means use EXIF orientation"
      incr errCnt 1
    }
  }
  if { [info exists cml(-do_blend)] }  {
    if { $::STS(doHDR) == 0 }  {
      ok_warn_msg "Argument '-do_blend' ignored in simple RAW conversion mode"
    } else {
      if { ($cml(-do_blend) == 0) || ($cml(-do_blend) == 1) }  {
        set ::STS(doBlend) $cml(-do_blend)
      } else {
        ok_err_msg "Parameter telling whether to perform blending (fusing) step (-do_blend); should be 0 or 1"
        incr errCnt 1
      }
    }
  } 
  if { [info exists cml(-do_skip_existing)] }  {
    if { ($cml(-do_skip_existing) == 0) || ($cml(-do_skip_existing) == 1) }  {
        set ::STS(doSkipExisting) $cml(-do_skip_existing)
      } else {
        ok_err_msg "Parameter telling whether to keep pre-existent outputs untouched (-do_skip_existing); should be 0 or 1"
        incr errCnt 1
      }
  }
  if { [info exists cml(-do_abort_on_low_disk_space)] }  {
    if { ($cml(-do_abort_on_low_disk_space) == 0) || ($cml(-do_abort_on_low_disk_space) == 1) }  {
        set ::STS(abortOnLowDiskSpace) $cml(-do_abort_on_low_disk_space)
      } else {
        ok_err_msg "Parameter telling whether to exit if free disk space is insufficient (-do_abort_on_low_disk_space); should be 0 or 1"
        incr errCnt 1
      }
  }
  if { [info exists cml(-wb_inp_file)] }  {
    set iwbPath [file join [pwd] $cml(-wb_inp_file)]
    if { 0 == [ok_filepath_is_readable $iwbPath] }  {
      ok_err_msg "Inexistent or invalid file '$iwbPath' specified as the input file with white-balance coefficients"
      incr errCnt 1
    } else {
      set ::STS(wbInpFile) $iwbPath
    }
  }
  if { [info exists cml(-wb_out_file)] }  {
    # accept the name - cannot check writability before dir-s created
    set ::STS(wbOutFile) [file join [pwd] $cml(-wb_out_file)]
  }
  if { $errCnt > 0 }  {
    #ok_err_msg "Error(s) in command parameters!"
    return  0
  }
  #ok_info_msg "Command parameters are valid"
  return  1
}


# Does conversion and blending for all inputs in 'dirPath' - if ::STS(doHDR)==1
# Does simple conversion only for all inputs in 'dirPath'  - if ::STS(doHDR)==0
# Assumes 'dirPath' is a valid directory
# Performs raw-conversion for all inputs, then blending for all inputs
proc _do_job_in_one_dir__by_stages {dirPath}  {
  set oldWD [pwd];  # save the old cwd, cd to dirPath, restore before return
  set tclResult [catch { set res [cd $dirPath] } execResult]
  if { $tclResult != 0 } {
    ok_err_msg "Failed changing work directory to '$dirPath': $execResult!"
    return  0
  }
  ok_info_msg "Success changing work directory to '$dirPath'"
  if { $::STS(doRawConv) || ($::STS(doHDR) == 0) } {
    if { 0 == [_arrange_dirs_for_current_dir] }  {
      ok_err_msg "Aborting because of failure to create a temporary output directory"
      return  0
    }
    if { 0 > [_convert_all_raws_in_current_dir $::STS(rawExt)] }  {
      return  0;  # errors already printed
    }
  }
  if { ($::STS(doBlend)) && ($::STS(doHDR) == 1) } {
    # assume that RAW conversions are done and thus the directories prepared
    if { 0 == [_fuse_converted_images_in_current_dir $::STS(rawExt)] }  {
      return  0;  # errors already printed
    }
  }
  set tclResult [catch { set res [cd $oldWD] } execResult]
  if { $tclResult != 0 } {
    ok_err_msg "Failed restoring work directory to '$oldWD': $execResult!"
    return  0
  }
  return  1
}


# Does conversion and blending for all inputs in 'dirPath' - if ::STS(doHDR)==1
# Does simple conversion only for all inputs in 'dirPath'  - if ::STS(doHDR)==0
# Assumes 'dirPath' is a valid directory
# Performs raw-conversion then immediately blending for all inputs
proc _do_job_in_one_dir__by_inputs {dirPath}  {
  set oldWD [pwd];  # save the old cwd, cd to dirPath, restore before return
  set tclResult [catch { set res [cd $dirPath] } execResult]
  if { $tclResult != 0 } {
    ok_err_msg "Failed changing work directory to '$dirPath': $execResult!"
    return  0
  }
  ok_info_msg "Success changing work directory to '$dirPath'"
  set rawPaths [glob -nocomplain "*.$::STS(rawExt)"]
  if { 0 == [llength $rawPaths] }  {
    ok_warn_msg "No RAW images (*.$::STS(rawExt)) found in '[pwd]'"
    # OK_TODO: consider returning to directory 'oldWD'
    return  0
  }
  set outDir [file join [pwd] $::STS(outDirName)];  # abs path for msg clarity
  
  if { $::STS(doRawConv) || ($::STS(doHDR) == 0) } {
    if { 0 == [_arrange_dirs_for_current_dir] }  {
      ok_err_msg "Aborting because of failure to create a temporary output directory"
      return  0
    }
  }
  for {set rawIdx 0}  {$rawIdx < [llength $rawPaths]}  {incr rawIdx 1}  {
    set lastRawPath [lindex $rawPaths $rawIdx]
    set descr "RAW input \[$rawIdx\] - '$lastRawPath'"
    # perform 1 or 3 conversions of the current RAW
    if { $::STS(doRawConv) || ($::STS(doHDR) == 0) } {
      set res [_convert_one_raw_in_current_dir $::STS(rawExt) $rawIdx]
      if { $res < 0 }  {
        ok_err_msg "Failed RAW conversions in '[pwd]' at $descr"
        return  $res
      }
    }
    # perform fusing of the 3 conversions of the current RAW
    if { ($::STS(doBlend)) && ($::STS(doHDR) == 1) } {
      # assume that RAW conversions are done and thus the directories prepared
      set rawName [file rootname [file tail $lastRawPath]]
      if { 0 == [_fuse_one_hdr $rawName $outDir $::g_fuseOpt] }  {
        return  0
      }
    }
    # perform cleanup of the 3 conversions of the current RAW
    _choose_inputs_for_fusing $rawName _inOutExt pathLow pathNorm pathHigh
    set tmpConversions [list $pathLow $pathNorm $pathHigh]
    foreach tmpF $tmpConversions  {
      if { 0 == [ok_delete_file $tmpF] }  {
        ok_err_msg "Aborting because cleanup failed for $descr."
        return  0
      }
    }
    ok_info_msg "Performed cleanup for $descr: {'$pathLow' '$pathNorm' '$pathHigh'}"
  }
  set tclResult [catch { set res [cd $oldWD] } execResult]
  if { $tclResult != 0 } {
    ok_err_msg "Failed restoring work directory to '$oldWD': $execResult!"
    return  0
  }
  return  1
}


# Builds ultimate per-input-dir output-directories' names
# and creates the directories
proc _arrange_dirs_for_current_dir {} {
  set currLeafDirName [file tail [pwd]]
  # directories for RAW conversions - under tmp-dir
  set ::STS(dirNorm) [file join $::STS(tmpDirPath) $currLeafDirName OUT_NORM]
  set ::STS(dirLow)  [file join $::STS(tmpDirPath) $currLeafDirName OUT_LOW ]
  set ::STS(dirHigh) [file join $::STS(tmpDirPath) $currLeafDirName OUT_HIGH]
  set dirList [list $::STS(outDirName) \
                    $::STS(dirNorm) $::STS(dirLow) $::STS(dirHigh)]
  set descrList  {"folder-for-final-HDR-images" "folder-for-normal-images" \
                  "folder-for-darker-images" "folder-for-brighter-images" }
  if { $::STS(doHDR) == 0 }  { ;  # only the ultimate output directory is needed
    set dirList   [list [lindex $dirList 0]]
    set descrList [list [lindex $descrList 0]]
  }
  if { 0 == [ok_create_absdirs_in_list $dirList $descrList] }  {
    return  0
  }
  return  1
}


# TODO  proc _prepare_for_processing_in_current_dir {rawExt \
#                                      rawNamesToWbMults brightValToAbsOutDir} {
#   upvar $rawNamesToWbMults    _rawNamesToWbMults
#   upvar $brightValToAbsOutDir _brightValToAbsOutDir
#   puts "====== Begin RAW conversions in '[pwd]' ========"
#   set rawPaths [glob -nocomplain "*.$rawExt"]
#   if { 0 == [llength $rawPaths] }  {
#     ok_warn_msg "No RAW images (*.$rawExt) found in '[pwd]'"
#     return  0
#   }
#   # if { (0 == [_estimate_free_disk_space_for_raw_conversion $rawPaths    \
#   #                                           [pwd] $::STS(tmpDirPath)])  \
#   #                                           && $::STS(abortOnLowDiskSpace) }  {
#   #   return  -1;   # error already printed
#   # }
#   if { "" == $::STS(wbInpFile) }  { 
#     set _rawNamesToWbMults  [dict create]
#   } else {
#     array unset _rawToWbArr
#     if { [file exists $::STS(wbInpFile)] }  {
#       if { 0 == [ok_read_csv_file_into_array_of_lists _rawToWbArr \
#                               $::STS(wbInpFile) "," 1 _ColorMultLineCheckCB] } {
#         return  -1;  # error already printed
#       }
#     } elseif { 0 == [ok_dirpath_equal $::STS(wbInpFile) $::STS(wbOutFile)] }  {
#       ok_err_msg "Missing WB-override file '$::STS(wbInpFile)'"
#       return  -1
#     } else {
#       ok_info_msg "No WB-override file for directory '[pwd]' - will use camera-WB there"
#     }
#     set _rawNamesToWbMults  [array get _rawToWbArr];   # dict == list
#     ok_trace_msg "Input color multipliers: {$_rawNamesToWbMults}"
#   }
#   if { $::STS(doHDR) == 0 }  { ;  # only the ultimate output directory is needed
#     set _brightValToAbsOutDir [dict create \
#                             1.0 [file join [pwd] $::STS(outDirName)]]
#   } else {                     ;  # per-brightness temporary directories needed
#     set _brightValToAbsOutDir [dict create \
#                             0.3 [file join [pwd] $::STS(dirLow)] \
#                             1.0 [file join [pwd] $::STS(dirNorm)] \
#                             1.7 [file join [pwd] $::STS(dirHigh)]]
#   }
#   # note: source of WB params is picked when converting 1st directory;
#   #       in consequent directories it appears like override,
#   #       but it's just carried out from the 1st directory
# }


# Makes RAW conversions; returns num of processed files, 0 if none, -1 on error.
# If '$::STS(wbInpFile)' keeps a file-path, takes WB multipliers from it.
# If '$::STS(wbOutFile)' keeps a file-path, prints WB multipliers into it.
proc _convert_all_raws_in_current_dir {rawExt} {
  puts "====== Begin RAW conversions in '[pwd]' ========"
  set rawPaths [glob -nocomplain "*.$rawExt"]
  if { 0 == [llength $rawPaths] }  {
    ok_warn_msg "No RAW images (*.$rawExt) found in '[pwd]'"
    return  0
  }
  if { (0 == [_estimate_free_disk_space_for_raw_conversion $rawPaths    \
                                            [pwd] $::STS(tmpDirPath)])  \
                                            && $::STS(abortOnLowDiskSpace) }  {
    return  -1;   # error already printed
  }
  for {set rawIdx 0}  {$rawIdx < [llength $rawPaths]}  {incr rawIdx 1}  {
    if { 0 > [set res [_convert_one_raw_in_current_dir $rawExt $rawIdx]] }  {
      ok_err_msg "Failed RAW conversions in '[pwd]' at index $rawIdx"
      return  $res
    }
  }
  puts "====== Finished RAW conversions in '[pwd]'; [llength $rawPaths] RAWs processed ========"
  return  [llength $rawPaths]
}


proc _convert_one_raw_in_current_dir {rawExt nextRawIndex}  {
  global g_rawNamesToWbMults g_brightValToAbsOutDir
  if { $nextRawIndex == 0 }  {;  # first RAW in the current directory
    if { "" == $::STS(wbInpFile) }  { 
      set g_rawNamesToWbMults  [dict create]
    } else {
      array unset _rawToWbArr
      if { [file exists $::STS(wbInpFile)] }  {
        if { 0 == [ok_read_csv_file_into_array_of_lists _rawToWbArr \
                     $::STS(wbInpFile) "," 1 _ColorMultLineCheckCB] } {
          return  -1;  # error already printed
        }
      } elseif { 0 == [ok_dirpath_equal $::STS(wbInpFile) $::STS(wbOutFile)] }  {
        ok_err_msg "Missing WB-override file '$::STS(wbInpFile)'"
        return  -1
      } else {
        ok_info_msg "No WB-override file for directory '[pwd]' - will use camera-WB there"
      }
      set g_rawNamesToWbMults  [array get _rawToWbArr];   # dict == list
      ok_trace_msg "Input color multipliers: {$g_rawNamesToWbMults}"
    }

    # decide on output directory(ies) based on whether HDR requested
    if { $::STS(doHDR) == 0 }  { ; # only the ultimate output directory needed
      set g_brightValToAbsOutDir [dict create \
                                  1.0 [file join [pwd] $::STS(outDirName)]]
    } else {                     ; # per-brightness temporary directories needed
      set g_brightValToAbsOutDir [dict create \
                                  0.3 [file join [pwd] $::STS(dirLow)] \
                                  1.0 [file join [pwd] $::STS(dirNorm)] \
                                  1.7 [file join [pwd] $::STS(dirHigh)]]
    }
  };#_END_OF__current_directory_preparation_at_first_RAW

  # note: source of WB params is picked when converting 1st directory;
  #       in consequent directories it appears like override,
  #       but it's just carried out from the 1st directory
  set rawPaths [glob -nocomplain "*.$rawExt"]; # assune existence already checked
  if { $nextRawIndex < [llength $rawPaths] }  {
    set rawPath [lindex $rawPaths $nextRawIndex]
    ok_info_msg "Processing RAW input \[$nextRawIndex\] - '$rawPath'"
    dict for {brightVal outDir} $g_brightValToAbsOutDir {
      if { 0 == [_convert_one_raw $rawPath $outDir "-b $brightVal" \
                                  ::g_rawNamesToWbMults] } {
        return  -1;  # error already printed
      }
      ##$::_DCRAW  $::g_dcrawParamsMain -w -b 0.3 %%f |$::_IMCONVERT ppm:- %g_convertSaveParams% $::g_dirLow\%%~nf.TIF
      ##if NOT EXIST "$::g_dirLow\%%~nf.TIF" (echo * Missing "$::g_dirLow\%%~nf.TIF". Aborting... & exit /B -1)
      ok_pause_and_reset_start_time_if_needed ;   # allow periodical resting
    }
  }
  ok_trace_msg "Done RAW-conversion stage for RAW input '$rawPath'"
  if { $nextRawIndex == [expr [llength $rawPaths] -1] }  {
    # store WB multipliers of all processed RAWs upon the last RAW in current dir
    if { "" != $::STS(wbOutFile) }  { 
      array unset _rawToWbArr;    array unset _rawToWbArrNew
      #(unsafe)  array set _rawToWbArrNew $g_rawNamesToWbMults
      if { 1 == [ok_list_to_array $g_rawNamesToWbMults _rawToWbArrNew] } {
        set _rawToWbArrNew("RawName") [list "Rmult" "Gmult" "Bmult" "G2mult"]
        if { [file exists $::STS(wbOutFile)] }  {; # merge new data with old data
          if { 0 == [ok_read_csv_file_into_array_of_lists _rawToWbArr \
                       $::STS(wbOutFile) "," 1 _ColorMultLineCheckCB] }  {
            # TODO: print warning and make a copy of the old file
          }
        }
        # merge if old data was read, otherwise preserve old values
        set oldCntWbRec [array size _rawToWbArr];                # incl header
        set addCntWbRec [expr [array size _rawToWbArrNew] - 1];  # -1 for header
        array set _rawToWbArr [array get _rawToWbArrNew]
        #parray _rawToWbArr
        set newCntWbRec [array size _rawToWbArr]
        incr newCntWbRec [expr {($oldCntWbRec > 0)? -2 : -1}]; # maybe 2 headers
        ok_info_msg "Appended $addCntWbRec record(s) to white-balance output file '$::STS(wbOutFile)' for directory '[pwd]'. New count of records: $newCntWbRec";  # -1 for header; -2 when duplicated
        ok_write_array_of_lists_into_csv_file _rawToWbArr $::STS(wbOutFile) \
          "RawName" ",";   # error, if any, printed
      }
    }
  }
  return  0
}


# ######### Enfuse ###########
# Makes HDR fusings; returns num of processed files, 0 if none, -1 on error
proc _fuse_converted_images_in_current_dir {rawExt}  {
  # assume that directories are prepared by RAW-conversion sage
  set rawPaths [glob -nocomplain "*.$rawExt"];  # browse by original names
  if { 0 == [llength $rawPaths] }  {
    ok_warn_msg "No RAW images (*.$rawExt) found in '[pwd]'; required by blend stage"
    return  0
  }
  set outDir [file join [pwd] $::STS(outDirName)];  # abs path for msg clarity

  puts "====== Begin fusing [llength $rawPaths] HDR versions in '[pwd]' ========"
  foreach rawPath $rawPaths {
    set rawName [file rootname [file tail $rawPath]]
    if { 0 == [_fuse_one_hdr $rawName $outDir $::g_fuseOpt] }  {
      return  -1
    }
    ok_pause_and_reset_start_time_if_needed ;   # allow periodical resting
  }
  puts "====== Finished HDR fusing in '[pwd]'; [llength $rawPaths] image(s) processed ========"
  return  [llength $rawPaths]
}


# ============== Subroutines =======================

# Converts RAW 'rawPath'; output image placed into 'outDir'.
# If 'rawNameToRgbMultList' dict given and includes name of 'rawPath',
#     uses RGB multipliers from this dict
# If 'rawNameToRgbMultList' dict given but doesn't include name of 'rawPath',
#     inserts RGB multipliers from the RAW into this dict
# TODO: return 1 if converted, 0 if skipped, -1 on error
proc _convert_one_raw {rawPath outDir dcrawParamsAdd {rawNameToRgbMultList 0}} {
  upvar $rawNameToRgbMultList rawNameToRgb
  if { $::STS(doPreview) == 0 }  {
    set _dcrawParamsMain $::g_dcrawParamsMain;        set descr "RAW-conversion"
    set _outExt          $::g_convertOutfileExt
    set _convertSaveParams $::g_convertSaveParams
  } else {
    set _dcrawParamsMain $::g_dcrawParamsMain_preview;  set descr "RAW-preview"
    set _outExt          $::g_convertOutfileExt_preview
    set _convertSaveParams $::g_convertSaveParams_preview
  }
  set rawName [file tail $rawPath]
  if { 0 == [file exists $outDir]  }  {  file mkdir $outDir  }
  set outPath  [file join $outDir "[file rootname $rawName].$_outExt"]
  # provide white-balance multipliers
  if { $rawNameToRgb != 0 }  {
    if { [dict exists $rawNameToRgb $rawName] }  {  # use input RGB
      set rgbMultList [dict get $rawNameToRgb $rawName]
      set rgbInputted 1
    } else {                                        # provide output RGB
      if { [get_image_attributes_by_dcraw $rawPath imgInfoArr] }  {
        set rgbMultList $imgInfoArr($::iMetaRGBG)
        dict set rawNameToRgb $rawName $rgbMultList
      } else {;  # read error - set init values (camera-wb)
        set rgbMultList 0
        set mR ""; set mG ""; set mB "";  set colorSwitches "-w"; #init to cam-wb
      }
      set rgbInputted 0
    }
    if { $rgbMultList != 0 }  { ;   # overriden or read from the RAW
      set mR [lindex $rgbMultList 0];    set mG [lindex $rgbMultList 1];
      set mB [lindex $rgbMultList 2];
      set colorSwitches [expr {($rgbInputted)? "-r $mR $mG $mB $mG" : "-w"}]
    }
  } else {
    set mR ""; set mG ""; set mB "";  set colorSwitches "-w";  # init to cam-wb
    set rgbInputted 0
  }
  set colorInfo [expr {($rgbInputted)? "{$mR $mG $mB}" : "as-shot"}]
  switch -exact $::STS(rotAngle)  {
    -1      { set rotSwitch ""      }
     0      { set rotSwitch "-t 0"  }
    90      { set rotSwitch "-t 6"  }
    180     { set rotSwitch "-t 3"  }
    270     { set rotSwitch "-t 5"  }
    default { set rotSwitch ""      }
  }
  # check whether the output exists AFTER white-balance multipliers taken care of
  if { $::STS(doSkipExisting) && (1 == [file exists $outPath]) }  {
    if { 1 == [check_image_integrity_by_imagemagick $outPath] }  {
      ok_info_msg "Image '$outPath' pre-existed; skipped by RAW conversion step"
      return 1
    }
    ok_info_msg "Invalid/corrupted image '$outPath' pre-existed; will be overriden by RAW conversion step"
  }
  if { 0 == [ok_filepath_is_writable $outPath] }  {
    ok_err_msg "Cannot write into '$outPath'";    return 0
  }
  #ok_info_msg "Start $descr '$rawPath';  colors: $colorInfo; output into '$outPath'..."

  #eval exec $::_DCRAW  $_dcrawParamsMain $dcrawParamsAdd $colorSwitches  $rawPath | $::_IMCONVERT ppm:- $::_convertSaveParams $outPath
  set cmdListRawConv [concat $::_DCRAW  $_dcrawParamsMain $dcrawParamsAdd \
                          $colorSwitches $rotSwitch  $rawPath  \
                          | $::_IMCONVERT ppm:- $_convertSaveParams $outPath]
  ok_info_msg "Start $descr '$rawPath':    $cmdListRawConv"
  if { 0 == [ok_run_loud_os_cmd $cmdListRawConv "_is_dcraw_result_ok"] }  {
    return  0; # error already printed
  }

	ok_info_msg "Done $descr of '$rawPath' into '$outPath'"
  return  1
}


proc _fuse_one_hdr {rawName outDir fuseOpt} {
  _choose_inputs_for_fusing $rawName _inOutExt pathLow pathNorm pathHigh
  set _fuseSaveParams [expr {($::STS(doPreview) == 0)? \
                           $::g_fuseSaveParams  :  $::g_fuseSaveParams_preview}]
  if { 0 == [file exists $outDir]  }  {  file mkdir $outDir  }
  set outPath  [file join $outDir "$rawName.$_inOutExt"]
  if { $::STS(doSkipExisting) && (1 == [file exists $outPath]) }  {
    if { 1 == [check_image_integrity_by_imagemagick $outPath] }  {
      ok_info_msg "Image '$outPath' pre-existed; skipped by fusion step"
      return 1
    }
    ok_info_msg "Invalid/corrupted image '$outPath' pre-existed; will be overriden by fusion step"
  }
  if { 0 == [ok_filepath_is_writable $outPath] }  {
    ok_err_msg "Cannot write into '$outPath'";    return 0
  }
  set inPathLow  [file join $::STS(dirLow)  "$rawName.$_inOutExt"]
  set inPathNorm [file join $::STS(dirNorm) "$rawName.$_inOutExt"]
  set inPathHigh [file join $::STS(dirHigh) "$rawName.$_inOutExt"]
  foreach p [list $inPathLow $inPathNorm $inPathHigh]  {
    if { ![ok_filepath_is_readable $p] || \
         (0 == [check_image_integrity_by_imagemagick $p]) }  {
      ok_err_msg "Inexistent, unreadable or corrupted intermediate image '$p'"
      return 0
    }
  }
  set cmdListFuse [concat $::_ENFUSE  $fuseOpt  --depth=$::STS(finalDepth) \
                          $_fuseSaveParams "--output=$outPath"  \
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


proc _choose_inputs_for_fusing {rawName inOutExt pathLow pathNorm pathHigh} {
  upvar $inOutExt _inOutExt
  upvar $pathLow  inPathLow
  upvar $pathNorm inPathNorm
  upvar $pathHigh inPathHigh
  if { $::STS(doPreview) == 0 }  {
    set _inOutExt          $::g_convertOutfileExt
  } else {
    set _inOutExt          $::g_convertOutfileExt_preview
  }
  set inPathLow  [file join $::STS(dirLow)  "$rawName.$_inOutExt"]
  set inPathNorm [file join $::STS(dirNorm) "$rawName.$_inOutExt"]
  set inPathHigh [file join $::STS(dirHigh) "$rawName.$_inOutExt"]
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
    set errKeys [list {Improper} {No such file} {no such file} {missing} {unable} {unrecognized} {Non-numeric}]
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
proc _raw_to_hdr_set_ext_tool_paths_from_csv {csvPath}  {
  unset -nocomplain ::_IMCONVERT ::_IMIDENTIFY ::_IMMONTAGE ::_DCRAW ::_EXIFTOOL
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
  set ::_IMIDENTIFY [format "{%s}"  [file join $::_IM_DIR "identify.exe"]]
  # - DCRAW:
  # unless ::_DCRAW_PATH points to some custom executable, point at the default
  if { (![info exists ::_DCRAW_PATH]) || (""== [string trim $::_DCRAW_PATH]) } {
    set ::_DCRAW    [format "{%s}"  [file join $::_IM_DIR "dcraw.exe"]]
  } else {
    ok_info_msg "Custom dcraw path specified by '$csvPath'"
    set ::_DCRAW    [format "{%s}"  $::_DCRAW_PATH]
  }
  # - ENFUSE
  set ::_ENFUSE     [format "{%s}"  [file join $::_ENFUSE_DIR "enfuse.exe"]]
  return  1
}


# proc _OLD__raw_to_hdr_verify_external_tools {} {
#   set errCnt 0
#   if { 0 == [file isdirectory $::_IM_DIR] }  {
#     ok_err_msg "Inexistent or invalid Imagemagick directory '$::_IM_DIR'"
#     incr errCnt 1
#   }
#   if { 0 == [file exists [string trim $::_IMCONVERT " {}"]] }  {
#     ok_err_msg "Inexistent ImageMagick 'convert' tool '$::_IMCONVERT'"
#     incr errCnt 1
#   }
#   if { 0 == [file exists [string trim $::_IMMOGRIFY " {}"]] }  {
#     ok_err_msg "Inexistent ImageMagick 'mogrify' tool '$::_IMMOGRIFY'"
#     incr errCnt 1
#   }
#   if { 0 == [file exists [string trim $::_IMIDENTIFY " {}"]] }  {
#     ok_err_msg "Inexistent ImageMagick 'identify' tool '$::_IMIDENTIFY'"
#     incr errCnt 1
#   }
#   if { 0 == [file exists [string trim $::_DCRAW " {}"]] }  {
#     ok_err_msg "Inexistent 'dcraw' tool '$::_DCRAW'"
#     incr errCnt 1
#   }
#   if { 0 == [file exists [string trim $::_ENFUSE " {}"]] }  {
#     ok_err_msg "Inexistent 'enfuse' tool '$::_ENFUSE'"
#     incr errCnt 1
#   }
#   if { $errCnt == 0 }  {
#     ok_info_msg "All external tools are present"
#     return  1
#   } else {
#     ok_err_msg "Some or all external tools are missing"
#     return  0
#   }
# }


proc _raw_to_hdr_verify_external_tools {} {
  set errCnt 0
  if { 0 == [file isdirectory $::_IM_DIR] }  {
    ok_err_msg "Inexistent or invalid Imagemagick directory '$::_IM_DIR'"
    incr errCnt 1
  }
  set pathToDescr [dict create  \
    ::_IMCONVERT   [list $::_IMCONVERT  "ImageMagick 'convert' tool"]  \
    ::_IMMOGRIFY   [list $::_IMMOGRIFY  "ImageMagick 'mogrify' tool"]  \
    ::_IMIDENTIFY  [list $::_IMIDENTIFY "ImageMagick 'identify' tool"] \
    ::_DCRAW       [list $::_DCRAW      "'dcraw' tool"]                \
    ::_ENFUSE      [list $::_ENFUSE     "'enfuse' tool"]               \
                  ]

  dict for {varName rec} $pathToDescr  {
    lassign $rec  toolPath toolDescr
    set tp [string trim $toolPath " {}"]
    if { 0 == [file exists $tp] }  {
      set tpNoExt [file rootname $tp]
      if { 0 == [file exists $tpNoExt] }  {
        ok_err_msg "Inexistent $toolDescr ($varName) '$toolPath' (neither '$tpNoExt')"
        incr errCnt 1
      } else {
        ok_info_msg "Overriden $toolDescr ($varName): from '$toolPath' into '$tpNoExt'"
        set $varName $tpNoExt
      }
    } else {
      ok_info_msg "Verified $toolDescr ($varName): as '$toolPath'"
    }
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


# Returns 1 if there's enough disk-space under 'outDirPath' and 'tmpDirPath'
# to convert 'rawPaths'
# Otherwise returns 0.
proc _estimate_free_disk_space_for_raw_conversion {rawPaths \
                                                   outDirPath tmpDirPath} {
  set _DISK_USAGE_FACTOR_TMP 20; # temporary files measured to take ~20x of RAWs
  set _DISK_USAGE_FACTOR_OUT 3.5; # output files measured to take ~3.5x of RAWs
  if { 0 > [set rawKb [ok_get_filelist_disk_space_kb $rawPaths 1]] }  {
    return  0;  # cannot measure usage; assume not-enough; error already printed
  }
  if { 0 > [set availOutKb [ok_try_get_free_disk_space_kb $outDirPath]] }  {
    return  0;  # cannot measure free; assume not-enough; error already printed
  }
  if { 0 > [set availTmpKb [ok_try_get_free_disk_space_kb $tmpDirPath]] }  {
    return  0;  # cannot measure free; assume not-enough; error already printed
  }
  set outDirList [list $::STS(outDirName)]
  set tmpDirList [list $::STS(dirNorm) $::STS(dirLow) $::STS(dirHigh)]
  set existOutKb [ok_dir_list_size $outDirList];  # outputs that may preexist
  set existTmpKb [ok_dir_list_size $tmpDirList];  # tmp-s that may preexist
  set reqOutKb [expr {($rawKb * $_DISK_USAGE_FACTOR_OUT) - $existOutKb}]
  set reqTmpKb [expr {($rawKb * $_DISK_USAGE_FACTOR_TMP) - $existTmpKb}]
  set msg "";  # as if enough space
  if { $availOutKb < $reqOutKb }  {
    set msg "~$reqOutKb Kb of free disk space under '$outDirPath' (only $availOutKb Kb available)"
  }
  if { $availTmpKb < $reqTmpKb }  {
    append msg "~$reqTmpKb Kb of free disk space under '$tmpDirPath' (only $availTmpKb Kb available)"
  }
  if { $msg != "" } {
    ok_err_msg  "Converting [llength $rawPaths] RAW(s) requires: $msg"
    return  0
    #~ if { $::STS(doSkipExisting) == 0 }   {
      #~ ok_err_msg  $msg;      return  0
    #~ } else {
      #~ ok_warn_msg "$msg. Allowed to continue due to repair mode - some files already exist"
      #~ return  1
    #~ }
  }
  ok_info_msg "Converting [llength $rawPaths] RAW(s) requires ~$reqOutKb Kb of free disk space under '$outDirPath'; $availOutKb Kb available - should be enough"
  ok_info_msg "Converting [llength $rawPaths] RAW(s) requires ~$reqTmpKb Kb of free disk space under '$tmpDirPath'; $availTmpKb Kb available - should be enough"
  return  1
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
