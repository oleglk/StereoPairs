# dir_file_mgr.tcl

set SCRIPT_DIR [file dirname [info script]]
## DO NOT:  source [file join $SCRIPT_DIR   "debug_utils.tcl"]
source [file join $SCRIPT_DIR   "cameras.tcl"]

package require ok_utils
namespace import -force ::ok_utils::*


set DIAGNOSTICS_FILE_NAME "dualcam_diagnostics.txt"
set PREFERENCES_FILE_NAME "dualcam_ini.csv"
set TOOLPATHS_FILE_NAME   "dualcam_ext_tool_dirs.csv"


# Safely attempts to switch workarea root dir to 'workDir'; returns "" on success.
# On error returns error message.
proc dualcam_cd_to_workdir_or_complain {workDir closeOldDiagnostics}  {
  global STS DIAGNOSTICS_FILE_NAME
  if { $workDir == "" } {
    set msg "No working directory specified; changing directory not performed"
    return  $msg
  }
  if { 0 == [is_dir_ok_for_workdir $workDir] }  {
    set msg "<$workDir> is not suitable for working directory"
    return  $msg
  }
  set tclResult [catch { set res [cd $workDir] } execResult]
  if { $tclResult != 0 } {
    set msg "Failed changing work directory to <$workDir>: $execResult!"
    ok_err_msg $msg
    return  $msg
  }
  if { $closeOldDiagnostics }  {
    ok_finalize_diagnostics;  # if old file was open, close it
  }
  set STS(origImgRootPath)  $workDir
  set STS(outDirPath)       "Data"  ; # TODO: take from preferences

  ok_init_diagnostics [file join $workDir \
                                  $STS(outDirPath) $DIAGNOSTICS_FILE_NAME]
  ok_info_msg "Working directory set to '$workDir'"
  return  ""
}


proc is_dir_ok_for_workdir {workDir}  {
  if { 0 == [ok_filepath_is_existent_dir $workDir] }  {
    ok_err_msg "There is no directory named '$workDir'"
    return  0
  }
  # unfortunately the check for writability constantly fails on Windows
  if { 0 == [file writable $workDir] }  {
    ok_err_msg "Directory '$workDir' is not writable"
    return  0
  }
    return  1
}



#~ # Defines file/dir path variables in ::STS to subdir-s under 'workDir'
#~ proc dualcam_set_paths_under_workdir {workDir}  {
  #~ global STS
#~ }


################################################################################



proc dualcam_find_preferences_file {{checkExist 1}}  {
  global PREFERENCES_FILE_NAME
  set pPath [file join [file normalize "~"] $PREFERENCES_FILE_NAME]
  if { $checkExist && (0 == [file exists $pPath]) } {
    ok_err_msg "Preferences file $pPath not found"
    return ""
  }
  return $pPath
}


proc dualcam_find_toolpaths_file {{checkExist 1}}  {
  global TOOLPATHS_FILE_NAME
  set pPath [file join [file normalize "~"] $TOOLPATHS_FILE_NAME]
  if { $checkExist && (0 == [file exists $pPath]) } {
    ok_err_msg "Tool paths file $pPath not found"
    return ""
  }
  return $pPath
}


