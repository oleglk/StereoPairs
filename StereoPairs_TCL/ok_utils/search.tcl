# from: http://stackoverflow.com/questions/8985032/searching-for-a-number-in-a-sorted-list-in-tcl

# Copyright (C) 2014-2016 by Oleg Kosyakovsky

namespace eval ::ok_utils:: {
    namespace export        \
      ok_bisect             \
      ok_bisect_find_range
}

# Assumes that lst is sorted in ascending order
proc ok_bisect { lst val } {

    ok_trace_msg "Looking for $val in \[[lindex $lst 0] ... [lindex $lst end]\]"

    set len [llength $lst]

    # Initial interval - the start to the middle of the list
    set start 0
    set end [expr $len - 1]
    set mid [expr $len / 2]
    set lastmid -1

    while { $mid != $lastmid } {
        if { [expr $val <= [lindex $lst $mid]] } {
            # val lies somewhere between the start and the mid
            set end $mid

        } else {
            # val lies somewhere between mid and end
            set start [expr $mid + 1]
        }

        set lastmid $mid
        set mid [expr ($start + $end ) / 2]
    }

    return $mid
}

# 'posBefore' and 'posAfter' are valid indices in 'lst';
# if 'val is out-of-range, both get first or last index appropriately
proc ok_bisect_find_range {lst val posBefore posAfter} {
  upvar $posBefore before
  upvar $posAfter after
  set before -1;  set after -1
  set last [expr [llength $lst] - 1]
  set exactOrNext [ok_bisect $lst $val]
  if       { $exactOrNext == 0 } {
    set before 0;  set after 0
  } elseif { $exactOrNext == $last } {
    set before $last;  set after $last
    if { [expr {$val < [lindex $lst $last]} && {$exactOrNext > 0}] } {
      set before [expr $exactOrNext - 1]
    }
  } elseif { $val == [lindex $lst $exactOrNext] } {
    set before $exactOrNext;  set after $exactOrNext
  } else {
    set before [expr $exactOrNext - 1];  set after $exactOrNext
  }
}


proc _Test_bisect {} {
set lst [lsort -real [list 1.2 3.4 5.4 7.9 2.3 1.1 0.9 22.7 4.3]]
puts $lst

set res [ok_bisect $lst 2.4]
puts "found [lindex $lst $res] at index $res"

set res [ok_bisect $lst -1]
puts "found [lindex $lst $res] at index $res"

set res [ok_bisect $lst 999]
puts "found [lindex $lst $res] at index $res"

set res [ok_bisect $lst 1.2]
puts "found [lindex $lst $res] at index $res"

set res [ok_bisect $lst 0.9]
puts "found [lindex $lst $res] at index $res"

set res [ok_bisect $lst 22.7]
puts "found [lindex $lst $res] at index $res"
}