# run__raw_to_hdr_rotate_and_crop.tcl - a "sourceable" file that runs raw_to_hdr, then  rotate_and_crop on L/Out and R/Out subdirectories

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
# (1) Detect this script location (use surely unique variable name)
set SCRIPT_DIR__raw_to_hdr_rotate_and_crop [file dirname [info script]]

# (2) Tell to look for left images under "L/OUT", right images under "R/OUT"
set SUBDIR_NAME_FOR_CONVERTED_IMAGES "OUT"

# (3) Run the code from "run__raw_to_hdr_on_l_r.tcl" script
source [file join $SCRIPT_DIR__raw_to_hdr_rotate_and_crop "run__raw_to_hdr_on_l_r.tcl"]

# (4) Run the code from "run__rotate_and_crop_on_l_r.tcl" script
source [file join $SCRIPT_DIR__raw_to_hdr_rotate_and_crop "run__rotate_and_crop_on_l_r.tcl"]

################################################################################


