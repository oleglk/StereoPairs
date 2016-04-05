# cnv_settings_finder.tcl - implements search for image-converter settings

set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR  "ok_utils" "debug_utils.tcl"]
ok_trace_msg "---- Sourcing '[info script]' in '$SCRIPT_DIR' ----"
source [file join $SCRIPT_DIR   "dir_file_utils.tcl"]

package require ok_utils
namespace import -force ::ok_utils::*

##### Search for settings files moved here,
#####        since some converters force standard location


# Mostly for testing
proc FindSettingsFiles {subdirName {priErr 1}} {
  global STS
  if { $STS(cnvSettingsDir) != "" }  { set settingsDir $STS(cnvSettingsDir) ;   # std dir
  } else                      { set settingsDir $subdirName   }
  return  [FindSettingsFilesInDir $settingsDir $priErr]
}


# Mostly for testing
proc FindSettingsFilesInDir {dirPath {priErr 1}} {
  # TODO: improve pattern - use extension for the converter or all extensions
  set fullPattern [file join $dirPath [SettingsFileName "*"]]
  set res [list]
  set tclResult [catch { set res [glob $fullPattern] } execResult]
  if { $tclResult != 0 } {
    if { $priErr != 0 }  {
      ok_err_msg "Failed searching for files matching <$fullPattern> (called by '[ok_callername]'): $execResult"
    }
    return  [list]
  }
  # filter out unnecessary files
  # we may have picked settings for other converters; filter these out
  # TODO: use [_SelectRelevantSettingsFiles $allFilePathsForOneRaw]
  set fRes [list]
  foreach sP $res {
    set settingsFileName [file tail $sP]
    set purename [SettingsFileNameToPurename $settingsFileName]
    set expSettingsName [SettingsFileName $purename]
    if { 0 == [string compare -nocase $settingsFileName $expSettingsName] } {
      lappend fRes $sP
    } else {
      ok_trace_msg "Settings file '$sP' assumed to belong to other RAW converter (pure-name=='$purename', expected-settings-name='$expSettingsName')"
    }    
  }
  return  $fRes
}


# For mainstream usage
# Returns list of settings paths for RAWs under 'dirPath'.
# Puts into 'cntMissing' number of RAWs for which no settings files found.
proc FindSettingsFilesForRawsInDir {dirPath cntMissing {priErr 1}} {
  global STS
  upvar $cntMissing cntMiss
  set cntMiss 0
  # TODO: check existence of dirPath
  set rawPaths [FindRawInputs $dirPath $priErr]
  if { 0 == [llength $rawPaths] }  {
    if { $priErr == 1 }  {
      ok_err_msg "No relevant RAW files found in '$dirPath'"
    }
    return  [list]
  }
  if { $STS(cnvSettingsDir) != "" }  {
    set settingsDir $STS(cnvSettingsDir) ;   # full path of standard dir
  } else {
    set settingsDir $dirPath
  }
  set settingsPaths [list]
  foreach rawPath $rawPaths {
    set rawName [file tail $rawPath]
    set allFilesForOneRaw [FindAllInputsForOneRAWInDir $rawName $settingsDir]
    set relevantSettingsFiles [_SelectRelevantSettingsFiles $allFilesForOneRaw]
    if { 0 == [llength $relevantSettingsFiles] }  {
      incr cntMiss 1
      if { $priErr == 1 }  {
        ok_err_msg "No relevant settings files found for '$rawPath' in '$settingsDir'"
      }
    } else {
      set settingsPaths [concat $settingsPaths $relevantSettingsFiles]
    }
  }
  ok_info_msg "Found [llength $settingsPaths] settings file(s) (in directory '$settingsDir') for [llength $rawPaths] RAWs in '$dirPath'"
  ##if { $cntMiss > 0 }  {error "Missing $cntMiss settings file(s) in '$settingsDir'"} ;   #OK_TMP
  return  $settingsPaths
}


proc FindAllSettingsFilesForOneRaw {rawPath {priErr 1}} {
  global WORK_DIR STS
  set rawName [file tail $rawPath]
  set rawDir  [file dirname $rawPath]
  if { $STS(cnvSettingsDir) != "" }  {
    set settingsDir $STS(cnvSettingsDir) ;   # full path of standard dir
  } else {
    set settingsDir $rawDir
  }
  set allFilesForOneRaw [FindAllInputsForOneRAWInDir $rawName $settingsDir]
  # the RAW itself could be included; drop it then
  for {set i 0} {$i < [llength $allFilesForOneRaw]} {incr i 1} {
    set filePath [lindex $allFilesForOneRaw $i]
    #ok_trace_msg "'$filePath' considered [expr {(1 == [IsOrigImageName $filePath])? {RAW-file} : {settings-file}}]"
    if { 1 == [IsOrigImageName $filePath] }  {
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


proc _SelectRelevantSettingsFiles {allFilePathsForOneRaw}  {
  # filter out unnecessary files
  # we may have picked settings for other converters; filter these out
  set fRes [list]
  foreach sP $allFilePathsForOneRaw {
    set settingsFileName [file tail $sP]
    set purename [SettingsFileNameToPurename $settingsFileName]
    set expSettingsName [SettingsFileName $purename]
    if { 0 == [string compare -nocase $settingsFileName $expSettingsName] } {
      lappend fRes $sP
    } else {
      ok_trace_msg "Settings file '$sP' assumed to belong to other RAW converter (pure-name=='$purename', expected-settings-name='$expSettingsName')"
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
  set allRAws [FindRawInputs $rawDir]
  if { $STS(cnvSettingsDir) != "" }  { ;  # settings for the RAWs; no unmatched settings
    set allSettings [FindSettingsFilesForDive $subdirName cntMissing 0]
  } else { ; # all settings in dive dir; some settings could be unmatched
    set allSettings [FindSettingsFiles $subdirName 0]
  }
  foreach f $allRAws {
    set purenameToRaw([string toupper [file rootname [file tail $f]]])  $f
  }
  ok_trace_msg "Image names for which RAWs exist: {[array names purenameToRaw]}"
  foreach f $allSettings {
    set purenameToSettings([string toupper [SettingsFileNameToPurename \
                                                      [file tail $f]]])  $f
  }
  ok_trace_msg "Image names for which settings exist: {[array names purenameToSettings]}"
}

