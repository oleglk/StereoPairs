# preferences_mgr.tcl

set SCRIPT_DIR [file dirname [info script]]
## DO NOT:  source [file join $SCRIPT_DIR   "debug_utils.tcl"]
source [file join $SCRIPT_DIR   "dir_file_mgr.tcl"]

package require ok_utils
namespace import -force ::ok_utils::*

################################################################################
## Special keys for formatting options' lists
################################################################################
set SEPARATOR_KEY "SEPARATOR*"
set HEADER_KEY    "HEADER: *"
set HEADER_REGEXP "HEADER: (.+)"
################################################################################




################################################################################
# Initializes all options.
################################################################################
proc preferences_set_initial_values {}  {
  global PREFS  ; # array of key::val
  ok_info_msg "Setting hardcoded functional preferences"

  array unset PREFS
  preferences_get_initial_values PREFS
}


################################################################################
# Puts all initial options into array 'arrayName' - array of key::val.
################################################################################
proc preferences_get_initial_values {arrayName}  {
  upvar $arrayName _prefs
  # directory paths that might become absolute
  set _prefs(DIR_KEYS) [lsort [list -orig_img_dir -std_img_dir -out_dir]]
  
  # name-keywords for backup/thrash directories
  set _prefs(BACKUP_DIRNAME_KEY__HIDE_UNUSED)      "HideUnusedFiles"
  set _prefs(BACKUP_DIRNAME_KEY__BACKUP_SETTINGS)  "BackupSettingsFiles"
  set _prefs(BACKUP_DIRNAME_KEYS) [list $_prefs(BACKUP_DIRNAME_KEY__HIDE_UNUSED)]

  set _prefs(-INITIAL_WORK_DIR)  "." ;  # [pwd] causes Reset to whatever CWD is
  
  # common - all shared options come here
  set _prefs(-orig_img_dir)        "." ; # results in $_prefs(-INITIAL_WORK_DIR)
  set _prefs(-std_img_dir)         "." ; # results in $_prefs(-INITIAL_WORK_DIR)
  set _prefs(-name_format_left)    {[LeftName]-[RightId]_l} ; # dsc1234-8765_l
  set _prefs(-name_format_right)   {[LeftName]-[RightId]_r} ; # dsc1234-8765_r
  set _prefs(-out_dir)             "Data"
  set _prefs(-global_img_settings_dir)  "" ;  # global settings dir; relevant for some converters
  set _prefs(-backup_dir)  "Backup"
  set _prefs(-simulate_only)       YES
  
  # pair matcher:
  set _prefs(-time_diff)           0
  set _prefs(-min_success_rate)    50
  set _prefs(-orig_img_subdir_name_left)   "L"
  set _prefs(-orig_img_subdir_name_right)  "R"
  set _prefs(-out_pairlist_filename)  "lr_pairs.csv"
  set _prefs(-use_pairlist)        ""
  set _prefs(-dir_for_unmatched)   "Unmatched"
  set _prefs(-create_sbs)          NO
  set _prefs(-rename_lr)           YES
  set _prefs(-time_from)           "exif"
  set _prefs(-max_frame_gap)       1.0
  
  # settings copier
  set _prefs(-copy_from)  "left"

  # color analyzer/comparator
  set _prefs(-img_dir)  "."   ; # results in $_prefs(-INITIAL_WORK_DIR)
  set _prefs(-left_img_subdir)         "L/TIFF"
  set _prefs(-right_img_subdir)        "R/TIFF"
  set _prefs(-ext_left)                "tif"
  set _prefs(-ext_right)               "tif"
  set _prefs(-warn_color_diff_above)   30
  
  # workarea cleaner
  set _prefs(-final_img_dir)       "." ; # results in $_prefs(-INITIAL_WORK_DIR)

  # workarea restorer
  set _prefs(-workarea_root_dir)  "." ; # results in $_prefs(-INITIAL_WORK_DIR)
  # TODO

#  set _prefs(-)  ""

  
################################################################################
## Common option list to be used ONLY in GUI frontend                         ##
################################################################################
  set _prefs(COMMON__keyToDescrAndFormat) [dict create \
    -INITIAL_WORK_DIR {"workarea root directory assumed at startup" "%s"}]
  set _prefs(COMMON__keysInOrder) [list -INITIAL_WORK_DIR]
  set _prefs(COMMON__keyOnlyArgsList) [list]
  set _prefs(COMMON__hardcodedArgsStr) ""
################################################################################
  
################################################################################
## Per-application option lists to be used in GUI frontend                    ##
################################################################################
  set _prefs(PAIR_MATCHER__keyToDescrAndFormat) [dict create \
    -max_frame_gap {"max time difference between left/right frames to be considered a stereopair, sec" "%g"} \
    -time_diff {"time difference in seconds between the right- and left cameras" "%d"} \
    -orig_img_dir {"input directory; left (right) out-of-camera images expected in 'orig_img_dir'/L ('orig_img_dir'/R)" "%s"} \
    -std_img_dir {"input directory with standard images (out-of-camera JPEG or converted from RAW); left (right) images expected in 'std_img_dir'/L ('std_img_dir'/R)" "%s"} \
    -name_format_left  {"name spec for left images - <prefix>\[LeftName\]<delimeter>\[RightId\]<suffix>; example: \[LeftName\]-\[RightId\]_left" "%s"} \
    -name_format_right {"name spec for right images - <prefix>\[LeftName\]<delimeter>\[RightId\]<suffix>; example: \[LeftName\]-\[RightId\]_right" "%s"} \
    -min_success_rate {"min percentage of successfull matches to permit image-file operations" "%d"} \
    -out_dir {"output directory" "%s"} \
    -simulate_only {"YES/NO; YES means no file changes performed, only decide and report what should be done" "%s"}
  ]
  set _prefs(PAIR_MATCHER__keysInOrder) [list -time_diff -orig_img_dir \
        -std_img_dir -name_format_left -name_format_right \
        -min_success_rate -out_dir -max_frame_gap -simulate_only]
  set _prefs(PAIR_MATCHER__keyOnlyArgsList) [list -simulate_only]
  set _prefs(PAIR_MATCHER__hardcodedArgsStr) "-rename_lr"
################################################################################
  set _prefs(LR_NAME_RESTORER__keyToDescrAndFormat)  [dict remove \
    $_prefs(PAIR_MATCHER__keyToDescrAndFormat) \
                                    -name_format_left -name_format_right \
                                    -max_frame_gap -time_diff -min_success_rate]
  set _prefs(LR_NAME_RESTORER__keysInOrder)  \
            [ok_lremove $_prefs(PAIR_MATCHER__keysInOrder) \
                            [list -name_format_left -name_format_right \
                                  -max_frame_gap -time_diff -min_success_rate]]
  set _prefs(LR_NAME_RESTORER__keyOnlyArgsList) $_prefs(PAIR_MATCHER__keyOnlyArgsList)
  set _prefs(LR_NAME_RESTORER__hardcodedArgsStr) "-restore_lr"
################################################################################
  set _prefs(SETTINGS_COPIER__keyToDescrAndFormat) [dict create \
    -global_img_settings_dir {"full path of the directory where the RAW converter keeps all image-settings files - if relevant for your converter" "%s"} \
    -orig_img_dir {"directory with image files whose settings are dealt with; left (right) images expected in 'orig_img_dir'/L ('orig_img_dir'/R)" "%s"} \
    -name_format_left  {"name spec for left images - <prefix>\[LeftName\]<delimeter>\[RightId\]<suffix>; example: \[LeftName\]-\[RightId\]_left" "%s"} \
    -name_format_right {"name spec for right images - <prefix>\[LeftName\]<delimeter>\[RightId\]<suffix>; example: \[LeftName\]-\[RightId\]_right" "%s"} \
    -out_dir {"output directory" "%s"} \
    -backup_dir {"directory to move overriden settings files to" "%s"} \
    -copy_from {"'left' == copy settings from left to right, 'right' == from right to left" "%s"} \
    -simulate_only {"YES/NO; YES means no file changes performed, only decide and report what should be done" "%s"}
  ]
  set _prefs(SETTINGS_COPIER__keysInOrder) [list -global_img_settings_dir \
                  -name_format_left -name_format_right \
                  -orig_img_dir -out_dir -backup_dir -copy_from -simulate_only]
  set _prefs(SETTINGS_COPIER__keyOnlyArgsList) [list -simulate_only]
  set _prefs(SETTINGS_COPIER__hardcodedArgsStr) ""
################################################################################
set _prefs(COLOR_ANALYZER__keyToDescrAndFormat) [dict create \
  -img_dir {"root input directory" "%s"} \
  -name_format_left  {"name spec for left images - <prefix>\[LeftName\]<delimeter>\[RightId\]<suffix>; example: \[LeftName\]-\[RightId\]_left" "%s"} \
    -name_format_right {"name spec for right images - <prefix>\[LeftName\]<delimeter>\[RightId\]<suffix>; example: \[LeftName\]-\[RightId\]_right" "%s"} \
  -left_img_subdir {"subdirectory for left images; left images expected in 'img_dir'/'left_img_subdir'" "%s"} \
  -right_img_subdir {"subdirectory for right images; right images expected in 'img_dir'/'right_img_subdir'" "%s"} \
  -ext_left {"file extension of left images; standard type only (tif/jpg/etc.)" "%s"} \
  -ext_right {"file extension of right images; standard type only (tif/jpg/etc.)" "%s"} \
  -out_dir {"output directory" "%s"} \
  -warn_color_diff_above {"minimal left-right color difference (%) to warn on" "%d"} ]
  set _prefs(COLOR_ANALYZER__keysInOrder) [list -img_dir \
                  -name_format_left -name_format_right \
                  -left_img_subdir -right_img_subdir -ext_left -ext_right \
                  -out_dir -warn_color_diff_above]
  set _prefs(COLOR_ANALYZER__keyOnlyArgsList) [list]
  set _prefs(COLOR_ANALYZER__hardcodedArgsStr) ""
################################################################################
  set _prefs(WORKAREA_CLEANER__keyToDescrAndFormat) [dict create \
    -global_img_settings_dir {"full path of the directory where the RAW converter keeps all image-settings files - if relevant for your converter" "%s"} \
    -orig_img_dir {"input directory; left (right) out-of-camera images expected in 'orig_img_dir'/L ('orig_img_dir'/R)" "%s"} \
    -std_img_dir {"input directory with standard images (out-of-camera JPEG or converted from RAW and/or intermediate images); left (right) images expected in 'std_img_dir'/L ('std_img_dir'/R)" "%s"} \
    -name_format_left  {"name spec for left images - <prefix>\[LeftName\]<delimeter>\[RightId\]<suffix>; example: \[LeftName\]-\[RightId\]_left" "%s"} \
    -name_format_right {"name spec for right images - <prefix>\[LeftName\]<delimeter>\[RightId\]<suffix>; example: \[LeftName\]-\[RightId\]_right" "%s"} \
    -final_img_dir {"directory with ultimate stereopair images" "%s"} \
    -out_dir {"output directory" "%s"} \
    -backup_dir {"directory to move overriden settings files to" "%s"} \
    -simulate_only {"YES/NO; YES means no file changes performed, only decide and report what should be done" "%s"}
  ]
  set _prefs(WORKAREA_CLEANER__keysInOrder) [list -global_img_settings_dir \
              -orig_img_dir -std_img_dir -name_format_left -name_format_right \
              -final_img_dir -out_dir -backup_dir -simulate_only]
  set _prefs(WORKAREA_CLEANER__keyOnlyArgsList) [list -simulate_only]
  set _prefs(WORKAREA_CLEANER__hardcodedArgsStr) ""
################################################################################
################################################################################
  # -restore_from_dir to be requested by file dialog
  # -workarea_root_dir is the main-gui root directory
  # -global_img_settings_dir is implied - full paths encoded in the backup
  set _prefs(WORKAREA_RESTORER__keyToDescrAndFormat) [dict create \
    -workarea_root_dir {"full path of the directory where to unhide/restore files to" "%s"} \
    -out_dir {"output directory" "%s"} \
    -simulate_only {"YES/NO; YES means no file changes performed, only decide and report what should be done" "%s"}
  ]
  set _prefs(WORKAREA_RESTORER__keysInOrder) [list -workarea_root_dir \
                -out_dir -simulate_only]
  set _prefs(WORKAREA_RESTORER__keyOnlyArgsList) [list -simulate_only]
  set _prefs(WORKAREA_RESTORER__hardcodedArgsStr) ""
################################################################################

################################################################################
## ALL_PREFERENCES__keyToDescrAndFormat should automatically assemble ALL RECORDS
  set descrFormatDictArrayEntries [array get _prefs "*__keyToDescrAndFormat"]
  set descrFormatDicts [dict values $descrFormatDictArrayEntries]
  set _prefs(ALL_PREFERENCES__keyToDescrAndFormat) \
                                              [dict merge {*}$descrFormatDicts]
  # note, COMMON section with its header will be prepended afterwards
  set keysInOrderWithRepetitions [concat              \
              [list "HEADER: ==== Options specific to Pair-Matcher      ===="] \
              $_prefs(PAIR_MATCHER__keysInOrder)       \
              [list "HEADER: ==== Options specific to Name-Restorer     ===="] \
              $_prefs(LR_NAME_RESTORER__keysInOrder)   \
              [list "HEADER: ==== Options specific to Settings-Copier   ===="] \
              $_prefs(SETTINGS_COPIER__keysInOrder)    \
              [list "HEADER: ==== Options specific to Color-Analyzer    ===="] \
              $_prefs(COLOR_ANALYZER__keysInOrder)     \
              [list "HEADER: ==== Options specific to Workarea-Cleaner  ===="] \
              $_prefs(WORKAREA_CLEANER__keysInOrder)   \
              [list "HEADER: ==== Options specific to Workarea-Restorer ===="] \
              $_prefs(WORKAREA_RESTORER__keysInOrder)  ]
  # prepend SHARED section with its header
  set keysUsedByUtils [ok_group_repeated_elements_in_list     \
                                                  $keysInOrderWithRepetitions 0]
  # grouping shared options may have created empty sections; eliminate such ones
  set keysUsedByUtils [preferences_strip_empty_sections_from_list \
                                                              $keysUsedByUtils]
  set _prefs(ALL_PREFERENCES__keysInOrder) [                  \
              linsert $keysUsedByUtils 0                      \
              "HEADER: ==== Common/shared options ===="       \
              "-INITIAL_WORK_DIR"]
  
################################################################################
  
  
  #~ set INITIAL_WORK_DIR [pwd]
  #~ set WORK_DIR $INITIAL_WORK_DIR
  #~ set LOG_VIEWER write
  #~ set HELP_VIEWER write
  #~ set SHOW_TRACE 1
}
################################################################################
## DO NOT: preferences_set_initial_values
################################################################################


################################################################################
# Resets user-changeable options to their defaults.
################################################################################
proc UNUSED__preferences_reset {}  {
  global PREFS  ; # array of key::val
  ok_copy_array PREFS buPREFS
  preferences_set_initial_values ;  # reset everything in PREFS
  set hiddenOptions [array get buPREFS {[a-z_A-Z.]*}] ; # not starting from "-"
  array set PREFS $hiddenOptions; # restore non-user-changeable options
  ok_info_msg "Non user-changeable options are unreset"
}


proc preferences_get_initial_user_changeable_values {arrayName} {
  upvar $arrayName prefsArray
  array unset allIniPrefs
  preferences_get_initial_values allIniPrefs
  set userIniOptions [array get allIniPrefs {[-]*}] ; # starting from "-"
  array set prefsArray $userIniOptions
}


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
# ('-INITIAL_WORK_DIR' will be included too)
proc preferences_collect {}  {
  global PREFS  ; # array of key::val
  set prefAsPlainList [array get PREFS "-*"] ;  # has keys/vals alternaring
  set prefAsListOfPairs [list]
  dict for {key val} $prefAsPlainList {
    lappend prefAsListOfPairs [list $key $val]
  }
  return  $prefAsListOfPairs
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
   return  [preferences_apply $prefAsListOfPairs]
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
  set prefListWithHeader [ok_read_csv_file_into_list_of_lists $pPath "," "#" 0 0]
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
proc preferences_apply {prefListNoHeader}  {
  global PREFS  ; # array of key::val
  if { 0 == [llength $prefListNoHeader] }  {
    ok_err_msg "Got empty list of preferences"
    return 0
  }
  # go one-by-one, since ok_list_of_lists_to_array fails on
  # key-only and empty-val options 
  foreach oneOptionList $prefListNoHeader {
    set listLng [llength $oneOptionList]
    if { ($listLng != 1) && ($listLng != 2) } {
      ok_err_msg "Invalid option '$oneOptionList' in the list of preferences {$prefListNoHeader}"
      return 0
    }
    set key [lindex $oneOptionList 0]
    if { $listLng == 1 } {
      set PREFS($key) ""; # make key-only argument map to empty string
    } else { ;  # $listLng == 2
      set PREFS($key) [lindex $oneOptionList 1]
    }
    ok_info_msg "Option '$key' set to '$PREFS($key)' by '$oneOptionList'"  
  }
  set errCnt 0
  # TODO: implement
  
  #~ # apply proxy variables - read from file
  #~ set LOUD_MODE $SHOW_TRACE
  return  [expr $errCnt == 0]
}


proc preferences_key_is_separator {keyStr} {
  return  [expr {1 == [string match $::SEPARATOR_KEY $keyStr]}]
}


proc preferences_key_is_header {keyStr} {
  return  [expr {1 == [string match $::HEADER_KEY $keyStr]}]
}


proc preferences_extract_header_key_text {keyStr} {
  if { 1 == [string match $::HEADER_KEY $keyStr] }  {
    if { 0 == [regexp -- $::HEADER_REGEXP $keyStr fullMatch headerText] }   {
      set headerText $keyStr;  # bad header key; insert it as a whole
    }
    return  $headerText
  }
  return  0 ;   # not a header key
}


proc preferences_strip_special_keywords_from_list {keyOrderList} {
  set resList [list]
  foreach el $keyOrderList {
    if { (1 == [preferences_key_is_separator $el]) || \
         (1 == [preferences_key_is_header $el]) } { continue }
    lappend resList $el
  }
  return  $resList
}


# Removes header keys when there are no non-special keys up to next header 
proc preferences_strip_empty_sections_from_list {keyOrderList} {
  set resList [list]
  set nonSpecialElemAppeared 0
  foreach el [lreverse $keyOrderList] {
    if { 0 == [preferences_key_is_header $el] } {
      set resList [linsert $resList 0 $el]
      if { 0 == [preferences_key_is_separator $el] } {
        set nonSpecialElemAppeared 1
      }
    } else {  ;   # $el is header
      if { $nonSpecialElemAppeared == 1 } {
        set resList [linsert $resList 0 $el]
      }
      set nonSpecialElemAppeared 0
    }
  }
  return  $resList
}
