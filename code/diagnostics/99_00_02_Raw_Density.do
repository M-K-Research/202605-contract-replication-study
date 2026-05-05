* ==============================================================================
* DIAGNOSTIC: THE RAW DHS DENSITY PLOT (Corrected Names)
* ==============================================================================
use "processed_data/densities.dta", clear

* 1. Check the recovered totals
display "Total bins with data: " _N
summarize n_all1_D0 n_all1_D1

* 2. Simple Histogram (Raw Counts)
* We use n_all1_D* which are the variables your loop just created
twoway (bar n_all1_D0 bin, color(blue%50)) ///
       (bar n_all1_D1 bin, color(red%50)), ///
       xline(0, lcolor(black) lpattern(dash)) ///
       title("DHS Contract Density around $25,000") ///
       subtitle("Blue = Unpublicized (D0), Red = Publicized (D1)") ///
       xtitle("Log Price Difference (0 = $25,000)") ///
       xlabel(-0.5 "-40%" 0 "$25k" 0.5 "+65%")
