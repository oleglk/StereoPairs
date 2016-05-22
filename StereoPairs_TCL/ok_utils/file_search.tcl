# file_search.tcl - recursive search for files
# copied from: http://stackoverflow.com/questions/429386/tcl-recursively-search-subdirectories-to-source-all-tcl-files

namespace eval ::ok_utils:: {

  namespace export \
    ok_find_files
}


# ok_find_files  - recursive search for files.
#   Handles cycles created by symbolic links
#   and in the process eliminates duplicate files due to symbolic links as well
# 'basedir' - the directory to start looking in
# 'pattern' - A pattern, as defined by the glob command, that the files must match
proc ::ok_utils::ok_find_files {directory pattern} {
  # Fix the directory name, this ensures the directory name is in the
  # native format for the platform and contains a final directory seperator
  set directory [string trimright [file join [file normalize $directory] { }]]

  # Starting with the passed in directory, do a breadth first search for
  # subdirectories. Avoid cycles by normalizing all file paths and checking
  # for duplicates at each level.

  set directories [list $directory]
  set parents $directory
  while {[llength $parents] > 0} {
    # Find all the children at the current level
    set children [list]
    foreach parent $parents {
      set children [concat $children \
                        [glob -nocomplain -type {d r} -path $parent *]]
    }
    # Normalize the children
    set length [llength $children]
    for {set i 0} {$i < $length} {incr i} {
      lset children $i [string trimright \
                        [file join [file normalize [lindex $children $i]] { }]]
    }
    # Make the list of children unique
    set children [lsort -unique $children]
    # Find the children that are not duplicates, use them for the next level
    set parents [list]
    foreach child $children {
      if {[lsearch -sorted $directories $child] == -1} {
          lappend parents $child
      }
    }
    # Append the next level directories to the complete list
    set directories [lsort -unique [concat $directories $parents]]
  }

  # Get all the files in the passed in directory and all its subdirectories
  set result [list]
  foreach directory $directories {
    set result [concat $result \
                  [glob -nocomplain -type {f r} -path $directory -- $pattern]]
  }
  # Normalize the filenames
  set length [llength $result]
  for {set i 0} {$i < $length} {incr i} {
    lset result $i [file normalize [lindex $result $i]]
  }
  # Return only unique filenames
  return [lsort -unique $result]
}
