* 1. SET ENVIRONMENT
cd "C:/Users/shark/OneDrive/Documents/George Mason/Spring 2026/Econometrics/Replication Project/Replication_Files"

* 2. LOAD CUSTOM PROGRAMS (Crucial: this defines priceFx)
do "code/01_02_01_density_analysis_programs.do"

* 3. RELOAD THE BASE DATA
use "processed_data/analysisCGW_DHS.dta", clear

* 4. NOW RUN THE BOOTSTRAP (The "Clean Slate" version from our last step)
* [Paste the 'Balanced Range' code block here]
