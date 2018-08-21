# run__preview_raw_to_hdr_rotate_and_crop.tcl - a "sourceable" file that runs raw_to_hdr in preview mode, then  rotate_and_crop on L/Out and R/Out subdirectories

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

# (2) Request preview-mode - through DUALCAM_RAW2HDR_PREVIEW environment variable
set env(DUALCAM_RAW2HDR_PREVIEW)  1

# (3) Run the code from "run__raw_to_hdr_on_l_r.tcl" script
if { 1 == [source [file join $SCRIPT_DIR__raw_to_hdr_rotate_and_crop "run__raw_to_hdr_on_l_r.tcl"]] } {
# ... getting here only if RAW conversion was successfull ...

# (4) Run the code from "run__rotate_and_crop_on_l_r.tcl" script
  set res [source [file join $SCRIPT_DIR__raw_to_hdr_rotate_and_crop "run__rotate_and_crop_on_l_r.tcl"]]
} else {
  set res 0;  # failure
}

# (5) Cleanup - remove DUALCAM_RAW2HDR_PREVIEW environment variable
unset env(DUALCAM_RAW2HDR_PREVIEW)
################################################################################

return  $res
