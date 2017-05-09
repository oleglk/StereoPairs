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



# Rotates and/or crops image 'imgPath';
#   if 'buDir' given, the original image placed into it.
# 'rotAngle' could be 0, 90, 180 or 270; means clockwise.
proc ::img_proc::rotate_crop_one_img {imgPath rotAngle cropRatio buDir} {
  set imgName [file tail $imgPath]
  if { ($rotAngle != 0) && ($rotAngle != 90) && \
       ($rotAngle != 180) && ($rotAngle != 270) }  {
    ok_err_msg "Permitted rotation angles are 0, 90, 180, 270 (clockwise)"
    return 0
  }
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
  if { ($rotAngle == 0) || ($rotAngle == 180) }  {
            set rWd $width; set rHt $height
  } else {  set rWd $height; set rHt $width
  }
  set minSide [expr min($rWd, $rHt)]
  if {       ($cropRatio >= 1) && ($rWd >= [expr $rHt * $cropRatio]) }  {
    set cropWd [expr $rHt * $cropRatio];    set cropHt $rHt
  } elseif { ($cropRatio >= 1) && ($rWd <  [expr $rHt * $cropRatio]) }  {
    set cropWd $rWd;    set cropHt [expr 1.0* $rWd / $cropRatio]
  } elseif { ($cropRatio < 1) && ($rHt >= [expr 1.0* $rWd / $cropRatio])} {
    set cropWd $rWd;    set cropHt [expr 1.0* $rWd / $cropRatio]
  } elseif { ($cropRatio < 1) && ($rHt <  [expr 1.0* $rWd / $cropRatio])} {
    set cropWd [expr $rHt * $cropRatio];    set cropHt $rHt
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
