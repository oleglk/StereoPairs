# image_manip.tcl
# Copyright (C) 2016 by Oleg Kosyakovsky
global OK_TCLSRC_ROOT
if { [info exists OK_TCLSRC_ROOT] } {;   # assume running as a part of LazyConv
    source $OK_TCLSRC_ROOT/lzc_beta_license.tcl
    package provide img_proc 0.1
}


namespace eval ::img_proc:: {
    namespace export                          \
      rotate_crop_one_img                     \
}

set SCRIPT_DIR [file dirname [info script]]
package require ok_utils;   namespace import -force ::ok_utils::*

set UTIL_DIR [file dirname [info script]]
ok_trace_msg "---- Sourcing '[info script]' in '$UTIL_DIR' ----"
source [file join $UTIL_DIR ".." "ext_tools.tcl"]



# Rotates and/or crops image 'imgPath'; if 'buDir' given, the original image placed into it.
proc ::img_proc::rotate_crop_one_img {imgPath rotAngle cropRatio buDir} {
  set imgName [file tail $imgPath]
  if { $buDir != "" } {
    if { 0 == [file exists $buDir]  }  {  file mkdir $buDir  }
    set buPath  [file join $buDir "[file rootname $imgName].TIF"]
    if { 0 == [ok_filepath_is_writable $buPath] }  {
      ok_err_msg "Cannot write into '$buPath'";    return 0
    }
    if { 0 == [ok_safe_copy_file $imgPath $buDir] }  {
      return 0;   # error already printed
    }
  }
  if { 0 == [get_image_dimensions_by_imagemagick $imgPath width height] }  {
    return  0;  # error already printed
  }
  set minSide [expr min($width, $height)]
  if {       ($cropRatio >= 1) && ($width >= [expr $height * $cropRatio]) }  {
    set cropWd [expr $height * $cropRatio];    set cropHt $height
  } elseif { ($cropRatio >= 1) && ($width <  [expr $height * $cropRatio]) }  {
    set cropWd $width;    set cropHt [expr 1.0* $width / $cropRatio]
  } elseif { ($cropRatio < 1) && ($height >= [expr 1.0* $width / $cropRatio])} {
    set cropWd $width;    set cropHt [expr 1.0* $width / $cropRatio]
  } elseif { ($cropRatio < 1) && ($height <  [expr 1.0* $width / $cropRatio])} {
    set cropWd [expr $height * $cropRatio];    set cropHt $height
  }
  set rotateSwitches "-rotate $rotAngle"
  set cropSwitches [format "-gravity center -crop %dx%d" $cropWd $cropHt]
  ok_info_msg "Start rotating and/or cropping '$imgPath' (new-width=$cropWd, new-height=$cropHt) ..."
  set cmdListRotCrop [concat $::_IMMOGRIFY  $rotateSwitches  +repage \
                                            $cropSwitches    +repage \
                                            $::g_convertSaveParams  $imgPath]
  if { 0 == [ok_run_silent_os_cmd $cmdListRotCrop] }  {
    return  0; # error already printed
  }

	ok_info_msg "Done rotating and/or cropping '$imgPath'"
  return  1
}
