# make_offset_lr.tcl - offset separate L/R images onto fixed size canvas for POLARIZED projection

set SCRIPT_DIR__cards [file dirname [info script]]

# TODO: make locally arrangements to find the package(s) instead
# TODO: for instance use the setup file from StereoPairs if found in ../
source [file join $SCRIPT_DIR__cards "setup_goodies.tcl"]

package require ok_utils;   namespace import -force ::ok_utils::*
package require img_proc;   namespace import -force ::img_proc::*

ok_trace_msg "---- Sourcing '[info script]' in '$SCRIPT_DIR__cards' ----"
source [file join $SCRIPT_DIR__cards ".." "ext_tools.tcl"]


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


set ::g_dirL CANV_L
set ::g_dirR CANV_R

# extList - list of originals' extensions (typical: {TIF BMP JPG})
# canvWd/canvHt (pix) = canvas width/height - multiple of projector resolutiuon
# offset (pix) - horizontal shift of L|R image - left rightwards, right leftwards
# gamma - gamma correction value (typical: 0.8)
proc make_offset_lr_in_current_dir {extList canvWd canvHt offset gamma}  {
  if { 0 == [_read_and_check_ext_tool_paths] }  {
    return  0;   # error already printed
  }
  if { 0 == [set origPathList [_find_originals_in_current_dir $ext]] }  {
    return  0;   # error already printed
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


proc _read_and_check_ext_tool_paths {}  {
  if { 0 == [set extToolPathsFilePath [dualcam_find_toolpaths_file 0]] }   {
    #standalone invocaion
    set extToolPathsFilePath [file join $::SCRIPT_DIR__cards \
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
    ok_err_msg "No input images found in directory '[pwd]'"
  }
  ok_err_msg "Found [llength $origPathList] input image(s)  in directory '[pwd]'"
  return  $origPathList
}


proc _prepare_output_dirs {leftDirPath rightDirPath}  {
  upvar $leftDirPath  dirL
  upvar $rightDirPath dirR
  if { 0 == [ok_create_absdirs_in_list \
        [list $::g_dirL $::g_dirR] \
        {"folder-for-left-images" "folder-for-right-images"}] }  {
  return  0
  }
  set dirL $::g_dirL;   set dirR $::g_dirR
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
            $imgPath $geomL $colorL $leftDirPath]] }  { incr cntErr 1 }
    if { 0 == [_make_image_for_one_side  \
            $imgPath $geomR $colorR $rightDirPath]] }  { incr cntErr 1 }
  }
  set n [llength $origPathList];  set nGood [expr $n - $cntErr]
  if { $cntErr == 0 }   {
    ok_info_msg "Processed all $n stereopairs; no errors occured"
  } else                {
    ok_info_msg "Processed [llength $origPathList] stereopair(s); $cntErr error(s) occured"
  }
  return  $nGood
}


proc _make_image_for_one_side {imgPath geomCmd colorCmd outDirPath} {
    #~ set outImg [file join $tmpDir \
                    #~ [ok_insert_suffix_into_filename [file tail $imgPath] "_sm"]]
    #~ set nv_inpImg [format "{%s}" [file nativename $imgPath]]
    #~ set nv_outImg [format "{%s}" [file nativename $outImg]]
    #~ lappend nv_smallImagesAsList $nv_outImg
    #~ set cmdList [concat $::_IMCONVERT $nv_inpImg -density $dpi \
                  #~ -adaptive-resize [format "%dx%d" $pairWidthPx $pairHeightPx] \
                  #~ -depth 8 -compress LZW $nv_outImg]
    #~ if { 0 == [ok_run_silent_os_cmd $cmdList] }  {
      #~ ok_err_msg "Failed resizing input images for card '$cardFilePath'"
      #~ return  0
    #~ }
    #~ if { 0 == [get_image_dimensions_by_imagemagick $outImg width height] }  {
      #~ return  0;  # error already printed
    #~ }
    #~ if { $maxPairHeight < $height }  { set maxPairHeight $height }
}


# Returns description of photo-cards' contents as a list of stings
proc _format_card_spec {listOfQuads}  {
  set textList [list]
  set cardCnt 0
  foreach cardImgList $listOfQuads {
    incr cardCnt 1
    lappend textList "=== Begin card $cardCnt ==="
    foreach imgPath $cardImgList {
      lappend textList "  '$imgPath'"
    }
    lappend textList "=== End   card $cardCnt ==="
  }
  return  $textList
}


# Builds cards' images according to list of file-path quadruples in 'listOfQuads'
# Returns number of successfully generated cards.
proc _generate_cards_by_spec {listOfQuads outDir geomDict}  {
  file mkdir $outDir;  # if directory exists, no action and no error returned
  set cardCnt 0;  set errCnt 0
  foreach cardImgList $listOfQuads {
    incr cardCnt 1
    set cardFilePath [file join $outDir [format "%s%s.%s" \
                                        $::CARD_NAME_PREFFIX $cardCnt "TIF"]]
    ok_info_msg "Making card $cardCnt out of [llength $listOfQuads]; path '$cardFilePath'"
    if { 0 == [_generate_one_card $cardImgList $cardFilePath $geomDict] }  {
      incr errCnt 1;  # error already printed
    }
  }
  if { $cardCnt > $errCnt }  {
    ok_info_msg "Generated [expr $cardCnt-$errCnt] card(s) under '$outDir'"
  }
  if { $errCnt > 0 }  {
    ok_err_msg "Failed to generate $errCnt card(s) under '$outDir'"
  }
  return  [expr $cardCnt-$errCnt]
}


## Inputs for layout computing:
## - dpi = output device linear resolution (300..350 dpi for printing)
## - pairWidthCm (cm) = width (of one stereopair) - up to 6.4cm
## - origWhRatio = out-of-camera width/height ratio for single image
## - ::g_canvasWidthCm (cm)
## - ::g_canvasHeightCm (cm)
## - ::g_gapCm (cm) = distance between two pairs on the canvas == 1.0
################################################################################
#             |<--------------canvasWidth--------------------->|
#        -    +------------------------------------------------+
#        ^    |                                                |
#        |    |         pairWidth                              |
#        |    |     - +-------------+       +-------------+    |
#        |    | pair^ |             |<-gap->|             |    |
# canvasHeight| Height|             |       |             |    |
#        |    |     v |             |       |             |    |
#        |    |     - +-------------+       +-------------+    |
#        |    |          ^                                     |
#        |    |         gap                                    |
#        |    |          v                                     |
#        |    |       +-------------+       +-------------+    |
#        |    |       |             |       |             |    |
#        |    |       |             |       |             |    |
#        |    |       |             |       |             |    |
#        |    |       +-------------+       +-------------+    |
#        |    |                                                |
#        v    |                                                |
#        -    +------------------------------------------------+
################################################################################
################################################################################
# Returns dictionary with the following keys:
#### canvasWidthPx, canvasHeightPx, pairWidthPx, pairHeightPx, gapPx,
#### blankColWidth, blankRowHeight, borderThick
proc _compute_layout {dpi pairWidthCm origWhRatio}  {
  set pairWidthPx    [expr round(1.0 * $pairWidthCm * $dpi / 2.54)]
  set pairHeightPx   [expr round(1.0 * $pairWidthPx / 2.0 / $origWhRatio)]
  set canvasWidthPx  [expr round(1.0 * $::g_canvasWidthCm * $dpi / 2.54)]
  set canvasHeightPx [expr round(1.0 * $::g_canvasHeightCm * $dpi / 2.54)]
  set gapPx          [expr round(1.0 * $::g_gapCm * $dpi / 2.54)]
  # from now on all dimensions are in pixels; new variables have no Px suffixes
  set tileBorder [expr round($gapPx / 2.0)]
  set widthLeft [expr $canvasWidthPx - 2*$pairWidthPx - 4*$tileBorder]
  # remaining pixels go for (1) blank column on the left, (2) the border; ratio 10:1
  set blankColWidth [expr round($widthLeft * 0.9)]
  # border thickness below is for both vertical and horizontal dimensions
  set borderThick [expr round(($widthLeft - $blankColWidth) / 2.0)]
  # remaining pixels (if any) go for blank row on the top
  set blankRowHeight [expr $canvasHeightPx - 2*$pairHeightPx - 4*$tileBorder - 2*$borderThick]
  if { $blankRowHeight < 0 }  { set blankRowHeight 0 }
  set res [dict create  \
            dpi             $dpi                                               \
            canvasWidthPx   $canvasWidthPx  canvasHeightPx     $canvasHeightPx \
            pairWidthPx     $pairWidthPx    pairHeightPx       $pairHeightPx   \
            tileBorderPx    $tileBorder     borderThickPx      $borderThick    \
            blankColWidthPx $blankColWidth  blankRowHeightPx   $blankRowHeight ]
  return $res
}




# TODO: pair-width should be kept precise, height less important
proc _generate_one_card {cardImgList cardFilePath geomDict}  {
  set tmpDir [file join [file dirname $cardFilePath] "TMP"]
  file mkdir $tmpDir;  # if directory exists, no action and no error returned
  #~ for %f in (*.tif) DO  %CNV% %f -density 300 -adaptive-resize 709x473 -depth 8 -compress LZW Small\%~nf_sm.tif 
  #~ %MNT% Small\*_sm.tif -background black -bordercolor black -tile 2x2 -geometry +80+80 -density 300 ppm: | %CNV%  ppm: -background black -bordercolor black -border 17x17 -splice 210x0 -quality 98 Ready\ToPri_%d_2x2_b.jpg 
  # retrieve geometrical parameters from 'geomDict'
  set dpi              [dict get $geomDict dpi]
  set canvasWidthPx    [dict get $geomDict canvasWidthPx]
  set canvasHeightPx   [dict get $geomDict canvasHeightPx]
  set pairWidthPx      [dict get $geomDict pairWidthPx]
  set pairHeightPx     [dict get $geomDict pairHeightPx]
  set tileBorderPx     [dict get $geomDict tileBorderPx]
  set borderThickPx    [dict get $geomDict borderThickPx]
  set blankColWidthPx  [dict get $geomDict blankColWidthPx]
  set blankRowHeightPx [dict get $geomDict blankRowHeightPx]
  # resize individual image files and build list of small images
  # choose actual max height and adjust the geometry; avoid resizing by "montage"
  set nv_smallImagesAsList [list]
  set maxPairHeight 0
  foreach imgPath $cardImgList {
    set outImg [file join $tmpDir \
                    [ok_insert_suffix_into_filename [file tail $imgPath] "_sm"]]
    set nv_inpImg [format "{%s}" [file nativename $imgPath]]
    set nv_outImg [format "{%s}" [file nativename $outImg]]
    lappend nv_smallImagesAsList $nv_outImg
    set cmdList [concat $::_IMCONVERT $nv_inpImg -density $dpi \
                  -adaptive-resize [format "%dx%d" $pairWidthPx $pairHeightPx] \
                  -depth 8 -compress LZW $nv_outImg]
    if { 0 == [ok_run_silent_os_cmd $cmdList] }  {
      ok_err_msg "Failed resizing input images for card '$cardFilePath'"
      return  0
    }
    if { 0 == [get_image_dimensions_by_imagemagick $outImg width height] }  {
      return  0;  # error already printed
    }
    if { $maxPairHeight < $height }  { set maxPairHeight $height }
  }
  ok_info_msg "Resized [llength $cardImgList] input image(s) for card '$cardFilePath'"
  if { $pairHeightPx != $maxPairHeight }  {
    set blankRowHeightPx [expr $blankRowHeightPx + 2*$pairHeightPx - 2*$maxPairHeight]
    if { $blankRowHeightPx < 0 }  { set blankRowHeightPx 0 }
    ok_trace_msg "blankRowHeightPx adjusted from [dict get $geomDict blankRowHeightPx] to $blankRowHeightPx"
  }
  set nv_cardFilePath [format "{%s}" [file nativename $cardFilePath]]
  # convert from list to string to preserve separators while dropping curved braces
  set nv_smallImagesAsStr [join $nv_smallImagesAsList " "]
  set cmdList [concat $::_IMMONTAGE $nv_smallImagesAsStr                    \
          -background black -bordercolor black -tile 2x2                    \
          -geometry [format "+%d+%d" $tileBorderPx $tileBorderPx]           \
          -density $dpi ppm:                                                \
              | $::_IMCONVERT ppm: -background black -bordercolor black       \
                  -border [format "%dx%d" $borderThickPx $borderThickPx]      \
                  -splice [format "%dx%d" $blankColWidthPx $blankRowHeightPx] \
                  -compress LZW $nv_cardFilePath                              ]
  if { 0 == [ok_run_silent_os_cmd $cmdList] }  {
    ok_err_msg "Failed generating card '$cardFilePath'"
    return  0
  }
  ok_info_msg "Generated card '$cardFilePath'"
  return  1
}
