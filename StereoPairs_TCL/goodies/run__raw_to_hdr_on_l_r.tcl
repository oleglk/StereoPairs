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
