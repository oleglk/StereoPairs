# run__rotate_and_crop_on_l_r.tcl - a "sourceable" file that runs rotate_and_crop.tcl on L/ and R/ subdirectories


################################################################################
## Local procedures
################################################################################

################################################################################
## End of local procedures
################################################################################



################################################################################
## "MAIN"
################################################################################


################################################################################
# (1) Detect "rotate_and_crop.tcl" script location (use surely unique variable name)
set SCRIPT_DIR__rotate_and_crop [file dirname [info script]]

# (2) Load the code from "rotate_and_crop.tcl" script;  imports library utilities too
source [file join $SCRIPT_DIR__rotate_and_crop "rotate_and_crop.tcl"]

# (3) Execute the main procedure of "rotate_and_crop.tcl" script in L/ subdirectory
# (location of tool-path file reflects Dualcam-Companion software structure)
if { 0 == [rotate_and_crop_main "-rot_angle 90 -crop_ratio 1 -final_depth 8 -inp_dir {L} -bu_subdir_name {BU} -img_ext JPG   -tools_paths_file [file join $SCRIPT_DIR__rotate_and_crop ".." ".." ext_tool_dirs.csv]"]}   {
  return  0;  # error already printed
}

# (4) Execute the main procedure of "rotate_and_crop.tcl" script in R/ subdirectory
# (location of tool-path file reflects Dualcam-Companion software structure)
if { 0 == [rotate_and_crop_main "-rot_angle 0 -crop_ratio 1 -final_depth 8 -inp_dir {R} -bu_subdir_name {BU} -img_ext JPG  -tools_paths_file [file join $SCRIPT_DIR__rotate_and_crop ".." ".." ext_tool_dirs.csv]"] }   {
  return  0;  # error already printed
}
################################################################################


