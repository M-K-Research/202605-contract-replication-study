use "processed_data/analysisCGW_DHS.dta", clear
summarize amount_expected
list amount_expected logAmount bin in 1/10
