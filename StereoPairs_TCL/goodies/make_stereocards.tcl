# make_stereocards.tcl

set SCRIPT_DIR__cards [file dirname [info script]]

# TODO: make locally arrangements to find the package(s) instead
# TODO: for instance use the setup file from StereoPairs if found in ../
source [file join $SCRIPT_DIR__cards "setup_goodies.tcl"]

package require ok_utils;   namespace import -force ::ok_utils::*
package require img_proc;   namespace import -force ::img_proc::*

ok_trace_msg "---- Sourcing '[info script]' in '$SCRIPT_DIR__cards' ----"
source [file join $SCRIPT_DIR__cards ".." "ext_tools.tcl"]


################################################################################
######## Loreo (2:3):
# make 2x2 4*6cm horizontal(!) prints for 10x15 picture. 
# Width ~ 1800 = 709*2 + 30*2 + 342 
# Height ~ 1200 = 473*2 + 30*2 + 214 
#  make_cards_in_current_dir "tif" 6.0 [expr 4.0/3]
######## TDC (11:12):
# make 2x2 ~2.5*6.4cm horizontal(!) prints for 10x15 picture. 
#  make_cards_in_current_dir "tif" 6.4 [expr 22.0/24]
######## DualCam horizontal (11:12):
# make 2x2 ~2.4*6.4cm horizontal(!) prints for 10x15 picture. 
#  make_cards_in_current_dir "tif" 6.4 [expr 4.0/3.0]
################################################################################

set CARD_NAME_PREFFIX "C_"

set g_dpi             300 ;  # print resolution
set g_canvasWidthCm   15
set g_canvasHeightCm  10
set g_gapCm           1.0 ;  # distance between two pairs on the canvas


# pairWidthCm (cm) = width (of one stereopair) - up to 6.4cm
# origWhRatio = out-of-camera width/height ratio for single image
proc make_cards_in_current_dir {ext pairWidthCm origWhRatio}  {
  if { 0 == [_read_and_check_ext_tool_paths] }  {
    return  0;   # error already printed
  }
  if { 0 == [set listOfQuads [_sort_cards_in_current_dir $ext]] }  {
    return  0;   # error already printed
  }
  set geomDict [_compute_layout $::g_dpi $pairWidthCm $origWhRatio]
  if { 0 == [_generate_cards_by_spec $listOfQuads "Cards" $geomDict] }  {
    return  0;   # error already printed
  }
  return  1
}


proc _read_and_check_ext_tool_paths {}  {
  # if tool-paths are already defined, do nothing
  if { 1 == [verify_external_tools] }  {
    ok_info_msg "Stereocards will use pre-existent external tools' definitions"
    return  1
  }
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


# Builds and returns list of file-path quadruples - we need 4 images per a card
# Each quadruple is a list by itself
proc _sort_cards_in_current_dir {ext}  {
  set listOfQuads [list]
  set imgPattern  [file join [pwd] "*.$ext"]
  if { 0 == [set imgFiles [glob -nocomplain $imgPattern]] }  {
    ok_err_msg "No input images to match '$imgPattern'"
    return  0
  }
  set cardCnt 1;  # counts cards already with images allocated
  set quadCnt 0;  # counts images for one quadruple
  foreach inpImgPath $imgFiles {
    if { $quadCnt == 4 }  { ;   # switch to the next card
      incr cardCnt 1
      set quadCnt 0
      lappend listOfQuads $lastQuadList
      set lastQuadList [list]
    }
    incr quadCnt 1
    lappend lastQuadList $inpImgPath
    #ok_trace_msg "Image '$inpImgPath' added as #$quadCnt to card #$cardCnt"
  }
  if { ($quadCnt == 4) && ([llength $imgFiles] == 4) }  { ;  # single card
    lappend listOfQuads $lastQuadList;    # store the only card
  }
  # all input images are distributed; make the last quadruple complete
  if { ($quadCnt > 0) && ($quadCnt < 4) }  {
    # use images from the tail of 'imgFiles'
    while { $quadCnt < 4 }  { ;  # loop in case there are too few input images
      foreach inpImgPath [lreverse $imgFiles] {
        incr quadCnt 1
        lappend lastQuadList $inpImgPath
        #ok_trace_msg "Image '$inpImgPath' added as #$quadCnt to card #$cardCnt"
        if { $quadCnt == 4 }  { ;   # done
          incr cardCnt 1
          lappend listOfQuads $lastQuadList
          break
        }
      }; #foreach
    }; #while
  }
  if { 0 < [llength $imgFiles] }  {
    ok_info_msg "Distributed [llength $imgFiles] '*.$ext' input image(s) into $cardCnt card(s) of 4"
    #ok_trace_msg "@@@ listOfQuads = {$listOfQuads}"
    ok_trace_msg "Image distribution:"
    foreach line [_format_card_spec $listOfQuads]  {
      ok_trace_msg $line
    }
  } else {
    ok_info_msg "No '*.$ext' input images found"
  }
  return  $listOfQuads
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
  
  file delete -force -- [_cards_tmp_dir_path $outDir]; # no error if inexistent
  return  [expr $cardCnt-$errCnt]
}


proc _cards_tmp_dir_path {outDir}  {
  return  [file join $outDir "TMP"]
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
  set tmpDir [_cards_tmp_dir_path [file dirname $cardFilePath]]
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
