# make_offset_lr.tcl - offset separate L/R images onto fixed size canvas for POLARIZED projection

# TODO: have dir-name-base parameter



set SCRIPT_DIR__offset [file dirname [info script]]

# TODO: make locally arrangements to find the package(s) instead
# TODO: for instance use the setup file from StereoPairs if found in ../
source [file join $SCRIPT_DIR__offset "setup_goodies.tcl"]

package require ok_utils;   namespace import -force ::ok_utils::*
package require img_proc;   namespace import -force ::img_proc::*

ok_trace_msg "---- Sourcing '[info script]' in '$SCRIPT_DIR__offset' ----"
source [file join $SCRIPT_DIR__offset ".." "ext_tools.tcl"]
source [file join $SCRIPT_DIR__offset ".." "dir_file_mgr.tcl"]


################################################################################
#~ @REM ******* Input: SBS ************
#~ @REM Offset separate L/R images onto fixed size canvas for POLARIZED projection
#~ @REM Left is right-offset; right is left-offset
#~ @REM the ultimate size for Nierbo MAX500 (native from memory 1280x800) = 2560x1600
#~ @REM Experimentally chosen offset for Nierbo MAX500 == 250 pixels on each side
#~ @REM the ultimate size for AAXA Pico HD (native from memory 1280x720) = 2560x1440
#~ @REM Experimentally chosen offset for AAXA Pico HD == 200 pixels on each side for 2560x1440
#~ @REM Offset for straight 1280x720 picture would be 100 pixels
#~ set WIDTH=2560
#~ set HEIGHT=1440
#~ md CANV_L
#~ md CANV_R
#~ set "_CROP_LEFT=-gravity west -crop 50%x100%+0+0"
#~ set "_CROP_RIGHT=-gravity east -crop 50%x100%+0+0"
#~ set _OFFSET_BASE=-resize %HEIGHT%x%HEIGHT% -background black -gravity center -extent %WIDTH%x%HEIGHT%
#~ set _LEVEL_BASE=-level 0%,100%
#~ @REM for /L %z IN (100,50,350) DO (
#~ @REM for /L %z IN (100,100,200) DO (
#~ set z=200
#~ set g=0.85
#~ @REM for /L %g IN (0.8,0.1,1.0) DO (
  #~ md CANV_L\G%g%_OFF%z%
  #~ md CANV_R\G%g%_OFF%z%
  #~ for %f in (*.bmp,*.tif) DO (
    #~ @REM set _OFFSET_RIGHT=%_OFFSET_BASE%+%x%+0
    #~ @REM set _OFFSET_LEFT=%_OFFSET_BASE%-%x%-0
    #~ convert %f %_CROP_LEFT%  %_OFFSET_BASE%-%z%-0 %_LEVEL_BASE%,%g% -quality 98 CANV_L\G%g%_OFF%z%\%~nf_G%g%_L.JPG
    #~ convert %f %_CROP_RIGHT% %_OFFSET_BASE%+%z%+0 %_LEVEL_BASE%,%g% -quality 98 CANV_R\G%g%_OFF%z%\%~nf_G%g%_R.JPG
  #~ )
#~ @REM )
################################################################################


################################################################################

proc _make_offset_lr_set_defaults {}  {
  set ::STS(toolsPathsFile)   "" ;  # full path or relative to this script
  set ::STS(outDirNamePrefix) "" ;  # if given, dirNameY=<outDirNamePrefix><suffixY>
  set ::STS(dirL)             "CANV_L" ;  # only used if outDirNamePrefix not given
  set ::STS(dirR)             "CANV_R" ;  # only used if outDirNamePrefix not given
  set ::STS(suffixL)          "_L"
  set ::STS(suffixR)          "_R"
  set ::STS(extList)          ""
  set ::STS(canvWd)           ""
  set ::STS(canvHt)           ""
  set ::STS(offset)           ""
  set ::STS(gamma)            ""
  set ::STS(forceJpegQuality) 100
  #set ::STS() ""
}
################################################################################
_make_offset_lr_set_defaults ;  # load only;  do call it in a function for repeated invocations
################################################################################


# Splits all stereopairs in the current working directory
# into left- and right images, each horizontally offset on its canvas
# (left images are offset to the right, right images are offset to the left)
# On success returns number of processed stereopairs, on error returns 0.
## Example:
##  cd e:/Photo_Publish/Stereo/TMP/;  make_offset_lr "-screen_width 2560 -screen_height 1440 -offset 200 -gamma 0.85 -img_extensions {TIF JPG} -tools_paths_file ../ext_tool_dirs.csv -outdir_name_prefix OUT -suffix_left _L -suffix_right _R -jpeg_quality 95"
proc make_offset_lr {cmdLineAsStr}  {
  global SCRIPT_DIR
  _make_offset_lr_set_defaults ;  # calling it in a function for repeated invocations
  if { 0 == [offset_lr_cmd_line $cmdLineAsStr cml] }  {
    return  0;  # error or help already printed
  }  
  if { 0 == [_read_and_check_ext_tool_paths] }  {
    return  0;   # error already printed
  }
  if { 0 == [set nGood [make_offset_lr_in_current_dir $::STS(extList) \
                $::STS(canvWd) $::STS(canvHt) $::STS(offset) $::STS(gamma)]] } {
    return  0;  # error already printed
  }
  return  $nGood
}


# extList - list of originals' extensions (typical: {TIF BMP JPG})
# canvWd/canvHt (pix) = canvas width/height - multiple of projector resolutiuon
# offset (pix) - horizontal shift of L|R image - left rightwards, right leftwards
# gamma - gamma correction value (typical: 0.8).
# On success returns number of processed stereopairs, on error returns 0.
# Example:  cd e:/Photo_Publish/Stereo/TMP/;  make_offset_lr_in_current_dir {TIF JPG} 2560 1440 200 0.8
proc make_offset_lr_in_current_dir {extList canvWd canvHt offset gamma}  {
  set origPathList [_find_originals_in_current_dir $extList]
  if { 0 == [llength $origPathList] }  {
    return  0;  # error already printed
  }
  if { 0 == [set geomL [_make_geometry_command_for_one_side "L"   \
            $canvWd $canvHt $offset]] }  { return  0 };  # error already printed
  if { 0 == [set geomR [_make_geometry_command_for_one_side "R"   \
            $canvWd $canvHt $offset]] }  { return  0 };  # error already printed
  if { 0 == [set colorL [_make_color_correction_command_for_one_side "L"   \
            $gamma]] }                   { return  0 };  # error already printed
  if { 0 == [set colorR [_make_color_correction_command_for_one_side "R"   \
            $gamma]] }                   { return  0 };  # error already printed
  # everything is ready; now start making changes on the disk
  if { 0 == [_prepare_output_dirs leftDirPath rightDirPath] }  {
    return  0;   # error already printed
  }
  set nGood [_split_offset_listed_stereopairs $origPathList $geomL $geomR \
                          $colorL $colorR $leftDirPath $rightDirPath]
  return  $nGood
}


proc offset_lr_cmd_line {cmdLineAsStr cmlArrName}  {
  upvar $cmlArrName      cml
  # create the command-line description
  set descrList \
[list \
  -help {"" "print help"}                                                      \
  -tools_paths_file {val	"(for standalone run) path of CSV file with external tool locations - absolute or relative to this script; example: ../ext_tool_dirs.csv"} \
  -outdir_name_prefix {val	"prefix for the names of subdirectories for output left/right images"} \
  -suffix_left  {val	"suffix for output left  images' names"} \
  -suffix_right {val	"suffix for output right images' names"} \
  -img_extensions {list "list of extensions of input image files; example: {jpg bmp}"}                      \
  -screen_width  {val "image width  with border - in pixels - multiple of projector's horizontal resolution"} \
  -screen_height {val "image height with border - in pixels - multiple of projector's vertical   resolution"} \
  -offset {val	"offset of each image from the screen center - in pixels"} \
  -gamma   {val "gamma correction to apply"}  \
  -jpeg_quality {val "JPEG file-saving quality (1..100); 0 (default) means auto"} \
 ]
  array unset cmlD
  ok_new_cmd_line_descr cmlD $descrList
  # create dummy command line with the default parameters and copy it
  # (if an argument inexistent by default, don't provide dummy value)
  array unset defCml
  ok_set_cmd_line_params defCml cmlD {                                        \
    {-suffix_left "_L"} {-suffix_right "_R"} {-gamma 1.0} {-jpeg_quality "98"} }
  ok_copy_array defCml cml;    # to preset default parameters
  # now parse the user's command line
  if { 0 == [ok_read_cmd_line $cmdLineAsStr cml cmlD] } {
    ok_err_msg "Aborted because of invalid command line";	return  0
  }
  if { [info exists cml(-help)] } {
    set cmdHelp [ok_help_on_cmd_line defCml cmlD "\n"]
    ok_info_msg "================================================================"
    ok_info_msg "Splitting stereopairs into L/R images with horizontal offfset."
    ok_info_msg " (intended for passive 3D polarized projection)"
    ok_info_msg "========= Command line parameters (in random order): ==========="
    ok_info_msg $cmdHelp
    ok_info_msg "================================================================"
    ok_info_msg "  (note TCL-style directory separators in the examples below)"
    ok_info_msg "================= Example 1 - short: ==========================="
    ok_info_msg " make_offset_lr \"-screen_width 2560 -screen_height 1440 -offset 200 -img_extensions {TIF} -tools_paths_file ../ext_tool_dirs.csv\""
    ok_info_msg "================================================================"
    ok_info_msg "================= Example 2 - full: ============================"
    ok_info_msg " make_offset_lr \"-screen_width 3840 -screen_height 2160 -offset 200 -gamma 0.85 -img_extensions {TIF JPG} -tools_paths_file ../ext_tool_dirs.csv -subdir_left L -subdir_right R -suffix_left _L -suffix_right _R -jpeg_quality 95\""
    ok_info_msg "================================================================"
    return  0
  }
  if { 0 == [_offset_lr_parse_cmdline cml] }  {
    ok_err_msg "Error(s) in command parameters. Aborting..."
    return  0
  }
  set cmdStrNoHelp [ok_cmd_line_str cml cmlD "\n" 0]

  ok_info_msg "==== Now run offset-lr by the following spec: ===="
  ok_info_msg "==== \n$cmdStrNoHelp\n===="
  return  1
}


proc _read_and_check_ext_tool_paths {}  {
  if { 0 == [set extToolPathsFilePath [dualcam_find_toolpaths_file 0]] }   {
    #standalone invocaion
    set extToolPathsFilePath $::STS(toolsPathsFile)
  }
  if { 0 == [set_ext_tool_paths_from_csv $extToolPathsFilePath] }  {
    return  0;  # error already printed
  }
  if { 0 == [verify_external_tools] }  { return  0  };  # error already printed
  return  1
}


# Builds and returns list of original image file-paths
proc _find_originals_in_current_dir {extList}  {
  set origPathList [list]
  foreach ext $extList {
    set imgPattern  [file join [pwd] "*.$ext"]
    if { 0 == [set imgFiles [glob -nocomplain $imgPattern]] }  {
      ok_info_msg "No input images to match '$imgPattern'";    continue
    }
    set origPathList [concat $origPathList $imgFiles]
  }
  if { 0 == [llength $origPathList] }  {
    ok_err_msg "No input images ($extList) found in directory '[pwd]'"
  } else {
    ok_info_msg "Found [llength $origPathList] input image(s) in directory '[pwd]'"
  }
  return  $origPathList
}


proc _prepare_output_dirs {leftDirPath rightDirPath}  {
  upvar $leftDirPath  dirL
  upvar $rightDirPath dirR
  if { 0 == [ok_create_absdirs_in_list \
        [list $::STS(dirL) $::STS(dirR)] \
        {"folder-for-left-images" "folder-for-right-images"}] }  {
  return  0
  }
  set dirL $::STS(dirL);   set dirR $::STS(dirR)
  return  1
}


# Builds and returns Imagemagick geometry-related arguments
# for left- or right-side image. On error returns 0.
proc _make_geometry_command_for_one_side {lOrR canvWd canvHt offset}  {
  set lOrR [string toupper $lOrR]
  if { ($lOrR != "L") && ($lOrR != "R") } {
    ok_err_msg "Side is L or R; got '$lOrR'";    return  0
  }
  set cropDict [dict create \
    "L"   "-gravity west -crop 50%x100%+0+0"  \
    "R"   "-gravity east -crop 50%x100%+0+0"  ]
  set offsetBase [format                                                      \
              "-resize %dx%d -background black -gravity center -extent %dx%d" \
              $canvHt $canvHt $canvWd $canvHt]
  set offsetDict [dict create \
    "L"   "$offsetBase-$offset-0"  \
    "R"   "$offsetBase+$offset+0"  ]
  set geomCmd [format "%s  %s"  \
                        [dict get $cropDict $lOrR] [dict get $offsetDict $lOrR]]
  return  $geomCmd
}


proc _make_color_correction_command_for_one_side {lOrR gamma}  {
  set lOrR [string toupper $lOrR]
  if { ($lOrR != "L") && ($lOrR != "R") } {
    ok_err_msg "Side is L or R; got '$lOrR'";    return  0
  }
  set levelBase "-level 0%,100%"
  set levelDict [dict create    \
    "L"   "$levelBase,$gamma"   \
    "R"   "$levelBase,$gamma"   ]
  set colorCmd [dict get $levelDict $lOrR]
  return  $colorCmd
}


# Makes separate left-and right images for each original in 'origPathList'.
# Applies to output images geometrical-transform and color-correction commands.
# Returns the number of succesfully processed images.
proc _split_offset_listed_stereopairs {origPathList geomL geomR colorL colorR \
                                        leftDirPath rightDirPath} {
  set cntErr 0
  foreach imgPath $origPathList {
    if { 0 == [_make_image_for_one_side  \
        $imgPath $geomL $colorL $leftDirPath  $::STS(suffixL)] }  { incr cntErr 1 }
    if { 0 == [_make_image_for_one_side  \
        $imgPath $geomR $colorR $rightDirPath $::STS(suffixR)] }  { incr cntErr 1 }
  }
  set n [llength $origPathList];  set nGood [expr $n - $cntErr]
  if { $cntErr == 0 }   {
    ok_info_msg "Processed all $n stereopair(s); no errors occured"
  } else                {
    set msg "Processed $n stereopair(s); $cntErr error(s) occured"
    if { $cntErr == $n }  { ok_err_msg $msg } else { ok_warn_msg $msg }
  }
  return  $nGood
}


# Extracts one side of stereopair using 'geomCmd',
#   applies processing in 'colorCmd', saves as JPEG in directory 'outDirPath'.
# Returns 1 on success, 0 on error.
proc _make_image_for_one_side {imgPath geomCmd colorCmd outDirPath suffix} {
    set imgNameNoExt    [file rootname [file tail $imgPath]]
    set outImgNameNoExt [ok_insert_suffix_into_filename $imgNameNoExt $suffix]
    set outImgPath [file join $outDirPath "$outImgNameNoExt.JPG"]
    set descr "extracting one side from stereopair '$imgPath' into '$outImgPath'"
    set nv_inpImg [format "{%s}" [file nativename $imgPath]]
    set nv_outImg [format "{%s}" [file nativename $outImgPath]]
    lappend nv_outImagesAsList $nv_outImg
    set cmdList [concat $::_IMCONVERT $nv_inpImg $geomCmd $colorCmd \
                   -density 300 -depth 8 -quality 98 $nv_outImg]
    ok_info_msg "Next command: '$cmdList'"
    if { 0 == [ok_run_silent_os_cmd $cmdList] }  {
      ok_err_msg "Failed $descr";      return  0
    }
    ok_info_msg "Success $descr"
    return  1
}


proc _offset_lr_parse_cmdline {cmlArrName}  {
  upvar $cmlArrName      cml
  set errCnt 0
  if { 0 == [info exists cml(-tools_paths_file)] }  {
    ok_info_msg "No explicit path of CSV file with external tool locations given; assume running from DualCam-Companion"
    incr errCnt 1
  } elseif { 0 == [ok_filepath_is_readable $cml(-tools_paths_file)] }  {
    ok_err_msg "Inexistent or invalid file '$cml(-tools_paths_file)' specified as file with external tool locations"
    incr errCnt 1
  } else {
    set ::STS(toolsPathsFile) $cml(-tools_paths_file)
  }
  if { [info exists cml(-suffix_left)] }  {
    set ::STS(suffixL) $cml(-suffix_left)
  } ;   # otherwise use the default
  if { [info exists cml(-suffix_right)] }  {
    set ::STS(suffixR) $cml(-suffix_right)
  } ;   # otherwise use the default
  if { [info exists cml(-outdir_name_prefix)] }  {  ; # after the suffixes
    set ::STS(outdirNamePrefix) $cml(-outdir_name_prefix)
    set ::STS(dirL) "$::STS(outdirNamePrefix)$::STS(suffixL)"
    set ::STS(dirR) "$::STS(outdirNamePrefix)$::STS(suffixR)"
  } else {  ;   # otherwise use the default dirL/dirR
    ok_info_msg "Will use default output directory names ('$::STS(dirL)'/'$::STS(dirR)') since '-outdir_name_prefix' isn't provided"
  }
  if { [info exists cml(-img_extensions)] }  {
    set ::STS(extList) $cml(-img_extensions)
  } else {
    ok_err_msg "Please specify extensions for image files; example: -img_extensions {TIF jpg}"
    incr errCnt 1
  } 
  if { 0 == [info exists cml(-screen_width)] }  {
    ok_err_msg "Please specify the image width; example: -screen_width 2560"
    incr errCnt 1
  } else {
    if { ![string is integer $cml(-screen_width)] || \
          ($cml(-screen_width) <= 0) }  {
      ok_err_msg "Non-integer '$cml(-screen_width)' specified as the image width"
      incr errCnt 1
    } else {
      set ::STS(canvWd) $cml(-screen_width)
    }
  }
  if { 0 == [info exists cml(-screen_height)] }  {
    ok_err_msg "Please specify the image height; example: -screen_height 1440"
    incr errCnt 1
  } else {
    if { ![string is integer $cml(-screen_height)] || \
          ($cml(-screen_height) <= 0) }  {
      ok_err_msg "Non-integer '$cml(-screen_height)' specified as the image height"
      incr errCnt 1
    } else {
      set ::STS(canvHt) $cml(-screen_height)
    }
  }
  if { 0 == [info exists cml(-offset)] }  {
    ok_err_msg "Please specify the offset of individual left/right image from the screen center - in pixels; example: -offset 200"
    incr errCnt 1
  } else {
    if { ![string is integer $cml(-offset)] || \
          ($cml(-offset) <= 0) }  {
      ok_err_msg "Non-integer '$cml(-offset)' specified as the individual left/right image offset"
      incr errCnt 1
    } else {
      set ::STS(offset) $cml(-offset)
    }
  }
  if { 0 != $cml(-gamma) }  { ;  # =1.0 (default) if not given
    if { ([ok_isnumeric $cml(-gamma)]) && ($cml(-gamma) >= 0) }  {
      set ::STS(gamma) $cml(-gamma)
    } else {
      ok_err_msg "Parameter telling gamma correction (-gamma); should be non-negative number"
      incr errCnt 1
    }
  }  else {  ok_info_msg "Gamma correction not requested"  }
  if { 0 != $cml(-jpeg_quality) }  { ;  # =0 (default) if not given
    if { ([string is integer $cml(-jpeg_quality)]) && \
          ($cml(-jpeg_quality) >= 0) && ($cml(-jpeg_quality) <= 100) }  {
      set ::STS(forceJpegQuality) $cml(-jpeg_quality)
    } else {
      ok_err_msg "Parameter telling JPEG file-save quality (-jpeg_quality); should be 0..100"
      incr errCnt 1
    }
  }
  if { $errCnt > 0 }  {
    #ok_err_msg "Error(s) in command parameters!"
    return  0
  }
  #ok_info_msg "Command parameters are valid"
  return  1
}
