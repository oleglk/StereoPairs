# main_pair_matcher.tcl


set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR  "ok_utils" "debug_utils.tcl"]
ok_trace_msg "---- Sourcing '[info script]' in '$SCRIPT_DIR' ----"
source [file join $SCRIPT_DIR   "ext_tools.tcl"]
source [file join $SCRIPT_DIR   "image_metadata.tcl"]
source [file join $SCRIPT_DIR   "dir_file_utils.tcl"]

package require ok_utils
namespace import -force ::ok_utils::*


###################### Global variables ############################
array unset STS ;   # array for global settings

proc _set_defaults {}  {
  set ::STS(timeDiff)         0
  set ::STS(minSuccessRate)   0
  set ::STS(origImgRootPath)  ""
  set ::STS(origImgDirLeft)   ""
  set ::STS(origImgDirRight)  ""
  set ::STS(stdImgRootPath)   ""
  set ::STS(outDirPath)       ""
  set ::STS(outPairlistPath)  ""
  set ::STS(inPairlistPath)   ""
  set ::STS(dirForUnmatched)  ""
  set ::STS(doCreateSBS)      0
  set ::STS(doRenameLR)       0
  set ::STS(doUseExifTime)    1
  set ::STS(maxBurstGap)      0
  set ::STS(doSimulateOnly)   0
}
################################################################################
_set_defaults ;  # load only;  do call it in a function for repeated invocations
################################################################################

set ORIG_EXT              "" ;  # extension of original out-of-camera images

set FILENAME_TIMES_LEFT   "times_left.csv"
set FILENAME_TIMES_RIGHT  "times_right.csv"
set FILENAME_RENAME_SPEC  "rename_spec.csv"
################################################################################

proc pair_matcher_main {cmdLineAsStr}  {
  global STS ORIG_EXT
  if { 0 == [verify_external_tools] }  { return  0  };  # error already printed
  _set_defaults ;  # calling it in a function for repeated invocations
  if { 0 == [pair_matcher_cmd_line $cmdLineAsStr cml] }  {
    return  0;  # error or help already printed
  }
  # choose type of originals; RAW is preferable
  if { "" == [set ORIG_EXT [ChooseOrigImgExtensionInDirs \
                      [list $STS(origImgDirLeft) $STS(origImgDirRight)]]] }  {
    return  0;  # error already printed
  }
  if { 0 == [pair_matcher_find_originals origPathsLeft origPathsRight] }  {
    return  0;  # error already printed
  }
  if { 0 == [_arrange_workarea] }  { return  0  };  # error already printed
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
    if { 0 == $::STS(doSimulateOnly) }  {
      if { 0 != [_rename_images_by_rename_dict $renameDict] }  {
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
  -time_diff {val "time difference in miliseconds between the 2nd and 1st cameras"} \
  -orig_img_dir {val	"input directory; left (right) out-of-camera images expected in 'orig_img_dir'/L ('orig_img_dir'/R)"} \
  -std_img_dir {val	"input directory with standard images (out-of-camera JPEG or converted from RAW); left (right) images expected in 'std_img_dir'/L ('std_img_dir'/R)"} \
  -create_sbs	{"" "join matched pairs into SBS images; requires the directory with standard images"} \
  -rename_lr	{"" "rename left-right images to be recognizable by StereoPhotoMaker batch loading"} \
  -min_success_rate {val "min percentage of successfull matches to permit image-file operations"} \
  -use_pairlist {val "file given provides pre-built pair matches"} \
  -out_pairlist_filename {val "name of file to write pair matches to"} \
  -out_dir {val	"output directory"} \
  -move_unmatched_to {val "directory to move unmatched inputs to; if not given, don't move those"} \
  -time_from {val "<exif|create>	: source of shots' timestamps; using exif requires external tool (dcraw and identify)"} \
  -max_burst_gap {val "max time difference between consequent frames to be considered a burst, sec"} \
  -simulate_only {""	"if specified, no file changes performed, only decide and report what should be done"} ]
  array unset cmlD
  ok_new_cmd_line_descr cmlD $descrList
  # create dummy command line with the default parameters and copy it
  # (if an argument inexistent by default, don't provide dummy value)
  array unset defCml
  ok_set_cmd_line_params defCml cmlD { \
   {-time_diff 0} {-min_success_rate 50} \
   {-out_pairlist_filename "lr_pairs.csv"} {-time_from "exif"} \
   {-max_burst_gap 0.9} }
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
    ok_info_msg "========= Example (note TCL-style directory separators): ======="
    ok_info_msg "TODO"
    ok_info_msg "================================================================"
    return  0
  }
  if { 0 == [_parse_cmdline cml] }  {
    ok_err_msg "Error(s) in command parameters. Aborting..."
    return  0
  }
  set cmdStrNoHelp [ok_cmd_line_str cml cmlD "\n" 0]
  ok_info_msg "==== Now TODO by the following spec: ===="
  ok_info_msg $cmdStrNoHelp
  return  1
}


proc _parse_cmdline {cmlArrName}  {
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
  if { 1 == [info exists cml(-move_unmatched_to)] }  {
    set ::STS(dirForUnmatched) $cml(-move_unmatched_to)
    if { 0 == [file isdirectory $::STS(dirForUnmatched) }  {
      ok_err_msg "Inexistent or invalid directory for unmatched inputs '$::STS(dirForUnmatched)'"
      incr errCnt 1
    }
  }
  if { 1 == [info exists cml(-create_sbs)] }  {
    if { $::STS(stdImgRootPath) == "" }  {
      ok_err_msg "SBS creation requires valid input directory with standard images (-std_img_dir)"
      incr errCnt 1
    } else {
      set ::STS(doCreateSBS) 1
    }
  }
  if { 1 == [info exists cml(-rename_lr)] }  {
    set ::STS(doRenameLR) 1
  }
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
  }
  if { $errCnt > 0 }  {
    #ok_err_msg "Error(s) in command parameters!"
    return  0
  }
  #ok_info_msg "Command parameters are valid"
  return  1
}


proc pair_matcher_find_originals {origPathsLeftVar origPathsRightVar}  {
  global STS ORIG_EXT
  upvar $origPathsLeftVar  origPathsLeft
  upvar $origPathsRightVar origPathsRight
  if { $ORIG_EXT == "" }  {
    ok_err_msg "Cannot find originals before their extension is determined"
    return  0
  }
  set origPathsLeft  [glob -nocomplain -directory $STS(origImgDirLeft)  "*.$ORIG_EXT"]
  set origPathsRight [glob -nocomplain -directory $STS(origImgDirRight) "*.$ORIG_EXT"]
  ok_trace_msg "Left originals:   {$origPathsLeft}"
  ok_trace_msg "Right originals:  {$origPathsRight}"
  set missingStr ""
  if { 0 == [llength $origPathsLeft] }   { append missingStr " left" }
  if { 0 == [llength $origPathsRight] }  { append missingStr " right" }
  if { $missingStr != "" }  {
    ok_err_msg "Missing original images for:$missingStr"
    return  0
  }
  ok_info_msg "Found [llength $origPathsLeft] left- and [llength $origPathsRight] right original image(s)"
  return  1
}


proc _arrange_workarea {}  {
  if { 0 == [file exists $::STS(outDirPath)] }  {
    if { 0 == [ok_mkdir $::STS(outDirPath)] }  {
      return  0;  # error already printed
    }
    ok_info_msg "Created output directory '$::STS(outDirPath)'"
    return  1
  } else {
    ok_info_msg "Output directory '$::STS(outDirPath)' pre-existed"
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
        lreplace listOfLists [expr $i - 1] [expr $i - 1] $prevRec
      }
      incr idxInBurst 1 ;   # index for the current record
      set currRec [PackNameTimeRecord \
                                  $nameC $timeStrC $globalTimeC $idxInBurst]
      lreplace listOfLists $i $i $currRec
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
# to lists of renamed left/right stereopair member path.
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
    set basePurename [_build_stereopair_purename $nameLeft $nameRight]
    ok_trace_msg "TODO '$nameLeft' + '$nameRight' = '$basePurename'"
    set lname [_build_spm_left_purename  $basePurename]
    set rname [_build_spm_right_purename $basePurename]
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
  if { 1 == [dict exists $renameDict $dstPairPurename] }  {
    set targetsList [dict get $renameDict $dstPairPurename]
  } else {      set targetsList [list]     }
  if { 0 == [dict exists $origPureNameToPathDict $origPureName] }  {
    ok_err_msg "No source path for $descr image '$origPureName'"
    return  0
  }
  set srcPath [dict get $origPureNameToPathDict $origPureName]
  set srcDir  [file dirname $srcPath]
  set srcExt  [file extension $srcPath]
  set dstPairName "$dstPairPurename$srcExt"
  set n [expr 1 + [llength $targetsList]]
  ok_info_msg "Target #$n for '$srcPath':\t'$dstPairName'"
  lappend targetsList [file join $srcDir $dstPairName]
  dict set renameDict $srcPath $targetsList
  return  1
}


proc _build_spm_left_purename  {basePurename} {
  return  [format "%s_l" $basePurename] }
proc _build_spm_right_purename  {basePurename} {
  return  [format "%s_r" $basePurename] }


# 'renameDict' holds pairs <srcPath> => {list of <dstPath>-s}
# Returns number of errors encountered
proc _rename_images_by_rename_dict {renameDict} {
  set errCnt 0;   set replCnt 0
  set srcPaths [dict keys $renameDict]
  ok_info_msg "Start renaming [llength $srcPaths] original image(s) under '$::STS(origImgRootPath)'"
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
  ok_info_msg "Done renaming [llength $srcPaths] original image(s) under '$::STS(origImgRootPath)'; $replCnt file replication(s) made; $errCnt error(s) occured"
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
    set basePurename [_build_stereopair_purename $nameLeft $nameRight]
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


proc _build_stereopair_purename {purenameLeft purenameRight}  {
  set suffix [build_suffix_from_peer_purename $purenameRight]
  return  "$purenameLeft$suffix"
}


