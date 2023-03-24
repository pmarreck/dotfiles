fsattr() {
  needs attr "The 'attr' binary must be available to this OS for this function to work."
  local orig_attr name value file
  orig_attr=$(which attr);
  function _help() {
    echo "'fsattr' lets you list, get or set extended attributes (xattrs) on filesystem objects,"
    echo "assuming your filesystem supports this feature."
    echo "Filesystem objects can be files, directories, aliases, etc.;"
    echo "anything addressable via a pathname."
    echo "Note that this information may NOT be included with tools like 'tar', backups,"
    echo "sending files over the network, etc. etc."
    echo "The name length limit is 256 bytes and the value length limit is 64KB, at least on XFS."
    echo "Usage:"
    echo "fsattr [-h|--help] : this help"
    echo "fsattr <pathname> : list all extended attributes and values of object at <pathname> as name=value pairs."
    echo "fsattr <pathname> <name> : list the value of named extended attribute of <pathname>."
    echo "fsattr <pathname> <name> <value> : set the named extended attribute value of <pathname>."
    echo "fsattr <pathname> <name> \"\" : clear the named extended attribute value of <pathname>."
  }
  case $# in
    1) case $1 in
      --help|-h)
        _help
        return 0
        ;;
      *)
        file=$1
        $orig_attr -lq "$file" |\
        xargs -I {} sh -c 'echo $1=\"$('$orig_attr' -q -g $1 "'$file'")\"' - {}
        ;;
      esac
      ;;
    2) file=$1
      name=$2
      $orig_attr -qg "$name" "$file"
      ;;
    3) file=$1
      name=$2
      value=$3
      if [[ $value == "" ]]; then
      # remove value
      $orig_attr -r "$name" "$file"
      else
      $orig_attr -s "$name" -V "$value" -q "$file"
      fi
      ;;
    *) _help
      return 1
      ;;
  esac
}
source_relative_once bin/functions/assert.bash
# fsattr on the fly test suite
# this setup function takes a PID as an argument and uses it to create a file unique to the process
# ... Because prior to this I actually had fails here firing up multiple shells at the same time, facepalm.gif
_fsattr_test_setup() {
  touch /tmp/attr_test$1
  fsattr /tmp/attr_test$1 a 1
  fsattr /tmp/attr_test$1 b 2
}
assert "$(_fsattr_test_setup $! && fsattr /tmp/attr_test$! a)" == "1" "setting extended attributes on files should work"
assert "$(_fsattr_test_setup $! && fsattr /tmp/attr_test$! a 1 && fsattr /tmp/attr_test$! b 2 && fsattr /tmp/attr_test$!)" == "a=\"1\"\nb=\"2\"" "Listing extended attributes on files should work"
assert "$(fsattr /tmp/attr_test$! a "" && fsattr /tmp/attr_test$!)" == "b=\"2\"" "Deleting a named extended attribute by setting it to blank should work"
assert "$(fsattr /tmp/attr_test$! a 1 && fsattr /tmp/attr_test$! a "" && fsattr /tmp/attr_test$! a 1>/dev/null 2>/dev/null; echo $?)" != "0" "Accessing a deleted named extended attribute should fail"
[ -f /tmp/attr_test$! ] && rm /tmp/attr_test$!
unset -f _fsattr_test_setup
