: test 200 0 do i depth . loop  ; 
variable lp_a 3 CELLS ALLOT
variable rp_a 3 CELLS ALLOT
variable sp_a 3 CELLS ALLOT
variable offset 
0 offset ! 
: lo-pass-fwd-1 lp_a offset @ CELLS + @ 2/ rp_a offset @ CELLS + @ 2/ + ;
: lo-pass-fwd-2 sp_a offset @ CEllS + @ - sp_a offset @ CELLS + ! ;
: lo-pass-inv-1 lp_a offset @ CELLS + @ 2/ rp_a offset @ CELLS + @ 2/ + ;
: lo-pass-inv-2 lp_a offset @ CELLS + @ 2/ rp_a offset @ CELLS + @ 2/ + sp_a offset @ CEllS + @ swap + ;
: lo-fwd lo-pass-fwd-2 lo-pass-fwd-1 ;
: lo-inv lo-pass-inv-2 lo-pass-inv-1 sp_a offset @ CELLS + ! ;

157 lp_a 0 CELLS + ! 
156 rp_a 0 CELLS + !
155 sp_a 0 CELLS + !

157 lp_a 1 CELLS + ! 
155 rp_a 1 CELLS + !
154 sp_a 1 CELLS + !

156 lp_a 2 CELLS + ! 
156 rp_a 2 CELLS + !
155 sp_a 2 CELLS + !

154 lp_a 3 CELLS + ! 
157 rp_a 3 CELLS + !
155 sp_a 3 CELLS + !

 