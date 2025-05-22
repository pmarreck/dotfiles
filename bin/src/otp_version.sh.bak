# add otp --version command
otp() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  needs erl
  case $1 in
    "--version")
      erl -eval '{ok, Version} = file:read_file(filename:join([code:root_dir(), "releases", erlang:system_info(otp_release), "OTP_VERSION"])), io:fwrite(Version), halt().' -noshell
      ;;
    *)
      echo "Usage: otp --version"
      echo "This function is defined in $BASH_SOURCE"
      ;;
  esac
}
