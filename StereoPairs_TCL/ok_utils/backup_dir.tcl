# backup_dir.tcl
# Copyright (C) 2016 by Oleg Kosyakovsky
global OK_TCLSRC_ROOT
if { [info exists OK_TCLSRC_ROOT] } {;   # assume running as a part of LazyConv
    source $OK_TCLSRC_ROOT/lzc_beta_license.tcl
    package provide ok_utils 1.1
}


namespace eval ::ok_utils:: {

  namespace export                \
    ok_provide_backup_dir         \
    ok_move_files_to_backup_dir
    
  variable WORK_AREA_ROOT_DIR ; # path of work-area root directory
  variable BACKUP_ROOT_NAME ;   # name for backup subdirectory under work-area
  variable _LAST_BACKUP_DIR_PATH ; # path of the last backup directory created
}


# Finds or creates standartly named backup directory and returns its path.
# The backup directory path: <WORK_AREA_ROOT_DIR>/<BACKUP_ROOT_NAME>/<leaf-name>
# The leaf directory name is based on 'dirNameKey' and invocation timestamp.
# If 'trashDirPath' given and existent, just returns it.
# Example:
#  set ::ok_utils::WORK_AREA_ROOT_DIR qqWorkArea;  set ::ok_utils::BACKUP_ROOT_NAME qqBackupRoot;  set ::ok_utils::_LAST_BACKUP_DIR_PATH "";  ::ok_utils::ok_provide_backup_dir TestTheProc
proc ::ok_utils::ok_provide_backup_dir {dirNameKey {trashDirPath ""}}  {
  variable WORK_AREA_ROOT_DIR
  variable BACKUP_ROOT_NAME
  variable _LAST_BACKUP_DIR_PATH
  if { ($trashDirPath != "") && (1 == [file exists $trashDirPath]) }  {
    return  $trashDirPath
  }
  set trashRootDir [file join $WORK_AREA_ROOT_DIR $BACKUP_ROOT_NAME]
  if { ![file exists $trashRootDir] } { ;   # create root-dir at first use
    set tclExecResult [catch { file mkdir $trashRootDir } evalExecResult]
    if { $tclExecResult != 0 } {
      ok_err_msg "Failed creating backup root directory '$trashRootDir': $evalExecResult!"
      return  ""
    }
    ok_info_msg "Created root directory for trash/backup: '$trashRootDir'"
  }
  set nAttempts 4;  # will try up to 'nAttempts' different names
  for {set i 1} {$i <= $nAttempts} {incr i 1}  {
    set timeStr [clock format [clock seconds] -format "%Y-%m-%d_%H-%M-%S"]
    set idStr [format "%s__%s__%d" $timeStr $dirNameKey $i]
    set trashDirPath [file join $trashRootDir $idStr]
    if { 1 == [file exists $trashDirPath] }  {
      ok_trace_msg "Directory named '$trashDirPath' exists; cannot use it for backup"
      set trashDirPath "";  continue
    }
    set _LAST_BACKUP_DIR_PATH "" ;  # to avoid telling old path on failure
    set tclExecResult [catch { file mkdir $trashDirPath } evalExecResult]
    if { $tclExecResult != 0 } {
      ok_err_msg "Failed creating backup directory '$trashDirPath' (attempt $i): $evalExecResult!"
      return  ""
    }
    ok_info_msg "Created directory for trash/backup: '$trashDirPath'"
    set _LAST_BACKUP_DIR_PATH [file normalize $trashDirPath]
    break;  # created with path '$trashDirPath'
    set trashDirPath "";  # indicates failure to create dir so far
    after 1000;  # pause for 1 sec, so that next attempt picks different name
  }
  
  if { $trashDirPath == "" }  {
    ok_err_msg "Failed to create directory for trash/backup for '$dirNameKey'"
  }
  return  $trashDirPath
}


proc ::ok_utils::_ok_rename_root_component_in_filepath {fPathComponentsList}  {
  if { 0 == [llength $fPathComponentsList] }  { return $fPathComponentsList }
  set comp1Old [lindex $fPathComponentsList 0]
  set comp1New [string map {: _colon_ . _dot_ / _slash_} $comp1Old]
  return [lreplace $fPathComponentsList 0 0 $comp1New]
}


proc ::ok_utils::_ok_rename_root_in_filepath_string {fPath}  {
  set fPathComponentsList [file split [file normalize $filePath]]
  return  [_ok_rename_root_component_in_filepath $fPathComponentsList]
}


# Moves files from 'filePathsList' to under the current backup directory.
# Each is placed under a relative path of subdirectories
# reflecting its location:
# - under 'commonRootDirOrNone' if given and valid,
# - under the drive root if 'commonRootDirOrNone' not given or invalid.
proc ::ok_utils::ok_move_files_to_backup_dir {dirNameKey filePathsList \
                                       commonRootDirOrNone {trashDirPath ""}}  {
  if { "" == [set destRootDir [ok_provide_backup_dir \
                                                  $dirNameKey $trashDirPath]]} {
    return  0;  # error already printed
  }
  if { 0 == [llength $filePathsList] }  {
    ok_warn_msg "No files provided for trash/backup for '$dirNameKey'"
    return  1;  # nothing to do
  }
  ok_info_msg "Start moving [llength $filePathsList] file(s) to under '$destRootDir' - $dirNameKey"
  foreach fPath $filePathsList {
    set pathInBU [expr {($commonRootDirOrNone == "")?                          \
                  [::ok_utils::_ok_rename_root_in_filepath_string $fPath] :    \
                  [ok_strip_prefix_from_filepath $fPath $commonRootDirOrNone   \
                            ::ok_utils::_ok_rename_root_component_in_filepath]}]
    ok_trace_msg "Going to move '$fPath' (as '$pathInBU') to under '$destRootDir'"
  }
  ok_info_msg "Done  moving [llength $filePathsList] file(s) to under '$destRootDir' - $dirNameKey"
  return  1
}


proc ::ok_utils::ok_provide_backup_dirs_for_filelist {dirNameKey filePathsList \
                                       commonRootDirOrNone {trashDirPath ""}}  {
  set setOfDirs [dict create]
  if { "" == [set destRootDir [ok_provide_backup_dir \
                                                  $dirNameKey $trashDirPath]]} {
    return  0;  # error already printed
  }
  foreach fPath $filePathsList {
    set pathInBU [expr {($commonRootDirOrNone == "")?                          \
                  [::ok_utils::_ok_rename_root_in_filepath_string $fPath] :    \
                  [ok_strip_prefix_from_filepath $fPath $commonRootDirOrNone   \
                            ::ok_utils::_ok_rename_root_component_in_filepath]}]
    set subdirRelPath [file dirname $pathInBU]; # do not normalize relative paths
    set subdirAbsPath [file normalize [file join $destRootDir $subdirRelPath]]]
    if { 0 == [dict exists $setOfDirs $dirPathInBU] } {
      ok_trace_msg "Going to create directory '$subdirAbsPath' as backup destination for '$fPath'"
      #TODO: check if simulate-only mode
      if { 0 == [ok_create_absdirs_in_list [list $subdirAbsPath]] }  {
        ok_err msg "Failed creating destination directory '$subdirAbsPath' for '$fPath'"
        return  0
      }
      dict set setOfDirs $subdirAbsPath
    }
  }
  return  1
}

proc ::ok_utils::_ok_move_one_file_to_backup_dir {fPath destRootDir \
                                                  commonRootDirOrNone}  {
  set pathInBU [expr {($commonRootDirOrNone == "")?                          \
                [::ok_utils::_ok_rename_root_in_filepath_string $fPath] :    \
                [ok_strip_prefix_from_filepath $fPath $commonRootDirOrNone   \
                          ::ok_utils::_ok_rename_root_component_in_filepath]}
  ok_trace_msg "Going to move '$fPath' (as '$pathInBU') to under '$destRootDir'"
  set subdirRelPath [file dirname $pathInBU]
  set subdirAbsPath [file join $destRootDir $subdirRelPath]
  if { 0 == [ok_create_absdirs_in_list [list $subdirAbsPath]] }  {
    ok_err msg "Failed creating destination directory '$subdirAbsPath' for '$fPath'"
    return  0
  }
  set tclExecResult [catch { \
                        file rename -- $fPath $subdirAbsPath } evalExecResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "$evalExecResult!";    return  0
  }
  ok_trace_msg "Moved '$fPath' into '$subdirAbsPath'"
  return  1
}


#~ # On success returns empty string
#~ proc ::ok_utils::ok_move_listed_filesIntoTrashDir {preserveSrc pathList \
                                  #~ fileTypeDescr actionName trashDirVar} {
  #~ upvar $trashDirVar trashDir
  #~ if { 0 != [llength $pathList] } {
    #~ ok_trace_msg "::ok_utils::ok_move_listed_filesIntoTrashDir for '$actionName' called with trashDir='$trashDir'"
    #~ set trashDir [ProvideTrashDir $actionName $trashDir]
    #~ if { $trashDir == "" }  { return  "Cannot create backup directory" }
    #~ if { 0 > [::ok_utils::ok_move_listed_files $preserveSrc $pathList $trashDir] }  {
      #~ set msg "Failed to hide $fileTypeDescr file(s) in '$trashDir'"
      #~ ok_err_msg $msg;    return  $msg
    #~ }
    #~ ok_info_msg "[llength $pathList] $fileTypeDescr file(s) moved into '$trashDir'"
  #~ }
  #~ return  ""
#~ }


## proc ::ok_utils::ok_move_listed_files {preserveSrc pathList destDir} {
 #   return  [::ok_utils::ok_move_listed_files 1 $pathList $destDir]
 # }
 ##

# Moves/copies files in 'pathList' into 'destDir' - if 'preserveSrc' == 0/1.
# Destination directory 'destDir' should preexist.
# On success returns number of files moved;
# on error returns negative count of errors
proc ::ok_utils::ok_move_listed_files {preserveSrc pathList destDir} {
  set action [expr {($preserveSrc == 1)? "copy" : "rename"}]
  set descr [expr {($preserveSrc == 1)? "CopyListedFiles" : "::ok_utils::ok_move_listed_files"}]
  if { ![file exists $destDir] } {
    ok_err_msg "$descr: no directory $destDir"
    return  -1
  }
  if { ![file isdirectory $destDir] } {
    ok_err_msg "$descr: non-directory $destDir"
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

