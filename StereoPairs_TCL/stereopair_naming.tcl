# stereopair_naming.tcl

set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR  "ok_utils" "debug_utils.tcl"]
ok_trace_msg "---- Sourcing '[info script]' in '$SCRIPT_DIR' ----"
#source [file join $SCRIPT_DIR   "dir_file_utils.tcl"]
source [file join $SCRIPT_DIR   "preferences_mgr.tcl"]

package require ok_utils
namespace import -force ::ok_utils::*



set imgFileIdPattern    {[0-9]+} ;  # example: "dsc(01234).jpg"


# Changes stereopair naming parameters according to the two specs
# Returns 1 on success, 0 on error.
proc set_naming_parameters_from_left_right_specs { \
                                            formatSpecLeft formatSpecRight}  {
  set leftOK [_parse_naming_parameters $formatSpecLeft    \
                                       prefixLeft delimeterLeft suffixLeft]
  set rightOK [_parse_naming_parameters $formatSpecRight  \
                                       prefixRight delimeterRight suffixRight]
  if { !$leftOK || !$rightOK }  {
    set lrErrSpec [format "%s%s" \
                [expr {($leftOK)? "":" left"}] [expr {($rightOK)? "":" right"}]]
    ok_err_msg "Invalid naming format(s) specified for side(s):$lrErrSpec"
  }
  return  [expr {$leftOK && $rightOK}];   # OK_TMP
}


# Changes stereopair naming parameters when value given isn't string "none"
proc _set_naming_parameters {imgPrefixLeftOrNone imgPrefixRightOrNone  \
                            imgDelimeterOrNone                        \
                            imgSuffixLeftOrNone imgSuffixRightOrNone  } {
  global NAMING
  if { 0 == [string equal -nocase $imgPrefixLeftOrNone "none"] } {
    set NAMING(imgPrefixLeft)   $imgPrefixLeftOrNone
  }
  if { 0 == [string equal -nocase $imgPrefixRightOrNone "none"] } {
    set NAMING(imgPrefixRight)  $imgPrefixRightOrNone
  }
  if { 0 == [string equal -nocase $imgDelimeterOrNone "none"] } {
    set NAMING(imgDelimeter)  $imgDelimeterOrNone
  }
  if { 0 == [string equal -nocase $imgSuffixLeftOrNone "none"] } {
    set NAMING(imgSuffixLeft)   $imgSuffixLeftOrNone
  }
  if { 0 == [string equal -nocase $imgSuffixRightOrNone "none"] } {
    set NAMING(imgSuffixRight)  $imgSuffixRightOrNone
  }
}
_set_naming_parameters ""  ""  "-"  "_l"  "_r";   # for StereoPhotoMaker
#_set_naming_parameters "l_"  "r_"  "--"  "_ll"  "_rr"
#_set_naming_parameters "l_"  "r_"  "--"  ""  ""


# Reads naming parameters for one side (left or right) from 'formatSpec' string.
# 'formatSpec' == <prefix>[LeftName]<delimeter>[RightId]<suffix>
# Example 1: 'formatSpec'=="[LeftName]-[RightId]_l" <=> name ~ "dsc0003-1234_l"
# Example 1: 'formatSpec'=="R-[LeftName]@[RightId]" <=> name ~ "R-dsc0003@1234"
# Returns 1 on success, 0 on error.
# None of prefix, delimeter, suffix can contain whitespace.
proc _parse_naming_parameters {formatSpec prefix delimeter suffix}  {
  upvar $prefix pref;  upvar $delimeter delim;  upvar $suffix suff
  set pattern {^(\S*)\[LeftName\](\S*)\[RightId\](\S*)$}
  return  [regexp -- $pattern $formatSpec fullMatch pref delim suff]
}


proc build_spm_left_purename  {basePurename} {
  return  [format "%s%s%s" \
              $::NAMING(imgPrefixLeft) $basePurename $::NAMING(imgSuffixLeft)] }
  
  
proc build_spm_right_purename  {basePurename} {
  return  [format "%s%s%s" \
            $::NAMING(imgPrefixRight) $basePurename $::NAMING(imgSuffixRight)] }


proc is_spm_purename {purename} {
  global NAMING
  set iPrefLeft   [expr {($NAMING(imgPrefixLeft)  != "")?
                      [string first $NAMING(imgPrefixLeft)  $purename] : -1}]
  set iPrefRight  [expr {($NAMING(imgPrefixRight) != "")?
                      [string first $NAMING(imgPrefixRight) $purename] : -1}]
  set iSuffLeft   [expr {($NAMING(imgSuffixLeft)  != "")?
                      [string last $NAMING(imgSuffixLeft)  $purename] : -1}]
  set iSuffRight  [expr {($NAMING(imgSuffixRight) != "")?
                      [string last $NAMING(imgSuffixRight) $purename] : -1}]
                      
  set isLeftByPrefix  [expr {($NAMING(imgPrefixLeft)  != "") && \
                             ($iPrefLeft >= 0)  && ($iPrefRight < 0)}]
  set isLeftBySuffix  [expr {($NAMING(imgSuffixLeft)  != "") && \
                             ($iSuffLeft >= 0)  && ($iSuffRight < 0)}]
  set isRightByPrefix [expr {($NAMING(imgPrefixRight) != "") && \
                             ($iPrefLeft < 0) && ($iPrefRight >= 0)}]
  set isRightBySuffix [expr {($NAMING(imgSuffixRight) != "") && \
                             ($iSuffLeft < 0) && ($iSuffRight >= 0)}]
  if {  ($isLeftByPrefix || $isLeftBySuffix) && \
       !($isRightByPrefix || $isRightBySuffix) }  {
    return  1;      # it's a left  image
  } elseif { !($isLeftByPrefix || $isLeftBySuffix) && \
              ($isRightByPrefix || $isRightBySuffix) } {
    return  1;      # it's a right image
  }
  return  0  ; # not a stereopair name
}


# Swaps prefix and/or suffix
proc spm_purename_to_peer_purename {purename} {
  global NAMING
  set prefEndLeft  [expr {[string length $NAMING(imgPrefixLeft)]  - 1}]; # index
  set prefEndRight [expr {[string length $NAMING(imgPrefixRight)] - 1}]; # index
  
  set iPrefLeft   [expr {($NAMING(imgPrefixLeft)  != "")?
                      [string first $NAMING(imgPrefixLeft)  $purename] : -1}]
  set iPrefRight  [expr {($NAMING(imgPrefixRight) != "")?
                      [string first $NAMING(imgPrefixRight) $purename] : -1}]
  set tmpName $purename;  # as if no prefixes
  if { ($iPrefLeft == 0) && ($iPrefRight < 0) }  {      ; # it's a left  image
    set tmpName [string replace $purename \
                              $iPrefLeft  $prefEndLeft $NAMING(imgPrefixRight)]
  } elseif { ($iPrefLeft < 0) && ($iPrefRight == 0) } { ; # it's a right image
    set tmpName [string replace $purename \
                              $iPrefRight $prefEndRight $NAMING(imgPrefixLeft)]
  } elseif { ($iPrefLeft == 0) && ($iPrefRight == 0) }   {
    ok_err_msg "Invalid prefix in L/R image pure-name '$purename'";  return  ""
  }
  
  set iSuffLeft   [expr {($NAMING(imgSuffixLeft)  != "")?
                      [string last $NAMING(imgSuffixLeft)  $tmpName] : -1}]
  set iSuffRight  [expr {($NAMING(imgSuffixRight) != "")?
                      [string last $NAMING(imgSuffixRight) $tmpName] : -1}]
  if { ($iSuffLeft < 0) && ($iSuffRight < 0) }  {      ; # no suffixes
    return      $tmpName
  } elseif { ($iSuffLeft > 0) && ($iSuffRight < 0) } { ; # it's a left  image
    return      [string replace $tmpName \
                                $iSuffLeft  end $NAMING(imgSuffixRight)]
  } elseif { ($iSuffLeft < 0) && ($iSuffRight > 0) } { ; # it's a right image
    return      [string replace $tmpName \
                                $iSuffRight end $NAMING(imgSuffixLeft)]
  } elseif { ($iSuffLeft >= 0) && ($iSuffRight >= 0) }   {
    ok_err_msg "Invalid suffix in L/R image pure-name '$purename'";  return  ""
  }
  ok_err_msg "Invalid L/R image pure-name '$purename'"
  return  ""  ; # error
}


# Removes prefix and/or suffix
proc spm_purename_to_pair_purename {purename} {
  global NAMING
  set prefEndLeft  [expr {[string length $NAMING(imgPrefixLeft)]  - 1}]; # index
  set prefEndRight [expr {[string length $NAMING(imgPrefixRight)] - 1}]; # index
  
  set iPrefLeft   [expr {($NAMING(imgPrefixLeft)  != "")?
                      [string first $NAMING(imgPrefixLeft)  $purename] : -1}]
  set iPrefRight  [expr {($NAMING(imgPrefixRight) != "")?
                      [string first $NAMING(imgPrefixRight) $purename] : -1}]
  set tmpName $purename;  # as if no prefixes
  if { ($iPrefLeft == 0) && ($iPrefRight < 0) }  {      ; # it's a left  image
    set tmpName [string replace $purename $iPrefLeft  $prefEndLeft ""]
  } elseif { ($iPrefLeft < 0) && ($iPrefRight == 0) } { ; # it's a right image
    set tmpName [string replace $purename $iPrefRight $prefEndRight ""]
  } elseif { ($iPrefLeft == 0) && ($iPrefRight == 0) }   {
    ok_err_msg "Invalid prefix in L/R image pure-name '$purename'";  return  ""
  }
  
  set iSuffLeft   [expr {($NAMING(imgSuffixLeft)  != "")?
                      [string last $NAMING(imgSuffixLeft)  $tmpName] : -1}]
  set iSuffRight  [expr {($NAMING(imgSuffixRight) != "")?
                      [string last $NAMING(imgSuffixRight) $tmpName] : -1}]
  if { ($iSuffLeft < 0) && ($iSuffRight < 0) }  {      ; # no suffixes
    return      $tmpName
  } elseif { ($iSuffLeft > 0) && ($iSuffRight < 0) } { ; # it's a left  image
    return      [string replace $tmpName $iSuffLeft  end ""]
  } elseif { ($iSuffLeft < 0) && ($iSuffRight > 0) } { ; # it's a right image
    return      [string replace $tmpName $iSuffRight end ""]
  } elseif { ($iSuffLeft >= 0) && ($iSuffRight >= 0) }   {
    ok_err_msg "Invalid suffix in L/R image pure-name '$purename'";  return  ""
  }
  ok_err_msg "Invalid L/R image pure-name '$purename'"
  return  ""  ; # error
}


proc build_stereopair_purename {purenameLeft purenameRight}  {
  set idRight [get_image_id_from_orig_purename $purenameRight]
  return [format "%s%s%s" $purenameLeft $::NAMING(imgDelimeter) $idRight]
}


# dsc0045 => 0045
proc get_image_id_from_orig_purename {purename}  {
  if { 1 == [find_1or2_image_ids_in_imagename $purename id1 id2 1] }  {
    if { $id2 != "" }  {
      ok_err_msg "Got dual-id name '$purename' instead of original left/right name"
      return  ""
    }
    return  $id1  ;   # found exactly one ID
  }
  return  "";   # error already printed
}


proc UNUSED__build_suffix_from_peer_purename {peerPureName}  {
  if { 0 == [regexp {[0-9].*$} $peerPureName peerNameNum] }  {
    ok_err_msg "Invalid peer image name '$peerPureName'"
    set peerNameNum "INVALID"
  }
  set suffix [format "%s%s" $::NAMING(imgDelimeter) $peerNameNum]
  return  $suffix
}


# Puts into 'idLeft' and 'idRight' image-file IDs found in 'pairNamesOrPaths'.
# "dsc003-007.tif" => {003 007}
# Returns 1 on success, 0 on invalid name.
proc find_lr_image_ids_in_pairname {pairNameOrPath idLeft idRight {priErr 0}}  {
  upvar $idLeft  name1
  upvar $idRight name2
  set pureNameNoExt [file rootname [file tail $pairNameOrPath]]
  set spPattern [format "(%s)%s(%s)" \
              $::imgFileIdPattern $::NAMING(imgDelimeter) $::imgFileIdPattern]
  ok_trace_msg "Match '$pureNameNoExt' by '$spPattern'"
  if { 1 == [regexp -nocase -- $spPattern $pureNameNoExt full name1 name2] }  {
    return  1
  }
  if { $priErr }  {
    ok_err_msg "Invalid pair image name '$pairNameOrPath' (pure-name='$pureNameNoExt')"
  }
  return  0
}


# Returns dict of image-file IDs found in 'pairNamesOrPaths'
# mapped to the side(s) where they appear.
# "dsc003-007.tif" => {003 l 007 r};    "dsc033-033.tif" => {033 lr}
proc find_lr_image_ids_in_pair_namelist {pairNamesOrPaths {priErr 0}}  {
  set lNames [dict create]; set rNames [dict create]
  foreach pairPath $pairNamesOrPaths {
    if { 1 == [find_lr_image_ids_in_pairname $pairPath name1 name2 $priErr] }  {
      set lrIdsAreEqual [expr {1 == [string equal -nocase $name1 $name2]}]
      if { 0 == [dict exists $lNames $name1] } {
        dict set lNames $name1 "l"
      }
      if { 0 == [dict exists $rNames $name2] } {
        dict set rNames $name2 "r"
      }
    }
  }
  set allNames [concat [dict keys $lNames] [dict keys $rNames]]
  set lrNames [dict create]
  foreach name $allNames {
    set val [expr {([dict exists $lNames $name])? "l" : ""}]
    if { 1 == [dict exists $rNames $name] } { append val "r" }
    dict set lrNames $name $val
  }
  return  $lrNames
}


# Returns list of image-file IDs found in 'pairNamesOrPaths'.
# "dsc003-007.tif" => {003 007}
proc UNUSED__find_lr_image_ids_in_pair_namelist {pairNamesOrPaths {priErr 0}}  {
  set lrNames [list]
  foreach pairPath $pairNamesOrPaths {
    if { 1 == [find_lr_image_ids_in_pairname $pairPath name1 name2 $priErr] }  {
      lappend lrNames $name1;  lappend lrNames $name2
    }
  }
  return  [lsort -unique $lrNames]
}


# Puts into 'id1' and optionally 'id2' image-file IDs found in 'imgNamesOrPaths'.
# "dsc003-007.tif" => {"003" "007"};  "dsc0053.tif" => {"0053" ""}
# Returns 1 on success, 0 on invalid name.
proc find_1or2_image_ids_in_imagename {imgNameOrPath id1 id2 {priErr 0}}  {
  upvar $id1 name1
  upvar $id2 name2
  if { 1 == [find_lr_image_ids_in_pairname $imgNameOrPath name1 name2 0] }  {
    return  1;  # OK, it was a pair filename
  }
  set pureNameNoExt [file rootname [file tail $imgNameOrPath]]
  ok_trace_msg "Find occurences of  '$::imgFileIdPattern' in '$pureNameNoExt'"
  if { 1 == [regexp -nocase -- $::imgFileIdPattern $pureNameNoExt name1] }  {
    set name2 ""
    return  1
  }
  if { $priErr }  {
    ok_err_msg "Invalid image name '$imgNameOrPath' (pure-name='$pureNameNoExt')"
  }
  return  0
}


# Returns list of image-file IDs found in 'imgNamesOrPaths'.
# "dsc003-007.tif" => {003 007}
proc UNUSED__find_image_ids_in_image_namelist {imgNamesOrPaths {priErr 0}}  {
  set lrNames [list]
  foreach imgPath $imgNamesOrPaths {
    if { 1 == [find_1or2_image_ids_in_imagename $imgPath name1 name2 $priErr] }  {
      lappend lrNames $name1
      if { $name2 != "" } { lappend lrNames $name2 }
    }
  }
  return  [lsort -unique $lrNames]
}
