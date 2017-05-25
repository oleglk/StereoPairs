# run__rotate_and_crop_on_l_r__horiz.tcl - a "sourceable" file that runs rotate_and_crop.tcl on L/ and R/ subdirectories
### This version assumes the two cameras are horizontal, bottom-down
### Rotation angles (CW): left and right camera  - 0 degrees

set g_cropPreferences [dict create]; # per-arrangement cropping parameters
dict set g_cropPreferences Horizontal  xyRat [expr 4.0 / 3]
dict set g_cropPreferences Horizontal  pdX   10
dict set g_cropPreferences Horizontal  pdY   0
dict set g_cropPreferences Vertical    xyRat 1.0
dict set g_cropPreferences Vertical    pdX   0
dict set g_cropPreferences Vertical    pdY   15
dict set g_cropPreferences Angled      xyRat 1.0
dict set g_cropPreferences Angled      pdX   10
dict set g_cropPreferences Angled      pdY   10


################################################################################
## Local procedures
################################################################################

# Retrieves rotation and cropping parameters for known DualCam arrangement
# 'lrArrangement' = Horizontal|Vertical|Angled
proc _get_rotcrop_params_for_cam_arrangement {lrArrangement xyRatio padX padY} {
  upvar $xyRatio xyRat
  upvar $padX pdX
  upvar $padY pdY
  global g_cropPreferences
  if { 0 == [dict exists $g_cropPreferences $lrArrangement] }  {
    ok_err_msg "Invalid DualCam arrangement '$lrArrangement'; should be one of {[dict keys $g_cropPreferences]}"
    return  0
  }
  set xyRat [dict get $g_cropPreferences $lrArrangement   xyRat ]
  set pdX   [dict get $g_cropPreferences $lrArrangement   pdX   ]
  set pdY   [dict get $g_cropPreferences $lrArrangement   pdY   ]
  return  1
}


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
  } else {
    ok_info_msg "DualCam orientation: $lrOrientSpec; rotation needed: left->$angL, right->$angR"
  }
  # decide on crop ratio and pads
  if { (($angL == 0)||($angL == 180)) && (($angR == 0)||($angR == 180)) }   {
    ok_info_msg "Requested horizontal DualCam orientation"
    _get_rotcrop_params_for_cam_arrangement "Horizontal" xyRat pdX pdY
  }
  if { (($angL == 90)||($angL == 270)) && (($angR == 90)||($angR == 270)) }   {
    ok_info_msg "Requested vertical DualCam orientation"
    _get_rotcrop_params_for_cam_arrangement "Vertical" xyRat pdX pdY
  }
  if { ( (($angL == 0)||($angL == 180)) && (($angR == 90)||($angR == 270)) ) \
      || \
       ( (($angR == 0)||($angR == 180)) && (($angL == 90)||($angL == 270)) ) } {
    ok_info_msg "Requested angled DualCam orientation"
    _get_rotcrop_params_for_cam_arrangement "Angled" xyRat pdX pdY
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
source [file join $SCRIPT_DIR__rotate_and_crop ".." "preferences_mgr.tcl"]

# (3) Load orientation spec from preferences and decide on rotation and crop parameters
if { 0 == [_set_rotcrop_params_from_preferences \
                                angleL angleR xyRatio padX padY] }  {
  return  0;  # error already printed
}

# (4) Execute the main procedure of "rotate_and_crop.tcl" script in L/ subdirectory
# (location of tool-path file reflects Dualcam-Companion software structure)
if { 0 == [rotate_and_crop_main "-rot_angle $angleL -pad_x $padX -pad_y $padY -crop_ratio $xyRatio -final_depth 8 -inp_dir {L} -bu_subdir_name {BU} -img_extensions {JPG TIF}   -tools_paths_file [file join $SCRIPT_DIR__rotate_and_crop ".." ".." ext_tool_dirs.csv]"]}   {
  return  0;  # error already printed
}

# (5) Execute the main procedure of "rotate_and_crop.tcl" script in R/ subdirectory
# (location of tool-path file reflects Dualcam-Companion software structure)
if { 0 == [rotate_and_crop_main "-rot_angle $angleR -pad_x $padX -pad_y $padY -crop_ratio $xyRatio -final_depth 8 -inp_dir {R} -bu_subdir_name {BU} -img_extensions {JPG TIF}  -tools_paths_file [file join $SCRIPT_DIR__rotate_and_crop ".." ".." ext_tool_dirs.csv]"] }   {
  return  0;  # error already printed
}
################################################################################


