# load_pkg.tcl - sources all files in PKG_DIR
if { ![info exists PKG_DIR] } {
    puts "**** Using current dir '[pwd]' as PKG_DIR"
    set PKG_DIR [pwd]
}
puts "{-------- Start processing TCL sources in $PKG_DIR --------"
#foreach f [glob $PKG_DIR/*.tcl] {
#	puts "Encountered file '$f'"
#}
foreach f [glob $PKG_DIR/*.tcl] {
    if { [string match {*.oklib.tcl} $f] || \
	 [string equal {pkgIndex.tcl} [file tail $f]] } { continue } 
    puts "---- Sourcing $f \t----"
    source $f
}
puts "}-------- Done  processing TCL sources in $PKG_DIR --------"

