# dir_file_utils.tcl

set SCRIPT_DIR [file dirname [info script]]
## DO NOT:  source [file join $SCRIPT_DIR   "debug_utils.tcl"]
source [file join $SCRIPT_DIR   "cameras.tcl"]

package require ok_utils
namespace import -force ::ok_utils::*


set KNOWN_STD_IMG_EXTENSIONS_DICT [dict create jpg JPEG tif TIFF bmp BMP]


proc FindFilePath {dirPath pureName ext descr {checkExist 0}} {
  set fPath [file join $dirPath "$pureName.$ext"]
  if { $checkExist != 0 } {
    if { 0 == [file exists $fPath] } {
      ok_err_msg "$descr file $fPath not found"
      return ""
    }
  }
  return $fPath
}

################################################################################


# Puts into 'origPathsLeftVar' and 'origPathsRightVar' the paths of:
#   - original images if 'searchHidden'==0
#   - hidden original images if 'searchHidden'==1
# if 'skipRenamed' == 1, ignores already renamed image files
proc dualcam_find_originals {searchHidden skipRenamed origExtDict \
              origImgDirLeft origImgDirRight dirForUnmatched \
              origPathsLeftVar origPathsRightVar}  {
  upvar $origPathsLeftVar  origPathsLeft
  upvar $origPathsRightVar origPathsRight
  if { $origExtDict == 0 }  {
    ok_err_msg "Cannot find originals before their extensions are determined"
    return  0
  }
  set origExtLeft   [dict get $origExtDict "L"]
  set origExtRight  [dict get $origExtDict "R"]
  if { $searchHidden == 0}  {
    set descrSingle "original";   set descrPlural "original(s)"
    set origPathsLeft_  \
              [glob -nocomplain -directory $origImgDirLeft  "*.$origExtLeft"]
    set origPathsRight_ \
              [glob -nocomplain -directory $origImgDirRight "*.$origExtRight"]
  } else {
    set descrSingle "hidden-original";   set descrPlural "hidden-original(s)"
    set origPathsLeft_  [glob -nocomplain -directory \
                [file join $origImgDirLeft $dirForUnmatched]  "*.$origExtLeft"]
    set origPathsRight_ [glob -nocomplain -directory \
                [file join $origImgDirRight $dirForUnmatched] "*.$origExtRight"]
  }
  if { $skipRenamed == 1 }  { ; # filter out already renamed originals
    set origPathsLeft [list];  set origPathsRight [list]
    foreach p $origPathsLeft_ {
      if { 0 == [is_spm_purename [file rootname [file tail $p]]] }  {
        lappend origPathsLeft $p
      }
    }
    foreach p $origPathsRight_ {
      if { 0 == [is_spm_purename [file rootname [file tail $p]]] }  {
        lappend origPathsRight $p
      }
    }
  } else {
    set origPathsLeft $origPathsLeft_;  set origPathsRight $origPathsRight_
  }
  ok_trace_msg "Left $descrPlural:   {$origPathsLeft}"
  ok_trace_msg "Right $descrPlural:  {$origPathsRight}"
  set missingStr ""
  if { 0 == [llength $origPathsLeft] }   { append missingStr " left" }
  if { 0 == [llength $origPathsRight] }  { append missingStr " right" }
  if { $missingStr != "" }  {
    if { $searchHidden == 0}  {
      ok_err_msg "Missing $descrSingle images for side(s):$missingStr"
      return  0
    } else {
      ok_info_msg "No hidden $descrSingle images for side(s):$missingStr"
    }
  }
  ok_info_msg "Found [llength $origPathsLeft] left- and [llength $origPathsRight] right $descrSingle image(s)"
  return  1
}


# Puts into 'imgPathsLeftVar' and 'imgPathsRightVar' the paths 
# of properly named left and right images found in 'imgDirLeft' and 'imgDirRight'
proc dualcam_find_lr_images {imgExtDict imgDirLeft imgDirRight \
                              imgPathsLeftVar imgPathsRightVar}  {
  upvar $imgPathsLeftVar  imgPathsLeft
  upvar $imgPathsRightVar imgPathsRight
  if { $imgExtDict == 0 }  {
    ok_err_msg "Cannot find images before their extensions are determined"
    return  0
  }
  set imgExtLeft   [dict get $imgExtDict "L"]
  set imgExtRight  [dict get $imgExtDict "R"]
  ok_info_msg "Left  images (*.$imgExtLeft) expected in '$imgDirLeft'"
  ok_info_msg "Right images (*.$imgExtRight) expected in '$imgDirRight'"
  set imgPathsLeft_  \
            [glob -nocomplain -directory $imgDirLeft  "*.$imgExtLeft"]
  set imgPathsRight_ \
            [glob -nocomplain -directory $imgDirRight "*.$imgExtRight"]
  # filter out irrelevant images
  set imgPathsLeft [list];  set imgPathsRight [list]
  foreach p $imgPathsLeft_ {
    if { 1 == [is_spm_purename [file rootname [file tail $p]]] }  {
      lappend imgPathsLeft $p
    }
  }
  foreach p $imgPathsRight_ {
    if { 1 == [is_spm_purename [file rootname [file tail $p]]] }  {
      lappend imgPathsRight $p
    }
  }
  ok_trace_msg "Left image(s):   {$imgPathsLeft}"
  ok_trace_msg "Right image(s):  {$imgPathsRight}"
  set missingStr ""
  if { 0 == [llength $imgPathsLeft] }   { append missingStr " left" }
  if { 0 == [llength $imgPathsRight] }  { append missingStr " right" }
  if { $missingStr != "" }  {
    ok_err_msg "Missing image(s) for:$missingStr"
    return  0
  }
  ok_info_msg "Found [llength $imgPathsLeft] left- and [llength $imgPathsRight] right image(s)"
  return  1
}


# Returns dictionary of {L:extLeft, R:extRight} or 0 on error
proc dualcam_choose_and_check_type_of_originals {origImgDirLeft origImgDirRight \
                                                 requireRaw} {
  # choose type of originals; RAW is required
  if { 0 == [set dirToExt [ChooseOrigImgExtensionsInDirs \
                      [list $origImgDirLeft $origImgDirRight]]] }  {
    return  0;  # error already printed
  }
  set extLeft  [dict get $dirToExt $origImgDirLeft]
  set extRight [dict get $dirToExt $origImgDirRight]
  set lrToExt [dict create "L" $extLeft  "R" $extRight ]
  if { $requireRaw && \
       ((0 ==[IsRawExtension $extLeft]) || (0 ==[IsRawExtension $extRight])) } {
    ok_err_msg "Both-side originals should be RAW; got ('$extLeft' '$extRight')"
    return  0;
  }
  if { [IsRawExtension $extLeft] != [IsRawExtension $extRight] } {
    ok_err_msg "Both-side originals should be either RAW or not; got ('$extLeft' '$extRight')"
    return  0;
  }
  return  $lrToExt
}


# Detects originals' extensions for the work-area
# Returns a dict of {dirPath::ext} or 0 on error
proc ChooseOrigImgExtensionsInDirs {dirPathList}  {
  set allDirsRawExtList [list];   set allDirsStdExtList [list]
  set cntDirsWithRaw 0
  set dirToExt [dict create]
  foreach oneDir $dirPathList {
    if { 1 < [llength [set rawExtList [FindRawExtensionsInDir $oneDir]]] } {
      ok_err_msg "Directory '$oneDir' has file(s) with [llength $rawExtList] known RAW extension(s): {$rawExtList}; should be exactly one - all images should come from one camera"
      return  0
    } elseif { 1 == [llength $rawExtList] } {
      set ext [lindex $rawExtList 0]
      ok_info_msg "RAW extension in directory '$oneDir' is '$ext'"
      dict set dirToExt $oneDir $ext
      lappend allDirsRawExtList $ext
      incr cntDirsWithRaw 1
      continue
    }
    # no RAWs in 'oneDir'; perform the similar search for standard extensions
    if { 1 < [llength [set stdExtList [FindStdImageExtensionsInDir $oneDir]]] } {
      ok_err_msg "Directory '$oneDir' has file(s) with [llength $stdExtList] known standard-image extension(s): {$stdExtList}; should be exactly one - all images should come from one camera"
      return  0
    } elseif { 1 == [llength $stdExtList] } {
      set ext [lindex $stdExtList 0]
      ok_info_msg "Standard-image extension in directory '$oneDir' is '$ext'"
      dict set dirToExt $oneDir $ext
      lappend allDirsStdExtList $ext
      continue
    } elseif { 0 == [llength $stdExtList] } {
      ok_err_msg "Directory '$oneDir' has no known image files, RAW or standard"
      return  0
    }
  }
  if { ($cntDirsWithRaw > 0) && ($cntDirsWithRaw != [llength $dirPathList]) }  {
    ok_err_msg "Only $cntDirsWithRaw directory(ies) out of [llength $dirPathList] have RAW images. Aborting."
    return  0
  }
  return  $dirToExt
  #~ set allDirsRawExtList [lsort -unique $allDirsRawExtList]
  #~ set allDirsStdExtList [lsort -unique $allDirsStdExtList]
  #~ set numCandidates [expr {[llength $allDirsRawExtList] + \
                           #~ [llength $allDirsStdExtList]}]
  #~ if { 1 == [llength $allDirsRawExtList] }  {
    #~ set origExt [lindex $allDirsRawExtList 0]
    #~ ok_info_msg "Original RAW-image extension chosen to be '$origExt'"
  #~ } elseif { 1 == [llength $allDirsStdExtList] }  {
    #~ set origExt [lindex $allDirsStdExtList 0]
    #~ ok_info_msg "Original standard-image extension chosen to be '$origExt'"
    #~ } elseif { $numCandidates == 0 } {
      #~ ok_err_msg "Directories {$dirPathList} have no known image files, RAW or standard"
      #~ return  0
    #~ } else {

    #~ ok_err_msg "Cannot choose original image extension for directories {$dirPathList}: $numCandidates candidate(s) found: {[concat $allDirsRawExtList $allDirsStdExtList]}"
    #~ return  0
  #~ }
  #~ return  $origExt
}



# Returns 1 if 'filePath' lies in 'dirPathLeft'/'dirPathRight'
# and matches its extension
proc IsOrigImagePath {filePath dirPathLeft dirPathRight} {
  global ORIG_EXT_DICT
  if { $ORIG_EXT_DICT == 0 }  {
    ok_err_msg "Cannot recognize originals before their extension(s) chosen"
    return  0
  }
  # extract directory, decide whether L/R pick expected extension
  set dirPath [file dirname $filePath]
  if { "" == [set expectExt [GetOrigExtensionForDir $dirPath \
                                              $dirPathLeft $dirPathRight]] }  {
    return 0
  }
  set ext [string range [file extension $filePath] 1 end]; # without leading dot
  if { 0 == [string compare -nocase $ext $expectExt] }  { return 1 }
  return 0
}


# Returns original-images' extension for directory 'dirPath' or "" on error
proc GetOrigExtensionForDir {dirPath dirPathLeft dirPathRight} {
  global ORIG_EXT_DICT
  if { $ORIG_EXT_DICT == 0 }  {
    ok_err_msg "Cannot recognize originals' extension(s) before chosen"
    return  ""
  }
  # decide whether 'dirPath' is L/R, pick expected extension
  if {        [ok_dirpath_equal $dirPath $dirPathLeft] }  {
    set expectExt [dict get $ORIG_EXT_DICT "L"]
  } elseif {  [ok_dirpath_equal $dirPath $dirPathRight] } {
    set expectExt [dict get $ORIG_EXT_DICT "R"]
  } else {
    set expectExt ""
  }
  return  $expectExt
}


proc FindRawInputs {rawDir dirPathLeft dirPathRight {priErr 0}} {
  global ORIG_EXT_DICT
  if { "" == [set extInDir \
      [GetOrigExtensionForDir $rawDir $dirPathLeft $dirPathRight]] }  {
    return  [list];   // error, if any, already printed
  }
  if { 0 == [IsRawExtension $extInDir] }  {
    if { $priErr }  {
      ok_err_msg "Non-RAW image type '$extInDir' used as input in '$rawDir'"
    }
    return  [list]
  }
  set tclResult [catch {
    set res [glob [file join $rawDir "*.$extInDir"]] } execResult]
    if { $tclResult != 0 } { ok_err_msg "$execResult!";  return  [list]  }
  return  $res
}


proc FindRawInputsOrComplain {rawDir dirPathLeft dirPathRight allRawsListVar} {
  upvar $allRawsListVar allRaws
  set allRaws [FindRawInputs $rawDir $dirPathLeft $dirPathRight]
  if { 0 == [llength $allRaws] } {
    ok_err_msg "No RAW inputs found in '$rawDir'"
    return  0
  }
  return  1
}


proc FindRawInput {rawDir dirPathLeft dirPathRight pureName} {
  if { "" == [set extInDir \
    [GetOrigExtensionForDir $rawDir $dirPathLeft $dirPathRight]] }  {
    return  [list];   // error, if any, already printed
  }
  set rPath [file join $rawDir "$pureName.$extInDir"]
  if { 1 == [file exists $rPath] } {
    return $rPath
  }
  ok_err_msg "RAW file $rPath not found"
  return ""
}


proc RAWFileNameToPurename {rawName} {
  return  [AnyFileNameToPurename $rawName]
}


proc RAWFileNameToGlobPattern {rawName} {
  set purename [RAWFileNameToPurename $rawName]
  return  [PurenameToGlobPattern $purename]
}


proc PurenameToGlobPattern {purename} {
  return  "$purename.*"
}


# Returns list of files related to image 'imageName' in directory 'imgDirPath'
proc FindAllInputsForOneImageInDir {imageName imgDirPath {priErr 1}} {
  set purename [AnyFileNameToPurename $imageName]; # TODO: ImageNameToPurename
  set fullPattern [file join $imgDirPath [PurenameToGlobPattern $purename]]
  set res [list]
  set tclResult [catch { set res [glob $fullPattern] } execResult]
  if { ($tclResult != 0) && ($priErr == 1) } {
    ok_err_msg "Failed searching for input files associated with image '$imageName' (pattern: '$fullPattern': $execResult"
    return  [list]
  }
  ok_trace_msg "Found [llength $res] file(s) related to image '$imageName'; pattern: '$fullPattern'"
  return  $res
}


# A generic function that returns the name (path portion) before the first dot
proc AnyFileNameToPurename {fileName} {
  set nmp [file rootname $fileName]
  while { 1 }  {
    set nmn [file rootname $nmp]
    if { $nmp == $nmn }  { break; }
    set nmp $nmn
  }
  return  $nmp
}



################################################################################



################################################################################




proc CanWriteFile {fPath}  {
  if { $fPath == "" }  { return  0 }
  if { 0 == [file exists $fPath] }  { return  1 }
  if { 1 == [file isdirectory $fPath] }  { return  0 }
  if { 0 == [file writable $fPath] }  { return  0 }
  return  1
}


# Returns -1 if 'path1' is older than 'path2', 1 if newer, 0 if same time.
proc CompareFileDates {path1 path2} {
  # fill attr arrays for old and new files:
  #      atime, ctime, dev, gid, ino, mode, mtime, nlink, size, type, uid
  set tclExecResult [catch {
    file stat $path1 p1Stat
    file stat $path2 p2Stat
  } evalExecResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "Failed reading attributes of settings file(s) '$path1' and/or '$path2': $evalExecResult!"
    return  0;  # TODO: invent some error indication
  }
  ok_trace_msg "Dates of '$path1':\t atime=$p1Stat(atime)\t ctime=$p1Stat(ctime)\t mtime=$p1Stat(mtime)"
  ok_trace_msg "Dates of '$path2':\t atime=$p2Stat(atime)\t ctime=$p2Stat(ctime)\t mtime=$p2Stat(mtime)"
  # compare ??? time
  if { $p1Stat(mtime) <  $p2Stat(mtime) }  { return  -1 }
  if { $p1Stat(mtime) >  $p2Stat(mtime) }  { return   1 }
  return  0;  # times are equal
}


# Returns list of known RAW extensions (no dot) in directory 'dirPath'
proc FindRawExtensionsInDir {dirPath} {
  set allExtensions [FindSingleDotExtensionsInDir $dirPath]
  set rawExtensions [list]
  foreach ext $allExtensions {
    if { 1 == [IsRawExtension $ext] }  {
      lappend rawExtensions $ext
    }
  }
  ok_info_msg "Found [llength $rawExtensions] known RAW file extension(s) in '$dirPath': {$rawExtensions}"
  return  $rawExtensions
}


proc IsRawExtension {ext} {
  return  [dict exists $::KNOWN_RAW_EXTENSIONS_DICT $ext]
}


proc IsStdImageExtension {ext} {
  return  [dict exists $::KNOWN_STD_IMG_EXTENSIONS_DICT $ext]
}


# Returns list of known standard-image extensions (no dot) in directory 'dirPath'
proc FindStdImageExtensionsInDir {dirPath} {
  set allExtensions [FindSingleDotExtensionsInDir $dirPath]
  set foundExtensions [list]
  foreach ext $allExtensions {
    if { 1 == [IsStdImageExtension $ext] }  {
      lappend foundExtensions $ext
    }
  }
  ok_info_msg "Found [llength $foundExtensions] known standard-image file extension(s) in '$dirPath': {$foundExtensions}"
  return  $foundExtensions
}


# Returns list of extensions (no dot) for files matching "[^./]+\.([^./]+)"
proc FindSingleDotExtensionsInDir {dirPath} {
  set pattern {[^./]+\.([^./]+)$}
  set candidates [glob -nocomplain -directory $dirPath -- "*.*"]
  array unset extensionsArr
  foreach f $candidates {
    #(?slow?) if { 1 == [regexp $pattern $f fullMatch ext] }  {}h
    set ext [file extension $f]
    if { 1 < [string length $ext] }  { ;  # includes leading .
      ok_trace_msg "Candidate image-file extension: '$ext'"
      if { 0 < [string length [set ext [string range $ext 1 end]]] }  {
        set extensionsArr([string tolower $ext])  1
      }
    }
  }
  set extensions [array names extensionsArr]
  return  $extensions
}


proc BuildSortedPurenamesList {pathList} {
  set purenames [list]
  foreach p $pathList {
    lappend purenames [AnyFileNameToPurename [file tail $p]]
  }
  return  [lsort $purenames]
}

