# cnv_settings_finder.tcl - implements search for image-converter settings

set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR  "ok_utils" "debug_utils.tcl"]
ok_trace_msg "---- Sourcing '[info script]' in '$SCRIPT_DIR' ----"
source [file join $SCRIPT_DIR   "dir_file_utils.tcl"]

package require ok_utils
namespace import -force ::ok_utils::*

# Maps (low-case!) converter-settings-file extensions to converter names
set CNV_SETTINGS_EXTENSIONS_DICT [dict create                             \
      ".dummy_sts"      "Dummy-Converter"                                 \
      ".dummy_gl_sts"   "Dummy-Converter-with-Global-Settings-Directory"  \
      ".xmp"            "CorelAftershot-or-PhotoNinja"                    \
      ".pp3"            "RawTherapee"                                     \
                                                                          ]

##### Search for settings files moved here,
#####        since some converters force standard location


# Mostly for testing
proc FindSettingsFiles {subdirName {priErr 1}} {
  global STS
  if { $STS(globalImgSettingsDir) != "" }  { set settingsDir $STS(globalImgSettingsDir) ;   # std dir
  } else                      { set settingsDir $subdirName   }
  return  [FindSettingsFilesInDir $settingsDir $priErr]
}


#~ # Mostly for testing
#~ proc FindSettingsFilesInDir {dirPath {priErr 1}} {
  #~ # TODO: improve pattern - use extension for the converter or all extensions
  #~ set fullPattern [file join $dirPath [SettingsFileName "*"]]
  #~ set res [list]
  #~ set tclResult [catch { set res [glob $fullPattern] } execResult]
  #~ if { $tclResult != 0 } {
    #~ if { $priErr != 0 }  {
      #~ ok_err_msg "Failed searching for files matching <$fullPattern> (called by '[ok_callername]'): $execResult"
    #~ }
    #~ return  [list]
  #~ }
  #~ # filter out unnecessary files
  #~ # we may have picked settings for other converters; filter these out
  #~ set fRes [list]
  #~ foreach sP $res {
    #~ set settingsFileName [file tail $sP]
    #~ set purename [AnyFileNameToPurename $settingsFileName]
    #~ set expSettingsName [SettingsFileName $purename]
    #~ if { 0 == [string compare -nocase $settingsFileName $expSettingsName] } {
      #~ lappend fRes $sP
    #~ } else {
      #~ ok_trace_msg "Settings file '$sP' assumed to belong to other RAW converter (pure-name=='$purename', expected-settings-name='$expSettingsName')"
    #~ }    
  #~ }
  #~ return  $fRes
#~ }


# For mainstream usage
# Returns list of settings paths for RAWs under 'dirPath'.
# Puts into 'cntMissing' number of RAWs for which no settings files found.
proc FindSettingsFilesForRawsInDir {dirPath cntMissing {priErr 1}} {
  global STS
  upvar $cntMissing cntMiss
  set cntMiss 0
  # TODO: check existence of dirPath
  set rawPaths [FindRawInputs $dirPath \
                            $STS(origImgDirLeft) $STS(origImgDirRight) $priErr]
  if { 0 == [llength $rawPaths] }  {
    if { $priErr == 1 }  {
      ok_err_msg "No relevant RAW files found in '$dirPath'"
    }
    return  [list]
  }
  set settingsPaths [FindSettingsFilesForListedImages $rawPaths \
                                                      cntMissing $priErr]
  ok_info_msg "Found [llength $settingsPaths] conversion settings file(s) for [llength $rawPaths] RAWs in '$dirPath'"
  ##if { $cntMiss > 0 }  {error "Missing $cntMiss settings file(s) in '$settingsDir'"} ;   #OK_TMP
  return  $settingsPaths
}


# For mainstream usage
# Returns list of settings paths for images in 'imgPaths'.
# Puts into 'cntMissing' number of images for which no settings files found.
proc FindSettingsFilesForListedImages {imgPaths cntMissing {priErr 1}} {
  global STS
  upvar $cntMissing cntMiss
  set cntMiss 0
  ok_trace_msg "Source images for settings files: {$imgPaths}"
  set settingsPaths [list]
  foreach imgPath $imgPaths {
    set imgName [file tail $imgPath]
    if { $STS(globalImgSettingsDir) != "" }  {
      set settingsDir $STS(globalImgSettingsDir) ;   # full path of standard dir
    } else {
      set settingsDir [file dirname $imgPath];  # settings alongside the image
    }
    set allFilesForOneImage [FindAllInputsForOneImageInDir $imgName \
                                                           $settingsDir $priErr]
    set relevantSettingsFiles [_SelectSettingsFilesInFileList \
                                                         $allFilesForOneImage]
    if { 0 == [llength $relevantSettingsFiles] }  {
      incr cntMiss 1
      if { $priErr == 1 }  {
        ok_warn_msg "No relevant conversion settings files found for '$imgPath' in '$settingsDir'"
      }
    } else {
      set settingsPaths [concat $settingsPaths $relevantSettingsFiles]
    }
  }
  ok_info_msg "Found [llength $settingsPaths] conversion settings file(s) for [llength $imgPaths] image(s)"
  ##if { $cntMiss > 0 }  {error "Missing $cntMiss settings file(s) in '$settingsDir'"} ;   #OK_TMP
  return  $settingsPaths
}


proc FindAllSettingsFilesForOneRaw {rawPath {priErr 1}} {
  global WORK_DIR STS
  set rawName [file tail $rawPath]
  set rawDir  [file dirname $rawPath]
  if { $STS(globalImgSettingsDir) != "" }  {
    set settingsDir $STS(globalImgSettingsDir) ;   # full path of standard dir
  } else {
    set settingsDir $rawDir
  }
  set allFilesForOneRaw [FindAllInputsForOneImageInDir $rawName $settingsDir \
                                                       $priErr]
  # the RAW itself could be included; drop it then
  for {set i 0} {$i < [llength $allFilesForOneRaw]} {incr i 1} {
    set filePath [lindex $allFilesForOneRaw $i]
    #ok_trace_msg "'$filePath' considered [expr {(1 == [IsOrigImagePath $filePath $STS(origImgDirLeft) $STS(origImgDirRight)]])? {RAW-file} : {settings-file}}]"
    if { 1 == [IsOrigImagePath $filePath \
                               $STS(origImgDirLeft) $STS(origImgDirRight)]] } {
      set allFilesForOneRaw [lreplace $allFilesForOneRaw $i $i]
      break
    }
  }
  #ok_trace_msg "Settings file(s) for '$rawName': {$allFilesForOneRaw}"
  if { ($priErr == 1) && (0 == [llength $allFilesForOneRaw]) }  {
    ok_warn_msg "No settings file for '$rawName' found in '$settingsDir'"
  }
  return  $allFilesForOneRaw
}


#~ # Finds settings files for the curremt RAW converter
#~ proc _SelectRelevantSettingsFiles {allFilePathsForOneRaw}  {
  #~ # filter out unnecessary files
  #~ # we may have picked settings for other converters; filter these out
  #~ set fRes [list]
  #~ foreach sP $allFilePathsForOneRaw {
    #~ set settingsFileName [file tail $sP]
    #~ set purename [AnyFileNameToPurename $settingsFileName]
    #~ set expSettingsName [SettingsFileName $purename]
    #~ if { 0 == [string compare -nocase $settingsFileName $expSettingsName] } {
      #~ lappend fRes $sP
    #~ } else {
      #~ ok_trace_msg "Settings file '$sP' assumed to belong to other RAW converter (pure-name=='$purename', expected-settings-name='$expSettingsName')"
    #~ }    
  #~ }
  #~ return  $fRes
#~ }


# Finds settings files for all known RAW converters
proc _SelectSettingsFilesInFileList {filePaths}  {
  # filter out unnecessary files
  # we may have picked settings for other converters; filter these out
  set fRes [list]
  foreach sP $filePaths {
    set fileExt [string tolower [file extension $sP]]
    if { [dict exists $::CNV_SETTINGS_EXTENSIONS_DICT $fileExt] } {
      lappend fRes $sP
      ok_info_msg "Settings file '$sP' comes from RAW converter '[dict get $::CNV_SETTINGS_EXTENSIONS_DICT $fileExt]'"
    } else {
      ok_trace_msg "File '$sP' is not a RAW converter settings file"
    }    
  }
  return  $fRes
}


# Mostly for testing
proc FindRawColorTargetsSettings {{priErr 1}} {
  global RAW_COLOR_TARGET_DIR
  return  [FindSettingsFiles $RAW_COLOR_TARGET_DIR $priErr]
}

# Mostly for testing
proc FindUltimateRawPhotosSettings {{priErr 1}} {
  return  [FindSettingsFiles "" $priErr]
}

# For mainstream usage
proc FindRawColorTargetsSettingsForDive {{priErr 1}} {
  global RAW_COLOR_TARGET_DIR
  return  [FindSettingsFilesForDive $RAW_COLOR_TARGET_DIR cntMissing $priErr]
}

# For mainstream usage
proc FindUltimateRawPhotosSettingsForDive {{priErr 1}} {
  return  [FindSettingsFilesForDive "" cntMissing $priErr]
}



proc ListRAWsAndSettingsFiles {subdirName \
                                purenameToRawVar purenameToSettingsVar}  {
  global WORK_DIR STS
  upvar $purenameToRawVar purenameToRaw
  upvar $purenameToSettingsVar purenameToSettings
  array unset purenameToRaw;  array unset purenameToSettings
  set rawDir  [file join $WORK_DIR $subdirName]
  set allRAws [FindRawInputs $rawDir $STS(origImgDirLeft) $STS(origImgDirRight)]
  if { $STS(globalImgSettingsDir) != "" }  { ;  # settings for the RAWs; no unmatched settings
    set allSettings [FindSettingsFilesForDive $subdirName cntMissing 0]
  } else { ; # all settings in dive dir; some settings could be unmatched
    set allSettings [FindSettingsFiles $subdirName 0]
  }
  foreach f $allRAws {
    set purenameToRaw([string toupper [file rootname [file tail $f]]])  $f
  }
  ok_trace_msg "Image names for which RAWs exist: {[array names purenameToRaw]}"
  foreach f $allSettings {
    set purenameToSettings([string toupper [AnyFileNameToPurename \
                                                      [file tail $f]]])  $f
  }
  ok_trace_msg "Image names for which settings exist: {[array names purenameToSettings]}"
}


# Reads and returns as one string full settings file from 'settingsPath'.
# On error returns "".
proc ReadSettingsFile {settingsPath}  {
  if { $settingsPath == "" }  {
    ok_err_msg "Settings file path not given for reading"
    return  ""
  }
  if [catch {open $settingsPath "r"} fileId] {
    ok_err_msg "Cannot open '$settingsPath' for reading: $fileId"
    return  ""
  }
  set tclExecResult [catch {set data [read $fileId]} execResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "Failed reading settings from '$settingsPath': $execResult!"
    return  ""
  }
  close $fileId
  if { "" == [string trim $data] }  {
    ok_err_msg "Settings file '$settingsPath' is empty"
    return  ""
  }
  return $data
}


# Writes full settings from 'settingsStr' into settings file 'settingsPath'.
# Returns 1 on success, 0 on error.
proc WriteSettingsFile {settingsStr settingsPath} {
  if { $settingsPath == "" }  {
    ok_err_msg "Settings file path not given for writting"
    return  0
  }
  if [catch {open $settingsPath "w"} fileId] {
    ok_err_msg "Cannot open '$settingsPath' for writting: $fileId"
    return  0
  }
  set tclExecResult [catch {puts -nonewline $fileId $settingsStr} execResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "Failed writting settings sinto '$settingsPath': $execResult!"
    return  0
  }
  close $fileId
  return 1
}

