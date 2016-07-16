# key_val_list.tcl

# Copyright (C) 2016 by Oleg Kosyakovsky
global OK_TCLSRC_ROOT
if { [info exists OK_TCLSRC_ROOT] } {;   # assume running as a part of LazyConv
    source $OK_TCLSRC_ROOT/lzc_beta_license.tcl
    package provide ok_utils 1.1
}


namespace eval ::ok_utils:: {

  namespace export                \
    ok_key_val_list_scan_strings  \
    ok_key_val_list_to_string     \
    ok_read_boolean

  # keywords telling boolean values
  variable BOOLEANS_DICT [dict create 1 1  0 0  no 0  NO 0  No 0  nO 0   n 0  \
                                        yes 1  YES 1  Yes 1  yES 1   y 1      \
                                        false 0  FALSE 0  False 0  fALSE 0    \
                                        true 1  TRUE 1  True 1  tRUE 1]

}


# Converts values from 'keyToStrVal' into ultimate representation.
# The conversion involves stripping spaces and format scan.
# 'keyToDescrAndFormat' is a dictionary of <key>::[list <descr> <scan-format>].
# example: {-left_img_subdir {"Subdirectory for left images" "%s"} -time_diff {"time difference in sec between R and L" "%d"}}
# 'keyToStrVal' is a dictionary of <key>::<value-as-string>].
# example: {-left_img_subdir "L" -time_diff " -3450 "}
# Returns the dictionary of <key>::<value>, or 0 on any error
### Example of invocation:
##   ok_key_val_list_scan_strings [dict create -a {"value of a" "%s"} -i {"value of i" "%d"}]  [dict create -a INIT_a -i " 888"] errStr 
proc ::ok_utils::ok_key_val_list_scan_strings {keyToDescrAndFormat keyToStrVal \
                                                              multiLineErrStr} {
  upvar $multiLineErrStr errStr
  set keyToVal [dict create]
  set errCnt 0;  set errStr ""
  dict for {key strVal} $keyToStrVal {
    if { 0 == [dict exists $keyToDescrAndFormat $key] } {
      ok_err_msg "Missing scan format for key '$key'"
      incr errCnt 1;  continue
    }
    set origFmt [lindex [dict get $keyToDescrAndFormat $key] 1]
    if { $origFmt == "%s" }  {
      set val [string trim $strVal];  # to allow spaces inside the string
      set cntMatched 1
    } else {
      set fmt [format {%s%%c} $origFmt]; # %c - to catch an unexpected leftover
      set cntMatched [scan [string trim $strVal] $fmt val leftover]
    }
    if { $cntMatched != 1 } {
      set msg "Invalid string-value '$strVal' for key '$key'; scan format '$origFmt'"
      append errStr  [expr {($errCnt > 0)? "\n" : ""}]  $msg
      ok_err_msg $msg;  incr errCnt 1;  continue
    }
    dict append keyToVal $key $val
  }
  set msg "Scanned string value(s) for [dict size $keyToStrVal] key(s); $errCnt error(s) occurred"
  if { $errCnt == 0 } {   ok_trace_msg $msg;  return $keyToVal
  } else              {   ok_err_msg $msg;    return 0  }
}


proc ::ok_utils::ok_key_val_list_to_string {keyToValDict keyOnlyArgList}  {
  if { $keyToValDict == 0 }  {  return  ""  }
  # extract key-only arg-s
  set keyOnlyArgsStr ""
  foreach keyOnlyArg $keyOnlyArgList   {
    if { ([dict exists $keyToValDict $keyOnlyArg]) }   {
      set boolAsStr [dict get $keyToValDict $keyOnlyArg]
      if { 1 == [ok_read_boolean $boolAsStr boolAsInt] } {
        dict unset keyToValDict $keyOnlyArg; #  prevent it appearing with value
        if { $boolAsInt == 1 }  { append keyOnlyArgsStr " $keyOnlyArg" }
      } else {
        ok_err_msg "Invalid boolean value '$boolAsStr' for key '$keyOnlyArg'"
      }
    }
  }
  set paramStr [join $keyToValDict " "]
  append paramStr $keyOnlyArgsStr
  return  $paramStr
}


proc ::ok_utils::ok_read_boolean {boolAsStr boolAsIntVar}  {
  variable BOOLEANS_DICT
  upvar $boolAsIntVar boolAsInt
  if { 0 == [info exists BOOLEANS_DICT] }  {
    ok_err_msg "Missing dictionary of boolean constants in 'BOOLEANS_DICT'"
    return  0;  # should not get there
  }
  if { 0 == [dict exists $BOOLEANS_DICT $boolAsStr] }  {
    return  0;  # indicates not found
  }
  set boolAsInt [dict get $BOOLEANS_DICT $boolAsStr]
  return  1;  # indicates found
}
