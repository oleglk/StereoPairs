# run__rotate_and_crop_on_l_r.tcl - a "sourceable" file that runs rotate_and_crop.tcl on L/ and R/ subdirectories


set g_jpegQuality 99;  # 1..100 forces given JPEG quality; 0 leaves to default

################################################################################
## Local procedures
################################################################################


# Reads and applies relevant preferences from DualCam-Companion
proc _set_rotcrop_params_from_preferences {subDirL subDirR \
                                           angleL angleR xyRatio padX padY} {
  upvar $subDirL dirL;  upvar $subDirR dirR
  upvar $angleL angL;   upvar $angleR angR
  upvar $xyRatio xyRat
  upvar $padX pdX;      upvar $padY pdY
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
  if { 0 == [preferences_get_val -left_img_subdir dirL]} {
    ok_err_msg "Missing preference for left-side images subdirectory"
    set allApplied 0
  }
  if { 0 == [preferences_get_val -right_img_subdir dirR]} {
    ok_err_msg "Missing preference for right-side images subdirectory"
    set allApplied 0
  }
  # decide on crop ratio and pads
  if { 0 == [choose_crop_ratio_and_pads $lrOrientSpec xyRat pdX pdY] }  {
    set allApplied 0;  # error already printed
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
source [file join $SCRIPT_DIR__rotate_and_crop ".." "dir_file_mgr.tcl"]


# (3) Load orientation spec from preferences and decide on rotation and crop parameters
if { 0 == [_set_rotcrop_params_from_preferences \
                          subDirL subDirR angleL angleR xyRatio padX padY] }  {
  return  0;  # error already printed
}



# (4) Detect whether preview-mode requested - through DUALCAM_RAW2HDR_PREVIEW environment variable
# In preview mode no backup is done
if { ([info exists env(DUALCAM_RAW2HDR_PREVIEW)] && \
      ($env(DUALCAM_RAW2HDR_PREVIEW) != 0) && \
      ($env(DUALCAM_RAW2HDR_PREVIEW) != "")) }  {
  set buDirName "BU"
  ok_info_msg "Preview mode - includes backup of images before rotation"
} else {
  set buDirName "NONE"
  ok_info_msg "Ultimate-output mode - no backup of images before rotation"
}


# (5) Execute the main procedure of "rotate_and_crop.tcl" script in left images' subdirectory
# (location of tool-path file reflects Dualcam-Companion software structure)
if { 0 == [rotate_and_crop_main "-rot_angle $angleL -pad_x $padX -pad_y $padY -crop_ratio $xyRatio -final_depth 8 -inp_dir $subDirL -bu_subdir_name $buDirName -img_extensions {JPG TIF} -jpeg_quality $::g_jpegQuality   -tools_paths_file [dualcam_find_toolpaths_file 0]"]}   {
  return  0;  # error already printed
}

# (6) Execute the main procedure of "rotate_and_crop.tcl" script in right images' subdirectory
# (location of tool-path file reflects Dualcam-Companion software structure)
if { 0 == [rotate_and_crop_main "-rot_angle $angleR -pad_x $padX -pad_y $padY -crop_ratio $xyRatio -final_depth 8 -inp_dir $subDirR -bu_subdir_name $buDirName -img_extensions {JPG TIF} -jpeg_quality $::g_jpegQuality   -tools_paths_file [dualcam_find_toolpaths_file 0]"] }   {
  return  0;  # error already printed
}
################################################################################

return  1;  # success

