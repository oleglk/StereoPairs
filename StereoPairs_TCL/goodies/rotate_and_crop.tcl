# rotate_and_crop.tcl - rotation and cropping script - processes all standard images in current dir

set SCRIPT_DIR [file dirname [info script]]

# TODO: make locally arrangements to find the package(s) instead
# TODO: for instance use the setup file from StereoPairs if found in ../
source [file join $SCRIPT_DIR "setup_goodies.tcl"]

package require ok_utils;   namespace import -force ::ok_utils::*
package require img_proc;   namespace import -force ::img_proc::*


# set IM_DIR "C:\Program Files (x86)\ImageMagick-6.8.7-3"
# set IM_DIR "$::SCRIPT_DIR\ImageMagick"



################################################################################

proc _rotate_and_crop_set_defaults {}  {
  set ::STS(toolsPathsFile)   "" ;  # full path or relative to this script
  set ::STS(finalDepth)       8  ;  # color depth of final images; 8 or 16
  set ::STS(imgExts)          [list] ;  # list of extensions of input images (?output is always TIF?)
  set ::STS(inpDirPath)       "" ;  # input dir path - absolute or relative to the current directory
  set ::STS(buDirName)        "" ;  # backup dir - relative to the input directory - to be created under it
  set ::STS(rotAngle)         0  ;  # rotation angle - clockwise
  set ::STS(padX)             0  ;  # horizontal padding in % - after rotate
  set ::STS(padY)             0  ;  # vertical   padding in % - after rotate
  set ::STS(cropRatio)        0  ;  # 0 == no crop; otherwise width/height AFTER rotation
  set ::STS(imSaveParams)     "" ;  # compression and quality; should match type
  set ::STS(forceJpegQuality) 0  ;  # if > 0, tells forced JPEG quality value
}
################################################################################
_rotate_and_crop_set_defaults ;  # load only;  do call it in a function for repeated invocations
################################################################################

proc rotate_and_crop_main {cmdLineAsStr}  {
  global SCRIPT_DIR
  _rotate_and_crop_set_defaults ;  # calling it in a function for repeated invocations
  
  if { 0 == [rotate_and_crop_cmd_line $cmdLineAsStr cml] }  {
    return  0;  # error or help already printed
  }
  if { 0 == [_rotate_and_crop_set_ext_tool_paths_from_csv $::STS(toolsPathsFile)] } {
    return  0;  # error already printed
  }
  if { 0 == [_rotate_and_crop_verify_external_tools] }  { return  0  };  # error already printed

  ok_info_msg "Start processing image file(s) in input directory '$::STS(inpDirPath)'"
  if { 0 == [_do_job_in_one_dir $::STS(inpDirPath)] }  {
    ok_err_msg "Rotate-and-crop aborted in directory '$::STS(inpDirPath)'"
    return  0
  }
  ok_info_msg "Done rotate-and-crop image file(s) in directory '$::STS(inpDirPath)'"
  return  1
}


proc rotate_and_crop_cmd_line {cmdLineAsStr cmlArrName}  {
  upvar $cmlArrName      cml
  # create the command-line description
  set descrList \
[list \
  -help {"" "print help"}                                                      \
  -tools_paths_file {val	"path of the CSV file with external tool locations - absolute or relative to this script; example: ../ext_tool_dirs.csv"} \
  -final_depth {val	"color-depth of the final images (bit); 8 or 16"}         \
  -img_extensions {list "list of extensions of image files; example: {jpg bmp}"}                      \
  -inp_dir {val "input directory path; absolute or relative to the current directory"} \
  -bu_subdir_name {val	"name of backup directory (for original images); created under the input directory; empty string means no backup"} \
  -rot_angle   {val "rotation angle - clockwise"}  \
  -pad_x   {val "horizontal padding in % - after rotate"}  \
  -pad_y   {val "vertical   padding in % - after rotate"}  \
  -crop_ratio  {val "width-to-height ratio AFTER rotation; 0 means do not crop"} \
  -jpeg_quality {val "JPEG file-saving quality (1..100); 0 (default) means auto"} \
 ]
  array unset cmlD
  ok_new_cmd_line_descr cmlD $descrList
  # create dummy command line with the default parameters and copy it
  # (if an argument inexistent by default, don't provide dummy value)
  array unset defCml
  ok_set_cmd_line_params defCml cmlD { \
    {-final_depth "8"} {-rot_angle "0"} {-pad_x "0"} {-pad_y "0"} \
    {-crop_ratio "0"}  {-jpeg_quality "0"}  {-bu_subdir_name "Orig"} }
  ok_copy_array defCml cml;    # to preset default parameters
  # now parse the user's command line
  if { 0 == [ok_read_cmd_line $cmdLineAsStr cml cmlD] } {
    ok_err_msg "Aborted because of invalid command line";	return  0
  }
  if { [info exists cml(-help)] } {
    set cmdHelp [ok_help_on_cmd_line defCml cmlD "\n"]
    ok_info_msg "================================================================"
    ok_info_msg "    Rotation and cropping of images."
    ok_info_msg "========= Command line parameters (in random order): =============="
    ok_info_msg $cmdHelp
    ok_info_msg "================================================================"
    ok_info_msg "========= Example 1 - rotation only (note TCL-style directory separators): ======="
    ok_info_msg " rotate_and_crop_main \"-rot_angle 90 -crop_ratio 0 -final_depth 8 -inp_dir L -bu_subdir_name {} -img_extensions {TIF} -tools_paths_file ../ext_tool_dirs.csv\""
    ok_info_msg "================================================================"
    ok_info_msg "========= Example 2 - rotate and crop: ======="
    ok_info_msg " rotate_and_crop_main \"-rot_angle 90 -crop_ratio 1 -final_depth 8 -inp_dir R -bu_subdir_name {BU} -img_extensions {JPG TIF} -jpeg_quality 99 -tools_paths_file ../ext_tool_dirs.csv\""
    ok_info_msg "================================================================"
    return  0
  }
  if { 0 == [_rotate_and_crop_parse_cmdline cml] }  {
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


proc _rotate_and_crop_parse_cmdline {cmlArrName}  {
  upvar $cmlArrName      cml
  set errCnt 0
  if { 0 == [info exists cml(-tools_paths_file)] }  {
    ok_err_msg "Please specify path of the CSV file with external tool locations; example: ../ext_tool_dirs.csv"
    incr errCnt 1
  } elseif { 0 == [ok_filepath_is_readable $cml(-tools_paths_file)] }  {
    ok_err_msg "Inexistent or invalid file '$cml(-tools_paths_file)' specified as file with external tool locations"
    incr errCnt 1
  } else {
    set ::STS(toolsPathsFile) $cml(-tools_paths_file)
  }
  if { [info exists cml(-final_depth)] }  {
    if { ($cml(-final_depth) == 8) || ($cml(-final_depth) == 16) }  {
      set ::STS(finalDepth) $cml(-final_depth)
    } else {
      ok_err_msg "Invalid value specified for final images color depth (-final_depth); should be 8 or 16"
      incr errCnt 1
    }
  } 
  if { [info exists cml(-img_extensions)] }  {
    set ::STS(imgExts) $cml(-img_extensions)
  } else {
    ok_err_msg "Please specify extensions for image files; example: -img_extensions {TIF jpg}"
    incr errCnt 1
  } 
  if { 0 == [info exists cml(-inp_dir)] }  {
    ok_err_msg "Please specify the input directory; example: -inp_dir L"
    incr errCnt 1
  } else {
    set inDir $cml(-inp_dir)
    if { 0 == [ok_filepath_is_existent_dir $inDir] }  {
      ok_err_msg "Non-directory '$inDir' specified as the input directory"
      incr errCnt 1
    } else {
      set ::STS(inpDirPath) [file normalize $inDir]
    }
  }
  if { 1 == [info exists cml(-bu_subdir_name)] }  {
    if { (1 == [file exists $cml(-bu_subdir_name)]) && \
             (0 == [file isdirectory $cml(-bu_subdir_name)]) }  {
      ok_err_msg "Non-directory '$cml(-bu_subdir_name)' specified as backup directory"
      incr errCnt 1
    } else {
      set ::STS(buDirName)      $cml(-bu_subdir_name)
    }
  }
  if { 0 != $cml(-rot_angle) }  { ;  # =0 (default) if not given
    if { ($cml(-rot_angle) == 0)   || ($cml(-rot_angle) == 90) || \
         ($cml(-rot_angle) == 180) || ($cml(-rot_angle) == 270) }  {
      set ::STS(rotAngle) $cml(-rot_angle)
    } else {
      ok_err_msg "Parameter telling clock-wise rotation angle (-rot_angle); should 0, 90, 180 or 270"
      incr errCnt 1
    }
  } else {  ok_info_msg "Rotation not requested"  }
  if { 0 != $cml(-pad_x) }  { ;  # =0 (default) if not given
    if { ([ok_isnumeric $cml(-pad_x)]) && ($cml(-pad_x) >= 0) }  {
      set ::STS(padX) $cml(-pad_x)
    } else {
      ok_err_msg "Parameter telling horizontal padding (-pad_x); should be non-negative number"
      incr errCnt 1
    }
  }  else {  ok_info_msg "Horizontal padding not requested"  }
  if { 0 != $cml(-pad_y) }  { ;  # =0 (default) if not given
    if { ([ok_isnumeric $cml(-pad_y)]) && ($cml(-pad_y) >= 0) }  {
      set ::STS(padY) $cml(-pad_y)
    } else {
      ok_err_msg "Parameter telling vertical padding (-pad_y); should be non-negative number"
      incr errCnt 1
    }
  }  else {  ok_info_msg "Vertical padding not requested"  }
  if { 0 != $cml(-crop_ratio) }  { ;  # =0 (default) if not given
    if { [ok_isnumeric $cml(-crop_ratio)] }  {
      set ::STS(cropRatio) $cml(-crop_ratio)
    } else {
      ok_err_msg "Parameter telling crop ratio (-crop_ratio); should be numeric"
      incr errCnt 1
    }
  }  else {  ok_info_msg "Cropping not requested"  }
  if { (0 == $cml(-rot_angle)) && (0 == $cml(-crop_ratio)) }  { 
    ok_info_msg "Please specify rotation angle and/or crop ratio; example: -rot_angle 270 -crop_ratio 1"
    incr errCnt 1
  }
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


# Does conversion and blending for all inputs in 'dirPath'
# Assumes 'dirPath' is a valid directory
proc _do_job_in_one_dir {dirPath}  {
  set oldWD [pwd];  # save the old cwd, cd to dirPath, restore before return
  set tclResult [catch { set res [cd $dirPath] } execResult]
  if { $tclResult != 0 } {
    ok_err_msg "Failed changing work directory to '$dirPath': $execResult!"
    return  0
  }
  ok_info_msg "Success changing work directory to '$dirPath'"

  if { 0 == [_arrange_dirs_in_current_dir] }  {
    ok_err_msg "Aborting because of failure to create a temporary output directory"
    return  0
  }
  set nProcessed 0
  foreach ext $::STS(imgExts) {
    if { -1 == [set nInOneDir [_rotate_crop_all_in_current_dir $ext]] }  {
      return  0;  # errors already printed
    }
    incr nProcessed $nInOneDir
  }
 
  set tclResult [catch { set res [cd $oldWD] } execResult]
  if { $tclResult != 0 } {
    ok_err_msg "Failed restoring work directory to '$oldWD': $execResult!"
    return  0
  }
  if { $nProcessed == 0 }  {
    ok_err_msg "No images {$::STS(imgExts)} found in '[pwd]';. Aborting..."
    return  0
  }
  return  1
}

proc _arrange_dirs_in_current_dir {} {
  if { $::STS(buDirName) != "" }  {
    if { 0 == [ok_create_absdirs_in_list \
            [list $::STS(buDirName)] \
            {"backup-folder-for-original-images"}] }  {
      return  0
    }
  }
  return  1
}

# Performs rotations and croppings; returns num of processed files, 0 if none, -1 on error.
proc _rotate_crop_all_in_current_dir {imgExt} {
  set cntSkipped 0
  if { "-ERROR-" == [set commonImSaveParams [choose_im_img_save_params \
                     $imgExt $::STS(finalDepth) $::STS(forceJpegQuality)]] }  {
    ok_err_msg "Format '*.$imgExt not supported for saving images"
    return  -1
  }
  puts "====== Begin rotations and croppings in '[pwd]'; extension: '$imgExt' ========"
  set imgPaths [glob -nocomplain "*.$imgExt"]
  if { 0 == [llength $imgPaths] }  {
    ok_info_msg "No images (*.$imgExt) found in '[pwd]'"
    return  0
  }
  foreach imgPath $imgPaths {
    if { 1 == [_rotate_and_crop_is_image_processed $imgPath] }  {
      ok_info_msg "Image '$imgPath' assumed already rotated/cropped; skipped by rotation/cropping step"
      incr cntSkipped 1;      continue
    }
    # add comment to mark the image as processed
    if { 0 == [_make_new_image_comment $imgPath \
                                $::STS(rotAngle) $::STS(cropRatio) comment] }  {
      return  -1;  # error already printed
    }
    set imSaveParams "-set comment \"$comment\" $commonImSaveParams"
    if { 0 == [rotate_crop_one_img $imgPath \
                          $::STS(rotAngle) $::STS(padX)  $::STS(padY) \
                          $::STS(cropRatio) \
                          "white" $imSaveParams $::STS(buDirName)] } {
      return  -1;  # error already printed
    }
  }
  set nProcessed [expr {[llength $imgPaths] - $cntSkipped}]
  puts "====== Finished rotations and croppings in '[pwd]'; extension: '$imgExt'; $nProcessed image(s) processed; $cntSkipped image(s) skipped ========"
  return  [llength $imgPaths]
}


# ============== Subroutines =======================

# Returns ImageMagick file-save compression and quality parameters.
# On error returns "-ERROR-".
proc choose_im_img_save_params {imgExt finalDepth forceJpegQuality}  {
  if { ($finalDepth != 8) && ($finalDepth != 16) }  {  return  "-ERROR-"  }
  set jpegQual [expr {($forceJpegQuality > 0)? \
                                            "-quality $forceJpegQuality" : ""}]
  switch -nocase -- $imgExt  {
    "tif"   {  return "-compress LZW -depth $finalDepth"  }
    "jpg"   {  return "-depth $finalDepth $jpegQual"      }
    default {  return  "-ERROR-"                          }
  }
}


# Returns 1 if image 'imgPath' marked as processed, 0 if not marked, -1 on error
proc _rotate_and_crop_is_image_processed {imgPath}  {
  if { 0 == [get_image_comment_by_imagemagick $imgPath comment] } {
    return  -1; # error already printed
  }
  return  [expr {1 == [regexp "/:/rotated.*/:/cropped.*/:/" $comment]}]
}


# Puts into 'comment' a string that marks the image as processed
# If 'imgPath' already has some comment, the string starts with it
# Returns 1 on success, 0 on error
proc _make_new_image_comment {imgPath rotAngle cropRatio comment}  {
  upvar $comment cm
  if { 0 == [get_image_comment_by_imagemagick $imgPath cm] } {
    return  0; # error already printed
  }
  # add comment to mark the image as processed
  if { $cm != "" }  { append cm "----" };  # seems like comments are single-line
  append cm "/:/rotated$::STS(rotAngle)/:/cropped$::STS(cropRatio)/:/"
  return  1
}


# Reads the system-dependent paths from 'csvPath',
# then assigns ultimate tool paths
proc _rotate_and_crop_set_ext_tool_paths_from_csv {csvPath}  {
  if { 0 ==[ok_read_variable_values_from_csv $csvPath "external tool path(s)"]} {
    return  0;  # error already printed
  }
  if { 0 == [info exists ::_IM_DIR] }  {
    ok_err_msg "Imagemagick directory path not assigned to variable _IM_DIR by '$csvPath'"
    return  0
  }
  set ::_IMCONVERT  [format "{%s}"  [file join $::_IM_DIR "convert.exe"]]
  set ::_IMMOGRIFY  [format "{%s}"  [file join $::_IM_DIR "mogrify.exe"]]
  set ::_IMIDENTIFY [format "{%s}"  [file join $::_IM_DIR "identify.exe"]]
  return  1
}


proc _rotate_and_crop_verify_external_tools {} {
  set errCnt 0
  if { 0 == [file isdirectory $::_IM_DIR] }  {
    ok_err_msg "Inexistent or invalid Imagemagick directory '$::_IM_DIR'"
    incr errCnt 1
  }
  if { 0 == [file exists [string trim $::_IMCONVERT " {}"]] }  {
    ok_err_msg "Inexistent ImageMagick 'convert' tool '$::_IMCONVERT'"
    incr errCnt 1
  }
  if { 0 == [file exists [string trim $::_IMMOGRIFY " {}"]] }  {
    ok_err_msg "Inexistent ImageMagick 'mogrify' tool '$::_IMMOGRIFY'"
    incr errCnt 1
  }
  if { 0 == [file exists [string trim $::_IMIDENTIFY " {}"]] }  {
    ok_err_msg "Inexistent ImageMagick 'identify' tool '$::_IMIDENTIFY'"
    incr errCnt 1
  }
  if { $errCnt == 0 }  {
    ok_info_msg "All external tools are present"
    return  1
  } else {
    ok_err_msg "Some or all external tools are missing"
    return  0
  }
}
