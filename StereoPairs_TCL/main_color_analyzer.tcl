# main_color_analyzer.tcl


set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR  "ok_utils" "debug_utils.tcl"]
ok_trace_msg "---- Sourcing '[info script]' in '$SCRIPT_DIR' ----"
source [file join $SCRIPT_DIR   "ext_tools.tcl"]
source [file join $SCRIPT_DIR   "dir_file_utils.tcl"]
source [file join $SCRIPT_DIR   "stereopair_naming.tcl"]


package require ok_utils;   namespace import -force ::ok_utils::*
package require img_proc;   namespace import -force ::img_proc::*


###################### Global variables ############################
#DO NOT: array unset STS ;   # array for global settings; unset once per project

# TODO: extract a common part from _color_analyzer_set_defaults() for the whole project
proc _color_analyzer_set_defaults {}  {
  set ::STS(stdImgRootPath)   ""
  set ::STS(stdImgDirLeft)    ""
  set ::STS(stdImgDirRight)   ""
  set ::STS(stdImgExtLeft)    "" ;  # filename extension for left  images
  set ::STS(stdImgExtRight)   "" ;  # filename extension for right images
  set ::STS(outDirPath)       ""
  set ::STS(colorDiffThresh)  "" ;  # minimal L-R color difference to warn on
  
  set IMG_EXT_DICT   0 ;  # per-dir extensions of standard images
}
################################################################################
_color_analyzer_set_defaults ;  # load only;  do call it in a function for repeated invocations
################################################################################

set IMG_EXT_DICT    0 ;  # per-dir extensions of original out-of-camera images

################################################################################

proc color_analyzer_main {cmdLineAsStr}  {
  global STS SCRIPT_DIR IMG_EXT_DICT
  _color_analyzer_set_defaults ;  # calling it in a function for repeated invocations
  if { 0 == [color_analyzer_cmd_line $cmdLineAsStr cml] }  {
    return  0;  # error or help already printed
  }
  # type of standard images dictated by extensions from cmd line
  set IMG_EXT_DICT [dict create L $STS(stdImgExtLeft) R $STS(stdImgExtRight)]

  if { 0 == [_color_analyzer_find_lr_images imgPathsLeft imgPathsRight] } {
    return  0;  # error already printed
  }

  if { 0 == [_color_analyzer_arrange_workarea] }  { return  0  };  # error already printed

  if { 0 == [set pairNameToLRPathsDict \
      [_map_pairname_to_lrpaths $imgPathsLeft $imgPathsRight]] } {
    return  0;  # error already printed
  }
  puts $pairNameToLRPathsDict

  # TODO
  return  1
}


proc color_analyzer_cmd_line {cmdLineAsStr cmlArrName}  {
  upvar $cmlArrName      cml
  # create the command-line description
  set descrList \
[list \
  -help {"" "print help"} \
  -img_dir {val	"input directory; left (right) images to be checked expected in 'img_dir'/L ('img_dir'/R)"} \
  -ext_left {val	"file extension of left images; standard type only (tif/jpg/etc.)"} \
  -ext_right {val	"file extension of right images; standard type only (tif/jpg/etc.)"} \
  -out_dir {val	"output directory"} \
  -warn_color_diff_above {val "minimal left-right color difference (%) to warn on"} ]
  array unset cmlD
  ok_new_cmd_line_descr cmlD $descrList
  # create dummy command line with the default parameters and copy it
  # (if an argument inexistent by default, don't provide dummy value)
  array unset defCml
  ok_set_cmd_line_params defCml cmlD { \
   {-warn_color_diff_above "10"} }
  ok_copy_array defCml cml;    # to preset default parameters
  # now parse the user's command line
  if { 0 == [ok_read_cmd_line $cmdLineAsStr cml cmlD] } {
    ok_err_msg "Aborted because of invalid command line";	return  0
  }
  if { [info exists cml(-help)] } {
    set cmdHelp [ok_help_on_cmd_line defCml cmlD "\n"]
    ok_info_msg "================================================================"
    ok_info_msg "    DualCam Color Analyzer compares color-channels' statistics of left- and right images of each matched stereopair."
    ok_info_msg "========= Command line parameters (in any order): =============="
    ok_info_msg $cmdHelp
    ok_info_msg "================================================================"
    ok_info_msg "========= Example (note TCL-style directory separators): ======="
    ok_info_msg " color_analyzer_main \"-img_dir . -out_dir ./OUT -ext_left jpg -ext_right jpg -warn_color_diff_above 15\""
    ok_info_msg "================================================================"
    return  0
  }
  if { 0 == [_color_analyzer_parse_cmdline cml] }  {
    ok_err_msg "Error(s) in command parameters. Aborting..."
    return  0
  }
  set cmdStrNoHelp [ok_cmd_line_str cml cmlD "\n" 0]
  ok_info_msg "==== Now compare stereopairs' color-channel statistics by the following spec: ===="
  ok_info_msg "==== \n$cmdStrNoHelp\n===="
  return  1
}


proc _color_analyzer_parse_cmdline {cmlArrName}  {
  upvar $cmlArrName      cml
  set errCnt 0

##   set ::STS(stdImgRootPath)   ""
 #   set ::STS(stdImgDirLeft)    ""
 #   set ::STS(stdImgDirRight)   ""
 #   set ::STS(stdImgExtLeft)    "" ;  # filename extension for left  images
 #   set ::STS(stdImgExtRight)   "" ;  # filename extension for right images
 #   set ::STS(outDirPath)       ""
 #   set ::STS(colorDiffThresh)  "" ;  # minimal L-R color difference to warn on
 ##
##   -img_dir {val	"input directory; left (right) images to be checked expected in 'img_dir'/L ('img_dir'/R)"} \
 #   -ext_left {val	"file extension of left images; standard type only (tif/jpg/etc.)"} \
 #   -ext_right {val	"file extension of right images; standard type only (tif/jpg/etc.)"} \
 #   -out_dir {val	"output directory"} \
 #   -warn_color_diff_above {val "minimal left-right color difference (%) to warn on"} ]
 ##

  if { 0 == [info exists cml(-img_dir)] }  {
    ok_err_msg "Please specify input root directory; example: -img_dir D:/Photo/Work"
    incr errCnt 1
  } elseif { 0 == [file isdirectory $cml(-img_dir)] }  {
    ok_err_msg "Non-directory '$cml(-img_dir)' specified as input root directory"
    incr errCnt 1
  } else {
    set ::STS(stdImgRootPath) $cml(-img_dir)
    set ::STS(stdImgDirLeft)  [file join $::STS(stdImgRootPath) "L"]
    set ::STS(stdImgDirRight) [file join $::STS(stdImgRootPath) "R"]
    if { 0 == [file isdirectory $::STS(stdImgDirLeft)] }  {
      ok_err_msg "Non-directory '$::STS(stdImgDirLeft)' specified as left input directory"
      incr errCnt 1
    }
    if { 0 == [file isdirectory $::STS(stdImgDirRight)] }  {
      ok_err_msg "Non-directory '$::STS(stdImgDirRight)' specified as right input directory"
      incr errCnt 1
    }
  }
  if { 0 == [info exists cml(-out_dir)] }  {
    ok_err_msg "Please specify output directory; example: -out_dir D:/Photo/Work"
    incr errCnt 1
  } elseif { (1 == [file exists $cml(-out_dir)]) && \
             (0 == [file isdirectory $cml(-out_dir)]) }  {
    ok_err_msg "Non-directory '$cml(-out_dir)' specified as output directory"
    incr errCnt 1
  } else {
    set ::STS(outDirPath)      [file normalize $cml(-out_dir)]
    # validity of pair-list path will be checked after out-dir creation
  }
 if { 1 == [info exists cml(-ext_left)] }  {
    set ::STS(stdImgExtLeft) $cml(-ext_left)
  } else {
    ok_err_msg "Please specify extension for left images; example: -ext_left TIF"
    incr errCnt 1
  } 
 if { 1 == [info exists cml(-ext_right)] }  {
    set ::STS(stdImgExtRight) $cml(-ext_right)
  } else {
    ok_err_msg "Please specify extension for right images; example: -ext_right TIF"
    incr errCnt 1
  } 
  if { 1 == [info exists cml(-warn_color_diff_above)] }  {
    set ::STS(colorDiffThresh) $cml(-warn_color_diff_above)
  }
  if { $errCnt > 0 }  {
    #ok_err_msg "Error(s) in command parameters!"
    return  0
  }
  #ok_info_msg "Command parameters are valid"
  return  1
}



# Puts into 'imgPathsLeftVar' and 'imgPathsRightVar' the paths of
# standard l/r images
proc _color_analyzer_find_lr_images {imgPathsLeftVar imgPathsRightVar}  {
  global STS IMG_EXT_DICT
  upvar $imgPathsLeftVar  imgPathsLeft
  upvar $imgPathsRightVar imgPathsRight
  return  [dualcam_find_lr_images $IMG_EXT_DICT \
            $STS(stdImgDirLeft) $STS(stdImgDirRight) imgPathsLeft imgPathsRight]
}


# Replicates and replaces image name(s) inside
proc _clone_settings_files {srcSettingsFiles destDir doSimulateOnly}  {
  global STS
  if { ![file exists $destDir] } {
    ok_err_msg "Inexistent destination directory for settings files '$destDir'"
    return  -1
  }
  if { ![file isdirectory $destDir] } {
    ok_err_msg "Non-directory '$destDir' specified as destination directory for settings files"
    return  -1
  }
  set cntGood 0;  set cntErr 0
  foreach pt $srcSettingsFiles {
    set nameOnly [file tail $pt]
    # settings-file purename examples: "dsc0001-2100_l", "dsc0001-2100_l.arw"
    # do handle optional RAW extension in settings file name for some converters
    set settingsPurename [file rootname $nameOnly];# qqq_l.arw.xmp -> qqq_l.arw
    set srcPurename [AnyFileNameToPurename $nameOnly];# qqq_l.arw.xmp -> qqq_l
    set dstPurename [spm_purename_to_peer_purename $srcPurename]
    if { [string length $settingsPurename] > [string length $srcPurename] }  {
      set suffixStart [string length $srcPurename]
      set suffix [string range $settingsPurename $suffixStart end]
      set dstPurename [format "%s%s" $dstPurename $suffix]
    }
    set dstPath [file join $destDir $dstPurename]]
    if { 0 == [_clone_one_cnv_settings_file $pt $dstPurename $destDir \
                                            $doSimulateOnly] }  {
              incr cntErr 1;  # error already printed
    } else {  incr cntGood 1  }
  }
  set cntDone [expr [llength $srcSettingsFiles] - $cntErr]
  if { $cntGood > 0 } {
    ok_info_msg "Cloned settings file(s) for $cntDone RAW(s) out of [llength $srcSettingsFiles] into directory '$destDir'; $cntErr error(s) occured"
  }
  if { $cntErr > 0 } {
    ok_err_msg "Failed to clone settings file(s) for $cntErr RAW(s) out of [llength $srcSettingsFiles] into directory '$destDir'"
  }
  return  [expr { ($cntErr == 0)? $cntGood : [expr -1 * $cntErr] }]
}


proc _clone_one_cnv_settings_file {srcPath dstPurename dstDir doSimulateOnly}  {
  if { "" == [set stStr [ReadSettingsFile $srcPath]] }   {
    return  0;  # error already printed
  }
  set srcPurename [AnyFileNameToPurename [file tail $srcPath]]
  set stStr [string map [list $srcPurename $dstPurename] $stStr]
  set ext [file extension $srcPath]
  set dstPath [file join $dstDir "$dstPurename$ext"]
  if { $::STS(doSimulateOnly) != 0 }  {
    ok_info_msg "Would have cloned conversion settings from '$srcPath' into '$dstPath'"
    return  1
  }
  if { 0 == [WriteSettingsFile $stStr $dstPath] }   {
    return  0;  # error already printed
  }
  ok_info_msg "Cloned conversion settings from '$srcPath' into '$dstPath'"
  return  1
}


proc _color_analyzer_arrange_workarea {}  {
  if { 0 == [ok_create_absdirs_in_list \
              [list $::STS(outDirPath)] \
              [list "output"         ]] } {
    return  0;  # error already printed
  }
  return  1
}


# Returns dictionary {pairname :: {pathLeft pathRight}} ot 0 on error
proc _map_pairname_to_lrpaths {imgPathsLeft imgPathsRight}  {
  set pairNameToLeftPath [dict create]
  set pairNameToRightPath [dict create]
  set errCnt 0
  foreach fPath $imgPathsLeft {
    set purename [AnyFileNameToPurename [file tail $fPath]]
    set pairPurename [spm_purename_to_pair_purename $purename]
    if { $pairPurename == "" }  {
      ok_err_msg "File '$fPath is not a left image";  incr errCnt 1
    }
    dict append pairNameToLeftPath $pairPurename $fPath
  }
  foreach fPath $imgPathsRight {
    set purename [AnyFileNameToPurename [file tail $fPath]]
    set pairPurename [spm_purename_to_pair_purename $purename]
    if { $pairPurename == "" }  {
      ok_err_msg "File '$fPath is not a right image";  incr errCnt 1
    }
    dict append pairNameToRightPath $pairPurename $fPath
  }
  set pairNameToLRPathsDict [dict create]
  ok_trace_msg "Found [dict size $pairNameToLeftPath] left and [dict size $pairNameToRightPath] right images"
  set allPairNames [lsort -unique [concat \
              [dict keys $pairNameToLeftPath] [dict keys $pairNameToRightPath]]]
  foreach pairPurename $allPairNames {
    if { ! [dict exists $pairNameToLeftPath $pairPurename] }  {
      ok_err_msg "Missing left image for '$pairPurename'";  incr errCnt 1
      continue
    }
    if { ! [dict exists $pairNameToRightPath $pairPurename] }  {
      ok_err_msg "Missing right image for '$pairPurename'";  incr errCnt 1
      continue
    }
    dict append pairNameToLRPathsDict $pairPurename [list \
                                [dict get $pairNameToLeftPath  $pairPurename] \
                                [dict get $pairNameToRightPath $pairPurename]]
  }
  set msg "Correlated paths of left/right images for [dict size $pairNameToLRPathsDict] stereopair(s); $errCnt error(s) occured"
  if { $errCnt == 0 }  {  ok_info_msg $msg;   return  $pairNameToLRPathsDict
  } else {                ok_err_msg  $msg;   return  0 }
}
