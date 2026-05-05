use "processed_data/analysisCGW_DHS.dta", clear

* 1. CHECK THE UNITS (Are we in dollars or thousands?)
summarize amount_total amount_expected
display "If Mean is ~25000, it's Dollars. If it's ~25, it's Thousands."

* 2. CHECK THE DATA LEAK (Where are the 63,000 contracts going?)
display "Total starts at:"
count
display "Missing Publicity (pub):"
count if missing(pub)
display "Missing Service Flag:"
count if missing(service)
display "Missing Bin (Price):"
count if missing(amount_expected) | amount_expected == 0

* 3. CHECK THE RANGE
display "Contracts outside your $10k-$40k filter (for Expected Amount):"
count if (amount_expected*1000 < 10000 | amount_expected*1000 > 40000) & amount_expected < 500
count if (amount_expected < 10000 | amount_expected > 40000) & amount_expected > 500
