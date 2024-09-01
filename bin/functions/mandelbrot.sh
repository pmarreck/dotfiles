# mandelbrot set
# from https://bruxy.regnet.cz/web/linux/EN/mandelbrot-set-in-bash/
# (fixed point version for speed. also because fuck floating point math)
mandelbrot() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  p=\>\>14 e=echo\ -ne\  S=(B A S H) I=-16384 t=/tmp/m$$; for x in {1..13}; do \
  R=-32768; for y in {1..80}; do B=0 r=0 s=0 j=0 i=0; while [ $((B++)) -lt 32 -a \
  $(($s*$j)) -le 1073741824 ];do s=$(($r*$r$p)) j=$(($i*$i$p)) t=$(($s-$j+$R));
  i=$(((($r*$i)$p-1)+$I)) r=$t;done;if [ $B -ge 32 ];then $e\ ;else #---::BruXy::-
  $e"\E[01;$(((B+3)%8+30))m${S[$((C++%4))]}"; fi;R=$((R+512));done;#----:::(c):::-
  $e "\E[m\E(\r\n";I=$((I+1311)); done|tee $t;head -n 12 $t| tac  #-----:2 O 1 O:-  
}
