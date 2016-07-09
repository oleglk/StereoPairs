# main_paira_matcher.tcl


set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR  "ok_utils" "debug_utils.tcl"]
ok_trace_msg "---- Sourcing '[info script]' in '$SCRIPT_DIR' ----"
source [file join $SCRIPT_DIR   "ext_tools.tcl"]
source [file join $SCRIPT_DIR   "dir_file_utils.tcl"]
source [file join $SCRIPT_DIR   "stereopair_naming.tcl"]
source [file join $SCRIPT_DIR   "cnv_settings_finder.tcl"]

package require ok_utils;   namespace import -force ::ok_utils::*
package require img_proc;   namespace import -force ::img_proc::*


###################### Global variables ############################
#DO NOT: array unset STS ;   # array for global settings; unset once per project

proc _pair_matcher_set_defaults {}  {
  set ::STS(timeDiff)         0
  set ::STS(minSuccessRate)   0
  set ::STS(globalImgSettingsDir)  "" ;  # global settings dir; relevant for some converters
  set ::STS(origImgRootPath)  ""
  set ::STS(origImgDirLeft)   ""
  set ::STS(origImgDirRight)  ""
  set ::STS(stdImgRootPath)   ""
  set ::STS(outDirPath)       ""
  set ::STS(outPairlistPath)  ""
  set ::STS(inPairlistPath)   ""
  set ::STS(dirForUnmatched)  ""
  set ::STS(doRestoreLR)      0
  set ::STS(doCreateSBS)      0
  set ::STS(doRenameLR)       0
  set ::STS(doUseExifTime)    1
  set ::STS(maxBurstGap)      0
  set ::STS(doSimulateOnly)   0
}
################################################################################
_pair_matcher_set_defaults ;  # load only;  do call it in a function for repeated invocations
################################################################################

set ORIG_EXT_DICT              0;  # extensions of original out-of-camera images

set FILENAME_TIMES_LEFT   "times_left.csv"
set FILENAME_TIMES_RIGHT  "times_right.csv"
set FILENAME_RENAME_SPEC  "rename_spec.csv"
################################################################################

proc pair_matcher_main {cmdLineAsStr}  {
  global STS SCRIPT_DIR ORIG_EXT_DICT
  _pair_matcher_set_defaults ;  # calling it in a function for repeated invocations
  set extToolPathsFilePath [file join $SCRIPT_DIR ".." "ext_tool_dirs.csv"]
  if { 0 == [set_ext_tool_paths_from_csv $extToolPathsFilePath] }  {
    return  0;  # error already printed
  }
  if { 0 == [verify_external_tools] }  { return  0  };  # error already printed
  if { 0 == [pair_matcher_cmd_line $cmdLineAsStr cml] }  {
    return  0;  # error or help already printed
  }
#parray STS; #OK_TMP
  # choose type of originals; RAW is preferable
  if { 0 == [set ORIG_EXT_DICT [dualcam_choose_and_check_type_of_originals \
                     $STS(origImgDirLeft) $STS(origImgDirRight) 0]] }  {
    return  0;  # error already printed
  }
  if { ($STS(doRestoreLR) == 1) }   { ;   # commanded to restore original' names
    set restoreRes  [_pair_matcher_restore_original_names $STS(doSimulateOnly)]
    if { $restoreRes == 0 }  { return  0 } ;  # error already printed
    set unhideRes   [_pair_matcher_restore_hidden_originals $STS(doSimulateOnly)]
    return  $unhideRes ;    # error, if any, printed
  }
  # commanded to rename the originals
  if { 0 == [_pair_matcher_find_originals 0 origPathsLeft origPathsRight] }  {
    return  0;  # error already printed
  }
  # TMP: abort if settings files present - too late to rename
  if { 0 != [_detect_and_warn_if_settings_exist \
                [concat $origPathsLeft $origPathsRight] \
                "conversion settings" "renaming originals"] } {
    return  0;  # error already printed
  }

  if { 0 == [_pair_matcher_arrange_workarea] }  { return  0  };  # error already printed
  # read timestamps from all the images
  if { 0 == [_read_all_images_timestamps_or_complain \
        $origPathsLeft $origPathsRight namesToTimesLeft namesToTimesRight] }  {
    return  0;  # error already printed
  }
  if { 0 == [set matchList [_find_and_dump_pair_matches \
                                    $namesToTimesLeft $namesToTimesRight]] }  {
    return  0;  # error already printed
  }
  # check success percentage
  ok_info_msg "Found [llength $matchList] match(es) between [dict size $namesToTimesLeft] left- and [dict size $namesToTimesRight] right image(s)"
  set matchedPrc [expr {round(100.0 * [llength $matchList] / \
    (0.5 * ([dict size $namesToTimesLeft] + [dict size $namesToTimesRight]))) }]
  set matchRateDescr "$matchedPrc% of the potential stereopairs are matched; $::STS(minSuccessRate)% required to proceed"
  if { ($::STS(doCreateSBS) == 1) || ($::STS(doRenameLR) == 1) }  {
    if { $matchedPrc < $::STS(minSuccessRate) }   {
      ok_err_msg "Only $matchRateDescr. Aborting"
      return  0;
    }
  }
  ok_info_msg "$matchRateDescr"
  #TODO: if building SBS requested, do it before renaming
  if { $::STS(doRenameLR) == 1 }  {
    if { 0 == [set renameDict [_make_rename_dict_from_match_list \
                                $origPathsLeft $origPathsRight $matchList]] }  {
      return  0;  # error already printed
    }
    if { 0 == [_dump_rename_dict $renameDict] }  {
      return  0;  # error already printed
    }
    if { $::STS(doSimulateOnly) == 0 }  {
      if { 0 != [_rename_images_by_rename_dict $renameDict] }  {
        return  0;  # error already printed
      }
      if { 0 != [_hide_unmatched_images_by_rename_dict \
                      [concat $origPathsLeft $origPathsRight] $renameDict] }  {
        return  0;  # error already printed
      }
    } else {
      ok_warn_msg "Simulation-only mode; no file changes made"
    }
  }
  return  1
}


proc pair_matcher_cmd_line {cmdLineAsStr cmlArrName}  {
  upvar $cmlArrName      cml
  # create the command-line description
  set descrList \
[list \
  -help {"" "print help"} \
  -time_diff {val "time difference in seconds between the 2nd and 1st cameras"} \
  -orig_img_dir {val	"input directory; left (right) out-of-camera images expected in 'orig_img_dir'/L ('orig_img_dir'/R)"} \
  -std_img_dir {val	"input directory with standard images (out-of-camera JPEG or converted from RAW); left (right) images expected in 'std_img_dir'/L ('std_img_dir'/R)"} \
  -create_sbs	{"" "join matched pairs into SBS images; requires the directory with standard images"} \
  -rename_lr	{"" "rename left-right images to be recognizable by StereoPhotoMaker batch loading"} \
  -restore_lr	{"" "restore original left-right images' names"} \
  -min_success_rate {val "min percentage of successfull matches to permit image-file operations"} \
  -use_pairlist {val "file given provides pre-built pair matches"} \
  -out_pairlist_filename {val "name of file to write pair matches to"} \
  -out_dir {val	"output directory"} \
  -dir_for_unmatched {val "name of subdirectory to move unmatched inputs to"} \
  -time_from {val "<exif|create>	: source of shots' timestamps; using exif requires external tool (dcraw and identify)"} \
  -max_burst_gap {val "max time difference between consequent frames to be considered a burst, sec"} \
  -simulate_only {""	"if specified, no file changes performed, only decide and report what should be done"} ]
  array unset cmlD
  ok_new_cmd_line_descr cmlD $descrList
  # create dummy command line with the default parameters and copy it
  # (if an argument inexistent by default, don't provide dummy value)
  array unset defCml
  #TODO: take defaults from preferences
  ok_set_cmd_line_params defCml cmlD { \
   {-time_diff 0} {-min_success_rate 50} \
   {-out_pairlist_filename "lr_pairs.csv"} {-dir_for_unmatched "Unmatched"} \
   {-time_from "exif"} {-max_burst_gap 0.9} }
  ok_copy_array defCml cml;    # to preset default parameters
  # now parse the user's command line
  if { 0 == [ok_read_cmd_line $cmdLineAsStr cml cmlD] } {
    ok_err_msg "Aborted because of invalid command line";	return  0
  }
  if { [info exists cml(-help)] } {
    set cmdHelp [ok_help_on_cmd_line defCml cmlD "\n"]
    ok_info_msg "================================================================"
    ok_info_msg "    DualCam Pair Matcher detects pairing of out-of-camera RAW or JPEG images using timestamps."
    ok_info_msg "========= Command line parameters (in any order): =============="
    ok_info_msg $cmdHelp
    ok_info_msg "================================================================"
    ok_info_msg "========= Examples (note TCL-style directory separators): ======="
    ok_info_msg " pair_matcher_main \"-max_burst_gap 1.0 -time_diff -84 -rename_lr -orig_img_dir . -std_img_dir . -out_dir ./OUT\""
    ok_info_msg " pair_matcher_main \"-max_burst_gap 1.0 -time_diff -84 -restore_lr -orig_img_dir . -std_img_dir . -out_dir ./OUT\""
    ok_info_msg "================================================================"
    return  0
  }
  if { 0 == [_pair_matcher_parse_cmdline cml] }  {
    ok_err_msg "Error(s) in command parameters. Aborting..."
    return  0
  }
  set cmdStrNoHelp [ok_cmd_line_str cml cmlD "\n" 0]
  ok_info_msg "==== Now find image pair matches by the following spec: ===="
  ok_info_msg $cmdStrNoHelp
  return  1
}


proc _pair_matcher_parse_cmdline {cmlArrName}  {
  upvar $cmlArrName      cml
  set errCnt 0
  if { 0 == [info exists cml(-orig_img_dir)] }  {
    ok_err_msg "Please specify input directory; example: -orig_img_dir D:/Photo/Work"
    incr errCnt 1
  } elseif { 0 == [file isdirectory $cml(-orig_img_dir)] }  {
    ok_err_msg "Non-directory '$cml(-orig_img_dir)' specified as input directory"
    incr errCnt 1
  } else {
    set ::STS(origImgRootPath) $cml(-orig_img_dir)
    set ::STS(origImgDirLeft)  [file join $::STS(origImgRootPath) "L"]
    set ::STS(origImgDirRight) [file join $::STS(origImgRootPath) "R"]
    if { 0 == [file isdirectory $::STS(origImgDirLeft)] }  {
      ok_err_msg "Non-directory '$::STS(origImgDirLeft)' specified as left input directory"
      incr errCnt 1
    }
    if { 0 == [file isdirectory $::STS(origImgDirRight)] }  {
      ok_err_msg "Non-directory '$::STS(origImgDirRight)' specified as right input directory"
      incr errCnt 1
    }
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
    set ::STS(outPairlistPath) [file join $::STS(outDirPath) \
                                          $cml(-out_pairlist_filename)]
    # validity of pair-list path will be checked after out-dir creation
  }
  if { 0 == [info exists cml(-std_img_dir)] }  {
    ok_err_msg "Please specify input directory with standard images; example: -std_img_dir D:/Photo/Work"
    incr errCnt 1
  } elseif { 0 == [file isdirectory $cml(-std_img_dir)] }  {
    ok_err_msg "Non-directory '$cml(-std_img_dir)' specified as input directory with standard images"
    incr errCnt 1
  } else {
     set ::STS(stdImgRootPath) $cml(-std_img_dir)
  }
  if { 1 == [info exists cml(-restore_lr)] }  {
    if { (1 == [info exists cml(-create_sbs)]) || \
         (1 == [info exists cml(-rename_lr)]) }   {
      ok_err_msg "One invocation either renames or restores images"
      incr errCnt 1
    } else {
      set ::STS(doRestoreLR) 1
    }
  } else {  set ::STS(doRestoreLR) 0  } ;  # ensure the variable exists

  if { 0 == [string is double $cml(-time_diff)] }  {
    ok_err_msg "Time-difference should be a number"
    incr errCnt 1
  } else {
     set ::STS(timeDiff) $cml(-time_diff)
  }
  if { 1 == [info exists cml(-in_pairlist_path)] }  {
    set ::STS(inPairlistPath) $cml(-in_pairlist_path)
    if { 0 == [file exists $::STS(inPairlistPath) }  {
      ok_err_msg "Inexistent input pairlist file '$::STS(inPairlistPath)'"
      incr errCnt 1
    }
  }
  if { 1 == [info exists cml(-dir_for_unmatched)] }  {
    set ::STS(dirForUnmatched) $cml(-dir_for_unmatched)
  }
  if { 1 == [info exists cml(-create_sbs)] }  {
    if { $::STS(stdImgRootPath) == "" }  {
      ok_err_msg "SBS creation requires valid input directory with standard images (-std_img_dir)"
      incr errCnt 1
    } else {
      set ::STS(doCreateSBS) 1
    }
  } else {  set ::STS(doCreateSBS) 0  } ;  # ensure the variable exists
  if { 1 == [info exists cml(-rename_lr)] }  {
    set ::STS(doRenameLR) 1
  } else {  set ::STS(doCreateSBS) 0  } ;  # ensure the variable exists
  if { ($cml(-min_success_rate) < 1) || ($cml(-min_success_rate) > 100) }  {
    ok_err_msg "Minimal succes rate should be 1 ... 100"
    incr errCnt 1
  } else {
     set ::STS(minSuccessRate) $cml(-min_success_rate)
  }
 if { 1 == [info exists cml(-time_from)] }  {
    switch -nocase -- [string tolower $cml(-time_from)]  {
      "exif"    {  set ::STS(doUseExifTime) 1  }
      "create"  {  set ::STS(doUseExifTime) 0  }
      default   {
        ok_err_msg "-time_from expects exif|create"
        incr errCnt 1
      }
    }    
  }
  if { $cml(-max_burst_gap) <= 0 }  {
    ok_err_msg "Maximal burst interframe gap should be positive"
    incr errCnt 1
  } else {
     set ::STS(maxBurstGap) $cml(-max_burst_gap)
  }
  if { 1 == [info exists cml(-simulate_only)] }  {
    set ::STS(doSimulateOnly) 1
  } else {  set ::STS(doSimulateOnly) 0  } ;  # ensure the variable exists
  if { $errCnt > 0 }  {
    #ok_err_msg "Error(s) in command parameters!"
    return  0
  }
  #ok_info_msg "Command parameters are valid"
  return  1
}


# Puts into 'origPathsLeftVar' and 'origPathsRightVar' the paths of:
#   - original images if 'searchHidden'==0
#   - hidden original images if 'searchHidden'==1
proc _pair_matcher_find_originals {searchHidden \
                                  origPathsLeftVar origPathsRightVar}  {
  global STS ORIG_EXT_DICT
  upvar $origPathsLeftVar  origPathsLeft
  upvar $origPathsRightVar origPathsRight
  return  [dualcam_find_originals $searchHidden 1 $ORIG_EXT_DICT \
              $STS(origImgDirLeft) $STS(origImgDirRight) $STS(dirForUnmatched) \
              origPathsLeft origPathsRight]
}


proc _pair_matcher_arrange_workarea {}  {
  set unmatchedDirLeft  [file join $::STS(origImgDirLeft) $::STS(dirForUnmatched)]
  set unmatchedDirRight [file join $::STS(origImgDirRight) $::STS(dirForUnmatched)]
  if { 0 == [ok_create_absdirs_in_list \
              [list $::STS(outDirPath) $unmatchedDirLeft $unmatchedDirRight] \
              [list "output"           "left-unmatched"  "right-unmatched"]] } {
    return  0;  # error already printed
  }
  if { 0 == [ok_filepath_is_writable $::STS(outPairlistPath)] }  {
    ok_err_msg "Output path for pairlist file '$::STS(outPairlistPath)' is unwritable"
    return  0;
  }
  return  1
}


# Given dictionaries of {purename::global-time},
# returns list of match records {purenameLeft purenameRight}; on error returns 0
proc _find_and_dump_pair_matches {namesToTimesLeft namesToTimesRight} {
  set imgRecordsLeft [_sort_and_dump_name_to_time_dict $namesToTimesLeft \
          [file join $::STS(outDirPath) $::FILENAME_TIMES_LEFT]  "left images"]
  set imgRecordsRight [_sort_and_dump_name_to_time_dict $namesToTimesRight \
          [file join $::STS(outDirPath) $::FILENAME_TIMES_RIGHT] "right images"]
  # find matches in both directions; dual matches in each direction are OK
  set leftToRightMatches [_find_candidate_peers \
              $imgRecordsLeft $imgRecordsRight $::STS(timeDiff)]
  set rightToLeftMatches [_find_candidate_peers \
              $imgRecordsRight $imgRecordsLeft [expr -1 * $::STS(timeDiff)]]
  #TODO: check for no matches at all and suggest to correct time-difference
  set flatListOfMatchesLR [list];  set flatListOfMatchesRL [list]; #{nameL nameR}
  dict for {name peers} $leftToRightMatches {
    set forGTime [dict get $namesToTimesLeft $name]; # time of the left image
    foreach rec $peers {
      ParseNameTimeRecord $rec nameP timeStrP globalTimeP idxInBurstOrZeroP
      set deltaT [expr $globalTimeP - ($forGTime + $::STS(timeDiff))]
      lappend flatListOfMatchesLR [list $name $nameP $deltaT]; # {nameL nameR dt}
    }
  }
  dict for {name peers} $rightToLeftMatches {
    set forGTime [dict get $namesToTimesRight $name]; # time of the right image
    foreach rec $peers {
      ParseNameTimeRecord $rec nameP timeStrP globalTimeP idxInBurstOrZeroP
      set deltaT [expr $forGTime - ($globalTimeP + $::STS(timeDiff))]
      lappend flatListOfMatchesRL [list $nameP $name $deltaT]; # {nameL nameR dt}
    }
  }
  ok_info_msg "Found [llength $flatListOfMatchesLR] left-to-right and [llength $flatListOfMatchesRL] rifht-to-left candidate match(es)"
  set flatListOfMatches [concat $flatListOfMatchesLR $flatListOfMatchesRL]
  if { 0 == [llength $flatListOfMatches] } {
    ok_err_msg "No matches found; please check time difference between the cameras"
    return  0
  }
  set flatListOfMatches [lsort -unique $flatListOfMatches]; # TODO: ignore times
  ok_info_msg "Found [llength $flatListOfMatches] ultimate bidirectional candidate match(es)"
  ok_trace_msg "flatListOfMatches: {$flatListOfMatches}"
  _dump_list_of_matches $flatListOfMatches
  #TODO? dump initial unidirectional matches
  return  $flatListOfMatches
}


proc _dump_list_of_matches {flatListOfMatchesNoHeader}  {
  set lstWithHdr [concat {{Left Right Time-Diff}} $flatListOfMatchesNoHeader]
  ok_write_list_of_lists_into_csv_file $lstWithHdr $::STS(outPairlistPath) ","
  # any error printed
}


# Returns dictionary {purename::list-of-possible-peers} for images in 'forImgRecords';
# peers taken from 'fromImgRecords'.
# An input/output record is {name time-str global-time idx-in-burst-or-minus1}
# timeFrom == timeFor + timeDiff
proc _find_candidate_peers {forImgRecords fromImgRecords timeBias}  {
  set nFor  [llength $forImgRecords]
  set nFrom [llength $fromImgRecords]
  set fromTimesList [list]; # build sorted list of candidate timestamps here
  foreach rec $fromImgRecords {
    ParseNameTimeRecord $rec name timeStr globalTime idxInBurstOrZero
    lappend fromTimesList $globalTime
  }
  set dictOfCandidateLists [dict create] ;  # for the returned value
  set iFrom 0
  for {set iFor 0} {$iFor < $nFor} {incr iFor 1} {
    set forRec [lindex $forImgRecords $iFor]
    ok_trace_msg "'FOR' record: {$forRec}"
    ParseNameTimeRecord $forRec name1 timeStr1 globalTime1 idxInBurst1
    set timeFrom    [expr $globalTime1 + $timeBias]
    set timeFromMin [expr $globalTime1 + $timeBias - $::STS(maxBurstGap)]
    set timeFromMax [expr $globalTime1 + $timeBias + $::STS(maxBurstGap)]
    ok_trace_msg "Peers global-time range for '$name1' ($globalTime1==>$timeFrom) is \[$timeFromMin .. $timeFromMax\]"
    ok_trace_msg "Going to search for peers of '$name1' ($globalTime1==>$timeFrom) in {$fromTimesList}"
    ok_bisect_find_range $fromTimesList $timeFromMin posBeforeMin posAfterMin
    ok_bisect_find_range $fromTimesList $timeFromMax posBeforeMax posAfterMax
    # 'posBefore' and 'posAfter' are valid indices in 'fromTimesList';
    # if the value is out-of-range, both get first or last index
    ok_trace_msg "Peers indices range for '$name1' ($globalTime==>$timeFrom) is {$posBeforeMin .. $posAfterMax}"
    # find peer(s) with min time-difference by scanning acceptable range
    set candidatesForOne [list];  set minAbsTimeDiff 99999999999999
    for {set iFrom $posBeforeMin} {$iFrom <= $posAfterMax} {incr iFrom 1} { ; #1
      set fromRec [lindex $fromImgRecords $iFrom]
      ParseNameTimeRecord $fromRec name2 timeStr2 globalTime2 idxInBurst2
      set timeDiff [expr $globalTime2 - $timeFrom]
      ok_trace_msg "Candidate '$name2' : \[$timeFromMin .. $globalTime2 .. $timeFromMax\]"
      ok_trace_msg "Time difference between '$name1' and '$name2' is $timeDiff"
      if { ($timeFromMin <= $globalTime2) && ($globalTime2 <= $timeFromMax) }  {
        if { abs($timeDiff) <= $minAbsTimeDiff }  {
          set minAbsTimeDiff [expr abs($timeDiff)]
        }
      } else {
        ok_trace_msg "Candidate '$name2' rejected, since its timestamp ($globalTime2) is outside of acceptable range \[$timeFromMin .. $timeFromMax\]"
      }
      
    }
    ok_trace_msg "Minimal global time difference for '$name1' is $minAbsTimeDiff"
    for {set iFrom $posBeforeMin} {$iFrom <= $posAfterMax} {incr iFrom 1} { ; #2
      set fromRec [lindex $fromImgRecords $iFrom]
      ParseNameTimeRecord $fromRec name2 timeStr2 globalTime2 idxInBurst2
      set timeDiff [expr $globalTime2 - $timeFrom]
      if { abs($timeDiff) == $minAbsTimeDiff }  {
        lappend candidatesForOne $fromRec
      }
    }
    ok_info_msg "Found [llength $candidatesForOne] candidate peer(s) for '$name1' ($globalTime)"
    dict set dictOfCandidateLists $name1 $candidatesForOne
  }
  return  $dictOfCandidateLists
}



# Returns sorted by time list of list-records:
#   {name time-str global-time idx-in-burst-or-minus1}
proc _sort_name_to_time_dict_and_detect_bursts {namesToTimesDict descr} {
  set listOfLists [list]
  # build and sort list of records without burst detection
  dict for {purename gTime} $namesToTimesDict {
    set timeStr [clock format $gTime -format "%Y-%m-%d/%H:%M:%S"]
    lappend listOfLists [PackNameTimeRecord $purename $timeStr $gTime -1]
  }
  #ok_trace_msg "Unsorted name-time list: {$listOfLists}"
  set listOfLists [lsort -command _cmp_file_times $listOfLists]
  #ok_trace_msg "Sorted name-time list: {$listOfLists}"
  # detect and mark images in bursts
  set burstCnt 0;  set idxInBurst -1
  for {set i 1} {$i < [llength $listOfLists]} {incr i}  {
    set prevRec [lindex $listOfLists [expr $i - 1]]
    set currRec [lindex $listOfLists $i]
    ParseNameTimeRecord $prevRec nameP timeStrP globalTimeP idxInBurstOrZeroP
    ParseNameTimeRecord $currRec nameC timeStrC globalTimeC idxInBurstOrZeroC
    if { $::STS(maxBurstGap) >= [global_time_diff $globalTimeC $globalTimeP] } {
      # the 2 records are in burst
      if { $idxInBurst == -1 } {
        incr burstCnt 1
        set idxInBurst 0;   # index for the previous record (start of burst)
        set prevRec [PackNameTimeRecord \
                                    $nameP $timeStrP $globalTimeP $idxInBurst]
        set listOfLists [lreplace $listOfLists [expr $i - 1] [expr $i - 1] \
                                                $prevRec]
      }
      incr idxInBurst 1 ;   # index for the current record
      set currRec [PackNameTimeRecord \
                                  $nameC $timeStrC $globalTimeC $idxInBurst]
      set listOfLists [lreplace $listOfLists $i $i $currRec]
    } else { set idxInBurst -1 }
  }
  ok_info_msg "Found $burstCnt burst(s) in the set of [llength $listOfLists] $descr"
  return $listOfLists
}


# Returns time difference (globalTime1 - globalTime2) in seconds
proc global_time_diff {globalTime1 globalTime2}  {
  return  [expr $globalTime1 - $globalTime2]
}


proc PackNameTimeRecord {name timeStr globalTime idxInBurstOrZero}  {
  return  [list $name $timeStr $globalTime $idxInBurstOrZero]
}


proc ParseNameTimeRecord {record name timeStr globalTime idxInBurstOrZero}  {
  upvar $name             nm
  upvar $timeStr          tm
  upvar $globalTime       gt
  upvar $idxInBurstOrZero ib
  set nm [lindex $record 0];  set tm [lindex $record 1]
  set gt [lindex $record 2];  set ib [lindex $record 3]
}


#TODO:  proc PackMatchListRecord {nameLeft nameRight timeDiffRightLeft} {}


proc ParseMatchListRecord {record nameLeft nameRight timeDiffRightLeft} {
  upvar $nameLeft           nmL
  upvar $nameRight          nmR
  upvar $timeDiffRightLeft  dt
  set nmL [lindex $record 0];  set nmR [lindex $record 1]
  set dt  [lindex $record 2]
}




# Compares list-records {name time-str global-time} by global-time
proc _cmp_file_times {fileTimeRecord1 fileTimeRecord2} {
  set t1 [lindex $fileTimeRecord1 2];   set t2 [lindex $fileTimeRecord2 2]
  return  [expr $t1 - $t2]
}


# Returns sorted by time list of list-records:
#   {name time-str global-time idx-in-burst-or-minus1}
# TODO: error detection
proc _sort_and_dump_name_to_time_dict {namesToTimesDict outPath descr} {
  set listOfLists [_sort_name_to_time_dict_and_detect_bursts \
                                                      $namesToTimesDict $descr]
  set headerElem [list "purename" "date-time" "global-time" "index-in-burst"]
  set topList [concat [list $headerElem] $listOfLists]
  #~ dict for {purename gTime} $namesToTimesDict {
    #~ set timeStr [clock format $gTime -format "%Y-%m-%d/%H:%M:%S"]
    #~ lappend topList [list $purename $timeStr $gTime]
  #~ }
  ok_write_list_of_lists_into_csv_file $topList $outPath ","; #any error printed
  return  $listOfLists
}


# Builds dictionaries of {purename::global-time}; returns 1 on success, 0 on error
proc _read_all_images_timestamps_or_complain {origPathsLeft origPathsRight \
                                              namesToTimesLeftDictVar \
                                              namesToTimesRightDictVar} {
  upvar $namesToTimesLeftDictVar  namesToTimesLeft
  upvar $namesToTimesRightDictVar namesToTimesRight
  # read timestamps from all the images
  set namesToTimesLeft  [get_listed_images_global_timestamps $origPathsLeft ]
  set namesToTimesRight [get_listed_images_global_timestamps $origPathsRight]
  if { ($namesToTimesLeft == 0)  || (0 == [dict size $namesToTimesLeft] ) || \
       ($namesToTimesRight == 0) || (0 == [dict size $namesToTimesRight]) }  {
    ok_err_msg "Failed reading original images' timestamps. Aborting..."
    return  0
  }
  set numLeft [llength $origPathsLeft]
  set numGoodLeft [dict size $namesToTimesLeft]
  set numRight [llength $origPathsRight]
  set numGoodRight [dict size $namesToTimesRight]
  ok_info_msg "Done reading timestamp(s) of [dict size $namesToTimesLeft] left- and [dict size $namesToTimesRight] right image(s)"
  if { ($numGoodLeft != $numLeft) || ($numRight != $numGoodRight) }  {
    ok_err_msg "Failed reading timestamp(s) for some of the images. Aborting"
    return  0
  }

  return  1
}


# Returns dictionary mapping original (both left and right) image paths
# to lists of renamed left/right stereopair member paths.
## Example: assuming 'matchList' includes f01<->f37, f02<->f37 and f04<->f38,
## the returned dict should have:
##    <dirL>/f01::{<dirL>/f01-f37_l}, <dirL>/f02::{<dirL>/f02-f37_l}
##    <dirL>/f04::{<dirL>/f04-f38_l},
##    <dirR>/f37::{<dirR>/f01-f37_r <dirR>/f02-f37_r},
##    <dirR>/f38::{<dirR>/f04-f38_r}
proc _make_rename_dict_from_match_list {imgPathsLeft imgPathsRight matchList} {
  set renameDict [dict create] 
  set pureNameToPathLeft [dict create];   set pureNameToPathRight [dict create]
  foreach p $imgPathsLeft {
    set purename [AnyFileNameToPurename [file tail $p]]
    dict set pureNameToPathLeft $purename $p
  }
  foreach p $imgPathsRight {
    set purename [AnyFileNameToPurename [file tail $p]]
    dict set pureNameToPathRight $purename $p
  }
  ok_info_msg "Start building rename specs for [expr 2*[llength $matchList]] images"
  set errCnt 0
  foreach m $matchList {
    ParseMatchListRecord $m nameLeft nameRight timeDiffRightLeft
    set basePurename [build_stereopair_purename $nameLeft $nameRight]
    ok_trace_msg "TODO '$nameLeft' + '$nameRight' = '$basePurename'"
    set lname [build_spm_left_purename  $basePurename]
    set rname [build_spm_right_purename $basePurename]
    if { 0 == [_set_src_and_dest_lr_paths $pureNameToPathLeft $nameLeft \
                                          $lname "left" renameDict] } {
      incr errCnt 1;  continue;  # error already printed
    }
    if { 0 == [_set_src_and_dest_lr_paths $pureNameToPathRight $nameRight \
                                          $rname "right" renameDict] } {
      incr errCnt 1;  continue;  # error already printed
    }    
  }
  ok_info_msg "Done building rename specs for [expr 2*[llength $matchList]] images; $errCnt error(s) occured"
  return  $renameDict
}


# origPureName=dsc003, dstPairPurename=dsc003-045, descr=left
# adds to renameDictVar <dir>/dsc003 =>{<dir>/dsc003-045_l}
# A mapping is from orig path to LIST of one or more destination paths.
proc _set_src_and_dest_lr_paths {origPureNameToPathDict origPureName \
                                 dstPairPurename descr renameDictVar}  {
  upvar $renameDictVar renameDict
  if { 0 == [dict exists $origPureNameToPathDict $origPureName] }  {
    ok_err_msg "No source path for $descr image '$origPureName'"
    return  0
  }
  set srcPath [dict get $origPureNameToPathDict $origPureName]
  if { 1 == [dict exists $renameDict $srcPath] }  {
    set targetsList [dict get $renameDict $srcPath]
  } else {      set targetsList [list]     }
  set srcDir  [file dirname $srcPath]
  set srcExt  [file extension $srcPath]
  set dstPairName "$dstPairPurename$srcExt"
  set n [expr 1 + [llength $targetsList]]
  ok_info_msg "Target #$n for '$srcPath':\t'$dstPairName'"
  lappend targetsList [file join $srcDir $dstPairName]
  dict set renameDict $srcPath $targetsList
  return  1
}


# 'renameDict' holds pairs <srcPath> => {list of <dstPath>-s}
# Returns number of errors encountered
proc _rename_images_by_rename_dict {renameDict} {
  set errCnt 0;   set replCnt 0
  set srcPaths [dict keys $renameDict]
  ok_info_msg "Start renaming [llength $srcPaths] original image(s) under '[file normalize $::STS(origImgRootPath)]'"
  foreach srcPath $srcPaths {
    set dstPaths [dict get $renameDict $srcPath]
    # if >1 destination images, the source should be replicated
    for {set i 1} {$i < [llength $dstPaths]} {incr i}  {
      set dstPath [lindex $dstPaths $i]
      ok_info_msg "Making replica #$i of '$srcPath': '$dstPath'"
      incr replCnt 1
      set tclExecResult [catch {
                          file copy -- $srcPath $dstPath } execResult]
      if { $tclExecResult != 0 } {
        ok_warn_msg "Failed replicating image '$srcPath' into '$dstPath'."
        incr errCnt 1
      }
    }
    set dstPath [lindex $dstPaths 0]
    ok_info_msg "Renaming '$srcPath': '$dstPath'"
    set tclExecResult [catch {
                        file rename -- $srcPath $dstPath } execResult]
    if { $tclExecResult != 0 } {
      ok_warn_msg "Failed renaming image '$srcPath' into '$dstPath'."
      incr errCnt 1
    }
  }
  ok_info_msg "Done renaming [llength $srcPaths] original image(s) under '[file normalize $::STS(origImgRootPath)]'; $replCnt file replication(s) made; $errCnt error(s) occured"
  return  $errCnt
}


# Moves unmatched originals into subdirectories STS(dirForUnmatched) of their dir-s
# 'renameDict' holds pairs <srcPath> => {list of <dstPath>-s}
# Returns number of errors encountered
proc _hide_unmatched_images_by_rename_dict {origPaths renameDict \
                                                            {simulateOnly 0}}  {
  set hideCnt 0;  set umCnt 0;  set errCnt 0
  set nOrigs [llength $origPaths]
  ok_trace_msg "Begin search for unmatched originals out of $nOrigs image(s)"
  foreach origPath $origPaths {
    if { 1 == [dict exists $renameDict $origPath] }  {
      continue;   # matched image
    }
    set settingsFilesForOne [FindSettingsFilesForListedImages \
                                                  [list $origPath] cntMissing 0]
    incr umCnt [expr {1 + [llength $settingsFilesForOne]}]
    set destDirPath [file join [file dirname $origPath] $::STS(dirForUnmatched)]
    # 'destDirPath' should exist
    set fileDescr "unmatched original image '$origPath' into '$destDirPath'"
    if { $simulateOnly != 0 }  {
      ok_info_msg "Would have moved $fileDescr";   incr hideCnt 1
    } else {
      if { 0 == [ok_move_file_if_target_inexistent $origPath $destDirPath 1] } {
        incr errCnt 1
      } else {
        ok_info_msg "Moved $fileDescr";   incr hideCnt 1
      }
    }
    foreach fP $settingsFilesForOne {
      set fileDescr "file '$fP' (related to unmatched image '$origPath') into '$destDirPath'"
      if { $simulateOnly != 0 }  {
        ok_info_msg "Would have moved $fileDescr";   incr hideCnt 1
      } else {
        if { 0 == [ok_move_file_if_target_inexistent $fP $destDirPath 1]} {
          incr errCnt 1
        } else {
          ok_info_msg "Moved $fileDescr";   incr hideCnt 1
        }
      }
    }
  }
  if { $umCnt == $hideCnt } {
    ok_info_msg "Found and hid $hideCnt file(s) related to unmatched original image(s)"
  } else {
    ok_warn_msg "Found $umCnt file(s) related to unmatched original image(s); hid $hideCnt; $errCnt error(s) occured"
  }
  return  $errCnt
}


proc UNUSED___rename_images_by_match_list {imgPathsLeft imgPathsRight matchList}  {
  set pureNameToPathLeft [dict create];   set pureNameToPathRight [dict create]
  foreach p $imgPathsLeft {
    set purename [AnyFileNameToPurename [file tail $p]]
    dict set pureNameToPathLeft $purename $p
  }
  foreach p $imgPathsRight {
    set purename [AnyFileNameToPurename [file tail $p]]
    dict set pureNameToPathRight $purename $p
  }
  ok_info_msg "Start renaming [expr 2*[llength $matchList]] images"
  foreach m $matchList {
    ParseMatchListRecord $m nameLeft nameRight timeDiffRightLeft
    set basePurename [build_stereopair_purename $nameLeft $nameRight]
    ok_trace_msg "TODO '$nameLeft' + '$nameRight' = '$basePurename'"
    #TODO: build full parh and rename
  }
}


# Saves 'renameDict' in CSV file
# 'renameDict' holds pairs <srcPath> => {list of <dstPath>-s}
proc _dump_rename_dict {renameDict}  {
  set outPath [file join $::STS(outDirPath) $::FILENAME_RENAME_SPEC] 
  set listOfLists [list]
  # build and sort list of src-dst pairs by src-then-dst; add header later
  dict for {srcPath dstPathList} $renameDict {
    foreach dstPath $dstPathList {
      lappend listOfLists [list $srcPath $dstPath]
    }
  }
  #ok_trace_msg "Unsorted src-dst list: {$listOfLists}"
  set listOfLists [lsort -dictionary -increasing $listOfLists]
  set headerElem [list "source-path" "destination-path"]
  set topList [concat [list $headerElem] $listOfLists]
  set wres [ok_write_list_of_lists_into_csv_file $topList $outPath ","]
  if { $wres == 1 }   {
    ok_info_msg "Success saving rename spec in '$outPath'"
  } else {
    ok_err_msg "Failed saving rename spec in '$outPath'"
  }
  return  $wres
}



# Renames left/right images in the work-area
# according to rename spec in '$::STS(outDirPath)/$::FILENAME_RENAME_SPEC'
proc _pair_matcher_restore_original_names {{simulateOnly 0}}  {
  set specPath [file join $::STS(outDirPath) $::FILENAME_RENAME_SPEC]
  set listOfLists [ok_read_csv_file_into_list_of_lists $specPath "," "#" 0]
  if { $listOfLists == 0 } {
    ok_err_msg "Failed reading rename spec from '$specPath'"
    return  0
  }
  ok_trace_msg "rename-spec unsorted: {$listOfLists}"
  # listOfLists == {{header} {origPath productPath} ... {origPath productPath}}
  # skip rename-spec header, then sort 'listOfLists',
  #   so that records for one original appear sequentially
  set listOfLists [lsort -dictionary [lrange $listOfLists 1 end]]
  ok_trace_msg "rename-spec sorted: {$listOfLists}"
  ok_info_msg "Read rename spec of [llength $listOfLists] rename-record(s) from '$specPath' - for image(s) under '[file normalize $::STS(origImgRootPath)]"

  set renamedOrigPaths [dict values [eval concat $listOfLists]]
  if { 0 != [_detect_and_warn_if_settings_exist $renamedOrigPaths \
            "conversion settings for renamed" "restoring originals' names"] } {
    return  0;  # error already printed
  }
 
  set listedOriginalsCnt 0; set restoredCnt 0
  set missingCnt 0;   set errCnt 0;   set existedCnt 0
  set lastListedOriginal ""
  set lastRestoredOriginal ""
  foreach renameRecord $listOfLists {
    set origPath     [lindex $renameRecord 0]
    set renamedPath  [lindex $renameRecord 1]
    if { $origPath == $lastRestoredOriginal }  {; # we already restored it
      if { $simulateOnly == 0 }  {
        ok_delete_file $renamedPath;  # not needed - its target already restored
        ok_info_msg "Deleted unneeded '$renamedPath' - its target already restored"
      } else {
        ok_info_msg "Would have deleted '$renamedPath' - its target already restored"
      }
      continue
    }
    if { ($lastListedOriginal != "") && ($origPath != $lastListedOriginal) && \
         ($lastListedOriginal != $lastRestoredOriginal) }  {
      ok_warn_msg "Original image file '$lastListedOriginal' not restored"
    }
    set lastListedOriginal $origPath ;  # it's the 1st record for 'origPath'
    incr listedOriginalsCnt 1
    if { [file exists $origPath] }  {
      ok_warn_msg "Original image file '$origPath' exists; not overriden"
      set origPath $lastRestoredOriginal ;  # existed or restored - no matter
      incr existedCnt 1;      continue
    }
    if { 0 == [file exists $renamedPath] }  {
      ok_warn_msg "Listed renamed image '$renamedPath' inexistent"
      incr missingCnt 1;      continue
    }
    if { $simulateOnly != 0 }  {
      ok_info_msg "Would have restored '$origPath' from '$renamedPath'"
      incr restoredCnt 1;  set lastRestoredOriginal $origPath;      continue
    }
    ok_info_msg "Going to restore '$origPath' from '$renamedPath'"
    set tclExecResult [catch {
                        file rename -- $renamedPath $origPath } execResult]
    if { $tclExecResult != 0 } {
      ok_warn_msg "Failed renaming image '$renamedPath' into '$origPath'"
      incr errCnt 1
    } else {
      ok_info_msg "Success restoring '$origPath' from '$renamedPath'"
      incr restoredCnt 1
      set lastRestoredOriginal $origPath
    }
  } ;   # foreach origPath
  set actionDescr [expr {($simulateOnly == 0)? \
                                      "Restored" : "Simulated restoration for"}]
  set msg "$actionDescr name(s) of $restoredCnt original image(s) out of $listedOriginalsCnt under '[file normalize $::STS(origImgRootPath)]"
  if { $missingCnt > 0 }  { append msg "; $missingCnt renamed image(s) missing"}
  if { $existedCnt > 0 }  { append msg "; $existedCnt original image(s) pre-existed (not overriden)"}
  if { $errCnt > 0 }      { append msg "; $errCnt error(s) occured"            }
  if { $errCnt == 0 }   { ok_info_msg $msg } else { ok_err_msg $msg }
  return  [expr {($errCnt == 0)? 1 : 0}]
}


proc _pair_matcher_restore_hidden_originals {{simulateOnly 0}}  {
  global STS
  if { 0 == [_pair_matcher_find_originals 1 hidePathsLeft hidePathsRight] }  {
    return  0;  # error already printed
  }
#  set unmatchedDirLeft  [file join $STS(origImgDirLeft)  $STS(dirForUnmatched)]
#  set unmatchedDirRight [file join $STS(origImgDirRight) $STS(dirForUnmatched)]
  set srcPathsAndDestDir [list  [list $hidePathsLeft $STS(origImgDirLeft)] \
                                [list $hidePathsRight $STS(origImgDirRight)] ]
  set hideCnt [expr [llength $hidePathsLeft] + [llength $hidePathsRight]]
  set unhideCnt 0;  set errCnt 0;   set existedCnt 0
  foreach rec $srcPathsAndDestDir {
    set hidePaths [lindex $rec 0];   set destDirPath [lindex $rec 1]
    set settingsDestDirPath [expr {($::STS(globalImgSettingsDir) == "")? \
                                  $destDirPath : $::STS(globalImgSettingsDir)}]
    foreach hiddenImgPath $hidePaths {
      set settingsFilesForOne [FindSettingsFilesForListedImages \
                                             [list $hiddenImgPath] cntMissing 0]
      incr hideCnt [llength $settingsFilesForOne]
      set origPath [file join $destDirPath [file tail $hiddenImgPath]]
      if { [file exists $origPath] }  {
        ok_warn_msg "Original image file '$origPath' exists; not overriden"
        incr existedCnt 1;      continue
      }
      set fileDescr "unmatched image '$hiddenImgPath' into '$destDirPath'"
      if { $simulateOnly != 0 }  {
        ok_info_msg "Would have returned $fileDescr";   incr unhideCnt 1
      } else {
        if { 0 == [ok_move_file_if_target_inexistent \
                                              $hiddenImgPath $destDirPath 1] } {
          incr errCnt 1
        } else {
          ok_info_msg "Returned $fileDescr";  incr unhideCnt 1
        }
      }
      set settingsDestDirPath [expr {($::STS(globalImgSettingsDir) == "")? \
                                    $destDirPath : $::STS(globalImgSettingsDir)}]
      foreach fP $settingsFilesForOne {
        set origPath [file join $settingsDestDirPath [file tail $fP]]
        if { [file exists $origPath] }  {
          ok_warn_msg "Original image related file '$origPath' exists; not overriden"
          incr existedCnt 1;      continue
        }
        set fileDescr "file '$fP' (related to unmatched image '$origPath') into '$settingsDestDirPath'"
        if { $simulateOnly != 0 }  {
          ok_info_msg "Would have returned $fileDescr";   incr unhideCnt 1
        } else {
          if { 0 == [ok_move_file_if_target_inexistent $fP $settingsDestDirPath 1]} {
            incr errCnt 1
          } else {
            ok_info_msg "Returned $fileDescr";  incr unhideCnt 1
          }
        }
      }
    }
  }
  set actStr [expr {($simulateOnly != 0)? "Would have restored" : "Restored"}]
  set msg "$actStr $unhideCnt hidden file(s) related to unmatched original image(s) out of $hideCnt; $existedCnt file(s) pre-existed; $errCnt error(s) occured"
  if { $errCnt == 0 } { ok_info_msg $msg } else { ok_err_msg $msg }
  return  [expr {($errCnt == 0)? 1 : 0}]s
}


# TMP: declare abort if settings files present - too late to rename
proc _detect_and_warn_if_settings_exist {origImgPaths \
                                        descrOfFile descrOfAction} {
  set srcSettingsFiles [FindSettingsFilesForListedImages \
                                                    $origImgPaths cntMissing 0]
  if { 0 != [llength $srcSettingsFiles] } {
    ok_err_msg "Aborted since $descrOfFile file(s) found; $descrOfAction may turn them unusable; the recommended workflow enforces renaming prior to conversion"
    return  1
  }
  return  0
}
