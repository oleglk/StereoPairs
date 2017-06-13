# run__make_stereocards.tcl - a "sourceable" file that runs make_stereocards.tcl on final images' subdirectory

set g_jpegQuality 99;  # 1..100 forces given JPEG quality; 0 leaves to default

################################################################################
## Local procedures
################################################################################

# Determines width/height ratio for given DualCam arrangement
proc get_recommended_sides_ratio {lrOrientSpec sidesRatio}  {
  upvar $sidesRatio ratio
  switch $lrOrientSpec {
    "bd-bd" { set ratio [expr 4.0 / 3.0];   return  1 }
    "br-bl" { set ratio 1.0;                return  1 }
    "br-bd" { set ratio 1.0;                return  1 }
    default {
      ok_err_msg "Invalid DualCam arrangement '$lrOrientSpec'";   return  0 }
  }
}


# Reads and applies relevant preferences from DualCam-Companion
proc _set_cards_params_from_preferences {subDirFinal sidesRatio} {
  upvar $subDirFinal dirFinal
  upvar $sidesRatio ratio
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
  if { 0 == [preferences_get_val -final_img_dir dirFinal]} {
    ok_err_msg "Missing preference for final images subdirectory"
    set allApplied 0
  }
  if { 0 == [get_recommended_sides_ratio $lrOrientSpec ratio] }  {
    set allApplied 0;  # error already printed; this one is fatal
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
if { 0 == [_set_cards_params_from_preferences subDirFinal sidesRatio] }  {
  return  0;  # error already printed
}

# (4) Change directory to that of the final images
set _oldWD [pwd];  # save the old cwd, cd to 'subDirFinal', restore before return
set _tclResult [catch { set _res [cd $subDirFinal] } _execResult]
if { $_tclResult != 0 } {
  ok_err_msg "Failed changing work directory to '$subDirFinal': $_execResult!"
  return  0
}
ok_info_msg "Success changing work directory to '$subDirFinal'"


# (5) Execute the main procedure of "make_stereocards.tcl" script
# (the make_stereocards.tcl script knows location of tool-path file in Dualcam-Companion software)
set anyExtDone 0
foreach ext {tif jpg} {
  incr anyExtDone [make_cards_in_current_dir $ext 6.4 $sidesRatio]
}

# (6) Return to work-area root directory
set _tclResult [catch { set _res [cd $_oldWD] } _execResult]
if { $_tclResult != 0 } {
  ok_err_msg "Failed restoring work directory to '$_oldWD': $_execResult!"
  return  0
}


# (7) The end - indicate faiure if needed
if { $anyExtDone <= 0 }   {;  # error already printed
  ok_warn_msg "No stereocards created for neither image type"
  return  0
}
################################################################################

return  1;  # success

