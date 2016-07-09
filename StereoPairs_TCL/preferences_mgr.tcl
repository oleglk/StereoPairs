# preferences_mgr.tcl

set SCRIPT_DIR [file dirname [info script]]
## DO NOT:  source [file join $SCRIPT_DIR   "debug_utils.tcl"]
source [file join $SCRIPT_DIR   "dir_file_mgr.tcl"]

package require ok_utils
namespace import -force ::ok_utils::*



################################################################################
proc _set_initial_values {}  {
  global PREFS  ; # array of key::val
  ok_trace_msg "Setting hardcoded functional preferences"

  array unset PREFS
  
  # pair matcher:

  set PREFS(-time_diff)         0
  set PREFS(-min_success_rate)   50
  set PREFS(-orig_img_dir)  [pwd]
  set PREFS(-orig_img_subdir_name_left)   "L"
  set PREFS(-orig_img_subdir_name_right)  "R"
  set PREFS(-std_img_dir)   $PREFS(origImgRootPath)
  set PREFS(-out_dir)       "Data"
  set PREFS(-out_pairlist_filename)  "lr_pairs.csv"
  set PREFS(-use_pairlist)  ""
  set PREFS(-dir_for_unmatched)  "Unmatched"
  set PREFS(-create_sbs)      NO
  set PREFS(-rename_lr)       YES
  set PREFS(-time_from )    "exif"
  set PREFS(-max_burst_gap )      0.9
  set PREFS(-simulate_only)   NO
  
  # settings copier
  set PREFS(global_img_settings_dir)  "" ;  # global settings dir; relevant for some converters
  set PREFS(-backup_dir)  "Backup"
  set PREFS(-copy_from)  "left"
  set PREFS(-)  ""
  set PREFS(-)  ""
  set PREFS(-)  ""
#  set PREFS(-)  ""

  
  
  #~ set INITIAL_WORK_DIR [pwd]
  #~ set WORK_DIR $INITIAL_WORK_DIR
  #~ set LOG_VIEWER write
  #~ set HELP_VIEWER write
  #~ set SHOW_TRACE 1
}
################################################################################
_SetInitialValues
################################################################################
