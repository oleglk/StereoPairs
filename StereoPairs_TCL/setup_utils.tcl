# setup_utils.tcl
# Copyright:  Oleg Kosyakovsky

##############################################################################
namespace eval ::setup {
    namespace export \
	define_src_path \
	check_dirs_in_list \
	configure_converter
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


# Configures converter to use converter TCL code under 'tclSrcRoot';
# standard TCL extensions are looked for under 'tclStdExtRoot';
# conversion command definitions are taken from 'cmdDefFile';
# viewer     command definitions are taken from 'viewDefFile'.
proc ::setup::configure_converter {tclSrcRoot tclStdExtRoot convWorkDir\
				       cmdDefFile viewDefFile} {
    if { [expr {$cmdDefFile == ""} || {$viewDefFile == ""}] } {
	puts "Conversion- or viewer command definition file is not specified"
	return  -code error
    }
    set dirList [list $tclSrcRoot $tclStdExtRoot $convWorkDir]
    setup::check_dirs_in_list $dirList

    set OK_CONV_WORK_DIR $convWorkDir; # root dir for converter internal use

    # guarantee that TCL interpreter finds the code and required standard libs
    define_src_path $tclSrcRoot $tclStdExtRoot

    # work-area root directory is current
    set waDir [pwd]

    # cd $tclSrcRoot

    # import all the commands
    package require rawconvert
    package require camera_data

    package require execution
    package require filesorter
    package require imageproc
    package require corr_def
    package require cnv_config
    package require ok_utils

    # source $tclSrcRoot/rawconvert/commands.tcl

    # if { ![::xx::init $cmdDefFile $viewDefFile EXEC "" "" [file join $waDir ""]] } {	return  -code error }
    if { ![::xx::init $cmdDefFile $viewDefFile EXEC "" "" stdout] } {
	return  -code error
    }
}
