# disk_info.tcl

namespace eval ::ok_utils:: {

  namespace export                \
    ok_df_k                 
}

# Copied from "proc df-k" at http://wiki.tcl.tk/526#pagetoc071ae01c
# Returns free disk space in kilobytes
proc ::ok_utils::ok_df_k {{dir .}} {
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
        return  [expr {[lindex $lastLine $numPos] / 1024}]
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
    default {error "don't know how to df-k on $::tcl_platform(os)"}
    }
} ;#RS
