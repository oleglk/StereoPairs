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

  set PREFS(BOOLEANS_DICT) [dict create 1 1  0 0  no 0  NO 0  No 0  nO 0   n 0 \
                                        yes 1  YES 1  Yes 1  yES 1   y 1       \
                                        false 0  FALSE 0  False 0  fALSE 0     \
                                        true 1  TRUE 1  True 1  tRUE 1]

  # directory paths that might become absolute
  set PREFS(DIR_KEYS) [lsort [list -orig_img_dir -std_img_dir -out_dir]]

  set PREFS(-INITIAL_WORK_DIR)  [pwd]
  # pair matcher:
  set PREFS(-time_diff)           0
  set PREFS(-min_success_rate)    50
  set PREFS(-orig_img_dir)        "."   ; # results in $PREFS(-INITIAL_WORK_DIR)
  set PREFS(-orig_img_subdir_name_left)   "L"
  set PREFS(-orig_img_subdir_name_right)  "R"
  set PREFS(-std_img_dir)         "."   ; # results in $PREFS(-INITIAL_WORK_DIR)
  set PREFS(-out_dir)             "Data"
  set PREFS(-out_pairlist_filename)  "lr_pairs.csv"
  set PREFS(-use_pairlist)        ""
  set PREFS(-dir_for_unmatched)   "Unmatched"
  set PREFS(-create_sbs)          NO
  set PREFS(-rename_lr)           YES
  set PREFS(-time_from)           "exif"
  set PREFS(-max_burst_gap)       0.9
  set PREFS(-simulate_only)       YES
  
  # settings copier
  set PREFS(global_img_settings_dir)  "" ;  # global settings dir; relevant for some converters
  set PREFS(-backup_dir)  "Backup"
  set PREFS(-copy_from)  "left"
  set PREFS(-)  ""
  set PREFS(-)  ""
  set PREFS(-)  ""
#  set PREFS(-)  ""

  
################################################################################
  set PREFS(PAIR_MATCHER__keyToDescrAndFormat) [dict create \
    -max_burst_gap {"max time difference between consequent frames to be considered a burst, sec" "%g"} \
    -time_diff {"time difference in seconds between the 2nd and 1st cameras" "%d"} \
    -orig_img_dir {"input directory; left (right) out-of-camera images expected in 'orig_img_dir'/L ('orig_img_dir'/R)" "%s"} \
    -std_img_dir {"input directory with standard images (out-of-camera JPEG or converted from RAW); left (right) images expected in 'std_img_dir'/L ('std_img_dir'/R)" "%s"} \
    -out_dir {"output directory" "%s"} \
    -simulate_only {"YES/NO; YES means no file changes performed, only decide and report what should be done" "%s"}
  ]
  set PREFS(PAIR_MATCHER__keysInOrder) [list -time_diff -orig_img_dir -std_img_dir -out_dir \
                        -max_burst_gap -simulate_only]
  set PREFS(PAIR_MATCHER__keyOnlyArgsList) [list -simulate_only]
  set PREFS(PAIR_MATCHER__hardcodedArgsStr) "-rename_lr"
################################################################################
  set PREFS(LR_NAME_RESTORER__keyToDescrAndFormat) $PREFS(PAIR_MATCHER__keyToDescrAndFormat)
  set PREFS(LR_NAME_RESTORER__keysInOrder) $PREFS(PAIR_MATCHER__keysInOrder)
  set PREFS(LR_NAME_RESTORER__keyOnlyArgsList) $PREFS(PAIR_MATCHER__keyOnlyArgsList)
  set PREFS(LR_NAME_RESTORER__hardcodedArgsStr) "-restore_lr"
################################################################################
  
  
  #~ set INITIAL_WORK_DIR [pwd]
  #~ set WORK_DIR $INITIAL_WORK_DIR
  #~ set LOG_VIEWER write
  #~ set HELP_VIEWER write
  #~ set SHOW_TRACE 1
}
################################################################################
_set_initial_values
################################################################################


proc preferences_get_val {key valRef} {
  global PREFS
  upvar $valRef val
  if { [info exists PREFS($key)] }  {
    set val $PREFS($key)
    return  1
  }
  return  0;  # inexistent key
}


proc preferences_set_val {key val} {
  global PREFS
  set PREFS($key) $val
}


proc preferences_read_boolean {boolAsStr boolAsIntVar}  {
  global PREFS
  upvar $boolAsIntVar boolAsInt
  if { 0 == [info exists PREFS(BOOLEANS_DICT)] }  {
    return  0;  # should not get there
  }
  if { 0 == [dict exists $PREFS(BOOLEANS_DICT) $boolAsStr] }  {
    return  0;  # indicates not found
  }
  set boolAsInt [dict get $PREFS(BOOLEANS_DICT) $boolAsStr]
  return  1;  # indicates found
}


# Returns dict of key::val; if 'allowMissing'==0 and some keys missing, returns 0
proc preferences_fetch_values {keyList allowMissing} {
  global PREFS
  set retDict [dict create]
  foreach key $keyList {
    if { [info exists PREFS($key)] } {
      dict set retDict $key $PREFS($key)
    } elseif { $allowMissing == 0 } {
      ok_err_msg "Missing preference for '$key'"
      return  0
    }
  }
  return  $retDict
}


proc preferences_strip_rootdir_prefix_from_dirs {prefDict rootDir newPrefix} {
  global PREFS
  set retDict [dict create]
  foreach key [dict keys $prefDict] {
    set val [dict get $prefDict $key]
    set newVal $val
    set isDir [expr {0 <= [lsearch -sorted $PREFS(DIR_KEYS) $key]}]
    if { $isDir } {
      if { 1 == [ok_is_underlying_filepath $val $rootDir] } {
        set suffix [ok_strip_prefix_from_filepath $val $rootDir]
        set newVal [file join $newPrefix $suffix]
      }
    }
    dict set retDict $key $newVal
  }
  return  $retDict
}