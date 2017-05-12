# cmd_line.tcl - command-line handler

# Copyright (C) 2007 by Oleg Kosyakovsky

namespace eval ::ok_utils:: {

    namespace export             \
	ok_new_cmd_line_descr    \
	ok_delete_cmd_line_descr \
	ok_set_cmd_line_params   \
	ok_read_cmd_line         \
	ok_help_on_cmd_line      \
	ok_cmd_line_str
}

global OK_TCLSRC_ROOT
if { [info exists OK_TCLSRC_ROOT] } {;   # assume running as a part of LazyConv
    source $OK_TCLSRC_ROOT/lzc_beta_license.tcl
    package provide ok_utils 1.1
} else {;
# 	set scriptDir [file dirname [info script]]
# 	puts "---- Sourcing '[info script]' in '$scriptDir' ----"
# 	source [file join $scriptDir "debug_utils.tcl"]
    # assume running standalone; define required proc-s instead of sourcing
if { "" == [info procs ::ok_utils::ok_err_msg] } {
    proc ::ok_utils::ok_err_msg {text} {	puts "* $text" }
}
if { "" == [info procs ok_utils::ok_list_to_array] } {
    # Inserts mapping-pairs from list 'srcList' into array 'dstArrName'.
    # Returns 1 on success, 0 on failure.
    proc ::ok_utils::ok_list_to_array {srcList dstArrName} {
	upvar $dstArrName dstArr
	set tclExecResult [catch {
	    array set dstArr $srcList } evalExecResult]
	if { $tclExecResult != 0 } {
	    ok_err_msg "$evalExecResult!"
	    return  0
	}
	return  1
    }
}
}


# Creates a description (spec) for the command line.
# Note, it's not the command line but the spec for it.
# Returns 1 on success, 0 on error.
# Example 1:
#  set descrList [list \
#               -help {"" "print help"} -year {val "current year"} \
#               -months {list "list of relevant months"}]
#  array unset cmlD;  set isOK [ok_new_cmd_line_descr cmlD $descrList]
#  Resulting array holds two-element list per each argument - {help, valKind}:
#    cmdLine(-help)   = {"print help"              , ""  }
#    cmdLine(-year)   = {"current year"            , val }
#    cmdLine(-months) = {"list of relevant months" , list}
# Example 2 (empty):
#  set dsL [list]; array unset cmlD; ok_new_cmd_line_descr cmlD $dsL
# Example 3:
#  set dsL {-a {"" Ahelp} -b {val Bhelp} -cd {list Chelp}}; array unset cmlD; ok_new_cmd_line_descr cmlD $dsL
proc ::ok_utils::ok_new_cmd_line_descr {cmlDescrArrName argDescrList} {
    upvar $cmlDescrArrName cmdL
    if { 0 == [ok_list_to_array $argDescrList cmdL] } {
	return  0
    }
    # parray cmdL
    # verify array structure: cmdL(-<argName>) = [list ""|val|list <help>]
    set argNames [array names cmdL]
    foreach argName $argNames {
	if { "-" != [string index $argName 0] } {
	    ok_err_msg "Command line description error at '$argName': missing leading -"
	    return  0
	}
	set vList $cmdL($argName)
	if { 2 != [llength $vList] } {
	    ok_err_msg "Command line description error at '$argName': spec should be {\"\"|val|list <help>}"
	    return  0
	}
	set valKind [lindex $vList 0]
	if { ($valKind !="") && ($valKind !="val") && ($valKind !="list") } {
	    ok_err_msg "Command line description error at '$argName': spec should be {\"\"|val|list <help>}"
	    return  0
	}
    }
    return  1
}

# TODO: looks like setting value for an undeclared parameter makes all _further_ settings invalid

# Adds and/or overrides parameter values in command line array 'cmlArrName'.
# Syntax should match description in 'cmlDescrArrName'
# 'paramsList' is a list of 2-element lists
# Returns 1 on success, 0 on error.
# Example 1:
#  set dsL {-help {"" "print help"} -year {val "current year"} -months {list "list of relevant months"}};  array unset cmlD;  array set cmlD $dsL;  array unset cml;  ok_set_cmd_line_params cml cmlD {{-year 1969} {-months {1 2}} {-help ""}}
# Example 2 (empty - no args to set - NO ARRAY CREATED!):
# set dsL {-a {"" Ahelp} -b {val Bhelp} -cd {list Chelp}}; array unset cmlD; array unset cml; array set cmlD $dsL;  ok_set_cmd_line_params cml cmlD [list]
# Example 3:
# set dsL {-a {"" Ahelp} -b {val Bhelp} -cd {list Chelp}}; array unset cmlD; array unset cml; array set cmlD $dsL;  ok_set_cmd_line_params cml cmlD {{-cd {d}}}
proc ::ok_utils::ok_set_cmd_line_params {cmlArrName cmlDescrArrName \
					     paramsList} {
    upvar $cmlArrName      cml
    upvar $cmlDescrArrName cmlDescr
    # copy values using spec; should be "-name <val>|list"
    foreach paramSet $paramsList {
	set paramName [lindex $paramSet 0]
	if { [llength $paramSet] == 2 } {;	    # parameter with value(s)
	    set paramVal [lindex $paramSet 1]
	} elseif { [llength $paramSet] == 1 } {;    # parameter without value
	    set paramVal ""
	} else {
	    ok_err_msg "Command line error at '$paramName': should be \"-name <val>|list\""
	    return  0
	}
	# puts ">>> paramName='$paramName';  paramVal='$paramVal'"
	if { "-" != [string index $paramName 0] } {
	    ok_err_msg "Command line error at '$paramName': missing leading -"
	    return  0
	}
	if { ![info exists cmlDescr($paramName)] } {
	    ok_err_msg "Command line error at '$paramName': unknown name"
	    return  0
	}
	set valSpec [lindex $cmlDescr($paramName) 0]
	# puts ">>> valSpec='$valSpec'"
	set valCnt [llength $paramVal]
	if { $valSpec == "val" } {
	    if { $valCnt != 1 } {
		ok_err_msg "Command line error at '$paramName': one value expected, got '$paramVal'"
		return  0
	    }
	    set cml($paramName) $paramVal
	} elseif { $valSpec == "list" } {
	    # force parameter value to be a list
	    if { $valCnt == 1 } {
		set cml($paramName) [list $paramVal]
	    } elseif { $valCnt > 1 } {
		set cml($paramName) $paramVal
	    } else {
		set cml($paramName) [list]
	    }
	} else {;	# assume the spec is ""
	    set cml($paramName) ""
	}
    }
    return  1
}

# Reads command line from 'cmdLineAsString' into array 'cmlArrName'
# structured according to the spec in array 'cmlDescrArrName'
# Returns 1 on success, 0 on error.
# Example:
#  set isOK [ok_read_cmd_line "-year 1969 -months 1 2 -help" cml cmlD]
proc ::ok_utils::ok_read_cmd_line {cmdLineAsString cmlArrName \
				       cmlDescrArrName} {
    upvar $cmlArrName      cml
    upvar $cmlDescrArrName cmlDescr
    # parse 'cmdLineAsString' into 'paramsList' for ok_set_cmd_line_params
    set paramsList [list]
    set prevKey "";    set valList [list]
    foreach token $cmdLineAsString {
	if { 1 == [_token_looks_like_switch $token] } {;   # done with prev. parameter
	    if { $prevKey != "" } {
		lappend paramsList [list $prevKey $valList]
	    }
	    set prevKey $token;    set valList [list]
	} else {;    # continuing with values for prev. parameter
	    #(wrong) lappend valList $token
      set valList [concat $valList $token]
	}
    }
    if { $prevKey != "" } {;	# save the last parameter
	lappend paramsList [list $prevKey $valList]
    }
    ok_trace_msg $paramsList
    set isOK [ok_set_cmd_line_params cml cmlDescr $paramsList]
    return $isOK
}


# Builds and returns a string with help on command line
# whose structure described by 'cmlDescrArrName'
# and defaults set in 'defaultCmlArrName' command-line array of same structure
proc ::ok_utils::ok_help_on_cmd_line {defaultCmlArrName cmlDescrArrName \
					  {separator "\n"}} {
    upvar $defaultCmlArrName defCml
    upvar $cmlDescrArrName   cmlD
    set helpParamList [list]
    foreach paramName [array names cmlD] {
	set defVal [expr {([info exists defCml($paramName)])? \
			                $defCml($paramName) : "<none>"}]
	lappend helpParamList [list $paramName $cmlD($paramName) \
				    "default:" $defVal]
    }
    return [format "%s%s" $separator [join $helpParamList $separator]]
}


# Builds and returns a string with command line from 'cmlArrName'
# whose structure described by 'cmlDescrArrName'
# Record per a parameter separated by 'separator'.
# If 'priHelp' == 1, adds help for each appearing parameter.
proc ::ok_utils::ok_cmd_line_str {cmlArrName cmlDescrArrName \
				      {separator " "} {priHelp 0}} {
    upvar $cmlArrName      cml
    upvar $cmlDescrArrName cmlD
    set cmdStr ""
    foreach paramName [array names cml] {
	if { $cmdStr != "" } {	    append cmdStr $separator	}
	append cmdStr $paramName
	if { [info exists cmlD($paramName)] } {
	    set paramSpec [lindex $cmlD($paramName) 0]
	    set paramHelp [lindex $cmlD($paramName) 1]
	} else {
	    set paramHelp "!INVALID_ARGUMENT!"
	}
	append cmdStr " " $cml($paramName)
	if { 1 == $priHelp } {
	    append cmdStr " <" $paramHelp ">"
	}
    }
    return  $cmdStr
}


proc ::ok_utils::_token_looks_like_switch {token} {
  return  [expr { ("-" == [string index $token 0]) && \
                  (2 <= [string length $token])    && \
                  (0 == [string is digit [string index $token 1]])}]
}


proc ::ok_utils::example_on_cmd_line {} {
    # create the command-line description
    set descrList [list \
		       -help {"" "print help"} -year {val "current year"} \
		       -months {list "list of relevant months"} \
		       -days {list "list of relevant days"} \
		       -loud {"" "print trace"}]
    array unset cmlD
    ok_new_cmd_line_descr cmlD $descrList
    puts "==== Below is the command-line description ====";    parray cmlD
    # create dummy command line with the default parameters
    array unset defCml
    ok_set_cmd_line_params defCml cmlD {{-year 1969} {-months {7}}}
    puts "==== Below is the default command line ====";    parray defCml
    # print a usual help where defaults are specified
    set cmdHelp [ok_help_on_cmd_line defCml cmlD "\n"]
    puts "==== Below is the command line help separated by <CR> ====\n$cmdHelp"
    # now parse a typical real-life command line
    array unset cml
    ok_read_cmd_line "-year 2007 -months 1 2 -loud" cml cmlD
    puts "==== Below is the ultimate command line ====";    parray cml
    # now build a string representation of the real-life command line
    set cmdStrNoHelp [ok_cmd_line_str cml cmlD " " 0]
    puts "==== Below is the ultimate command line as a string (no help) ===="
    puts "$cmdStrNoHelp"
    set cmdStrWithHelp [ok_cmd_line_str cml cmlD "\n" 1]
    puts "==== Below is the ultimate command line as a string with help ===="
    puts "$cmdStrWithHelp"
}

namespace import -force ::ok_utils::*
