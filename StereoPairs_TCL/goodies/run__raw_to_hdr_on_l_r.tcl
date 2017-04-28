# run__raw_to_hdr_on_l_r.tcl - a "sourceable" file that runs raw_to_hdr.tcl on L/ and R/ subdirectories

################################################################################
# (1) Detect "raw_to_hdr.tcl" script location (use surely unique variable name)
set SCRIPT_DIR__raw_to_hdr [file dirname [info script]]

# (2) Load the code from "raw_to_hdr.tcl" script
source [file join $SCRIPT_DIR__raw_to_hdr "raw_to_hdr.tcl"]

# (3) Execute the main procedure of "raw_to_hdr.tcl" script
# (location of tool-path file reflects Dualcam-Companion software structure)
raw_to_hdr_main "-inp_dirs {L R} -out_subdir_name OUT -final_depth 8 -raw_ext ARW -wb_out_file wb_dir1.csv -wb_inp_file wb_dir1.csv  -tools_paths_file [file join $SCRIPT_DIR__raw_to_hdr ".." ".." ext_tool_dirs.csv]"
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
    set newRec [lreplace $fileRec $namePos $namePos $pureName2]
    lappend newLinesList $newRec
    incr cntSwapped 1
  }
  if { 0 == [ok_write_list_of_lists_into_csv_file $newLinesList $outPath ","] } {
    ok_err_msg "Failed to write $descr file '$outPath'";    return  0
  }
  ok_info_msg "Wrote $cntSwapped renamed records into $descr file '$outPath'"
  return  1
}