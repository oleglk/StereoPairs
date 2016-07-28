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

  # directory paths that might become absolute
  set PREFS(DIR_KEYS) [lsort [list -orig_img_dir -std_img_dir -out_dir]]
  
  # name-keywords for backup/thrash directories
  set PREFS(BACKUP_DIRNAME_KEY__HIDE_UNUSED)      "HideUnusedFiles"
  set PREFS(BACKUP_DIRNAME_KEY__BACKUP_SETTINGS)  "BackupSettingsFiles"
  set PREFS(BACKUP_DIRNAME_KEYS) [list $PREFS(BACKUP_DIRNAME_KEY__HIDE_UNUSED)]

  set PREFS(-INITIAL_WORK_DIR)  [pwd]
  
  # TODO: common - collect all shared options here
  
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
  set PREFS(-max_burst_gap)       1.0
  set PREFS(-simulate_only)       YES
  
  # settings copier
  set PREFS(-global_img_settings_dir)  "" ;  # global settings dir; relevant for some converters
  set PREFS(-backup_dir)  "Backup"
  set PREFS(-copy_from)  "left"

  # color analyzer/comparator
  set PREFS(-img_dir)  "."   ; # results in $PREFS(-INITIAL_WORK_DIR)
  set PREFS(-left_img_subdir)         "L/TIFF"
  set PREFS(-right_img_subdir)        "R/TIFF"
  set PREFS(-ext_left)                "tif"
  set PREFS(-ext_right)               "tif"
  set PREFS(-out_dir)                 "Data"
  set PREFS(-warn_color_diff_above)   30
  
  # workarea cleaner
  set PREFS(-global_img_settings_dir)  "" ;  # global settings dir; relevant for some converters
  set PREFS(-orig_img_dir)        "."   ; # results in $PREFS(-INITIAL_WORK_DIR)
  set PREFS(-std_img_dir)         "."   ; # results in $PREFS(-INITIAL_WORK_DIR)
  set PREFS(-final_img_dir)       "."   ; # results in $PREFS(-INITIAL_WORK_DIR)
  set PREFS(-out_dir)             "Data"
  set PREFS(-backup_dir)          "Backup"
  set PREFS(-simulate_only)       YES

  # workarea restorer
  set PREFS(-workarea_root_dir)  "."   ; # results in $PREFS(-INITIAL_WORK_DIR)
  set PREFS(-global_img_settings_dir)  "" ;  # global settings dir; relevant for some converters
  set PREFS(-out_dir)             "Data"
  set PREFS(-simulate_only)       YES
  # TODO

#  set PREFS(-)  ""

  
################################################################################
## Per-application option lists to be used in GUI frontend                    ##
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
  set PREFS(LR_NAME_RESTORER__keyToDescrAndFormat)  [dict remove \
    $PREFS(PAIR_MATCHER__keyToDescrAndFormat) -max_burst_gap -time_diff]
  set PREFS(LR_NAME_RESTORER__keysInOrder)          [ok_lremove \
    $PREFS(PAIR_MATCHER__keysInOrder)   [list -max_burst_gap -time_diff]]
  set PREFS(LR_NAME_RESTORER__keyOnlyArgsList) $PREFS(PAIR_MATCHER__keyOnlyArgsList)
  set PREFS(LR_NAME_RESTORER__hardcodedArgsStr) "-restore_lr"
################################################################################
  set PREFS(SETTINGS_COPIER__keyToDescrAndFormat) [dict create \
    -global_img_settings_dir {"full path of the directory where the RAW converter keeps all image-settings files - if relevant for your converter" "%s"} \
    -orig_img_dir {"directory with image files whose settings are dealt with; left (right) images expected in 'orig_img_dir'/L ('orig_img_dir'/R)" "%s"} \
    -out_dir {"output directory" "%s"} \
    -backup_dir {"directory to move overriden settings files to" "%s"} \
    -copy_from {"'left' == copy settings from left to right, 'right' == from right to left" "%s"} \
    -simulate_only {"YES/NO; YES means no file changes performed, only decide and report what should be done" "%s"}
  ]
  set PREFS(SETTINGS_COPIER__keysInOrder) [list -global_img_settings_dir \
                  -orig_img_dir -out_dir -backup_dir -copy_from -simulate_only]
  set PREFS(SETTINGS_COPIER__keyOnlyArgsList) [list -simulate_only]
  set PREFS(SETTINGS_COPIER__hardcodedArgsStr) ""
################################################################################
set PREFS(COLOR_ANALYZER__keyToDescrAndFormat) [dict create \
  -img_dir {"root input directory" "%s"} \
  -left_img_subdir {"subdirectory for left images; left images expected in 'img_dir'/'left_img_subdir'" "%s"} \
  -right_img_subdir {"subdirectory for right images; right images expected in 'img_dir'/'right_img_subdir'" "%s"} \
  -ext_left {"file extension of left images; standard type only (tif/jpg/etc.)" "%s"} \
  -ext_right {"file extension of right images; standard type only (tif/jpg/etc.)" "%s"} \
  -out_dir {"output directory" "%s"} \
  -warn_color_diff_above {"minimal left-right color difference (%) to warn on" "%d"} ]
  set PREFS(COLOR_ANALYZER__keysInOrder) [list -img_dir \
                  -left_img_subdir -right_img_subdir -ext_left -ext_right \
                  -out_dir -warn_color_diff_above]
  set PREFS(COLOR_ANALYZER__keyOnlyArgsList) [list]
  set PREFS(COLOR_ANALYZER__hardcodedArgsStr) ""
################################################################################
  set PREFS(WORKAREA_CLEANER__keyToDescrAndFormat) [dict create \
    -global_img_settings_dir {"full path of the directory where the RAW converter keeps all image-settings files - if relevant for your converter" "%s"} \
    -orig_img_dir {"input directory; left (right) out-of-camera images expected in 'orig_img_dir'/L ('orig_img_dir'/R)" "%s"} \
    -std_img_dir {"input directory with standard images (out-of-camera JPEG or converted from RAW and/or intermediate images); left (right) images expected in 'std_img_dir'/L ('std_img_dir'/R)" "%s"} \
    -final_img_dir {"directory with ultimate stereopair images" "%s"} \
    -out_dir {"output directory" "%s"} \
    -backup_dir {"directory to move overriden settings files to" "%s"} \
    -simulate_only {"YES/NO; YES means no file changes performed, only decide and report what should be done" "%s"}
  ]
  set PREFS(WORKAREA_CLEANER__keysInOrder) [list -global_img_settings_dir \
                -orig_img_dir -std_img_dir -final_img_dir -out_dir -backup_dir \
                -simulate_only]
  set PREFS(WORKAREA_CLEANER__keyOnlyArgsList) [list -simulate_only]
  set PREFS(WORKAREA_CLEANER__hardcodedArgsStr) ""
################################################################################
################################################################################
  # -restore_from_dir to be requested by file dialog
  # -workarea_root_dir is the main-gui root directory
  # -global_img_settings_dir is implied - full paths encoded in the backup
  set PREFS(WORKAREA_RESTORER__keyToDescrAndFormat) [dict create \
    -workarea_root_dir {"full path of the directory where to unhide/restore files to" "%s"} \
    -out_dir {"output directory" "%s"} \
    -simulate_only {"YES/NO; YES means no file changes performed, only decide and report what should be done" "%s"}
  ]
  set PREFS(WORKAREA_RESTORER__keysInOrder) [list -workarea_root_dir \
                -out_dir -simulate_only]
  set PREFS(WORKAREA_RESTORER__keyOnlyArgsList) [list -simulate_only]
  set PREFS(WORKAREA_RESTORER__hardcodedArgsStr) ""
################################################################################
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


# Returns dict of key::val; if 'allowMissing'==0 and some keys missing, returns 0
# If 'emptyValMeansNone'==1, a key with empty value isn't included in the dict
proc preferences_fetch_values {keyList allowMissing emptyValMeansNone} {
  global PREFS
  set retDict [dict create]
  foreach key $keyList {
    if { [info exists PREFS($key)] } {
      if { ($PREFS($key) != "") || ($emptyValMeansNone == 0) }  {
        dict set retDict $key $PREFS($key)
      }
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


# Directory accepted as backup/thrash
# if its leaf name includes a known dirname key (case-insensitive)
proc preferences_is_backup_dir_path {dirPath} {
  global PREFS
  set leafNameUppercase [string toupper [file tail $dirPath]]
  foreach dirNameKey $PREFS(BACKUP_DIRNAME_KEYS) {
    set dirNameKeyUppercase [string toupper $dirNameKey]
    if { 0 <= [string first $dirNameKeyUppercase $leafNameUppercase] }  {
      return  1
    }
  }
  return  0
}


################################################################################
## Functions that read and write preference file
################################################################################

# Retrieves preferences from ::PREFS array.
# Returns list of {key val} pair lists that includes keys starting from "-".
# TODO: what about -INITIAL_WORK_DIR?
proc preferences_collect {}  {
  global PREFS  ; # array of key::val
  # TODO: implement
}

proc preferences_collect_and_write {}  {
  if { 0 == [set prefAsListOfPairs [preferences_collect]] }  {
    return  0;  # error already printed
   }
   return  [preferences_write_into_file $prefAsListOfPairs]
}


proc preferences_read_and_apply {}  {
  if { 0 == [set prefAsListOfPairs [preferences_read_from_file]] }  {
    return  0;  # error already printed
   }
   return  [preferences_app[y $prefAsListOfPairs]
}


# Saves the obtained list of pairs (no header) in the predefined path.
# Returns 1 on success, 0 on error.
proc preferences_write_into_file {prefAsListOfPairs}  {
  set pPath [dualcam_find_preferences_file 0]
  if { 0 == [CanWriteFile $pPath] }  {
    ok_err_msg "Cannot write into preferences file <$pPath>"
    return  0
  }
  # prepare wrapped header; "concat" data-list to it 
  set header [list [list "param-name" "param-val"]]
  set prefListWithHeader [concat $header $prefAsListOfPairs]
  return  [ok_write_list_of_lists_into_csv_file $prefListWithHeader \
                                                $pPath ","]
}


# Reads and returns list of pairs (no header) from the predefined path.
# Returns 0 on error.
proc preferences_read_from_file {}  {
  if { 0 == [set pPath [dualcam_find_preferences_file 1]] }  {
    ok_warn_msg "Inexistent preferences file <$pPath>; will use built-in values"
    return  0
  }
  set prefListWithHeader [ok_read_csv_file_into_list_of_lists $pPath "," "#" 0]
  if { $prefListWithHeader == 0 } {
    ok_err_msg "Failed reading preferences from file '$pPath'"
    return  0
  }
  return  [lrange $prefListWithHeader 1 end]
}


# Installs preferred values from the obtained list of pairs (no header).
# The StereoPairs app is built so that nothing should occur immediately
# upon changing a preference, so the values are just set in ::PREFS
# Returns 1 on success, 0 on error.
proc preferences_app[y {prefListNoHeader}  {
  global PREFS  ; # array of key::val
  if { 0 == [llength $prefListNoHeader] }  {
    ok_err_msg "Got empty list of preferences"
    return 0
  }
  if { 0 == [SafeListOfListsToArray $prefListNoHeader PREFS] }  {
    ok_err_msg "Invalid/corrupted list of preferences: ($prefListNoHeaderS)"
    return 0
  }
  set errCnt 0
  # TODO: implement
  
  #~ # apply proxy variables - read from file
  #~ set LOUD_MODE $SHOW_TRACE
  return  [expr $errCnt == 0]
}