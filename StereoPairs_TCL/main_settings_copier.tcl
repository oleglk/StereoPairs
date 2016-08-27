# main_settings_copier.tcl


set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR  "ok_utils" "debug_utils.tcl"]
ok_trace_msg "---- Sourcing '[info script]' in '$SCRIPT_DIR' ----"
source [file join $SCRIPT_DIR   "ext_tools.tcl"]
source [file join $SCRIPT_DIR   "dir_file_utils.tcl"]
source [file join $SCRIPT_DIR   "stereopair_naming.tcl"]
source [file join $SCRIPT_DIR   "cnv_settings_finder.tcl"]

package require ok_utils
namespace import -force ::ok_utils::*


###################### Global variables ############################
set _LAST_BU_DIR_FOR_SETTINGS "" ; # copy-settings action deals with single dir
#DO NOT: array unset STS ;   # array for global settings; unset once per project
################################################################################


# TODO: extract a common part from _settings_copier_set_defaults() for the whole project
proc _settings_copier_set_defaults {}  {
  set ::STS(workAreaRootPath) "" ;  # we may deduce common root for all dir-s
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
  global STS SCRIPT_DIR ORIG_EXT_DICT _LAST_BU_DIR_FOR_SETTINGS
  _settings_copier_set_defaults ;  # calling it in a function for repeated invocations
  set _LAST_BU_DIR_FOR_SETTINGS ""; # to be defined by 1st backup action
  if { 0 == [settings_copier_cmd_line $cmdLineAsStr cml] }  {
    return  0;  # error or help already printed
  }
  # choose type of originals; RAW is not required
  if { 0 == [set ORIG_EXT_DICT [dualcam_choose_and_check_type_of_originals \
                     $STS(origImgDirLeft) $STS(origImgDirRight) 0]] }  {
    return  0;  # error already printed
  }
  if { 0 == [_settings_copier_find_originals 0 origPathsLeft origPathsRight] } {
    return  0;  # error already printed
  }

  if { 0 == [_settings_copier_arrange_workarea] }  { return  0  };  # error already printed
  
  # source dir has originals and maybe settings files
  if { $STS(copyFromLR) == "left" } {
    set srcDir $STS(origImgDirLeft);  set dstDir $STS(origImgDirRight)
    set srcOrigPaths $origPathsLeft
  } elseif { $STS(copyFromLR) == "right" } {
    set srcDir $STS(origImgDirRight); set dstDir $STS(origImgDirLeft)
    set srcOrigPaths $origPathsRight
  } else {
    ok_err_msg "Invalid source settings side specified: '$STS(copyFromLR)'"
    return  0
  }
  if { $STS(globalImgSettingsDir) != "" } {
    set dstDir $STS(globalImgSettingsDir)
  }

  # set variables required for maintaining backup/trash directory
  set ::ok_utils::WORK_AREA_ROOT_DIR    "" ;   # OK for this use-case
  set ::ok_utils::BACKUP_ROOT_NAME      $STS(backupDir)
  set ::ok_utils::_LAST_BACKUP_DIR_PATH ""

  set srcSettingsFiles [FindSettingsFilesForListedImages $srcOrigPaths \
                                                         cntMissing 1]
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
  -name_format_left {val "name spec for left images - <prefix>[LeftName]<delimeter>[RightId]<suffix>; example: [LeftName]-[RightId]_left"} \
  -name_format_right {val "name spec for right images - <prefix>[LeftName]<delimeter>[RightId]<suffix>; example: [LeftName]-[RightId]_right"} \
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
    {-name_format_left "[LeftName]-[RightId]_l"} {-name_format_right "[LeftName]-[RightId]_r"} \
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
    ok_info_msg "========= Command line parameters (in random order): =============="
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
  ok_info_msg "==== Now clone image-conversion settings by the following spec: ===="
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
  if { 0 == [set_naming_parameters_from_format_spec_array cml \
                                    "-name_format_left" "-name_format_right"]} {
    incr errCnt 1;  # error already printed
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
  # deduce workarea root from image and backup dir-s; TODO: make utility
  set waDirs [ok_discard_empty_list_elements \
      [list $::STS(origImgRootPath) $::STS(backupDir)]]
  if { "" != [set ::STS(workAreaRootPath) \
                                [ok_find_filepaths_common_prefix $waDirs]] } {
    ok_info_msg "Common work-area root directory is '$::STS(workAreaRootPath)'"
    set ::ok_utils::WORK_AREA_ROOT_DIR $::STS(workAreaRootPath)
  } else {
    ok_info_msg "No common work-area root directory assumed"
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
  return  [dualcam_find_originals $searchHidden 0 $ORIG_EXT_DICT \
            $STS(origImgDirLeft) $STS(origImgDirRight) "dummy-dirForUnmatched" \
            origPathsLeft origPathsRight]
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
      if { $::_LAST_BU_DIR_FOR_SETTINGS == "" } {
        ok_err_msg "Aborted cloning settings since failed to provide a backup directory"
        break
      }
    } else {  incr cntGood 1  }
  }
  set cntDone [expr [llength $srcSettingsFiles] - $cntErr]
  if { $cntGood > 0 } {
    set actDescr [expr {($doSimulateOnly==1)? "Would have cloned" : "Cloned"}]
    ok_info_msg "$actDescr conversion settings file(s) for $cntDone RAW(s) out of [llength $srcSettingsFiles] into directory '$destDir'; $cntErr error(s) occured"
  }
  if { $cntErr > 0 } {
    ok_err_msg "Failed to clone settings file(s) for $cntErr RAW(s) out of [llength $srcSettingsFiles] into directory '$destDir'"
  }
  return  [expr { ($cntErr == 0)? $cntGood : [expr -1 * $cntErr] }]
}


proc _clone_one_cnv_settings_file {srcPath dstPurename dstDir doSimulateOnly}  {
  # even if nothing overriden, provide backup dir - its inexistence considered an error
  # guarantee that all old settings files moved to one backup/thrash dir
  if { $::_LAST_BU_DIR_FOR_SETTINGS == "" }  {
    set ::_LAST_BU_DIR_FOR_SETTINGS [ok_provide_backup_dir \
                                $::PREFS(BACKUP_DIRNAME_KEY__BACKUP_SETTINGS)]
    if { $::_LAST_BU_DIR_FOR_SETTINGS == "" } { return  0 };  # error printed
  }
  if { "" == [set stStr [ReadSettingsFile $srcPath]] }   {
    return  0;  # error already printed
  }
  set srcPurename [AnyFileNameToPurename [file tail $srcPath]]
  set stStr [string map [list $srcPurename $dstPurename] $stStr]
  set ext [file extension $srcPath]
  set dstPath [file join $dstDir "$dstPurename$ext"]
  if { [file exists $dstPath] }  {
    ok_trace_msg "Cloning of settings file '$srcPath' will override '$dstPath'"
  } else {
    ok_trace_msg "Cloning of settings file '$srcPath' will create first version of '$dstPath'"
  }
  if { [file exists $dstPath] }  {
    if { 0 == [ok_move_files_to_backup_dir \
                $::PREFS(BACKUP_DIRNAME_KEY__BACKUP_SETTINGS) [list $dstPath] \
                $::STS(workAreaRootPath) $doSimulateOnly  \
                $::_LAST_BU_DIR_FOR_SETTINGS] } {
      incr cntErr 1;  ok_err_msg "Will not clone settings file '$srcPath'"
      continue
    }
  }
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


proc _settings_copier_arrange_workarea {}  {
  if { 0 == [ok_create_absdirs_in_list \
              [list $::STS(outDirPath) $::STS(backupDir)] \
              [list "output"           "backup"         ]] } {
    return  0;  # error already printed
  }
  return  1
}
