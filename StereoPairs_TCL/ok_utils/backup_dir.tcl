# backup_dir.tcl
# Copyright (C) 2016 by Oleg Kosyakovsky
global OK_TCLSRC_ROOT
if { [info exists OK_TCLSRC_ROOT] } {;   # assume running as a part of LazyConv
    source $OK_TCLSRC_ROOT/lzc_beta_license.tcl
    package provide ok_utils 1.1
}


namespace eval ::ok_utils:: {

  namespace export \
    ok_provide_backup_dir
}



proc ::ok_utils::ok_provide_backup_dir {callerAction \
                            workRootDirPath buRootDirName \
                            lastBUDirPathRef {trashDirPath ""}}  {
  if { ($trashDirPath != "") && (1 == [file exists $trashDirPath]) }  {
    return  $trashDirPath
  }
  set trashRootDir [file join $workRootDirPath $buRootDirName]
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
    set idStr [format "%s__%s__%d" $timeStr $callerAction $i]
    set trashDirPath [file join $trashRootDir $idStr]
    if { 1 == [file exists $trashDirPath] }  {
      ok_trace_msg "Directory named '$trashDirPath' exists; cannot use it for backup"
      set trashDirPath "";  continue
    }
    set lastBUDirPathRef "" ;  # to avoid telling old path on failure
    set tclExecResult [catch { file mkdir $trashDirPath } evalExecResult]
    if { $tclExecResult != 0 } {
      ok_err_msg "Failed creating backup directory '$trashDirPath' (attempt $i): $evalExecResult!"
      return  ""
    }
    ok_info_msg "Created directory for trash/backup: '$trashDirPath'"
    set lastBUDirPathRef [file normalize $trashDirPath]
    break;  # created with path '$trashDirPath'
    set trashDirPath "";  # indicates failure to create dir so far
    after 1000;  # pause for 1 sec, so that next attempt picks different name
  }
  
  if { $trashDirPath == "" }  {
    ok_err_msg "Failed to create directory for trash/backup for '$callerAction'"
  }
  return  $trashDirPath
}

