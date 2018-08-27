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

# (2) Run the code from "run__raw_to_hdr_on_l_r.tcl" script
if { 1 == [source [file join $SCRIPT_DIR__raw_to_hdr_rotate_and_crop "run__raw_to_hdr_on_l_r.tcl"]] } {
# ... getting here only if RAW conversion was successfull ...

# (3) Run the code from "run__rotate_and_crop_on_l_r.tcl" script
  set res [source [file join $SCRIPT_DIR__raw_to_hdr_rotate_and_crop "run__rotate_and_crop_on_l_r.tcl"]]
} else {
  set res 0;  # failure
}
################################################################################

return  $res
