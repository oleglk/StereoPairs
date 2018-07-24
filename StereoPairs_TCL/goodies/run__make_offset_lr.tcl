# run__make_offset_lr.tcl - a "sourceable" file that runs make_offset_lr.tcl on final images' subdirectory

# TODO: move out-dir upwards - not under SBS/

################################################################################
## Configuration parameters for 'make_offset_lr' command line
################################################################################
# Picture-related command-line parameters:
set imgParams "-screen_width 2560 -screen_height 1440 -offset 200 -gamma 0.85"
# Image-file-related command-line parameters:
set fileParams "-img_extensions {TIF JPG} -suffix_left _L -suffix_right _R -jpeg_quality 95"
################################################################################


################################################################################
## Local procedures
################################################################################


#TODO: study the issue of unsetting ::STS !!!
# Reads and applies relevant preferences from DualCam-Companion
# Here we need only subdirectory with final images
proc _set_projection_params_from_preferences {subDirFinal} {
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
source [file join $SCRIPT_DIR__cards "make_offset_lr.tcl"]
source [file join $SCRIPT_DIR__cards ".." "preferences_mgr.tcl"]
source [file join $SCRIPT_DIR__cards ".." "dir_file_mgr.tcl"]


# (3) Load orientation spec and location of final images from preferences
#     and decide on sides ratio
if { 0 == [_set_projection_params_from_preferences subDirFinal] }  {
  return  0;  # error already printed
}

# (4) Take work-area root directory as the base for output directory names:
###### <work-area-root>__OFFLR/CANV_L  and  <work-area-root>__OFFLR/CANV_R
# Current dir should be the work-area root, but then we descend 1 level (into SBS)
set workAreaRootDirName [lindex [file split [pwd]] end]
ok_info_msg "Work-area root directory name is '$workAreaRootDirName'"
set outDirRootName [format "%s__PROJ" $workAreaRootDirName]
set outdirPathPref [file join ".." "PROJ_LR" $outDirRootName]
################ TODO #############################

# (5) Change directory to that of the final images
set _oldWD [pwd];  # save the old cwd, cd to 'subDirFinal', restore before return
set _tclResult [catch { set _res [cd $subDirFinal] } _execResult]
if { $_tclResult != 0 } {
  ok_err_msg "Failed changing work directory to '$subDirFinal': $_execResult!"
  return  0
}
ok_info_msg "Success changing work directory to '$subDirFinal'"


# (6) Execute the main procedure of "make_offset_lr.tcl" script
# TODO: ? where tool-path-file is expected: relative to script location ?
set nProcessed [make_offset_lr "$imgParams $fileParams                        \
                            -tools_paths_file [dualcam_find_toolpaths_file 0] \
                            -outdir_name_prefix $outdirPathPref               \
                            -suffix_left _L -suffix_right _R -jpeg_quality 95"]


# (7) Return to work-area root directory
set _tclResult [catch { set _res [cd $_oldWD] } _execResult]
if { $_tclResult != 0 } {
  ok_err_msg "Failed restoring work directory to '$_oldWD': $_execResult!"
  return  0
}


# (8) The end - indicate faiure if needed
if { $nProcessed <= 0 }   {;  # error already printed
  ok_warn_msg "No stereopairs processed for neither image type"
  return  0
}
################################################################################

return  1;  # success

