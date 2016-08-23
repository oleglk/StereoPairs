# main_color_analyzer.tcl


set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR  "ok_utils" "debug_utils.tcl"]
ok_trace_msg "---- Sourcing '[info script]' in '$SCRIPT_DIR' ----"
source [file join $SCRIPT_DIR   "ext_tools.tcl"]
source [file join $SCRIPT_DIR   "dir_file_utils.tcl"]
source [file join $SCRIPT_DIR   "stereopair_naming.tcl"]


package require ok_utils;   namespace import -force ::ok_utils::*
package require img_proc;   namespace import -force ::img_proc::*


###################### Global variables ############################
#DO NOT: array unset STS ;   # array for global settings; unset once per project

# TODO: extract a common part from _color_analyzer_set_defaults() for the whole project
proc _color_analyzer_set_defaults {}  {
  set ::STS(stdImgRootPath)   ""
  set ::STS(stdImgPathLeft)   "" ;  # full path or relative path under CWD
  set ::STS(stdImgPathRight)  "" ;  # full path or relative path under CWD
  set ::STS(stdImgExtLeft)    "" ;  # filename extension for left  images
  set ::STS(stdImgExtRight)   "" ;  # filename extension for right images
  set ::STS(outDirPath)       ""
  set ::STS(colorDiffThresh)  "" ;  # minimal L-R color difference to warn on
  
  set IMG_EXT_DICT   0 ;  # per-dir extensions of standard images
}
################################################################################
_color_analyzer_set_defaults ;  # load only;  do call it in a function for repeated invocations
################################################################################

set IMG_EXT_DICT    0 ;  # per-dir extensions of original out-of-camera images

set COLORDIFF_CSV_NAME        "color_diff_lr.csv"  ;   # name for color-channel diff file
set COLORDIFF_SORTED_CSV_NAME "color_diff_lr.sorted.csv"  ;   # name for sorted color-channel diff file

################################################################################

proc color_analyzer_main {cmdLineAsStr}  {
  global STS SCRIPT_DIR IMG_EXT_DICT
  _color_analyzer_set_defaults ;  # calling it in a function for repeated invocations
  set extToolPathsFilePath [file join $SCRIPT_DIR ".." "ext_tool_dirs.csv"]
  if { 0 == [set_ext_tool_paths_from_csv $extToolPathsFilePath] }  {
    return  0;  # error already printed
  }
  if { 0 == [verify_external_tools] }  { return  0  };  # error already printed
  
  if { 0 == [color_analyzer_cmd_line $cmdLineAsStr cml] }  {
    return  0;  # error or help already printed
  }
  # type of standard images dictated by extensions from cmd line
  set IMG_EXT_DICT [dict create L $STS(stdImgExtLeft) R $STS(stdImgExtRight)]

  if { 0 == [_color_analyzer_find_lr_images imgPathsLeft imgPathsRight] } {
    return  0;  # error already printed
  }

  if { 0 == [_color_analyzer_arrange_workarea] }  { return  0  };  # error already printed

  if { 0 == [dict size [set pairNameToLRPathsDict \
      [_map_pairname_to_lrpaths $imgPathsLeft $imgPathsRight]]] } {
    return  0;  # error already printed
  }
  ###puts $pairNameToLRPathsDict

  if { 0 == [set pairNameAndColorChannelDiffList \
      [_map_pairname_to_color_stat_diff $pairNameToLRPathsDict]] } {
    return  0;  # error already printed
  }

  if { 0 == [_report_pairname_to_color_diff $pairNameAndColorChannelDiffList] } {
    return  0;  # error already printed
  }

  # TODO
  return  1
}


proc color_analyzer_cmd_line {cmdLineAsStr cmlArrName}  {
  upvar $cmlArrName      cml
  # create the command-line description
  set descrList \
[list \
  -help {"" "print help"} \
  -img_dir {val	"root input directory"} \
  -left_img_subdir {val	"subdirectory for left images; left images to be checked expected in 'img_dir'/'left_img_subdir')"} \
  -right_img_subdir {val "subdirectory for right images; right images to be checked expected in 'img_dir'/'right_img_subdir')"} \
  -ext_left {val	"file extension of left images; standard type only (tif/jpg/etc.)"} \
  -name_format_left {val "name spec for left images - <prefix>[LeftName]<delimeter>[RightId]<suffix>; example: [LeftName]-[RightId]_left"} \
  -name_format_right {val "name spec for right images - <prefix>[LeftName]<delimeter>[RightId]<suffix>; example: [LeftName]-[RightId]_right"} \
  -ext_right {val	"file extension of right images; standard type only (tif/jpg/etc.)"} \
  -out_dir {val	"output directory"} \
  -warn_color_diff_above {val "minimal left-right color difference (%) to warn on"} ]
  array unset cmlD
  ok_new_cmd_line_descr cmlD $descrList
  # create dummy command line with the default parameters and copy it
  # (if an argument inexistent by default, don't provide dummy value)
  array unset defCml
  ok_set_cmd_line_params defCml cmlD { \
    {-name_format_left "[LeftName]-[RightId]_l"} {-name_format_right "[LeftName]-[RightId]_r"} \
    {-warn_color_diff_above "10"} }
  ok_copy_array defCml cml;    # to preset default parameters
  # now parse the user's command line
  if { 0 == [ok_read_cmd_line $cmdLineAsStr cml cmlD] } {
    ok_err_msg "Aborted because of invalid command line";	return  0
  }
  if { [info exists cml(-help)] } {
    set cmdHelp [ok_help_on_cmd_line defCml cmlD "\n"]
    ok_info_msg "================================================================"
    ok_info_msg "    DualCam Color Analyzer compares color-channels' statistics of left- and right images of each matched stereopair."
    ok_info_msg "========= Command line parameters (in any order): =============="
    ok_info_msg $cmdHelp
    ok_info_msg "================================================================"
    ok_info_msg "========= Example (note TCL-style directory separators): ======="
    ok_info_msg " color_analyzer_main \"-img_dir . -left_img_subdir L -right_img_subdir R -out_dir ./OUT -ext_left jpg -ext_right jpg -warn_color_diff_above 15\""
    ok_info_msg "================================================================"
    return  0
  }
  if { 0 == [_color_analyzer_parse_cmdline cml] }  {
    ok_err_msg "Error(s) in command parameters. Aborting..."
    return  0
  }
  set cmdStrNoHelp [ok_cmd_line_str cml cmlD "\n" 0]
  ok_info_msg "==== Now compare stereopairs' color-channel statistics by the following spec: ===="
  ok_info_msg "==== \n$cmdStrNoHelp\n===="
  return  1
}


proc _color_analyzer_parse_cmdline {cmlArrName}  {
  upvar $cmlArrName      cml
  set errCnt 0

##   set ::STS(stdImgRootPath)   ""
 #   set ::STS(stdImgPathLeft)    ""
 #   set ::STS(stdImgPathRight)   ""
 #   set ::STS(stdImgExtLeft)    "" ;  # filename extension for left  images
 #   set ::STS(stdImgExtRight)   "" ;  # filename extension for right images
 #   set ::STS(outDirPath)       ""
 #   set ::STS(colorDiffThresh)  "" ;  # minimal L-R color difference to warn on
 ##
##   -img_dir {val	"input directory; left (right) images to be checked expected in 'img_dir'/L ('img_dir'/R)"} \
 #   -ext_left {val	"file extension of left images; standard type only (tif/jpg/etc.)"} \
 #   -ext_right {val	"file extension of right images; standard type only (tif/jpg/etc.)"} \
 #   -out_dir {val	"output directory"} \
 #   -warn_color_diff_above {val "minimal left-right color difference (%) to warn on"} ]
 ##

  if { 0 == [info exists cml(-img_dir)] }  {
    ok_err_msg "Please specify input root directory; example: -img_dir D:/Photo/Work"
    incr errCnt 1
  } elseif { 0 == [file isdirectory $cml(-img_dir)] }  {
    ok_err_msg "Non-directory '$cml(-img_dir)' specified as input root directory"
    incr errCnt 1
  } else {
    set ::STS(stdImgRootPath) $cml(-img_dir)
    if { 0 == [info exists cml(-left_img_subdir)] }  {
      ok_err_msg "Please specify input subdirectory for left images; example: -left_img_subdir L/TIFF"
      incr errCnt 1
    } else {
      set ::STS(stdImgPathLeft)  [file join $::STS(stdImgRootPath) \
                                            $cml(-left_img_subdir)]
    }
    if { 0 == [info exists cml(-right_img_subdir)] }  {
      ok_err_msg "Please specify input subdirectory for right images; example: -right_img_subdir R/TIFF"
      incr errCnt 1
    } else {
      set ::STS(stdImgPathRight)  [file join $::STS(stdImgRootPath) \
                                            $cml(-right_img_subdir)]
    }
    if { 0 == [file isdirectory $::STS(stdImgPathLeft)] }  {
      ok_err_msg "Non-directory '$::STS(stdImgPathLeft)' specified as left input directory"
      incr errCnt 1
    }
    if { 0 == [file isdirectory $::STS(stdImgPathRight)] }  {
      ok_err_msg "Non-directory '$::STS(stdImgPathRight)' specified as right input directory"
      incr errCnt 1
    }
  }
  if { 0 == [set_naming_parameters_from_format_spec_array cml \
                                    "-name_format_left" "-name_format_right"]} {
    incr errCnt 1;  # error already printed
  }
  if { 0 == [info exists cml(-out_dir)] }  {
    ok_err_msg "Please specify output directory; example: -out_dir D:/Photo/Work"
    incr errCnt 1
  } elseif { (1 == [file exists $cml(-out_dir)]) && \
             (0 == [file isdirectory $cml(-out_dir)]) }  {
    ok_err_msg "Non-directory '$cml(-out_dir)' specified as output directory"
    incr errCnt 1
  } else {
    set ::STS(outDirPath)      [file normalize $cml(-out_dir)]
    # validity of pair-list path will be checked after out-dir creation
  }
 if { 1 == [info exists cml(-ext_left)] }  {
    set ::STS(stdImgExtLeft) $cml(-ext_left)
  } else {
    ok_err_msg "Please specify extension for left images; example: -ext_left TIF"
    incr errCnt 1
  } 
 if { 1 == [info exists cml(-ext_right)] }  {
    set ::STS(stdImgExtRight) $cml(-ext_right)
  } else {
    ok_err_msg "Please specify extension for right images; example: -ext_right TIF"
    incr errCnt 1
  } 
  if { 1 == [info exists cml(-warn_color_diff_above)] }  {
    set ::STS(colorDiffThresh) $cml(-warn_color_diff_above)
  }
  if { $errCnt > 0 }  {
    #ok_err_msg "Error(s) in command parameters!"
    return  0
  }
  #ok_info_msg "Command parameters are valid"
  return  1
}



# Puts into 'imgPathsLeftVar' and 'imgPathsRightVar' the paths of
# standard l/r images
proc _color_analyzer_find_lr_images {imgPathsLeftVar imgPathsRightVar}  {
  global STS IMG_EXT_DICT
  upvar $imgPathsLeftVar  imgPathsLeft
  upvar $imgPathsRightVar imgPathsRight
  return  [dualcam_find_lr_images $IMG_EXT_DICT \
            $STS(stdImgPathLeft) $STS(stdImgPathRight) imgPathsLeft imgPathsRight]
}


proc _color_analyzer_arrange_workarea {}  {
  if { 0 == [ok_create_absdirs_in_list \
              [list $::STS(outDirPath)] \
              [list "output"         ]] } {
    return  0;  # error already printed
  }
  return  1
}


# Returns dictionary {pairname :: {pathLeft pathRight}} ot 0 on error
proc _map_pairname_to_lrpaths {imgPathsLeft imgPathsRight}  {
  set pairNameToLeftPath [dict create]
  set pairNameToRightPath [dict create]
  set errCnt 0
  foreach fPath $imgPathsLeft {
    set purename [AnyFileNameToPurename [file tail $fPath]]
    set pairPurename [spm_purename_to_pair_purename $purename]
    if { $pairPurename == "" }  {
      ok_err_msg "File '$fPath is not a left image";  incr errCnt 1
    }
    dict append pairNameToLeftPath $pairPurename $fPath
  }
  foreach fPath $imgPathsRight {
    set purename [AnyFileNameToPurename [file tail $fPath]]
    set pairPurename [spm_purename_to_pair_purename $purename]
    if { $pairPurename == "" }  {
      ok_err_msg "File '$fPath is not a right image";  incr errCnt 1
    }
    dict append pairNameToRightPath $pairPurename $fPath
  }
  set pairNameToLRPathsDict [dict create]
  ok_trace_msg "Found [dict size $pairNameToLeftPath] left and [dict size $pairNameToRightPath] right images"
  set allPairNames [lsort -unique [concat \
              [dict keys $pairNameToLeftPath] [dict keys $pairNameToRightPath]]]
  foreach pairPurename $allPairNames {
    if { ! [dict exists $pairNameToLeftPath $pairPurename] }  {
      ok_err_msg "Missing left image for '$pairPurename'";  incr errCnt 1
      continue
    }
    if { ! [dict exists $pairNameToRightPath $pairPurename] }  {
      ok_err_msg "Missing right image for '$pairPurename'";  incr errCnt 1
      continue
    }
    dict append pairNameToLRPathsDict $pairPurename [list \
                                [dict get $pairNameToLeftPath  $pairPurename] \
                                [dict get $pairNameToRightPath $pairPurename]]
  }
  set msg "Correlated paths of left/right images for [dict size $pairNameToLRPathsDict] stereopair(s); $errCnt error(s) occured"
  if { $errCnt == 0 }  {  ok_info_msg $msg } else { ok_err_msg  $msg  }
  return  $pairNameToLRPathsDict  ;  # whatever was correlated
}


# Returns list of {pairname diffR diffG diffB} records
proc _map_pairname_to_color_stat_diff {pairNameToLRPathsDict}  {
  set pairNameAndColorChannelDiffList [list]
  set errCnt 0
  dict for {pairname lrPathsList} $pairNameToLRPathsDict {
    set pathLeft [lindex $lrPathsList 0];  set pathRight [lindex $lrPathsList 1]
    if { 0 == [read_channel_statistics_by_imagemagick \
                              $pathLeft meanRLeft meanGLeft meanBLeft] }  {
      incr errCnt 1;  continue;   # error already printed
    }
    if { 0 == [read_channel_statistics_by_imagemagick \
                              $pathRight meanRRight meanGRight meanBRight] }  {
      incr errCnt 1;  continue;   # error already printed
    }
    ok_trace_msg "Channel means for '$pairname' (L/R): Red $meanRLeft/$meanRRight, Green $meanGLeft/$meanGRight, Blue $meanBLeft/$meanBRight"
    set avgR [expr ($meanRLeft + $meanRRight)/2]
    set diffR [expr {($avgR==0.0)? 0 \
                : [expr {round(100 * abs($meanRLeft - $meanRRight) / $avgR)}]}]
    set avgG [expr ($meanGLeft + $meanGRight)/2]
    set diffG [expr {($avgG==0.0)? 0 \
                : [expr {round(100 * abs($meanGLeft - $meanGRight) / $avgG)}]}]
    set avgB [expr ($meanBLeft + $meanBRight)/2]
    set diffB [expr {($avgB==0.0)? 0 \
                : [expr {round(100 * abs($meanBLeft - $meanBRight) / $avgB)}]}]

    set ratioRGLeft [expr {($meanGLeft==0.0)? 9999 \
                                    : [expr {$meanRLeft  / $meanGLeft }]}]
    set ratioGBLeft [expr {($meanBLeft==0.0)? 9999 \
                                    : [expr {$meanGLeft  / $meanBLeft }]}]
    set ratioRGRight [expr {($meanGRight==0.0)? 9999 \
                                    : [expr {$meanRRight / $meanGRight}]}]
    set ratioGBRight [expr {($meanBRight==0.0)? 9999 \
                                    : [expr {$meanGRight / $meanBRight}]}]
    ok_trace_msg "Channel ratios for '$pairname': Red/Green(Left)=$ratioRGLeft, Red/Green(Right)=$ratioRGRight, Green/Blue(Left)=$ratioGBLeft, Green/Blue(Right)=$ratioGBRight"
    set avgRG [expr ($ratioRGLeft + $ratioRGRight)/2]
    set diffRG [expr {($avgRG==0.0)? 0 \
            : [expr {round(100 * abs($ratioRGLeft - $ratioRGRight) / $avgRG)}]}]
    set avgGB [expr ($ratioGBLeft + $ratioGBRight)/2]
    set diffGB [expr {($avgGB==0.0)? 0 \
            : [expr {round(100 * abs($ratioGBLeft - $ratioGBRight) / $avgGB)}]}]

    set rec [pack_pairname_to_rgb_diff_record $pairname $diffR $diffG $diffB \
                                                        $diffRG $diffGB]
    lappend pairNameAndColorChannelDiffList $rec
  }
  return  $pairNameAndColorChannelDiffList
}


# Compares supplied {pair-name diffR(%) diffG(%) diffB(%) diffRG(%) diffGB(%)}
# records by total diff, then by name
proc _less_then__pairname_to_color_diff_rec {rec1 rec2}  {
  if { 0 == [parse_pairname_to_rgb_diff_record $rec1 \
                            pairname1 diffR1 diffG1 diffB1 diffRG1 diffGB1] } {
    ok_err_msg "Invalid  {pair-name diffR(%) diffG(%) diffB(%) diffRG(%) diffGB(%)} record {$rec1}"
    return  0
  }
  if { 0 == [parse_pairname_to_rgb_diff_record $rec2 \
                            pairname2 diffR2 diffG2 diffB2 diffRG2 diffGB2] } {
    ok_err_msg "Invalid  {pair-name diffR(%) diffG(%) diffB(%) diffRG(%) diffGB(%)} record {$rec2}"
    return  0
  }
  set totalDiff1 [expr $diffR1 + $diffG1 + $diffB1 + $diffRG1 + $diffGB1]
  set totalDiff2 [expr $diffR2 + $diffG2 + $diffB2 + $diffRG2 + $diffGB2]
  if { $totalDiff1 < $totalDiff2 }  { return -1 }
  if { $totalDiff1 > $totalDiff2 }  { return  1 }
  # force ordering equal-diff records by name
  return  [string compare -nocase $pairname1 $pairname2]
}


# Outputs "raw" and sorted-by-diff versions
# of supplied list of {pair-name diffR(%) diffG(%) diffB(%)} lists.
# Warns on elements with diff above the threshold
proc _report_pairname_to_color_diff {pairNameAndColorChannelDiffList}  {
  set colorDiffCSVPath [file join $::STS(outDirPath) $::COLORDIFF_CSV_NAME]
  set colorDiffSortedCSVPath \
                [file join $::STS(outDirPath) $::COLORDIFF_SORTED_CSV_NAME]
  set header [pack_pairname_to_rgb_diff_record "pair-name" \
                      "diffR(%)" "diffG(%)" "diffB(%)" "diffRG(%)" "diffGB(%)"]
  set descrFormat " printing %s color-channel relative differences into '%s'"
  set descr1 [format $descrFormat "unsorted" $colorDiffCSVPath]
  set descr2 [format $descrFormat "sorted"   $colorDiffSortedCSVPath]
  # print unsorted list of differences
  set extendedListWithHeader [concat [list $header] $pairNameAndColorChannelDiffList]
  set ret1 [ok_write_list_of_lists_into_csv_file $extendedListWithHeader \
                                                 $colorDiffCSVPath " "]
  if { $ret1 } {ok_info_msg "Success $descr1"} else {ok_err_msg  "Failed $descr1"}
  # print sorted list of differences
  set sortedDataList [lsort -command _less_then__pairname_to_color_diff_rec \
                            -decreasing $pairNameAndColorChannelDiffList]
  set extendedListWithHeader [concat [list $header] $sortedDataList]
  # print sorted report with dual-TAB delimeter for human readability
  set ret2 [ok_write_list_of_lists_into_csv_file $extendedListWithHeader \
                                                $colorDiffSortedCSVPath "\t\t"]
  if { $ret2 } {ok_info_msg "Success $descr2"} else {ok_err_msg  "Failed $descr2"}
  # report stereopairs with differences above the threshold
  set errCnt 0;  set aboveThreshCnt 0
  foreach rec $pairNameAndColorChannelDiffList {
    if { 0 == [parse_pairname_to_rgb_diff_record $rec \
                                  pairname diffR diffG diffB diffRG diffGB] } {
      ok_err_msg "Invalid  {pair-name diffR(%) diffG(%) diffB(%) diffRG(%) diffGB(%)} record {$rec}"
      incr errCnt 1;  continue
    }
    set diffDescr ""
    foreach ch [list [list $diffR red] [list $diffG green] [list $diffB blue] \
              [list $diffRG redToGreenRatio] [list $diffGB greenToBlueRatio]] {
      set d [lindex $ch 0]; set c [lindex $ch 1]
      if { $d >= $::STS(colorDiffThresh) }  {
        append diffDescr [format " %s(%d%%)" $c $d]
      }
    }
    if { $diffDescr != "" }  {
      ok_warn_msg "Difference above the threshold of $::STS(colorDiffThresh)% in '$pairname': $diffDescr"
      incr aboveThreshCnt 1
    }
  }
  if { ($errCnt == 0) && ($aboveThreshCnt == 0) }  {
    ok_info_msg "None of [llength $pairNameAndColorChannelDiffList] stereopair(s) have color difference above the threshold of $::STS(colorDiffThresh)%"
  } else {
    ok_warn_msg "$aboveThreshCnt of [llength $pairNameAndColorChannelDiffList] stereopair(s) has/have color difference above the threshold of $::STS(colorDiffThresh)%; $errCnt error(s) occured"
  }
  return  [expr {($ret1 != 0) && ($ret2 != 0)}]
}


proc pack_pairname_to_rgb_diff_record {pairname valForR valForG valForB \
                                                valForRG valForGB} {
  return  [list $pairname $valForR $valForG $valForB $valForRG $valForGB]
}


proc parse_pairname_to_rgb_diff_record {recAsList pairname \
                                    valForR valForG valForB valForRG valForGB} {
  upvar $pairname nm
  upvar $valForR  vR;   upvar $valForG  vG;   upvar $valForB  vB
  upvar $valForRG vRG;  upvar $valForGB vGB
  if { 6 > [llength $recAsList] }  {
    return  0
  }
  set nm    [lindex $recAsList 0]
  set vR    [lindex $recAsList 1]
  set vG    [lindex $recAsList 2]
  set vB    [lindex $recAsList 3]
  set vRG   [lindex $recAsList 4]
  set vGB   [lindex $recAsList 5]
  return  1
}

