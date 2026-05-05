* 1. Nuke any remnants of the "too new" version
capture ado uninstall rdrobust
capture ado uninstall st0366_1

* 2. Install the 2017 Legacy Version via HTTP (Bypasses the certificate error)
net install st0366_1, from("http://www.stata-journal.com/software/sj17-2/") replace

* 3. Re-index the math libraries
mata: mata mlib index
discard

rdrobust overruns_rel logAmount_centered, c(0)
