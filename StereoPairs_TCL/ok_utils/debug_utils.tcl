# Copyright (C) 2005-2006 by Oleg Kosyakovsky

global OK_TCLSRC_ROOT
if { [info exists OK_TCLSRC_ROOT] } {;   # assume running as a part of LazyConv
    source $OK_TCLSRC_ROOT/lzc_beta_license.tcl
    package provide ok_utils 1.1
}

namespace eval ::ok_utils:: {

    namespace export \
	ok_arr_to_string \
	pri_arr \
	ok_pri_list_as_list \
	ok_info_msg \
	ok_trace_msg \
	ok_err_msg \
	ok_warn_msg \
	ok_assert \
	ok_set_loud \
	ok_loud_mode

    variable LOUD_MODE 0
}

proc ::ok_utils::ok_set_loud {toPriTraceMsgs} {
    variable LOUD_MODE
    set LOUD_MODE [expr ($toPriTraceMsgs == 0)? 0 : 1]
}
proc ::ok_utils::ok_loud_mode {} {
    variable LOUD_MODE
    return $LOUD_MODE
}

proc ::ok_utils::ok_arr_to_string {theArr} {
    upvar $theArr arrName
    set arrStr ""
    foreach {name value} [array get arrName] {
	append arrStr " $theArr\[\"$name\"\]=\"$value\""
    }
    return  $arrStr
}

proc ::ok_utils::pri_arr {theArr} {
    upvar $theArr arrName
    foreach {name value} [array get arrName] {
	puts "$theArr\[\"$name\"\] = \"$value\""
    }
}

proc ::ok_utils::ok_pri_list_as_list {theList} {
    set length [llength $theList]
    for {set i 0} {$i < $length} {incr i} {
	set elem [lindex $theList $i]
	puts -nonewline " ELEM\[$i\]='$elem'"
    }
    puts ""
}

###############################################################################
########## Messages/Errors/Warning ################################
proc ::ok_utils::ok_msg {text kind} {
    variable LOUD_MODE
    set pref ""
    switch [string toupper $kind] {
	"INFO" { set pref "-I-" }
	"TRACE" {
	    set pref [expr {($LOUD_MODE == 1)? "\# [msg_caller_name]:" : "\#"}]
	}
	"ERROR" {
	    set pref [expr {($LOUD_MODE == 1)? "-E- [msg_caller_name]:":"-E-"}]
	}
	"WARNING" {
	    set pref [expr {($LOUD_MODE == 1)? "-W- [msg_caller_name]:":"-W-"}]
	}
    }
    puts "$pref $text"
}

proc ::ok_utils::ok_info_msg {text} {
    ok_msg $text "INFO"
}
proc ::ok_utils::ok_trace_msg {text} {
    variable LOUD_MODE
    if { $LOUD_MODE == 1 } {
	ok_msg $text "TRACE"
    }
}
proc ::ok_utils::ok_err_msg {text} {
    ok_msg $text "ERROR"
}
proc ::ok_utils::ok_warn_msg {text} {
    ok_msg $text "WARNING"
}

proc ::ok_utils::msg_caller_name {} {
  #puts "level=[info level]"
  set callerLevel [expr { ([info level] > 3)? -3 : [expr -1*([info level]-1)] }]
    set callerAndArgs [info level $callerLevel]
    return  [lindex $callerAndArgs 0]
}
###############################################################################
########## Assertions ################################

proc ::ok_utils::ok_assert {condExpr {msgText ""}} {
#    ok_trace_msg "ok_assert '$condExpr'"
    if { ![uplevel expr $condExpr] } {
# 	set theMsg [expr ($msgText == "")? "condExpr" : $msgText]
 	set theMsg $msgText
 	ok_err_msg "Assertion failed: '$theMsg' at [info level -1]"
	for {set theLevel [info level]} {$theLevel >= 0} {incr theLevel -1} {
	     ok_err_msg "Stack $theLevel:\t[info level $theLevel]"
	}
	return -code error
    }
}
