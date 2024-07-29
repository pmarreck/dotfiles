# Mostly duplicate the functionality of `ls -l` but using only stat and awk
# Just for funsies.
ls-l() {
  stat --format="%b %B" * | gawk '{s+=$1} END {print "total " (s / (1024 / $2))}' && stat --printf "%11A %4h %-10U %-8G %10s %y %N\n" * | gawk 'NR>1 {print $0 | "sort -k6,6 -k7,7"}'
}
