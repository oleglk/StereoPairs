# run__raw_to_hdr_on_l_r.tcl - a "sourceable" file that runs raw_to_hdr.tcl on L/ and R/ subdirectories

################################################################################
## Local configuration variables
################################################################################
# Temporary directory used for HUGE amount of data
# Either specify implicit path for temp dir, or unset the variable (use default)
unset -nocomplain _RAWRC_TMP_PATH ;  # force the default value for temp directory
#set _RAWRC_TMP_PATH "E:/TMP/RAWRC_TMP"; # explicitly specify an _absolute_ path
################################################################################
## End of local configuration variables
################################################################################


################################################################################
## Local procedures
################################################################################
proc _swap_lr_names_in_csv_file {inPath outPath namePos descr}  {
  if { ![file exists $inPath] }  {
    ok_err_msg "Missing $descr file '$inPath'";    return  0
  }
  if { ![ok_filepath_is_writable $outPath] }  {
    ok_err_msg "Non-writable output $descr file-path '$outPath'";    return  0
  }
  if { 0 == [set linesList [ok_read_csv_file_into_list_of_lists $inPath \
                                                          "," "#" 1 0]] } {
    return  0;  # error already printed
  }
  ok_info_msg "Read per-image records to be renamed from $descr file '$inPath'"
  set cntSwapped 0;  set cntAll 0;  set cntBad 0
  set newLinesList [list]
  foreach fileRec $linesList {
    if { $namePos >= [llength $fileRec] }  {
      ok_err_msg "No element #$namePos in $descr file line '$fileRec'; aborting"
      return  0
    }
    incr cntAll 1
    set name1 [lindex $fileRec $namePos]
    set pureName1 [file rootname  $name1]
    set ext       [file extension $name1]
    if { ![is_spm_purename $pureName1] }  {
      # assume header line; should come 1st
      if { 0 == [llength $newLinesList] }  {
        lappend newLinesList $fileRec;      continue
      } else {
        ok_warn_msg "Unexpected line '$fileRec' in $descr file; please check image file names; skipping it"
        incr cntBad 1;  continue 
      }
    }
    set pureName2 [spm_purename_to_peer_purename $pureName1]
    set name2 "$pureName2$ext"
    set newRec [lreplace $fileRec $namePos $namePos $name2]
    lappend newLinesList $newRec
    incr cntSwapped 1
  }
  if { 0 == [ok_write_list_of_lists_into_csv_file $newLinesList $outPath ","] } {
    ok_err_msg "Failed to write $descr file '$outPath'";    return  0
  }
  ok_info_msg "Wrote $cntSwapped renamed records into $descr file '$outPath'; $cntBad unexpected line(s) ignored"
  return  1
}


# Reads and applies relevant preferences from DualCam-Companion
proc _load_some_preferences {} {
  array unset ::STS ;   # array for global settings ;  unset once per a project
  preferences_set_initial_values  ; # initializing the settings is mandatory
  # load default settings if possible
  set allApplied 1;  # as if all succeeded
  if { 0 == [preferences_read_and_apply] }  {
    ok_warn_msg "Preferences were not loaded; will use hardcoded values"
  } else {
    ok_info_msg "Preferences successfully loaded"
  }
  # perform initializations dependent on the saved or hardcoded preferences
  if { 0 == [preferences_get_val -name_format_left specLeft]} {
    ok_err_msg "Missing preference for left image name-format"
    set allApplied 0
  }
  if { 0 == [preferences_get_val -name_format_right specRight]} {
    ok_err_msg "Missing preference for right image name-format"
    set allApplied 0
  }
  if { 0 == [set_naming_parameters_from_left_right_specs \
                                        $specLeft $specRight] } {
    set allApplied 0;  # error already printed
  }
  set descr "Temporary directory for custom commands as specified in preferences"
  if { 0 == [preferences_get_val -tmp_dir_for_custom_cmd custTmpDir]} {
    unset -nocomplain ::_PREFERENCY_TMP_DIR
    ok_info_msg "$descr is not included"
  } else {
    set ::_PREFERENCY_TMP_DIR $custTmpDir
    ok_info_msg "$descr is '$::_PREFERENCY_TMP_DIR'"
  }

  if { $allApplied == 1 }  {
    ok_info_msg "Preferences successfully loaded and applied"
    return  1
  } else {
    ok_warn_msg "Preferences were not applied; should use hardcoded values"
    return  0
  }
}
################################################################################
## End of local procedures
################################################################################





################################################################################
## "MAIN"
################################################################################


################################################################################
# (1) Detect "raw_to_hdr.tcl" script location (use surely unique variable name)
set SCRIPT_DIR__raw_to_hdr [file dirname [info script]]

# (2) Load the code from "raw_to_hdr.tcl" script;  imports library utilities too
source [file join $SCRIPT_DIR__raw_to_hdr "raw_to_hdr.tcl"]
source [file join $SCRIPT_DIR__raw_to_hdr ".." "stereopair_naming.tcl"]
source [file join $SCRIPT_DIR__raw_to_hdr ".." "preferences_mgr.tcl"]
source [file join $SCRIPT_DIR__raw_to_hdr ".." "dir_file_mgr.tcl"]

unset -nocomplain _PREFERENCY_TMP_DIR ; # placeholder for dir of "-tmp_dir_for_custom_cmd"

# (3) Read from Dualcam-Companion preferences file:
#     - image-file naming parameters
#     - temporary directory for custom commands
if { 0 == [_load_some_preferences] }  {  ; # unless defined by preferences
  ok_warn_msg "Setting stereopair naming parameters to StereoPhotoMaker-compatible defaults"
  _set_naming_parameters ""  ""  "-"  "_l"  "_r";   # for StereoPhotoMaker
}

#~ # (3) Execute the main procedure of "raw_to_hdr.tcl" script
#~ # (location of tool-path file reflects Dualcam-Companion software structure)
#~ raw_to_hdr_main "-inp_dirs {L R} -out_subdir_name OUT -final_depth 8 -raw_ext ARW -wb_out_file wb_dir1.csv -wb_inp_file wb_dir1.csv  -tools_paths_file [file join $SCRIPT_DIR__raw_to_hdr ".." ".." ext_tool_dirs.csv]"


# (4) Choose the ultimate per-session temporary directory .
#     Source priority: (a) $_RAWRC_TMP_PATH,
#                      (b) -tmp_dir_for_custom_cmd in preferences
## If temporary directory path is explicitly specified,
##      create a subdirectory under it - named after work-area root
##      e.g.:  $_RAWRC_TMP_PATH/<work-area-root>/
## If temporary directory path is not specified,
##      do not provide corresponding parameter - force the default location
# Current dir should be the work-area root
set workAreaRootDirName [file tail [pwd]]
ok_info_msg "Work-area root directory name is '$workAreaRootDirName'"
if { ([info exists ::_RAWRC_TMP_PATH]) && ($::_RAWRC_TMP_PATH != "") }  {
  # use explicitly provided tmp-dir
  set tmpDirPath [file join $::_RAWRC_TMP_PATH $workAreaRootDirName]
  set TMP_DIR_ARG__OR_EMPTY "-tmp_dir_path $tmpDirPath"
  ok_info_msg "Will use explicitly provided ultimate temporary directory '$tmpDirPath'"
} elseif { ([info exists ::_PREFERENCY_TMP_DIR]) && \
                           ($::_PREFERENCY_TMP_DIR != "") }  {
  # use tmp-dir from preferencies
  set tmpDirPath [file join $::_PREFERENCY_TMP_DIR $workAreaRootDirName]
  set tmpDirPath [expr {("relative" != [file pathtype $::_PREFERENCY_TMP_DIR])? \
              [file join $::_PREFERENCY_TMP_DIR $workAreaRootDirName] : \
              $::_PREFERENCY_TMP_DIR}]
  set TMP_DIR_ARG__OR_EMPTY "-tmp_dir_path $::tmpDirPath"
  ok_info_msg "Will use ultimate temporary directory from the preferences '$::tmpDirPath'"
} else {                                  ; # let raw2hdr choose default tmp-dir
  set TMP_DIR_ARG__OR_EMPTY "";   # force using the default
  ok_info_msg "Will use the default path for the ultimate temporary directory"
}


# TODO: add left suffix in ovrd file unless it's there

# (5) If input white-balance override file exists, tell to use it for L/ directory
#     File names in "wb_ovrd_left.csv" should be those of the left images
if { [file exists "wb_ovrd_left.csv"] }  {
  set INP_WB_OVRD "-wb_inp_file wb_ovrd_left.csv"
  ok_info_msg "Input white-balance override provided in file 'wb_ovrd_left.csv'"
} else {
  set INP_WB_OVRD ""
  ok_info_msg "No input white-balance override provided"
}

# (6) Execute the main procedure of "raw_to_hdr.tcl" script in L/ subdirectory
#     "wb_ovrd_left.csv", if exists, provides external override for white-balance
#     white-balance parameters used for all images are printed into "wb_left.csv"
# (location of tool-path file reflects Dualcam-Companion software structure)
if { 0 == [raw_to_hdr_main "-inp_dirs {L} -out_subdir_name OUT $TMP_DIR_ARG__OR_EMPTY -final_depth 8 -raw_ext ARW -rotate 0  -wb_out_file wb_left.csv $INP_WB_OVRD   -tools_paths_file [dualcam_find_toolpaths_file 0] -do_skip_existing 1 -do_abort_on_low_disk_space 1"]}   {
  return  0;  # error already printed
}


# (7) Change image-file names in WB-file created while processing left directory
#     into names of their right peers
if { 0 == [_swap_lr_names_in_csv_file "wb_left.csv" "wb_ovrd_right.csv" 0 \
                                                    "white-balance-sync"] }   {
  return  0;  # error already printed
}

# (8) Execute the main procedure of "raw_to_hdr.tcl" script in R/ subdirectory
#     "wb_ovrd_right.csv", if exists, provides external override for white-balance
#     white-balance parameters used for all images are printed into "wb_right.csv"
# (location of tool-path file reflects Dualcam-Companion software structure)
if { 0 == [raw_to_hdr_main "-inp_dirs {R} -out_subdir_name OUT $TMP_DIR_ARG__OR_EMPTY -final_depth 8 -raw_ext ARW -rotate 0  -wb_out_file wb_right.csv -wb_inp_file wb_ovrd_right.csv  -tools_paths_file [dualcam_find_toolpaths_file 0] -do_skip_existing 1 -do_abort_on_low_disk_space 1"] }   {
  return  0;  # error already printed
}

return  1;  # indicate successfull execution
################################################################################


