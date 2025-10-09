#!/usr/bin/env -S awk -f
BEGIN {
  s = "#!/usr/bin/env -S awk -f%cBEGIN {%c  s = %c%s%c%c  printf s, 10, 10, 34, s, 34, 10, 10, 10%c}%c"
  printf s, 10, 10, 34, s, 34, 10, 10, 10
}
