# get nvidia driver version on linux
if [ "$PLATFORM" = "linux" ]; then
  nvidia() {
    [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
    needs nvidia-smi from nvidia-cuda-toolkit
    needs rg get ripgrep
    nv_version=$(nvidia-smi | rg -r '$1' -o --color never 'Driver Version: ([0-9]{3}\.[0-9]{1,3}(?:\.[0-9]{1,3})?)')
    case $1 in
      "--version")
        echo $nv_version
        ;;
      "")
        echo -ne "Driver: "
        echo $nv_version
        echo "Devices: "
        lspci | rg -r '$1' -o --color never 'VGA compatible controller: NVIDIA Corporation [^ ]+ (.+)$'
        ;;
      *)
        echo "Usage: nvidia [--version]"
        echo "The --version flag prints the driver version only."
        echo "This function is defined in ${BASH_SOURCE} ."
        ;;
    esac
  }
fi
