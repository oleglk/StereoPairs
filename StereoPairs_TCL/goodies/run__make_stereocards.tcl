# run__make_stereocards.tcl - a "sourceable" file that runs make_stereocards.tcl on final images' subdirectory

set g_jpegQuality 99;  # 1..100 forces given JPEG quality; 0 leaves to default

################################################################################
## Local procedures
################################################################################

proc get_recommended_sides_ratio {lrOrientSpec sidesRatio}  {
  upvar $sidesRatio ratio
  switch $lrOrientSpec {
    "bd-bd" { set ratio [expr 4.0 / 3.0];   return  1 };  # horizontal
    "br-bl" { set ratio 1.0;                return  1 };  # vertical
    "br-bd" { set ratio 1.0;                return  1 };  # anled
    default { ok_err_msg "Invalid DualCam arrangement '$lrOrientSpec'"
              return  0 }
  }
}


# Reads and applies relevant preferences from DualCam-Companion
proc _set_cards_params_from_preferences {subDirFinal} {
  upvar $subDirFinal dirFinal
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
  if { 0 == [preferences_get_val -final_img_dir dirFinal]} {
    ok_err_msg "Missing preference for final images subdirectory"
    set allApplied 0
  }
  if { 0 == [preferences_get_val -left_img_subdir dirL]} {
    ok_err_msg "Missing preference for left-side images subdirectory"
    set allApplied 0
  }
  if { $allApplied == 1 }  {
    ok_info_msg "Relevant preferences successfully loaded and applied"
    return  1
  } else {
    ok_warn_msg "Relevant preferences were not applied; should use hardcoded values"
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
set SCRIPT_DIR__cards [file dirname [info script]]

# (2) Load the code from "make_stereocards.tcl" script;  imports library utilities too
source [file join $SCRIPT_DIR__cards "make_stereocards.tcl"]
source [file join $SCRIPT_DIR__cards ".." "preferences_mgr.tcl"]
source [file join $SCRIPT_DIR__cards ".." "dir_file_mgr.tcl"]


# (3) Load orientation spec from preferences and decide on rotation and crop parameters
if { 0 == [_set_cards_params_from_preferences subDirFinal] }  {
  return  0;  # error already printed
}


# (4) Execute the main procedure of "make_stereocards.tcl" script
# (the make_stereocards.tcl script knows location of tool-path file in Dualcam-Companion software)
if { 0 == [make_cards_in_current_dir "tif" 6.4 [expr 4.0/3.0]]}   {
  return  0;  # error already printed
}

# (5) Execute the main procedure of "rotate_and_crop.tcl" script in right images' subdirectory
# (location of tool-path file reflects Dualcam-Companion software structure)
if { 0 == [rotate_and_crop_main "-rot_angle $angleR -pad_x $padX -pad_y $padY -crop_ratio $xyRatio -final_depth 8 -inp_dir $subDirR -bu_subdir_name {BU} -img_extensions {JPG TIF} -jpeg_quality $::g_jpegQuality   -tools_paths_file [dualcam_find_toolpaths_file 0]"] }   {
  return  0;  # error already printed
}
################################################################################

return  1;  # success

