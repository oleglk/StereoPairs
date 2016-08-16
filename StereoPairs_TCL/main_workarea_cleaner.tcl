# main_workarea_cleaner.tcl - hides files named after original
#   and/or standard images not used in ultimate stereopairs
#   Files of interest are those with extensions of RAWs, standard images
#       and conversion settings.


set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR  "ok_utils" "debug_utils.tcl"]
ok_trace_msg "---- Sourcing '[info script]' in '$SCRIPT_DIR' ----"
source [file join $SCRIPT_DIR   "ext_tools.tcl"]
source [file join $SCRIPT_DIR   "dir_file_utils.tcl"]
source [file join $SCRIPT_DIR   "stereopair_naming.tcl"]


package require ok_utils
namespace import -force ::ok_utils::*


###################### Global variables ############################
#DO NOT: array unset STS ;   # array for global settings; unset once per project

# TODO: extract a common part from _workarea_cleaner_set_defaults() for the whole project
proc _workarea_cleaner_set_defaults {}  {
  set ::STS(workAreaRootPath) "" ;  # we may deduce common root for all dir-s
  set ::STS(origImgRootPath)  ""
  set ::STS(stdImgRootPath)   ""
  set ::STS(origImgDirLeft)   ""
  set ::STS(origImgDirRight)  ""
  set ::STS(globalImgSettingsDir)  "" ;  # global settings dir; relevant for some converters
  set ::STS(finalImgDirPath)       "" ;  # directory with ultimate images
  set ::STS(outDirPath)       ""
  set ::STS(backupDir)        ""
  set ::STS(restoreFromDir)   "" ; # reverse the backup/thrash operation from this dir
  set ::STS(doSimulateOnly)   0
  
  set ORIG_EXT_DICT   0 ;  # per-dir extensions of original out-of-camera images
}
################################################################################
_workarea_cleaner_set_defaults ;  # load only;  do call it in a function for repeated invocations
################################################################################

set ORIG_EXT_DICT    0 ;  # per-dir extensions of original out-of-camera images

################################################################################

proc workarea_cleaner_main {cmdLineAsStr}  {
  global STS SCRIPT_DIR ORIG_EXT_DICT PREFS
  _workarea_cleaner_set_defaults ;  # calling it in a function for repeated invocations
  if { 0 == [workarea_cleaner_cmd_line $cmdLineAsStr cml] }  {
    return  0;  # error or help already printed
  }
  if { 0 == [_workarea_cleaner_arrange_workarea] }  { return  0  };  # error already printed
  
  if { 1 == [_workarea_cleaner_is_unhide_mode] } {
    return  [ok_restore_files_from_backup_dir $STS(restoreFromDir) \
                                    $STS(workAreaRootPath) $STS(doSimulateOnly)]
  }
  
  # set variables required for maintaining backup/trash directory
  set ::ok_utils::WORK_AREA_ROOT_DIR    "" ;   # OK for this use-case
  set ::ok_utils::BACKUP_ROOT_NAME      $STS(backupDir)
  set ::ok_utils::_LAST_BACKUP_DIR_PATH ""

  # "original"s in wa-cleaner help  to CONSERVATIVELY find unused settings files
  if { $STS(origImgRootPath) != "" } {; # requested to clean originals and settings
    # choose type of originals; RAW is not required
    if { 0 == [set ORIG_EXT_DICT [dualcam_choose_and_check_type_of_originals \
                       $STS(origImgDirLeft) $STS(origImgDirRight) 0]] }  {
      return  0;  # error already printed
    }
    if { 0 == [_workarea_cleaner_find_originals origPathsLeft origPathsRight]} {
      return  0;  # error already printed
    }

    set cnvSettingsFiles [FindSettingsFilesForListedImages \
                          [concat $origPathsLeft $origPathsRight] cntMissing 0]
    # it's OK to have no settings files
  } else {
    set cnvSettingsFiles [list]; # cannot safely clean settings without originals
  }
  
  # find standard-image files IN ultimate-results location
  set ultimateImages [_workarea_cleaner_find_ultimate_images]
  if { 0 == [llength $ultimateImages] } {
    return  0;  # error already printed
  }

  # find standard-image and RAW files UNDER originals' location
  set originalImages [_workarea_cleaner_find_original_images]
  # it's OK to have no original image files

  # find standard-image files UNDER standard-images' location
  set intermediateImages [_workarea_cleaner_find_intermediate_images]
  # it's OK to have no intermediate image files

  set hideCandidates [lsort -unique [concat \
                        $cnvSettingsFiles $originalImages $intermediateImages]]
  if { 0 == [llength $hideCandidates] }  {
    ok_warn_msg "No candidate files to hide were found; there's nothing to do."
    return  0
  }
  ok_info_msg "Found [llength $hideCandidates] potential candidate-to-hide file(s)"
  
  set usedIDsDict [ok_list_to_dict_set \
                        [find_lr_image_ids_in_pair_namelist $ultimateImages 1]]
  if { 0 == [dict size $usedIDsDict] }  {
    ok_warn_msg "No used image IDs were found; this is suspicious."
    return  0
  }
  ok_info_msg "Found [dict size $usedIDsDict] used image ID(s)"
  
  # TODO: distinguish between left-side and right-side IDs
  set filesToHide [_workarea_cleaner_find_images_with_unused_ids \
                                                  $hideCandidates $usedIDsDict]
  if { 0 == [llength $filesToHide] }  {
    ok_info_msg "No unused-id files were found; there's nothing to do."
    return  0
  }
  
  return  [ok_move_files_to_backup_dir $PREFS(BACKUP_DIRNAME_KEY__HIDE_UNUSED) \
                $filesToHide $::STS(workAreaRootPath) $::STS(doSimulateOnly) ""]
}


proc workarea_cleaner_cmd_line {cmdLineAsStr cmlArrName}  {
  upvar $cmlArrName      cml
  # create the command-line description
  set descrList \
[list \
  -help {"" "print help"} \
  -global_img_settings_dir {val	"full path of the directory where the RAW converter keeps all image-settings files - specify if relevant for your converter"} \
  -orig_img_dir {val	"input directory; left (right) out-of-camera images expected in 'orig_img_dir'/L ('orig_img_dir'/R)"} \
  -std_img_dir {val	"input directory with standard images (out-of-camera JPEG or converted from RAW and/or intermediate images); left (right) images expected in 'std_img_dir'/L ('std_img_dir'/R)"} \
  -final_img_dir {val	"directory with ultimate stereopair images"} \
  -out_dir {val	"output directory"} \
  -backup_dir {val	"directory to hide unused files in"} \
  -restore_from_dir {val	"directory to unhide/restore files from"} \
  -workarea_root_dir {val	"workarea root directory - where to unhide/restore files to"} \
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
    ok_info_msg "    DualCam Workarea_Cleaner hides original and intermediate files not used in final stereopairs."
    ok_info_msg "========= Command line parameters (in any order): =============="
    ok_info_msg $cmdHelp
    ok_info_msg "================================================================"
    ok_info_msg "========= Example - hide (note TCL-style directory separators): ======="
    ok_info_msg " workarea_cleaner_main \"-orig_img_dir . -std_img_dir TIFF -final_img_dir . -out_dir ./OUT -backup_dir TRASH\""
    ok_info_msg "========= Example - unhide (note TCL-style directory separators): ======="
    ok_info_msg " workarea_cleaner_main \"-restore_from_dir ./TRASH/2016-06-10_15-15-46__HideUnusedFiles__1/ -workarea_root_dir . -out_dir ./OUT\""
    ok_info_msg "================================================================"
    return  0
  }
  if { 0 == [_workarea_cleaner_parse_cmdline cml] }  {
    ok_err_msg "Error(s) in command parameters. Aborting..."
    return  0
  }
  set cmdStrNoHelp [ok_cmd_line_str cml cmlD "\n" 0]
  ok_info_msg "==== Now clean the workarea by the following spec: ===="
  ok_info_msg $cmdStrNoHelp
  return  1
}


proc _workarea_cleaner_is_unhide_mode {} {
  return [expr {$::STS(restoreFromDir) != ""}]
}


proc _workarea_cleaner_warn_unhide_mode {cliParamName} {
  if { $::STS(restoreFromDir) == "" }  {  return  0 } ; # not in unhide mode
  switch -- $cliParamName {
    "-global_img_settings_dir"  -
    "-orig_img_dir"             -
    "-std_img_dir"              -
    "-final_img_dir"            -
    "-backup_dir"   {
      ok_err_msg "Option '$cliParamName' is incompatible with restore/unhide mode"
      return  1
    }
    default   { return 0 } ;  # non-conflicting parameter
  }
}


proc _workarea_cleaner_parse_cmdline {cmlArrName}  {
  upvar $cmlArrName      cml
  set errCnt 0
  
  if { 1 == [info exists cml(-restore_from_dir)] }  { ; # comes 1st - MUX with most
    if { 0 == [file isdirectory $cml(-restore_from_dir)] }  {
      ok_err_msg "Non-directory '$cml(-restore_from_dir)' specified as the directory to restore hidden files from"
      incr errCnt 1
    } else {
      set ::STS(restoreFromDir) $cml(-restore_from_dir)
    }
  }
  if { 1 == [info exists cml(-global_img_settings_dir)] }  {
    if { 1 == [_workarea_cleaner_warn_unhide_mode "-global_img_settings_dir"] } {
      incr errCnt 1
    } else {
      if { 0 == [file isdirectory $cml(-global_img_settings_dir)] }  {
        ok_err_msg "Non-directory '$cml(-global_img_settings_dir)' specified as the global image-settings directory"
        incr errCnt 1
      } else {
        set ::STS(globalImgSettingsDir) $cml(-global_img_settings_dir)
      }
    }
  }  
  if { 0 == [info exists cml(-orig_img_dir)] }  {
    if { 0 == [_workarea_cleaner_is_unhide_mode] } {
      ok_warn_msg "Workarea cleaner did not obtain directory with original images"
    }
  } else {
    if { 1 == [_workarea_cleaner_warn_unhide_mode "-orig_img_dir"] } {
      incr errCnt 1
    } elseif { 0 == [file isdirectory $cml(-orig_img_dir)] }  {
      ok_err_msg "Non-directory '$cml(-orig_img_dir)' specified as input directory"
      incr errCnt 1
    } else {
      set ::STS(origImgRootPath) $cml(-orig_img_dir); # recurse under L/R subdir-s 
      set ::STS(origImgDirLeft)  [file join $::STS(origImgRootPath) "L"]
      set ::STS(origImgDirRight) [file join $::STS(origImgRootPath) "R"]
    }
  }
  if { 0 == [info exists cml(-std_img_dir)] }  {
    if { 0 == [_workarea_cleaner_is_unhide_mode] } {
      ok_warn_msg "Workarea cleaner did not obtain directory with standard images"
    }
  } else {
    if { 1 == [_workarea_cleaner_warn_unhide_mode "-std_img_dir"] } {
      incr errCnt 1
    } elseif { 0 == [file isdirectory $cml(-std_img_dir)] }  {
      ok_err_msg "Non-directory '$cml(-std_img_dir)' specified as standard-images directory"
      incr errCnt 1
    } else {
      set ::STS(stdImgRootPath) $cml(-std_img_dir); # recurse under stdImgRootPath
    }
  }
  if { 0 == [info exists cml(-final_img_dir)] }  {
    if { 0 == [_workarea_cleaner_is_unhide_mode] } {
      ok_err_msg "Please specify directory with final images; example: -final_img_dir D:/Photo/Work"
      incr errCnt 1
    }
  } else {
    if { 1 == [_workarea_cleaner_warn_unhide_mode "-final_img_dir"] } {
      incr errCnt 1
    } elseif { 0 == [file isdirectory $cml(-final_img_dir)] }  {
      ok_err_msg "Non-directory '$cml(-final_img_dir)' specified as final images directory"
      incr errCnt 1
    } else {
      set ::STS(finalImgDirPath) $cml(-final_img_dir)
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
    # since "-backup_dir" has a default, it cannot be prohibited in unhide mode
    set ::STS(backupDir) $cml(-backup_dir)
  }
  if { 1 == [info exists cml(-simulate_only)] }  {
    set ::STS(doSimulateOnly) 1
  }
  if { $errCnt > 0 }  {
    #ok_err_msg "Error(s) in command parameters!"
    return  0
  }
  if { 1 == [_workarea_cleaner_is_unhide_mode] } {
    if { 0 == [info exists cml(-workarea_root_dir)] }  {
      ok_err_msg "Please specify workarea root directory; example: -workarea_root_dir D:/Photo/Work/Yesterday"
      incr errCnt 1
    } elseif { (1 == [file exists $cml(-workarea_root_dir)]) && \
               (0 == [file isdirectory $cml(-workarea_root_dir)]) }  {
      ok_err_msg "Non-directory '$cml(-workarea_root_dir)' specified as workarea root directory"
      incr errCnt 1
    } else {
      set ::STS(workAreaRootPath)      [file normalize $cml(-workarea_root_dir)]
      set ::ok_utils::WORK_AREA_ROOT_DIR $::STS(workAreaRootPath)
    }
  } else { ;  # deduce workarea root from image dir-s; TODO: make utility
    set waDirs [ok_discard_empty_list_elements \
        [list $::STS(origImgRootPath) $::STS(stdImgRootPath) $::STS(backupDir)]]
    if { "" != [set ::STS(workAreaRootPath) \
                                  [ok_find_filepaths_common_prefix $waDirs]] } {
      ok_info_msg "Common work-area root directory is '$::STS(workAreaRootPath)'"
      set ::ok_utils::WORK_AREA_ROOT_DIR $::STS(workAreaRootPath)
    } else {
      ok_info_msg "No common work-area root directory assumed"
    }
  }
  if { $errCnt > 0 }  { ;   # recheck for root-dir
    #ok_err_msg "Error(s) in command parameters!"
    return  0
  }
  #ok_info_msg "Command parameters are valid"
  return  1
}


# Puts into 'origPathsLeftVar' and 'origPathsRightVar' the paths of
# standard and RAW images anywhere under originals' directories.
# Returns number of files found.
proc _workarea_cleaner_find_originals {origPathsLeftVar origPathsRightVar}  {
  global STS ORIG_EXT_DICT
  upvar $origPathsLeftVar  origPathsLeft
  upvar $origPathsRightVar origPathsRight
  set origExtLeft   [dict get $ORIG_EXT_DICT "L"]
  set origExtRight  [dict get $ORIG_EXT_DICT "R"]
  set origPathsLeft  [ok_find_files $STS(origImgDirLeft)  "*.$origExtLeft" ]
  set origPathsRight [ok_find_files $STS(origImgDirRight) "*.$origExtRight"]
  set cntFound [expr [llength $origPathsLeft] + [llength $origPathsRight]]
  return  $cntFound
}


# Finds and returns standard-image files IN ultimate-results location
proc _workarea_cleaner_find_ultimate_images {} {
  ok_info_msg "Start searching for ultimate images"
  set ultimateImages [ok_find_files_by_entensions $::STS(finalImgDirPath) \
                                [dict keys $::KNOWN_STD_IMG_EXTENSIONS_DICT] 0]
  if { 0 < [llength $ultimateImages] }  {
    ok_info_msg "Found [llength $ultimateImages] ultimate image(s) in '$::STS(finalImgDirPath)'"
  } else {
    ok_err_msg "No ultimate image(s) found in '$::STS(finalImgDirPath)'"
  }
  return  $ultimateImages
}


# Finds and returns RAW- and standard-image files UNDER original-images location
proc _workarea_cleaner_find_original_images {} {
  if { $::STS(origImgRootPath) == "" }  {
    ok_info_msg "Cleaning original images not requested"
    return  [list]
  }
  ok_info_msg "Start searching for original images"
  set allExtensions [concat [dict keys $::KNOWN_STD_IMG_EXTENSIONS_DICT] \
                            [dict keys $::KNOWN_RAW_EXTENSIONS_DICT]]
  set originalImagesLeft [ok_find_files_by_entensions $::STS(origImgDirLeft) \
                                                      $allExtensions 1]
  set originalImagesRight [ok_find_files_by_entensions $::STS(origImgDirRight) \
                                                       $allExtensions 1]
  set originalImages [concat $originalImagesLeft $originalImagesRight]
  if { 0 < [llength $originalImages] }  {
    ok_info_msg "Found [llength $originalImagesLeft] original image(s) under '$::STS(origImgDirLeft)' and [llength $originalImagesRight] original image(s) under '$::STS(origImgDirRight)'"
  } else {
    ok_info_msg "No original image(s) found under '$::STS(origImgDirLeft)' and '$::STS(origImgDirRight)'"
  }
  return  $originalImages
}


# Finds and returns standard-image files UNDER intermediate-images location
proc _workarea_cleaner_find_intermediate_images {} {
  if { $::STS(stdImgRootPath) == "" }  {
    ok_info_msg "Cleaning intermediate images not requested"
    return  [list]
  }
  ok_info_msg "Start searching for intermediate images"
  set intermediateImages [ok_find_files_by_entensions $::STS(stdImgRootPath) \
                                [dict keys $::KNOWN_STD_IMG_EXTENSIONS_DICT] 1]
  if { 0 < [llength $intermediateImages] }  {
    ok_info_msg "Found [llength $intermediateImages] intermediate image(s) under '$::STS(stdImgRootPath)'"
  } else {
    ok_info_msg "No intermediate image(s) found under '$::STS(stdImgRootPath)'"
  }
  return  $intermediateImages
}


# Returns list of file-paths (out of 'candidates') that have
# - either single ID that's unused
# - or two IDs of which at least one is unused
# TODO: distinguish between left-side and right-side IDs
proc _workarea_cleaner_find_images_with_unused_ids {candidates usedIDsDict}  {
  set unusedFilesList [list]
  set skipCnt 0
  foreach fPath $candidates {
    if { 0 == [find_1or2_image_ids_in_imagename $fPath id1 id2 0] }  {
      ok_info_msg "File '$fPath' considered irrelevant - skipped"
      incr skipCnt 1
    }
    if { (0 == [dict exists $usedIDsDict $id1]) || \
          (($id2 != "") && (0 == [dict exists $usedIDsDict $id2])) } {
      ok_info_msg "File '$fPath' has unused ID(s)"
      lappend unusedFilesList $fPath
    } else {
      ok_info_msg "File '$fPath' has all ID(s) in use"
    }
  }
  ok_info_msg "Found [llength $unusedFilesList] file(s) with unused image IDs out of  [llength $candidates] candidate(s); $skipCnt file(s) skipped as irrelevant"
  return  $unusedFilesList
}


proc _UNUSED__workarea_cleaner_find_images_without_used_ids {candidates usedIDsDict}  {
  set unusedFilesList [list]
  set skipCnt 0
  foreach fPath $candidates {
    if { 0 == [find_1or2_image_ids_in_imagename $fPath id1 id2 0] }  {
      ok_info_msg "File '$fPath' considered irrelevant - skipped"
      incr skipCnt 1
    }
    if { ([dict exists $usedIDsDict $id1]) || \
          (($id2 != "") && ([dict exists $usedIDsDict $id2])) } {
      ok_info_msg "File '$fPath' has ID(s) in use"
      continue
    }
    lappend unusedFilesList $fPath
  }
  ok_info_msg "Found [llength $unusedFilesList] file(s) with no used image IDs out of  [llength $candidates] candidate(s); $skipCnt file(s) skipped as irrelevant"
  return  $unusedFilesList
}


proc _workarea_cleaner_arrange_workarea {}  {
  if { 0 == [ok_create_absdirs_in_list \
              [list $::STS(outDirPath) $::STS(backupDir)] \
              [list "output"           "backup"         ]] } {
    return  0;  # error already printed
  }
  return  1
}
