* 1. Check if the data is actually loaded and scaled correctly
tab bin if inrange(bin, -900, 450)
summarize n_all1_D0 n_all1_D1

* 2. The Naked Test (No capture, no quietly)
* This WILL show an error message. Tell me what that message says!
local p         = 5     
local binWidth  = 10    
local minB      = -900  
local maxB      = 450   
local lB1       = -100  
local uB1       = 150   
local lB0       = -100  
local uB0       = 150   
local binFactor = 1000

cfDensities, bin(bin) n_observed_D0(n_all1_D0) n_observed_D1(n_all1_D1) ///
             p(`p') binWidth(`binWidth') minB(`minB') maxB(`maxB') ///
             lB0(`lB0') uB0(`uB0') lB1(`lB1') uB1(`uB1') binFactor(`binFactor') ///
             gammaMean(-0.156) cfDensity(debug_tilde) ///
             deltaMin(0) deltaStep(2) deltaMax(1000)
