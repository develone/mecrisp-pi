: test 200 0 do i depth . loop  ; 
variable lp 
variable rp 
variable sp 
155 sp ! 
156 rp ! 
157 lp !
: lo-pass-fwd-1 rp @ 2/  ;
: lo-pass-fwd-2 sp @ lp @ 2/  - sp ! ; 
lo-pass-fwd-2 lo-pass-fwd-1 