#!/usr/bin/env bash

list_all_executables_on_PATH() {
  echo $PATH | tr : '\n' | xargs -I {} find {} -maxdepth 1 -executable | xargs basename -a | sort | uniq
}
