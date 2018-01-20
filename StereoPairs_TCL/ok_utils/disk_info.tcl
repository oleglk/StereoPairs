# disk_info.tcl

namespace eval ::ok_utils:: {

  namespace export                \
    ok_get_free_disk_space_kb     \
    ok_try_get_free_disk_space_kb \
    ok_get_filelist_disk_space_kb
}

# Copied from "proc df-k" at http://wiki.tcl.tk/526#pagetoc071ae01c
# Returns free disk space in kilobytes
proc ::ok_utils::ok_get_free_disk_space_kb {{dir .}} {
    switch $::tcl_platform(os) {
    FreeBSD -
    Linux -
    OSF1 -
    SunOS {
        # Use end-2 instead of 3 because long mountpoints can 
        # make the output to appear in two lines. There is df -k -P
        # to avoid this, but -P is Linux specific afaict
        return  [lindex [lindex [split [exec df -k $dir] \n] end] end-2]
    }
    HP-UX {return  [lindex [lindex [split [exec bdf   $dir] \n] end] 3]}
    {Windows NT} {
        set numPos 2;  # Oleg: was 0
        set lastLine [lindex [split [exec cmd /c dir /-c $dir] \n] end]
        return  [expr {round([lindex $lastLine $numPos] / 1024.0)}]
            # CL notes that, someday when we want a bit more
            #    sophistication in this region, we can try
            #    something like
            #       secpercluster,bytespersector, \
            #       freeclusters,noclusters = \
            #            win32api.GetDiskFreeSpace(drive)
            #    Then multiply long(freeclusters), secpercluster,
            #    and bytespersector to get a total number of
            #    effective free bytes for the drive.
            # CL further notes that
            #http://developer.apple.com/techpubs/mac/Files/Files-96.html
            #    explains use of PBHGetVInfo() to do something analogous
            #    for MacOS.
        }
    default {error "don't know how to measure free disk space on '$::tcl_platform(os)'"}
    }
} ;#RS


# If possible, returns free disk space on the disk of path '$dir'.
# On error returns -1
proc ::ok_utils::ok_try_get_free_disk_space_kb {{dir .}} {
  set tclExecResult [catch {set n [ok_get_free_disk_space_kb $dir]} execResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "$execResult!"
    ok_err_msg "Cannot check free space for '$dir'."
    return  -1
  }
  return $n
}


# Calculates and returns total disk space consumed by files in 'filePathsList'.
# On error returns -1 * <number-of-unreadable-files>
proc ::ok_utils::ok_get_filelist_disk_space_kb {filePathsList {priErr 1}}  {
  set size 0;    set noaccess [list]
  foreach filePath $filePathsList {
    if { [file exists $filePath] && [file readable $filePath] } {
      incr size [file size $filePath]
    } else {
      lappend noaccess $filePath
    }
  }
  if { 0 != [llength $noaccess] }  {
    if { $priErr }  {
      ok_err_msg "Measuring used disk space encountered [llength $noaccess] inexistent and/or unreadable file(s)"
    }
    return  [expr -1 * [llength $noaccess]]
  }
  return  [expr {round($size / 1024.0)}]
}
