# main_settings_copier.tcl


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
  set ::STS(origImgRootPath)  ""
  set ::STS(globalImgSettingsDir)  ""
  set ::STS(origImgDirLeft)   ""
  set ::STS(origImgDirRight)  ""
  set ::STS(outDirPath)       ""
  set ::STS(backupDir)        ""
  set ::STS(copyFromLR)       "" ;  "left" == copy settings from left to right, "right" == from right to left
  set ::STS(doSimulateOnly)   0
  
  set ORIG_EXT_DICT    0 
}
################################################################################
_set_defaults ;  # load only;  do call it in a function for repeated invocations
################################################################################

set ORIG_EXT_DICT    0 ;  # per-dir extensions of original out-of-camera images

################################################################################

proc settings_copier_main {cmdLineAsStr}  {
  global STS SCRIPT_DIR ORIG_EXT_DICT
  _set_defaults ;  # calling it in a function for repeated invocations
  if { 0 == [settings_copier_cmd_line $cmdLineAsStr cml] }  {
    return  0;  # error or help already printed
  }

  if { 0 == [dualcam_find_originals 0 origPathsLeft origPathsRight] }  {
    return  0;  # error already printed
  }
  if { 0 == [_arrange_workarea] }  { return  0  };  # error already printed
  
  # TODO: find source settings for originals' names, replicate and replace image name(s) inside

  if { $::STS(doRenameLR) == 1 }  {
    if { 0 == $::STS(doSimulateOnly) }  {
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


proc settings_copier_cmd_line {cmdLineAsStr cmlArrName}  {
  upvar $cmlArrName      cml
  # create the command-line description
  set descrList \
[list \
  -help {"" "print help"} \
  -global_img_settings_dir {val	"full path of the directory where the RAW converter keeps all image-settings files - specify if relevant for your converter"} \
  -orig_img_dir {val	"input directory; left (right) out-of-camera images expected in 'orig_img_dir'/L ('orig_img_dir'/R)"} \
  -std_img_dir {val	"input directory with standard images (out-of-camera JPEG or converted from RAW); left (right) images expected in 'std_img_dir'/L ('std_img_dir'/R)"} \
  -out_dir {val	"output directory"} \
  -backup_dir {val	"directory to move overriden settings files to"} \
  -copy_from {val	"'left' == copy settings from left to right, 'right' == from right to left"} \
  -simulate_only {""	"if specified, no file changes performed, only decide and report what should be done"} ]
  array unset cmlD
  ok_new_cmd_line_descr cmlD $descrList
  # create dummy command line with the default parameters and copy it
  # (if an argument inexistent by default, don't provide dummy value)
  array unset defCml
  ok_set_cmd_line_params defCml cmlD { \
   {-backup_dir "Backup"} }
  ok_copy_array defCml cml;    # to preset default parameters
  # now parse the user's command line
  if { 0 == [ok_read_cmd_line $cmdLineAsStr cml cmlD] } {
    ok_err_msg "Aborted because of invalid command line";	return  0
  }
  if { [info exists cml(-help)] } {
    set cmdHelp [ok_help_on_cmd_line defCml cmlD "\n"]
    ok_info_msg "================================================================"
    ok_info_msg "    DualCam Settings Copier replicates image-conversion settings from  left- to right images of each matched stereopair, or vice-versa."
    ok_info_msg "========= Command line parameters (in any order): =============="
    ok_info_msg $cmdHelp
    ok_info_msg "================================================================"
    ok_info_msg "========= Example (note TCL-style directory separators): ======="
    ok_info_msg " settings_copier_main \"-orig_img_dir . -std_img_dir . -out_dir ./OUT -copy_from left\""
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
  
  if { 1 == [info exists cml(-global_img_settings_dir)] }  {
    if { 0 == [file isdirectory $cml(-global_img_settings_dir)] }  {
      ok_err_msg "Non-directory '$cml(-global_img_settings_dir)' specified as the global image-settings directory"
      incr errCnt 1
    } else {
      set ::STS(globalImgSettingsDir) $cml(-global_img_settings_dir)
    }
  }  
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
    # validity of pair-list path will be checked after out-dir creation
  }
  if { 1 == [info exists cml(-backup_dir)] }  {
    set ::STS(backupDir) $cml(-backup_dir)
  }
 if { 1 == [info exists cml(-copy_from)] }  {
    switch -nocase -- [string tolower $cml(-copy_from)]  {
      "left"   {  set ::STS(copyFromLR) "left"   }
      "right"  {  set ::STS(copyFromLR) "right"  }
      default  {
        ok_err_msg "-copy_from expects left|right"
        incr errCnt 1
      }
    }    
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


# Puts into 'origPathsLeftVar' and 'origPathsRightVar' the paths of:
#   - original images if 'searchHidden'==0
#   - hidden original images if 'searchHidden'==1
proc dualcam_find_originals {searchHidden \
                                  origPathsLeftVar origPathsRightVar}  {
  global STS ORIG_EXT_DICT
  upvar $origPathsLeftVar  origPathsLeft
  upvar $origPathsRightVar origPathsRight
  if { $ORIG_EXT_DICT == "" }  {
    ok_err_msg "Cannot find originals before their extension is determined"
    return  0
  }
  if { $searchHidden == 0}  {
    set descrSingle "original";   set descrPlural "original(s)"
    set origPathsLeft  [glob -nocomplain -directory $STS(origImgDirLeft)  "*.$ORIG_EXT_DICT"]
    set origPathsRight [glob -nocomplain -directory $STS(origImgDirRight) "*.$ORIG_EXT_DICT"]
  } else {
    set descrSingle "hidden-original";   set descrPlural "hidden-original(s)"
    set origPathsLeft  [glob -nocomplain -directory [file join $STS(origImgDirLeft) $STS(dirForUnused)]  "*.$ORIG_EXT_DICT"]
    set origPathsRight [glob -nocomplain -directory [file join $STS(origImgDirRight) $STS(dirForUnused)] "*.$ORIG_EXT_DICT"]
  }
  ok_trace_msg "Left $descrPlural:   {$origPathsLeft}"
  ok_trace_msg "Right $descrPlural:  {$origPathsRight}"
  set missingStr ""
  if { 0 == [llength $origPathsLeft] }   { append missingStr " left" }
  if { 0 == [llength $origPathsRight] }  { append missingStr " right" }
  if { $missingStr != "" }  {
    if { $searchHidden == 0}  {
      ok_err_msg "Missing $descrSingle images for:$missingStr"
      return  0
    } else {
      ok_info_msg "No hidden $descrSingle images for:$missingStr"
    }
  }
  ok_info_msg "Found [llength $origPathsLeft] left- and [llength $origPathsRight] right $descrSingle image(s)"
  return  1
}


proc _arrange_workarea {}  {
  set unmatchedDirLeft  [file join $::STS(origImgDirLeft) $::STS(dirForUnused)]
  set unmatchedDirRight [file join $::STS(origImgDirRight) $::STS(dirForUnused)]
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


# Moves unmatched originals into subdirectories STS(dirForUnused) of their dir-s
# 'renameDict' holds pairs <srcPath> => {list of <dstPath>-s}
# Returns number of errors encountered
proc _hide_unmatched_images_by_rename_dict {origPaths renameDict}  {
  set hideCnt 0;  set umCnt 0;  set errCnt 0
  set nOrigs [llength $origPaths]
  ok_trace_msg "Begin search for unmatched originals out of $nOrigs image(s)"
  foreach origPath $origPaths {
    if { 1 == [dict exists $renameDict $origPath] }  {
      continue;   # matched image
    }
    incr umCnt 1
    set destDirPath [file join [file dirname $origPath] $::STS(dirForUnused)]
    # 'destDirPath' should exist
    set tclResult [catch {
      set res [file rename $origPath $destDirPath] } execResult]
    if { $tclResult != 0 } {
      ok_err_msg "$execResult!";  incr errCnt 1
    } else {
      incr hideCnt 1
      ok_info_msg "Moved unmatched image '$origPath' into '$destDirPath'"
    }
  }
  if { $umCnt == $hideCnt } {
    ok_info_msg "Found and hided $hideCnt unmatched original image(s)"
  } else {
    ok_warn_msg "Found $umCnt unmatched original image(s); hided $hideCnt; $errCnt error(s) occured"
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



# Renames left/right images in the work-area
# according to rename spec in '$::STS(outDirPath)/$::FILENAME_RENAME_SPEC'
proc _settings_copier_restore_original_names {{simulateOnly 0}}  {
  set specPath [file join $::STS(outDirPath) $::FILENAME_RENAME_SPEC]
  set listOfLists [ok_read_csv_file_into_list_of_lists $specPath "," "#" 0]
  if { $listOfLists == 0 } {
    ok_err_msg "Failed reading rename spec from '$specPath'"
    return  0
  }
  # listOfLists == {{header} {origPath productPath} ... {origPath productPath}}
  # skip rename-spec header, then sort 'listOfLists',
  #   so that records for one original appear sequentially
  set listOfLists [lsort -dictionary [lrange $listOfLists 1 end]]
  ok_info_msg "Read rename spec of [llength listOfLists] rename-record(s) from '$specPath' - for image(s) under '[file normalize $::STS(origImgRootPath)]"
  set listedOriginalsCnt 0; set restoredCnt 0
  set missingCnt 0;   set errCnt 0;   set existedCnt 0
  set lastListedOriginal ""
  set lastRestoredOriginal ""
  foreach renameRecord $listOfLists {
    set origPath     [lindex $renameRecord 0]
    set renamedPath  [lindex $renameRecord 1]
    if { $origPath == $lastRestoredOriginal }  { continue }; # we restored it
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


proc _settings_copier_restore_hidden_originals {{simulateOnly 0}}  {
  global STS
  if { 0 == [dualcam_find_originals 1 hidePathsLeft hidePathsRight] }  {
    return  0;  # error already printed
  }
#  set unmatchedDirLeft  [file join $STS(origImgDirLeft)  $STS(dirForUnused)]
#  set unmatchedDirRight [file join $STS(origImgDirRight) $STS(dirForUnused)]
  set srcPathsAndDestDir [list  [list $hidePathsLeft $STS(origImgDirLeft)] \
                                [list $hidePathsRight $STS(origImgDirRight)] ]
  set hideCnt [expr [llength $hidePathsLeft] + [llength $hidePathsRight]]
  set unhideCnt 0;  set errCnt 0;   set existedCnt 0
  foreach rec $srcPathsAndDestDir {
    set hidePaths [lindex $rec 0];   set destDirPath [lindex $rec 1]
    foreach hiddenImgPath $hidePaths {
      set origPath [file join $destDirPath [file tail $hiddenImgPath]]
      if { [file exists $origPath] }  {
        ok_warn_msg "Original image file '$origPath' exists; not overriden"
        incr existedCnt 1;      continue
      }
      if { $simulateOnly != 0 }  {
        ok_info_msg "Would have returned unmatched image '$hiddenImgPath' into '$destDirPath'"
        incr unhideCnt 1;  continue
      }
      set tclResult [catch {
        set res [file rename $hiddenImgPath $destDirPath] } execResult]
      if { $tclResult != 0 } {
        ok_err_msg "$execResult!";  incr errCnt 1
      } else {
        incr unhideCnt 1
        ok_info_msg "Returned unmatched image '$hiddenImgPath' into '$destDirPath'"
      }
    }
  }
  set actStr [expr {($simulateOnly != 0)? "Would have restored" : "Restored"}]
  set msg "$actStr $unhideCnt hidden unmatched image(s) out of $hideCnt; $existedCnt original(s) pre-existed; $errCnt error(s) occured"
  if { $errCnt == 0 } { ok_info_msg $msg } else { ok_err_msg $msg }
  return  [expr {($errCnt == 0)? 1 : 0}]s
}


proc _build_stereopair_purename {purenameLeft purenameRight}  {
  set suffix [build_suffix_from_peer_purename $purenameRight]
  return  "$purenameLeft$suffix"
}


