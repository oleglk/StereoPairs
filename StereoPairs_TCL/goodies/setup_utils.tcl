# setup_utils.tcl
# Copyright:  Oleg Kosyakovsky

##############################################################################
namespace eval ::setup {
    namespace export \
	define_src_path \
	check_dirs_in_list
}
##############################################################################


# Tells TCL interpreter to look for converter code under 'tclSrcRoot'
# and for standard TCL extensons - under 'tclStdExtRoot'
proc ::setup::define_src_path {tclSrcRoot tclStdExtRoot} {
    global auto_path
    # guarantee that TCL interpreter finds the code
    if { -1 == [lsearch -exact $auto_path $tclSrcRoot] } {
	lappend auto_path $tclSrcRoot
    }
    # guarantee that TCL interpreter finds the required standard libs
    if { -1 == [lsearch -exact $auto_path $tclStdExtRoot] } {
	lappend auto_path $tclStdExtRoot
    }
}


# Checks directories in 'dirList' for existence. Exits if anyone absent.
proc ::setup::check_dirs_in_list {dirList} {
    foreach dir $dirList {
	if { [expr {$dir == ""} || ![file exists $dir] || \
		  ![file isdirectory $dir]] } {
	    puts "Invalid or inexistent directory name '$dir'"
	    return  -code error
	}
    }
}
