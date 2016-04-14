# main_settings_copier.tcl


set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR  "ok_utils" "debug_utils.tcl"]
ok_trace_msg "---- Sourcing '[info script]' in '$SCRIPT_DIR' ----"
source [file join $SCRIPT_DIR   "ext_tools.tcl"]
source [file join $SCRIPT_DIR   "image_metadata.tcl"]
source [file join $SCRIPT_DIR   "dir_file_utils.tcl"]
source [file join $SCRIPT_DIR   "stereopair_naming.tcl"]

source [file join $SCRIPT_DIR   "cnv_settings_finder.tcl"]

package require ok_utils
namespace import -force ::ok_utils::*


###################### Global variables ############################
#DO NOT: array unset STS ;   # array for global settings; unset once per project

# TODO: extract a common part from _settings_copier_set_defaults() for the whole project
proc _settings_copier_set_defaults {}  {
  set ::STS(origImgRootPath)  ""
  set ::STS(globalImgSettingsDir)  "" ;  # global settings dir; relevant for some converters
  set ::STS(origImgDirLeft)   ""
  set ::STS(origImgDirRight)  ""
  set ::STS(outDirPath)       ""
  set ::STS(backupDir)        ""
  set ::STS(copyFromLR)       "" ;  # "left" == copy settings from left to right, "right" == from right to left
  set ::STS(doSimulateOnly)   0
  
  set ORIG_EXT_DICT   0 ;  # per-dir extensions of original out-of-camera images
}
################################################################################
_settings_copier_set_defaults ;  # load only;  do call it in a function for repeated invocations
################################################################################

set ORIG_EXT_DICT    0 ;  # per-dir extensions of original out-of-camera images

################################################################################

proc settings_copier_main {cmdLineAsStr}  {
  global STS SCRIPT_DIR ORIG_EXT_DICT
  _settings_copier_set_defaults ;  # calling it in a function for repeated invocations
  if { 0 == [settings_copier_cmd_line $cmdLineAsStr cml] }  {
    return  0;  # error or help already printed
  }
  # choose type of originals; RAW is required
  if { 0 == [set ORIG_EXT_DICT [dualcam_choose_and_check_type_of_originals \
                     $STS(origImgDirLeft) $STS(origImgDirRight) 1]] }  {
    return  0;  # error already printed
  }

  if { 0 == [_settings_copier_arrange_workarea] }  { return  0  };  # error already printed
  
  # source dir has RAWs and maybe settings files
  if { $STS(copyFromLR) == "left" } {
    set srcDir $STS(origImgDirLeft);  set dstDir $STS(origImgDirRight) 
  } else {
    set srcDir $STS(origImgDirRight); set dstDir $STS(origImgDirLeft)  }
  if { $STS(globalImgSettingsDir) != "" } {
    set dstDir $STS(globalImgSettingsDir)
  }

  set srcSettingsFiles [FindSettingsFilesForRawsInDir $srcDir cntMissing 1]
  if { 0 == [llength $srcSettingsFiles] } { return  0 };  # error printed
  # replicate and replace image name(s) inside
  if { 0 == [_clone_settings_files $srcSettingsFiles $dstDir \ 
                                   $::STS(doSimulateOnly)] } {
    return  0;  # error printed
  }
  return  1
}


proc settings_copier_cmd_line {cmdLineAsStr cmlArrName}  {
  upvar $cmlArrName      cml
  # create the command-line description
  set descrList \
[list \
  -help {"" "print help"} \
  -global_img_settings_dir {val	"full path of the directory where the RAW converter keeps all image-settings files - specify if relevant for your converter"} \
  -orig_img_dir {val	"input directory; left (right) out-of-camera images expected in 'orig_img_dir'/L ('orig_img_dir'/R)"} \
  -out_dir {val	"output directory"} \
  -backup_dir {val	"directory to move overriden settings files to"} \
  -copy_from {val	"'left' == copy settings from left to right, 'right' == from right to left"} \
  -simulate_only {""	"if specified, no file changes performed, only decide and report what should be done"} ]
  array unset cmlD
  ok_new_cmd_line_descr cmlD $descrList
  # create dummy command line with the default parameters and copy it
  # (if an argument inexistent by default, don't provide dummy value)
  array unset defCml
  ok_set_cmd_line_params defCml cmlD { \
   {-backup_dir "Backup"} }
  ok_copy_array defCml cml;    # to preset default parameters
  # now parse the user's command line
  if { 0 == [ok_read_cmd_line $cmdLineAsStr cml cmlD] } {
    ok_err_msg "Aborted because of invalid command line";	return  0
  }
  if { [info exists cml(-help)] } {
    set cmdHelp [ok_help_on_cmd_line defCml cmlD "\n"]
    ok_info_msg "================================================================"
    ok_info_msg "    DualCam Settings Copier replicates image-conversion settings from  left- to right images of each matched stereopair, or vice-versa."
    ok_info_msg "========= Command line parameters (in any order): =============="
    ok_info_msg $cmdHelp
    ok_info_msg "================================================================"
    ok_info_msg "========= Example (note TCL-style directory separators): ======="
    ok_info_msg " settings_copier_main \"-orig_img_dir . -out_dir ./OUT -copy_from left\""
    ok_info_msg "================================================================"
    return  0
  }
  if { 0 == [_settings_copier_parse_cmdline cml] }  {
    ok_err_msg "Error(s) in command parameters. Aborting..."
    return  0
  }
  set cmdStrNoHelp [ok_cmd_line_str cml cmlD "\n" 0]
  ok_info_msg "==== Now TODO by the following spec: ===="
  ok_info_msg $cmdStrNoHelp
  return  1
}


proc _settings_copier_parse_cmdline {cmlArrName}  {
  upvar $cmlArrName      cml
  set errCnt 0
  
  if { 1 == [info exists cml(-global_img_settings_dir)] }  {
    if { 0 == [file isdirectory $cml(-global_img_settings_dir)] }  {
      ok_err_msg "Non-directory '$cml(-global_img_settings_dir)' specified as the global image-settings directory"
      incr errCnt 1
    } else {
      set ::STS(globalImgSettingsDir) $cml(-global_img_settings_dir)
    }
  }  
  if { 0 == [info exists cml(-orig_img_dir)] }  {
    ok_err_msg "Please specify input directory; example: -orig_img_dir D:/Photo/Work"
    incr errCnt 1
  } elseif { 0 == [file isdirectory $cml(-orig_img_dir)] }  {
    ok_err_msg "Non-directory '$cml(-orig_img_dir)' specified as input directory"
    incr errCnt 1
  } else {
    set ::STS(origImgRootPath) $cml(-orig_img_dir)
    set ::STS(origImgDirLeft)  [file join $::STS(origImgRootPath) "L"]
    set ::STS(origImgDirRight) [file join $::STS(origImgRootPath) "R"]
    if { 0 == [file isdirectory $::STS(origImgDirLeft)] }  {
      ok_err_msg "Non-directory '$::STS(origImgDirLeft)' specified as left input directory"
      incr errCnt 1
    }
    if { 0 == [file isdirectory $::STS(origImgDirRight)] }  {
      ok_err_msg "Non-directory '$::STS(origImgDirRight)' specified as right input directory"
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
  if { 1 == [info exists cml(-backup_dir)] }  {
    set ::STS(backupDir) $cml(-backup_dir)
  }
 if { 1 == [info exists cml(-copy_from)] }  {
    switch -nocase -- [string tolower $cml(-copy_from)]  {
      "left"   {  set ::STS(copyFromLR) "left"   }
      "right"  {  set ::STS(copyFromLR) "right"  }
      default  {
        ok_err_msg "-copy_from expects left|right"
        incr errCnt 1
      }
    }    
  } else {
    ok_err_msg "Please specify from which side to take the conversion settings; example: -copy_from left"
    incr errCnt 1
  } 
  if { 1 == [info exists cml(-simulate_only)] }  {
    set ::STS(doSimulateOnly) 1
  }
  if { $errCnt > 0 }  {
    #ok_err_msg "Error(s) in command parameters!"
    return  0
  }
  #ok_info_msg "Command parameters are valid"
  return  1
}



# Puts into 'origPathsLeftVar' and 'origPathsRightVar' the paths of:
#   - original images if 'searchHidden'==0
#   - hidden original images if 'searchHidden'==1
proc _settings_copier_find_originals {searchHidden \
                                      origPathsLeftVar origPathsRightVar}  {
  global STS ORIG_EXT_DICT
  upvar $origPathsLeftVar  origPathsLeft
  upvar $origPathsRightVar origPathsRight
  return  [dualcam_find_originals $searchHidden $ORIG_EXT_DICT \
            $STS(origImgDirLeft) $STS(origImgDirRight) "dummy-dirForUnmatched" \
            origPathsLeft origPathsRight]
}


# Replicates and replaces image name(s) inside
proc _clone_settings_files {srcSettingsFiles dstDir doSimulateOnly}  {
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
  foreach pt $pathList {
    set dstPurename [spm_purename_to_peer_purename [AnyFileNameToPurename $pt]]
    set dstPath [file join $destDir $dstPurename]]
    if { 0 == [_clone_one_cnv_settings_file $pt $dstPurename $destDir \
                                            $doSimulateOnly] }  {
              incr cntErr 1;  # error already printed
    } else {  incr cntGood 1  }
  }
  set cntDone [expr [llength $pathList] - $cntErr]
  ok_info_msg "Cloned settings file(s) for $cntDone RAWs out of [llength $pathList] into directory '$destDir'; $cntErr error(s) occured"
  return  [expr { ($cntErr == 0)? $cntGood : [expr -1 * $cntErr] }]
}


proc _clone_one_cnv_settings_file {srcPath dstPurename dstDir doSimulateOnly}  {
  if { "" == [set stStr [ReadSettingsFile $srcPath]] }   {
    return  0;  # error already printed
  }
  set srcPurename [AnyFileNameToPurename $srcPath]
  set stStr [string map $srcPurename $dstPurename $stStr]
  set ext [file extension $srcPath]
  set dstPath [file join $dstDir "$dstPurename$ext"]
  if { $doSimulateOnly }  {
    ok_info_msg "Would have cloned conversion settings from '$srcPath' into '$dstPath'"
    return  1
  }
  if { 0 == [WriteSettingsFile $stStr $dstPath] }   {
    return  0;  # error already printed
  }
  ok_info_msg "Cloned conversion settings from '$srcPath' into '$dstPath'"
  return  1
}


proc _settings_copier_arrange_workarea {}  {
  if { 0 == [ok_create_absdirs_in_list \
              [list $::STS(outDirPath) $::STS(backupDir)] \
              [list "output"           "backup"         ]] } {
    return  0;  # error already printed
  }
  return  1
}
