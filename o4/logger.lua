local l={}
function l:info(m)print("[INFO] "..m)end
function l:warn(m)print("[WARN] "..m)end
function l:error(m)error("[ERROR] "..m,2)end
return l

