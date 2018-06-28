# make_offset_lr.tcl - offset separate L/R images onto fixed size canvas for POLARIZED projection

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
#~ set g=0.9
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


#~ set ::STS(dirL) CANV_L
#~ set ::STS(dirR) CANV_R
#~ set ::STS(suffixL) "_L"
#~ set ::STS(suffixR) "_R"

# TODO: wrap into command-line based top function
################################################################################

proc _make_offset_lr_set_defaults {}  {
  set ::STS(dirL)    "CANV_L"
  set ::STS(dirR)    "CANV_R"
  set ::STS(suffixL) "_L"
  set ::STS(suffixR) "_R"
  set ::STS(extList) ""
  set ::STS(canvWd)  ""
  set ::STS(canvHt)  ""
  set ::STS(offset)  ""
  set ::STS(gamma)   ""
  #set ::STS() ""
  #set ::STS() ""
}
################################################################################
_make_offset_lr_set_defaults ;  # load only;  do call it in a function for repeated invocations
################################################################################

proc make_offset_lr_main {cmdLineAsStr}  {
  global SCRIPT_DIR
  _make_offset_lr_set_defaults ;  # calling it in a function for repeated invocations
  
  if { 0 == [offset_lr_cmd_line $cmdLineAsStr cml] }  {
    return  0;  # error or help already printed
  }
}

# extList - list of originals' extensions (typical: {TIF BMP JPG})
# canvWd/canvHt (pix) = canvas width/height - multiple of projector resolutiuon
# offset (pix) - horizontal shift of L|R image - left rightwards, right leftwards
# gamma - gamma correction value (typical: 0.8)
# Example:  cd e:/Photo_Publish/Stereo/TMP/;  make_offset_lr_in_current_dir {TIF JPG} 2560 1440 200 0.8
proc make_offset_lr_in_current_dir {extList canvWd canvHt offset gamma}  {
  if { 0 == [_read_and_check_ext_tool_paths] }  {
    return  0;   # error already printed
  }
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
  #OK_TODO
  return  1
}


  #~ set ::STS(dirL)    "CANV_L"
  #~ set ::STS(dirR)    "CANV_R"
  #~ set ::STS(suffixL) "_L"
  #~ set ::STS(suffixR) "_R"
  #~ set ::STS(extList) ""
  #~ set ::STS(canvWd)  ""
  #~ set ::STS(canvHt)  ""
  #~ set ::STS(offset)  ""
  #~ set ::STS(gamma)   ""
proc offset_lr_cmd_line {cmdLineAsStr cmlArrName}  {
  upvar $cmlArrName      cml
  # create the command-line description
  set descrList \
[list \
  -help {"" "print help"}                                        outout             \
  -subdir_left  {val	"name of subdirectory for output left images"} \
  -subdir_right {val	"name of subdirectory for output right images"} \
  -suffix_left  {val	"suffix for output left  images' names"} \
  -suffix_right {val	"suffix for output right images' names"} \
  -img_extensions {list "list of extensions of input image files; example: {jpg bmp}"}                      \
  -screen_width  {val "image width  with border - in pixels - multiple of projector's horizontal resolution"} \
  -screen_height {val "image height with border - in pixels - multiple of projector's vertical   resolution"} \
  -offset {val	"offset of each image from the screen center - in pixels"} \
  -gamma   {val "gamma correction to apply"}  \
s  -jpeg_quality {val "JPEG file-saving quality (1..100); 0 (default) means auto"} \
 ]
  array unset cmlD
  ok_new_cmd_line_descr cmlD $descrList
  # create dummy command line with the default parameters and copy it
  # (if an argument inexistent by default, don't provide dummy value)
  array unset defCml
  ok_set_cmd_line_params defCml cmlD { \
    {-subdir_left "CANV_L"} {-subdir_right "CANV_R"}                          \
    {-suffix_left "_L"} {-suffix_right "_R"} {-jpeg_quality "0"}              }
  ok_copy_array defCml cml;    # to preset default parameters
  # now parse the user's command line
  if { 0 == [ok_read_cmd_line $cmdLineAsStr cml cmlD] } {
    ok_err_msg "Aborted because of invalid command line";	return  0
  }
  if { [info exists cml(-help)] } {
    set cmdHelp [ok_help_on_cmd_line defCml cmlD "\n"]
    # OK_TODO
    ok_info_msg "================================================================"
    ok_info_msg "    Rotation and cropping of images."
    ok_info_msg "========= Command line parameters (in random order): =============="
    ok_info_msg $cmdHelp
    ok_info_msg "================================================================"
    ok_info_msg "========= Example 1 - rotation only (note TCL-style directory separators): ======="
    ok_info_msg " offset_lr_main \"-rot_angle 90 -crop_ratio 0 -final_depth 8 -inp_dir L -bu_subdir_name {} -img_extensions {TIF} -tools_paths_file ../ext_tool_dirs.csv\""
    ok_info_msg "================================================================"
    ok_info_msg "========= Example 2 - rotate and crop: ======="
    ok_info_msg " offset_lr_main \"-rot_angle 90 -crop_ratio 1 -final_depth 8 -inp_dir R -bu_subdir_name {BU} -img_extensions {JPG TIF} -jpeg_quality 99 -tools_paths_file ../ext_tool_dirs.csv\""
    ok_info_msg "================================================================"
    return  0
  }
  if { 0 == [_offset_lr_parse_cmdline cml] }  {
    ok_err_msg "Error(s) in command parameters. Aborting..."
    return  0
  }
  set cmdStrNoHelp [ok_cmd_line_str cml cmlD "\n" 0]
  set ::STS(imSaveParams) [dict create];  # early check of image types
  foreach ext $::STS(imgExts)  {
    if { "-ERROR-" == [set saveParamsForType [choose_im_img_save_params \
                        $ext $::STS(finalDepth) $::STS(forceJpegQuality)]] }  {
      return  0;  # error already printed
    }
    dict set ::STS(imSaveParams) $ext $saveParamsForType
  }

  ok_info_msg "==== Now run rotate-and-crop by the following spec: ===="
  ok_info_msg "==== \n$cmdStrNoHelp\n===="
  return  1
}


proc _read_and_check_ext_tool_paths {}  {
  if { 0 == [set extToolPathsFilePath [dualcam_find_toolpaths_file 0]] }   {
    #standalone invocaion
    set extToolPathsFilePath [file join $::SCRIPT_DIR__offset \
                                        ".." "ext_tool_dirs.csv"]
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
    "L"   "$levelBase,%gamma"   \
    "R"   "$levelBase,%gamma"   ]
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
    if { 0 == [ok_run_silent_os_cmd $cmdList] }  {
      ok_err_msg "Failed $descr";      return  0
    }
    ok_info_msg "Success $descr"
    return  1
}
