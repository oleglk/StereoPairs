# dir_file_utils.tcl

set SCRIPT_DIR [file dirname [info script]]
## DO NOT:  source [file join $SCRIPT_DIR   "debug_utils.tcl"]
source [file join $SCRIPT_DIR   "cameras.tcl"]

package require ok_utils
namespace import -force ::ok_utils::*


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
proc dualcam_find_originals {searchHidden origExt \
              origImgDirLeft origImgDirRight dirForUnmatched \
              origPathsLeftVar origPathsRightVar}  {
  upvar $origPathsLeftVar  origPathsLeft
  upvar $origPathsRightVar origPathsRight
  if { $origExt == "" }  {
    ok_err_msg "Cannot find originals before their extension is determined"
    return  0
  }
  if { $searchHidden == 0}  {
    set descrSingle "original";   set descrPlural "original(s)"
    set origPathsLeft  [glob -nocomplain -directory $origImgDirLeft  "*.$origExt"]
    set origPathsRight [glob -nocomplain -directory $origImgDirRight "*.$origExt"]
  } else {
    set descrSingle "hidden-original";   set descrPlural "hidden-original(s)"
    set origPathsLeft  [glob -nocomplain -directory \
                  [file join $origImgDirLeft $dirForUnmatched]  "*.$origExt"]
    set origPathsRight [glob -nocomplain -directory \
                  [file join $origImgDirRight $dirForUnmatched] "*.$origExt"]
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




# Detects and returns originals' extension for the work-area
proc ChooseOrigImgExtensionInDirs {dirParhList}  {
  set allDirsRawExtList [list];   set allDirsStdExtList [list]
  set cntDirsWithRaw 0
  foreach oneDir $dirParhList {
    if { 1 < [llength [set rawExtList [FindRawExtensionsInDir $oneDir]]] } {
      ok_err_msg "Directory '$oneDir' has file(s) with [llength $rawExtList] known RAW extension(s): {$rawExtList}; should be exactly one - all images should come from one camera"
      return  ""
    } elseif { 1 == [llength $rawExtList] } {
      set ext [lindex $rawExtList 0]
      ok_info_msg "RAW extension in directory '$oneDir' is '$ext'"
      lappend allDirsRawExtList $ext
      incr cntDirsWithRaw 1
      continue
    }
    # no RAWs in 'oneDir'; perform the similar search for standard extensions
    if { 1 < [llength [set stdExtList [FindStdImageExtensionsInDir $oneDir]]] } {
      ok_err_msg "Directory '$oneDir' has file(s) with [llength $stdExtList] known standard-image extension(s): {$stdExtList}; should be exactly one - all images should come from one camera"
      return  ""
    } elseif { 1 == [llength $stdExtList] } {
      set ext [lindex $stdExtList 0]
      ok_info_msg "standard-image extension in directory '$oneDir' is '$ext'"
      lappend allDirsStdExtList $ext
      continue
    } elseif { 0 == [llength $stdExtList] } {
      ok_err_msg "Directory '$oneDir' has no known image files, RAW or standard"
      return  ""
    }
  }
  if { ($cntDirsWithRaw > 0) && ($cntDirsWithRaw != [llength $dirParhList]) }  {
    ok_err_msg "Only $cntDirsWithRaw directory(ies) out of [llength $dirParhList] have RAW images. Aborting."
    return  ""
  }
  set allDirsRawExtList [lsort -unique $allDirsRawExtList]
  set allDirsStdExtList [lsort -unique $allDirsStdExtList]
  set numCandidates [expr {[llength $allDirsRawExtList] + \
                           [llength $allDirsStdExtList]}]
  if { 1 == [llength $allDirsRawExtList] }  {
    set origExt [lindex $allDirsRawExtList 0]
    ok_info_msg "Original RAW-image extension chosen to be '$origExt'"
  } elseif { 1 == [llength $allDirsStdExtList] }  {
    set origExt [lindex $allDirsStdExtList 0]
    ok_info_msg "Original standard-image extension chosen to be '$origExt'"
    } elseif { $numCandidates == 0 } {
      ok_err_msg "Directories {$dirParhList} have no known image files, RAW or standard"
      return  ""
    } else {

    ok_err_msg "Cannot choose original image extension for directories {$dirParhList}: $numCandidates candidate(s) found: {[concat $allDirsRawExtList $allDirsStdExtList]}"
    return  ""
  }
  return  $origExt
}



proc IsRawImageName {filePath} {
  global ORIG_EXT
  set ext [string range [file extension $filePath] 1 end]; # without leading dot
  if { 0 == [string compare -nocase $ext $ORIG_EXT] }  { return 1
  } else {                                                    return 0  }
}


proc FindRawInputs {rawDir {priErr 0}} {
  global ORIG_EXT
  if { 0 == [IsRawExtension $ORIG_EXT] }  {
    if { $priErr }  {
      ok_err_msg "Non-RAW image type '$ORIG_EXT' used as input"
    }
    return  [list]
  }
  set tclResult [catch {
    set res [glob [file join $rawDir "*.$ORIG_EXT"]] } execResult]
    if { $tclResult != 0 } { ok_err_msg "$execResult!";  return  [list]  }
  return  $res
}


proc FindRawInputsOrComplain {rawDir allRawsListVar} {
  upvar $allRawsListVar allRaws
  set allRaws [FindRawInputs $rawDir]
  if { 0 == [llength $allRaws] } {
    ok_err_msg "No RAW inputs found in '[pwd]'"
    return  0
  }
  return  1
}


proc FindRawInput {rawDir pureName} {
  global ORIG_EXT
  set rPath [file join $rawDir "$pureName.$ORIG_EXT"]
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
  set pureName [RAWFileNameToPurename $rawName]
  return  "$pureName.*"
}


# Returns list of files related to RAW 'rawName' in directory 'rawDirPath'
proc FindAllInputsForOneRAWInDir {rawName rawDirPath} {
  set fullPattern [file join $rawDirPath [RAWFileNameToGlobPattern $rawName]]
  set res [list]
  set tclResult [catch { set res [glob $fullPattern] } execResult]
  if { $tclResult != 0 } {
    ok_err_msg "Failed searching for input files associated with RAW '$rawName' (pattern: '$fullPattern': $execResult"
    return  [list]
  }
  ok_trace_msg "Found [llength $res] files related to RAW '$rawName'; pattern: '$fullPattern'"
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


#~ # On success returns empty string
#~ proc MoveListedFilesIntoTrashDir {preserveSrc pathList \
                                  #~ fileTypeDescr actionName trashDirVar} {
  #~ upvar $trashDirVar trashDir
  #~ if { 0 != [llength $pathList] } {
    #~ ok_trace_msg "MoveListedFilesIntoTrashDir for '$actionName' called with trashDir='$trashDir'"
    #~ set trashDir [ProvideTrashDir $actionName $trashDir]
    #~ if { $trashDir == "" }  { return  "Cannot create backup directory" }
    #~ if { 0 > [MoveListedFiles $preserveSrc $pathList $trashDir] }  {
      #~ set msg "Failed to hide $fileTypeDescr file(s) in '$trashDir'"
      #~ ok_err_msg $msg;    return  $msg
    #~ }
    #~ ok_info_msg "[llength $pathList] $fileTypeDescr file(s) moved into '$trashDir'"
  #~ }
  #~ return  ""
#~ }


# Moves/copies files in 'pathList' into 'destDir' - if 'preserveSrc' == 0/1.
# Destination directory 'destDir' should preexist.
# On success returns number of files moved;
# on error returns negative count of errors
proc MoveListedFiles {preserveSrc pathList destDir} {
  set action [expr {($preserveSrc == 1)? "copy" : "rename"}]
  if { ![file exists $destDir] } {
    ok_err_msg "MoveListedFiles: no directory $destDir"
    return  -1
  }
  if { ![file isdirectory $destDir] } {
    ok_err_msg "MoveListedFiles: non-directory $destDir"
    return  -1
  }
  set cntGood 0;  set cntErr 0
  foreach pt $pathList {
    set tclExecResult [catch { file $action -- $pt $destDir } evalExecResult]
    if { $tclExecResult != 0 } {
      ok_err_msg "$evalExecResult!";  incr cntErr 1
    } else {                          incr cntGood 1  }
  }
  return  [expr { ($cntErr == 0)? $cntGood : [expr -1 * $cntErr] }]
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


# Returns list of known standard-image extensions (no dot) in directory 'dirPath'
proc FindStdImageExtensionsInDir {dirPath} {
  set knownStdImgExtensions [dict create jpg JPEG tif TIFF]
  set allExtensions [FindSingleDotExtensionsInDir $dirPath]
  set foundExtensions [list]
  foreach ext $allExtensions {
    if { 1 == [dict exists $knownStdImgExtensions $ext] }  {
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
    #(?slow?) if { 1 == [regexp $pattern $f fullMatch ext] }  {}
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

