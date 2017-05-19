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
#   if 'buDir' given, the original image placed into it (unless already there).
# 'rotAngle' could be 0, 90, 180 or 270; means clockwise.
# EXIF orientation tag is ignored!
# 'padX'/'padY' == horizontal/vertical padding in % - after rotate
# 'cropRatio' == width/height
# 'bgColor' tells background color - in IM covention
# 'imSaveParams' tells output compression and quality; should match input type.
proc ::img_proc::rotate_crop_one_img {imgPath rotAngle padX padY cropRatio \
                                      bgColor imSaveParams buDir} {
  set imgName [file tail $imgPath]
  if { ($rotAngle != 0) && ($rotAngle != 90) && \
       ($rotAngle != 180) && ($rotAngle != 270) }  {
    ok_err_msg "Permitted rotation angles are 0, 90, 180, 270 (clockwise)"
    return 0
  }
  if { $buDir != "" } {
    if { 0 == [ok_create_absdirs_in_list [list $buDir]] }  {
      ok_err msg "Failed creating backup directory '$buDir'"
      return  0
    }
    if { 0 == [ok_copy_file_if_target_inexistent $imgPath $buDir 0] }  {
      return 0;   # error already printed
    }
  }
  if { 0 == [get_image_dimensions_by_imagemagick $imgPath width height] }  {
    return  0;  # error already printed
  }
  if { ($rotAngle == 0) || ($rotAngle == 180) }  {
            set rWd $width; set rHt $height ;   # orientation preserved
  } else {  set rWd $height; set rHt $width ;   # orientation changed
  }
  set rpWd [expr {int((100+$padX) * $rWd / 100.0)}]; # width  with pad
  set rpHt [expr {int((100+$padY) * $rHt / 100.0)}]; # height with pad
  if {       ($cropRatio >= 1) && ($rpWd >= [expr $rpHt * $cropRatio]) }  {
    # horizontal; limited by height
    set cropWd [expr int($rpHt * $cropRatio)];    set cropHt $rpHt
  } elseif { ($cropRatio >= 1) && ($rpWd <  [expr $rpHt * $cropRatio]) }  {
    # horizontal; limited by width
    set cropWd $rpWd;    set cropHt [expr int($rpWd / $cropRatio)]
  } elseif { ($cropRatio < 1) && ($rpHt >= [expr $rpWd / $cropRatio])} {
    # vertical; limited by width
    set cropWd $rpWd;    set cropHt [expr int($rpWd / $cropRatio)]
  } elseif { ($cropRatio < 1) && ($rpHt <  [expr $rpWd / $cropRatio])} {
    # vertical; limited by height
    set cropWd [expr int($rpHt * $cropRatio)];    set cropHt $rpHt
  }
  set rotateSwitches "-orient undefined -rotate $rotAngle"
  set extentSwitches [expr {(($padX==0) && ($padY==0))? "" \
                                  : [format "-extent %dx%d" $rpWd $rpHt]}]
  set cropSwitches [format "-gravity center -crop %dx%d+0+0" $cropWd $cropHt]
  ok_info_msg "Start rotating and/or cropping '$imgPath' (rotation=$rotAngle, new-width=$cropWd, new-height=$cropHt) ..."
  set cmdListRotCrop [concat $::_IMMOGRIFY  -background $bgColor            \
                        $rotateSwitches  +repage  $extentSwitches  +repage  \
                        $cropSwitches    +repage  $imSaveParams  $imgPath]
  if { 0 == [ok_run_silent_os_cmd $cmdListRotCrop] }  {
    return  0; # error already printed
  }

	ok_info_msg "Done rotating and/or cropping '$imgPath'"
  return  1
}
