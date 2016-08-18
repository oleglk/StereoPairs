# stereopair_naming.tcl

set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR  "ok_utils" "debug_utils.tcl"]
ok_trace_msg "---- Sourcing '[info script]' in '$SCRIPT_DIR' ----"
#source [file join $SCRIPT_DIR   "dir_file_utils.tcl"]

package require ok_utils
namespace import -force ::ok_utils::*


set imgNameEndingLeft   "_l"
set imgNameEndingRight  "_r"
set imgFileIdPattern    {[0-9]+} ;  # example: "dsc(01234).jpg"


proc build_spm_left_purename  {basePurename} {
  return  [format "%s%s" $basePurename $::imgNameEndingLeft] }
  
  
proc build_spm_right_purename  {basePurename} {
  return  [format "%s%s" $basePurename $::imgNameEndingRight] }


proc is_spm_purename {purename} {
  # OK_TODO: generalize
  set iLeft   [string last $::imgNameEndingLeft $purename]
  set iRight  [string last $::imgNameEndingRight $purename]
  if { ($iLeft >= 0) && ($iRight < 0) }  {      ; # it's a left  image
    return  1
  } elseif { ($iLeft < 0) && ($iRight >= 0) } { ; # it's a right image
    return  1
  }
  return  0  ; # not a stereopair name
}


proc spm_purename_to_peer_purename {purename} {
  # OK_TODO: generalize
  set iLeft   [string last $::imgNameEndingLeft $purename]
  set iRight  [string last $::imgNameEndingRight $purename]
  if { ($iLeft >= 0) && ($iRight < 0) }  {      ; # it's a left  image
    return  [string replace $purename $iLeft  end $::imgNameEndingRight]
  } elseif { ($iLeft < 0) && ($iRight >= 0) } { ; # it's a right image
    return  [string replace $purename $iRight end $::imgNameEndingLeft]
  }
  return  ""  ; # error
}


proc spm_purename_to_pair_purename {purename} {
  # OK_TODO: generalize
  set iLeft   [string last $::imgNameEndingLeft $purename]
  set iRight  [string last $::imgNameEndingRight $purename]
  if { ($iLeft >= 0) && ($iRight < 0) }  {      ; # it's a left  image
    return  [string replace $purename $iLeft  end ""]
  } elseif { ($iLeft < 0) && ($iRight >= 0) } { ; # it's a right image
    return  [string replace $purename $iRight end ""]
  }
  return  ""  ; # error
}


proc build_stereopair_purename {purenameLeft purenameRight}  {
  set suffix [build_suffix_from_peer_purename $purenameRight]
  return  "$purenameLeft$suffix"
}


proc build_suffix_from_peer_purename {peerPureName}  {
  if { 0 == [regexp {[0-9].*$} $peerPureName peerNameNum] }  {
    ok_err_msg "Invalid peer image name '$peerPureName'"
    set peerNameNum "INVALID"
  }
  set suffix [format "-%s" $peerNameNum]
  return  $suffix
}


# Puts into 'idLeft' and 'idRight' image-file IDs found in 'pairNamesOrPaths'.
# "dsc003-007.tif" => {003 007}
# Returns 1 on success, 0 on invalid name.
proc find_lr_image_ids_in_pairname {pairNameOrPath idLeft idRight {priErr 0}}  {
  upvar $idLeft  name1
  upvar $idRight name2
  set pureNameNoExt [file rootname [file tail $pairNameOrPath]]
  set spPattern "($::imgFileIdPattern)-($::imgFileIdPattern)"
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
  set spPattern "($::imgFileIdPattern)-($::imgFileIdPattern)"
  ok_trace_msg "Match '$pureNameNoExt' by '$::imgFileIdPattern'"
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
