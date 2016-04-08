# main_settings_copier.tcl


set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR  "ok_utils" "debug_utils.tcl"]
ok_trace_msg "---- Sourcing '[info script]' in '$SCRIPT_DIR' ----"
source [file join $SCRIPT_DIR   "ext_tools.tcl"]
source [file join $SCRIPT_DIR   "image_metadata.tcl"]
source [file join $SCRIPT_DIR   "dir_file_utils.tcl"]

source [file join $SCRIPT_DIR   "cnv_settings_finder.tcl"]

package require ok_utils
namespace import -force ::ok_utils::*


###################### Global variables ############################
array unset STS ;   # array for global settings ;  TODO: call once per a project

# TODO: extract a common part from _set_defaults() for the whole project
proc _set_defaults {}  {
  set ::STS(origImgRootPath)  ""
  set ::STS(globalImgSettingsDir)  ""
  set ::STS(origImgDirLeft)   ""
  set ::STS(origImgDirRight)  ""
  set ::STS(outDirPath)       ""
  set ::STS(backupDir)        ""
  set ::STS(copyFromLR)       "" ;  # "left" == copy settings from left to right, "right" == from right to left
  set ::STS(doSimulateOnly)   0
  
  set ORIG_EXT_DICT    0 
}
################################################################################
_set_defaults ;  # load only;  do call it in a function for repeated invocations
################################################################################

set ORIG_EXT_DICT    0 ;  # per-dir extensions of original out-of-camera images

################################################################################

proc settings_copier_main {cmdLineAsStr}  {
  global STS SCRIPT_DIR ORIG_EXT_DICT
  _set_defaults ;  # calling it in a function for repeated invocations
  if { 0 == [settings_copier_cmd_line $cmdLineAsStr cml] }  {
    return  0;  # error or help already printed
  }

  if { 0 == [_settings_copier_find_originals 0 origPathsLeft origPathsRight] } {
    return  0;  # error already printed
  }
  if { 0 == [_arrange_workarea] }  { return  0  };  # error already printed
  
  # TODO: find source settings for originals' names, replicate and replace image name(s) inside

  if { $::STS(doRenameLR) == 1 }  {
    if { 0 == $::STS(doSimulateOnly) }  {
      if { 0 != [_rename_images_by_rename_dict $renameDict] }  {
        return  0;  # error already printed
      }
      if { 0 != [_hide_unmatched_images_by_rename_dict \
                      [concat $origPathsLeft $origPathsRight] $renameDict] }  {
        return  0;  # error already printed
      }
    } else {
      ok_warn_msg "Simulation-only mode; no file changes made"
    }
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
  if { 0 == [_parse_cmdline cml] }  {
    ok_err_msg "Error(s) in command parameters. Aborting..."
    return  0
  }
  set cmdStrNoHelp [ok_cmd_line_str cml cmlD "\n" 0]
  ok_info_msg "==== Now TODO by the following spec: ===="
  ok_info_msg $cmdStrNoHelp
  return  1
}


proc _parse_cmdline {cmlArrName}  {
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
              $STS(origImgDirLeft) $STS(origImgDirRight) $STS(dirForUnmatched) \
              origPathsLeft origPathsRight]
}


proc _arrange_workarea {}  {
  set unmatchedDirLeft  [file join $::STS(origImgDirLeft) $::STS(dirForUnused)]
  set unmatchedDirRight [file join $::STS(origImgDirRight) $::STS(dirForUnused)]
  if { 0 == [ok_create_absdirs_in_list \
              [list $::STS(outDirPath) $unmatchedDirLeft $unmatchedDirRight] \
              [list "output"           "left-unmatched"  "right-unmatched"]] } {
    return  0;  # error already printed
  }
  if { 0 == [ok_filepath_is_writable $::STS(outPairlistPath)] }  {
    ok_err_msg "Output path for pairlist file '$::STS(outPairlistPath)' is unwritable"
    return  0;
  }
  return  1
}
