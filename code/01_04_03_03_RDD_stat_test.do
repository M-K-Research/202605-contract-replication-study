* ==============================================================================
* RDD STATISTICAL TESTS: LINEAR vs QUADRATIC
* Outcome: overruns_any | Window: +/- 0.3 Log Points
* ==============================================================================
cd "C:\Users\shark\OneDrive\Documents\George Mason\Spring 2026\Econometrics\Replication Project\Replication_Files"
use "processed_data/analysisCGW_DHS.dta", clear

* 1. PREP
capture gen logAmount_centered = ln(amount_initial) - ln(25000)
drop if missing(overruns_any) | missing(logAmount_centered)

* 2. THE LINEAR TEST (p=1) - Your "Significant" result
display "{hline}"
display "{bf:TEST 1: LOCAL LINEAR REGRESSION (p=1)}"
rdrobust overruns_any logAmount_centered if abs(logAmount_centered) <= 0.3, ///
    c(0) p(1) kernel(triangular) all

* 3. THE QUADRATIC TEST (p=2) - The "Overfitted" result
display "{hline}"
display "{bf:TEST 2: LOCAL QUADRATIC REGRESSION (p=2)}"
rdrobust overruns_any logAmount_centered if abs(logAmount_centered) <= 0.3, ///
    c(0) p(2) kernel(triangular) all
