Change to String Variable


gen tract_code_std = "" 

replace tract_code_std = "000" + tract_code if strlen(tract_code) == 3 

replace tract_code_std = "00" + tract_code if strlen(tract_code) == 4 

replace tract_code_std = "0" + tract_code if strlen(tract_code) == 5 

replace tract_code_std = tract_code if strlen(tract_code) == 6 

label variable tract_code_std "Standardized 6-digit tract code" 

order year area_name tract_code_std tract_code 

destring tract_code_std, gen(tract_num) 
