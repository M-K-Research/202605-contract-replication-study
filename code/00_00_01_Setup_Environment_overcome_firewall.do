* ==============================================================================
* SETUP: INSTALL REQUIRED PACKAGES (PLAN B - SSC MIRROR)
* Use this if the GitHub 'net install' gives a certificate error (r5100).
* ==============================================================================

* 1. Essential Libraries (Adding 'replace' to fix the r602 error)
ssc install moremata, replace
ssc install ranktest, replace
ssc install texdoc, replace
ssc install geodist, replace
ssc install gtools, replace
ssc install distinct, replace
ssc install rdrobust, replace
ssc install estout, replace
ssc install gsample, replace
ssc install egenmore, replace
ssc install winsor2, replace

* 2. High-Performance Regressions (Switching from GitHub to SSC)
* These versions are usually stable enough for AER replications.
ssc install ftools, replace
ssc install reghdfe, replace
ssc install ivreg2, replace
ssc install ivreghdfe, replace

display "ENVIRONMENT READY: All packages installed via SSC."
