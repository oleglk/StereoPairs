# run__rotate_and_crop_on_l_r__horiz.tcl - a "sourceable" file that runs rotate_and_crop.tcl on L/ and R/ subdirectories
### This version assumes the two cameras are horizontal, bottom-down
### Rotation angles (CW): left and right camera  - 0 degrees


################################################################################
## Local procedures
################################################################################

# Reads and applies relevant preferences from DualCam-Companion
proc _set_rotcrop_params_from_preferences {angleL angleR xyRatio padX padY} {
  upvar $angleL angL
  upvar $angleR angR
  upvar $xyRatio xyRat
  upvar $padX pdX
  upvar $padY pdY
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
  if { 0 == [preferences_get_val -lr_cam_orient lrOrientSpec]} {
    ok_err_msg "Missing preference for left- and right cameras' orientations"
    set allApplied 0
  }
  if { 0 == [get_lr_postproc_rotation_angles $lrOrientSpec angL angR] } {
    ok_err_msg "Invalid left- and right cameras' orientation spec '$lrOrientSpec'"
    set allApplied 0
  }
  # decide on crop ratio and pads
  if { (($angL == 0)||($angL == 180)) && (($angR == 0)||($angR == 180)) }   {
    ok_info_msg "Requested horizontal DualCam orientation"
    set xyRat [expr 4.0 / 3]
    set pdX 10;  set pdY 0
  }
  if { (($angL == 90)||($angL == 270)) && (($angR == 90)||($angR == 270)) }   {
    ok_info_msg "Requested vertical DualCam orientation"
    set xyRat 1.0
    set pdX 0;  set pdY 15; # 3mm offset out of 17mm is ~ 18%, and we allow more
  }
  if { ( (($angL == 0)||($angL == 180)) && (($angR == 90)||($angR == 270)) ) \
      || \
       ( (($angR == 0)||($angR == 180)) && (($angL == 90)||($angL == 270)) ) } {
    ok_info_msg "Requested angled DualCam orientation"
    set xyRat 1.0
    set pdX 10;  set pdY 10;  # allow for some disallignment
  }
  if { $allApplied == 1 }  {
    ok_info_msg "Orientation preferences successfully loaded and applied"
    return  1
  } else {
    ok_warn_msg "Orientation preferences were not applied; should use hardcoded values"
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
# (1) Detect "rotate_and_crop.tcl" script location (use surely unique variable name)
set SCRIPT_DIR__rotate_and_crop [file dirname [info script]]

# (2) Load the code from "rotate_and_crop.tcl" script;  imports library utilities too
source [file join $SCRIPT_DIR__rotate_and_crop "rotate_and_crop.tcl"]

# (3) Load orientation spec from preferences and decide on rotation and crop parameters
if { 0 == [_set_rotcrop_params_from_preferences \
                                angleL angleR xyRatio padX padY] {
  return  0;  # error already printed
}

# (4) Execute the main procedure of "rotate_and_crop.tcl" script in L/ subdirectory
# (location of tool-path file reflects Dualcam-Companion software structure)
if { 0 == [rotate_and_crop_main "-rot_angle $angleL -pad_x $padX -pad_y $padY -crop_ratio $xyRatio -final_depth 8 -inp_dir {L} -bu_subdir_name {BU} -img_extensions {JPG TIF}   -tools_paths_file [file join $SCRIPT_DIR__rotate_and_crop ".." ".." ext_tool_dirs.csv]"]}   {
  return  0;  # error already printed
}

# (5) Execute the main procedure of "rotate_and_crop.tcl" script in R/ subdirectory
# (location of tool-path file reflects Dualcam-Companion software structure)
if { 0 == [rotate_and_crop_main "-rot_angle $angle% -pad_x $padX -pad_y $padY -crop_ratio $xyRatio -final_depth 8 -inp_dir {R} -bu_subdir_name {BU} -img_extensions {JPG TIF}  -tools_paths_file [file join $SCRIPT_DIR__rotate_and_crop ".." ".." ext_tool_dirs.csv]"] }   {
  return  0;  # error already printed
}
################################################################################


