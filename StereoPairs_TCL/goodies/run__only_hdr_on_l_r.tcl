# run__only_hdr_on_l_r.tcl - a "sourceable" file that runs raw_to_hdr.tcl on L/ and R/ subdirectories


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
  set cntSwapped 0;  set cntAll 0
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
        ok_err_msg "Unexpected line '$fileRec' in $descr file; aborting"
        return  0
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
  ok_info_msg "Wrote $cntSwapped renamed records into $descr file '$outPath'"
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

# (3) Read image-file naming parameters from Dualcam-Companion preferences file
if { 0 == [_load_some_preferences] }  {  ; # unless defined by preferences
  ok_warn_msg "Setting stereopair naming parameters to StereoPhotoMaker-compatible defaults"
  _set_naming_parameters ""  ""  "-"  "_l"  "_r";   # for StereoPhotoMaker
}

#~ # (3) Execute the main procedure of "raw_to_hdr.tcl" script
#~ # (location of tool-path file reflects Dualcam-Companion software structure)
#~ raw_to_hdr_main "-inp_dirs {L R} -out_subdir_name OUT -final_depth 8 -raw_ext ARW -wb_out_file wb_dir1.csv -wb_inp_file wb_dir1.csv  -tools_paths_file [file join $SCRIPT_DIR__raw_to_hdr ".." ".." ext_tool_dirs.csv]"


# (5) Execute the main procedure of "raw_to_hdr.tcl" script in L/ subdirectory
#     "wb_ovrd_left.csv", if exists, provides external override for white-balance
#     white-balance parameters used for all images are printed into "wb_left.csv"
# (location of tool-path file reflects Dualcam-Companion software structure)
if { 0 == [raw_to_hdr_main "-do_raw_conv 0  -inp_dirs {L} -out_subdir_name OUT -final_depth 8 -raw_ext ARW -rotate 0  -tools_paths_file [dualcam_find_toolpaths_file 0]"]}   {
  return  0;  # error already printed
}


# (7) Execute the main procedure of "raw_to_hdr.tcl" script in R/ subdirectory
#     "wb_ovrd_right.csv", if exists, provides external override for white-balance
#     white-balance parameters used for all images are printed into "wb_right.csv"
# (location of tool-path file reflects Dualcam-Companion software structure)
if { 0 == [raw_to_hdr_main "-do_raw_conv 0  -inp_dirs {R} -out_subdir_name OUT -final_depth 8 -raw_ext ARW -rotate 0  -tools_paths_file [dualcam_find_toolpaths_file 0]"] }   {
  return  0;  # error already printed
}

return  1;  # indicate successfull execution
################################################################################


