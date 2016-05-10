# image_pixel_data.tcl
# Copyright (C) 2016 by Oleg Kosyakovsky
global OK_TCLSRC_ROOT
if { [info exists OK_TCLSRC_ROOT] } {;   # assume running as a part of LazyConv
    source $OK_TCLSRC_ROOT/lzc_beta_license.tcl
    package provide img_proc 0.1
}


namespace eval ::img_proc:: {
    namespace export                          \
      read_pixel_color_by_imagemagick         \
      read_channel_statistics_by_imagemagick
}


package require ok_utils
namespace import -force ::ok_utils::*

set UTIL_DIR [file dirname [info script]]
ok_trace_msg "---- Sourcing '[info script]' in '$UTIL_DIR' ----"
source [file join $UTIL_DIR ".." "ext_tools.tcl"]


# Puts into 'brightness' the EXIF brightness value of 'fullPath'
# The input is a standard image, not RAW.
# Returns 1 on success, 0 on error.
# Imagemagick "convert" invocation:
# 	$::_IMCONVERT <filename> -quiet -format "%[pixel: u.p{<x>,<y>}]" info: 
proc ::img_proc::read_pixel_color_by_imagemagick {fullPath x y color} {
  upvar $color cVal
  if { ![file exists $fullPath] || ![file isfile $fullPath] } {
    ok_err_msg "Invalid image path '$fullPath'"
    return  0
  }
  set nv_fullPath [file nativename $fullPath]
  #set pixelSpec [format {%%[pixel: u.p{%d,%d}]} $x $y]
  set tclExecResult [catch {
	# Open a pipe to the program
	#   set io [open "|convert -format \"\%[pixel: u.p{$x,$y}]\" $fullPath" r]
    set io [eval [list open [format \
                    {|%s {%s} -quiet -format "%%[pixel: u.p{%d,%d}]" info:} \
                    $::_IMCONVERT $nv_fullPath $x $y] r]]
      set len [gets $io line];	# Get the reply
    close $io
  } execResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "$execResult!"
    ok_err_msg "Cannot get pixel color at $x,$y of '$fullPath'"
    return  0
  }
  # $line should be: "<color>"
  if { $len == -1 } {
    ok_err_msg "Cannot get pixel color at $x,$y of '$fullPath'"
    return  0
  }
  # ok_trace_msg "{pixel color at $x,$y} of $fullPath = $line"
  set cVal [string trim $line]
  if { $cVal == "" } {
    ok_err_msg "Cannot get pixel color at $x,$y of '$fullPath'"
	  return  0
  }
  ok_trace_msg "Pixel color at $x,$y of $fullPath: $cVal"
  return  1
}


proc ::img_proc::read_channel_statistics_by_imagemagick {fullPath \
                                                          meanR meanG meanB} {
  upvar $meanR mR
  upvar $meanG mG 
  upvar $meanB mB
  if { ![file exists $fullPath] || ![file isfile $fullPath] } {
    ok_err_msg "Invalid image path '$fullPath'"
    return  0
  }
  set nv_fullPath [file nativename $fullPath]
  # example:  convert DSC00454_44-56_s060b94g090.TIF -scale 1024x1024 tif:- |convert - -format "%[colorspace]\n%[fx:mean.r]\n%[fx:mean.g]\n%[fx:mean.b]\n%[fx:mean]" info:
  set tclExecResult [catch {
	# Open a pipe to the program; NOTE "| %s" - SPACE AFTER CONVEYER PIPE
    set io [eval [list open [format \
                    {|%s {%s} -quiet -scale 1024x1024 tif:- \
                    | %s - -format "%%[colorspace] %%[fx:mean.r] %%[fx:mean.g] %%[fx:mean.b] %%[fx:mean]" info:} \
                    $::_IMCONVERT $nv_fullPath $::_IMCONVERT] r]]
    set len [gets $io line];	# Get the reply
    close $io
  } execResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "$execResult!"
    ok_err_msg "Cannot get channel statistics of '$fullPath'"
    return  0
  }
  # $line should be: "RGB <meanR> <meanG> <meanB> <mean>"
  if { $len == -1 } {
    ok_err_msg "Cannot get channel statistics of '$fullPath'"
    return  0
  }
  ok_trace_msg "channel statistics of $fullPath = $line"
  #~ set cVal [string trim $line]
  #~ if { $cVal == "" } {
    #~ ok_err_msg "Cannot get pixel color at $x,$y of '$fullPath'"
	  #~ return  0
  #~ }
  #~ ok_trace_msg "Pixel color at $x,$y of $fullPath: $cVal"
  return  1
}
