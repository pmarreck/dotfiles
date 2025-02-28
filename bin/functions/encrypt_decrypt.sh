#!/usr/bin/env bash

# Encryption functions. Requires the GNUpg "gpg" commandline tool. On OS X, "brew install gnupg"
# Explanation of options here:
# --symmetric - Don't public-key encrypt, just symmetrically encrypt in-place with a passphrase.
# -z 9 - Compression level
# --require-secmem - Require use of secured memory for operations. Bails otherwise.
# cipher-algo, s2k-cipher-algo - The algorithm used for the secret key
# digest-algo - The algorithm used to mangle the secret key
# s2k-mode 3 - Enables multiple rounds of mangling to thwart brute-force attacks
# s2k-count 65000000 - Mangles the passphrase this number of times. Takes over a second on modern hardware.
# compress-algo BZIP2- Uses a high quality compression algorithm before encryption. BZIP2 is good but not compatible with PGP proper, FYI.

# Test function for encrypt/decrypt
_test_encrypt_decrypt() {
  local test_string="This is a test string with special chars: !@#$%^&*()_+"
  local test_password="testpassword123"
  local temp_file
  temp_file=$(mktemp)
  
  echo -e "\n${ANSI}${TXTYLW}Running encryption/decryption test...${ANSI}${TXTRST}"
  
  # Test string encryption/decryption
  echo -e "${ANSI}${TXTYLW}Test 1: String encryption/decryption${ANSI}${TXTRST}"
  local encrypted
  local decrypted
  
  encrypted=$(echo -n "$test_string" | encrypt -i - -o - -p "$test_password" 2>/dev/null)
  if [[ $? -ne 0 ]]; then
    echo -e "${ANSI}${TXTRED}✗ Encryption failed${ANSI}${TXTRST}"
    rm -f "$temp_file"
    return 1
  fi
  
  decrypted=$(echo -n "$encrypted" | decrypt -i - -o - -p "$test_password" 2>/dev/null)
  if [[ $? -ne 0 ]]; then
    echo -e "${ANSI}${TXTRED}✗ Decryption failed${ANSI}${TXTRST}"
    rm -f "$temp_file"
    return 1
  fi
  
  if [[ "$decrypted" == "$test_string" ]]; then
    echo -e "${ANSI}${TXTGRN}✓ String encryption/decryption test passed${ANSI}${TXTRST}"
  else
    echo -e "${ANSI}${TXTRED}✗ String encryption/decryption test failed${ANSI}${TXTRST}"
    echo "Expected: $test_string"
    echo "Got: $decrypted"
    rm -f "$temp_file"
    return 1
  fi
  
  # Test file encryption/decryption
  echo -e "${ANSI}${TXTYLW}Test 2: File encryption/decryption${ANSI}${TXTRST}"
  echo -n "$test_string" > "$temp_file"
  
  encrypt -i "$temp_file" -o "$temp_file.gpg" -p "$test_password" >/dev/null 2>&1
  if [[ $? -ne 0 ]]; then
    echo -e "${ANSI}${TXTRED}✗ File encryption failed${ANSI}${TXTRST}"
    rm -f "$temp_file" "$temp_file.gpg"
    return 1
  fi
  
  decrypted=$(decrypt -i "$temp_file.gpg" -o - -p "$test_password" 2>/dev/null)
  if [[ $? -ne 0 ]]; then
    echo -e "${ANSI}${TXTRED}✗ File decryption failed${ANSI}${TXTRST}"
    rm -f "$temp_file" "$temp_file.gpg"
    return 1
  fi
  
  if [[ "$decrypted" == "$test_string" ]]; then
    echo -e "${ANSI}${TXTGRN}✓ File encryption/decryption test passed${ANSI}${TXTRST}"
  else
    echo -e "${ANSI}${TXTRED}✗ File encryption/decryption test failed${ANSI}${TXTRST}"
    echo "Expected: $test_string"
    echo "Got: $decrypted"
    rm -f "$temp_file" "$temp_file.gpg"
    return 1
  fi
  
  # Cleanup
  rm -f "$temp_file" "$temp_file.gpg"
  echo -e "${ANSI}${TXTGRN}All tests passed successfully!${ANSI}${TXTRST}"
  return 0
}

encrypt() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  needs gpg
  
  # Check for test mode
  if [[ "$1" == "--test" ]]; then
    _test_encrypt_decrypt
    return $?
  fi
  
  # Default values
  local input_file=""
  local output_file=""
  local input_string=""
  local password=""
  local gpg_args=()
  local use_stdin=false
  local use_stdout=false
  local use_string=false
  local use_password=false
  
  # Show help if no arguments
  if [[ $# -eq 0 ]]; then
    encrypt --help
    return
  fi
  
  # Parse arguments using case and shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        echo 'Usage: encrypt [-i input|-] [-o output|-] [-- <additional gpg options>]'
        echo '       encrypt -s "string" [-o output|-] [-- <additional gpg options>]'
        echo '       encrypt --test'
        echo "This function is defined in ${BASH_SOURCE[0]}"
        echo 'Options:'
        echo '  -i, --input <file>   Input file to encrypt (use - for stdin)'
        echo '  -s, --string <text>  Text string to encrypt'
        echo '  -o, --output <file>  Output file for encrypted data (use - for stdout)'
        echo '  -p, --password <pw>  Use this password (INSECURE: visible in history!)'
        echo '  --test               Run self-test and exit'
        echo '  --                   All options after this are passed directly to gpg'
        echo 'Examples:'
        echo '  encrypt -i secret.txt                      # Encrypts to secret.txt.gpg'
        echo '  encrypt -i secret.txt -o custom.gpg        # Encrypts to custom output path'
        echo '  encrypt -s "secret text" -o secret.gpg     # Encrypt string to file'
        echo '  echo "secret" | encrypt -i - -o secret.gpg # Encrypt stdin to file'
        echo '  encrypt -i secret.txt -o -                 # Encrypt to stdout'
        echo '  encrypt -i secret.txt -- --armor           # Outputs ASCII-armored encryption'
        echo '  encrypt -i secret.txt -p "pass" -o out.gpg # Use password from command line'
        echo '  encrypt --test                             # Run self-test'
        return
        ;;
      -i|--input)
        if [[ $# -lt 2 ]]; then
          echo "Error: -i/--input option requires a file or -" >&2
          return 1
        fi
        input_file="$2"
        if [[ "$input_file" == "-" ]]; then
          use_stdin=true
          input_file=""
        fi
        shift 2
        ;;
      -s|--string)
        if [[ $# -lt 2 ]]; then
          echo "Error: -s/--string option requires a text string" >&2
          return 1
        fi
        input_string="$2"
        use_string=true
        shift 2
        ;;
      -o|--output)
        if [[ $# -lt 2 ]]; then
          echo "Error: -o/--output option requires a file or -" >&2
          return 1
        fi
        output_file="$2"
        if [[ "$output_file" == "-" ]]; then
          use_stdout=true
          output_file=""
        fi
        shift 2
        ;;
      -p|--password)
        if [[ $# -lt 2 ]]; then
          echo "Error: -p/--password option requires a password" >&2
          return 1
        fi
        password="$2"
        use_password=true
        shift 2
        ;;
      --)
        shift
        # All remaining args are for gpg
        gpg_args+=("$@")
        break
        ;;
      *)
        # If no explicit -i was given, treat first non-option as input file
        if [[ -z "$input_file" && ! "$1" =~ ^- ]]; then
          input_file="$1"
        else
          # Otherwise, pass to gpg
          gpg_args+=("$1")
        fi
        shift
        ;;
    esac
  done
  
  # Construct the base command
  local cmd=(gpg --symmetric -z 9 --require-secmem --cipher-algo AES256 --s2k-cipher-algo AES256 --s2k-digest-algo SHA512 --s2k-mode 3 --s2k-count 65000000 --compress-algo BZIP2)
  
  # Add password if specified
  if [[ "$use_password" == true ]]; then
    cmd+=(--batch --passphrase "$password")
  fi
  
  # Add output file if specified
  if [[ -n "$output_file" ]]; then
    cmd+=("-o" "$output_file")
  fi
  
  # Add any passthrough arguments
  if [[ ${#gpg_args[@]} -gt 0 ]]; then
    cmd+=("${gpg_args[@]}")
  fi
  
  # Add input file if specified and not using stdin or string
  if [[ -n "$input_file" && "$use_stdin" == false && "$use_string" == false ]]; then
    cmd+=("$input_file")
  fi
  
  # Echo the command to stderr (hide password)
  local cmd_display=("${cmd[@]}")
  if [[ "$use_password" == true ]]; then
    # Replace password with ****** in display
    for i in "${!cmd_display[@]}"; do
      if [[ "${cmd_display[$i]}" == "--passphrase" ]]; then
        cmd_display[$((i+1))]="******"
      fi
    done
  fi
  >&2 echo -e "${ANSI}${TXTYLW}${cmd_display[*]}${ANSI}${TXTRST}"
  
  # Execute the command
  if [[ "$use_string" == true ]]; then
    # Use provided string
    echo -n "$input_string" | "${cmd[@]}"
  elif [[ "$use_stdin" == true ]]; then
    # Read from stdin
    "${cmd[@]}"
  else
    # Standard execution
    "${cmd[@]}"
  fi
}
export -f encrypt

# note: will decrypt to STDOUT by default, for security reasons.
decrypt() {
  [ -n "${EDIT}" ] && unset EDIT && edit_function "${FUNCNAME[0]}" "$BASH_SOURCE" && return
  needs gpg
  
  # Check for test mode
  if [[ "$1" == "--test" ]]; then
    _test_encrypt_decrypt
    return $?
  fi
  
  # Default values
  local input_file=""
  local output_file=""
  local password=""
  local gpg_args=()
  local use_stdin=false
  local use_stdout=false
  local use_password=false
  
  # Show help if no arguments
  if [[ $# -eq 0 ]]; then
    decrypt --help
    return
  fi
  
  # Parse arguments using case and shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        echo 'Usage: decrypt [-i input|-] [-o output|-] [-- <additional gpg options>]'
        echo '       decrypt --test'
        echo "This function is defined in ${BASH_SOURCE[0]}"
        echo 'Options:'
        echo '  -i, --input <file>   Input file to decrypt (use - for stdin)'
        echo '  -o, --output <file>  Output file for decrypted data (use - for stdout, default)'
        echo '  -p, --password <pw>  Use this password (INSECURE: visible in history!)'
        echo '  --test               Run self-test and exit'
        echo '  --                   All options after this are passed directly to gpg'
        echo 'Will ask for password and *output cleartext to stdout* by default for security reasons'
        echo 'Examples:'
        echo '  decrypt -i secret.txt.gpg                  # Decrypt to stdout'
        echo '  decrypt -i secret.txt.gpg -o secret.txt    # Decrypt to file'
        echo '  decrypt -i secret.txt.gpg -o -             # Decrypt to stdout (explicit)'
        echo '  decrypt -i - -o secret.txt                 # Decrypt from stdin to file'
        echo '  decrypt -i secret.txt.gpg -- --quiet       # Suppress gpg status messages'
        echo '  decrypt -i secret.gpg -p "pass" -o out.txt # Use password from command line'
        echo '  decrypt --test                             # Run self-test'
        return
        ;;
      -i|--input)
        if [[ $# -lt 2 ]]; then
          echo "Error: -i/--input option requires a file or -" >&2
          return 1
        fi
        input_file="$2"
        if [[ "$input_file" == "-" ]]; then
          use_stdin=true
          input_file=""
        fi
        shift 2
        ;;
      -o|--output)
        if [[ $# -lt 2 ]]; then
          echo "Error: -o/--output option requires a file or -" >&2
          return 1
        fi
        output_file="$2"
        if [[ "$output_file" == "-" ]]; then
          use_stdout=true
          output_file=""
        fi
        shift 2
        ;;
      -p|--password)
        if [[ $# -lt 2 ]]; then
          echo "Error: -p/--password option requires a password" >&2
          return 1
        fi
        password="$2"
        use_password=true
        shift 2
        ;;
      --)
        shift
        # All remaining args are for gpg
        gpg_args+=("$@")
        break
        ;;
      *)
        # If no explicit -i was given, treat first non-option as input file
        if [[ -z "$input_file" && ! "$1" =~ ^- ]]; then
          input_file="$1"
        else
          # Otherwise, pass to gpg
          gpg_args+=("$1")
        fi
        shift
        ;;
    esac
  done
  
  # Construct the base command
  local cmd=(gpg)
  
  # Add password if specified
  if [[ "$use_password" == true ]]; then
    cmd+=(--batch --passphrase "$password")
  fi
  
  # Set decrypt mode if using stdout (default) or explicitly specified
  if [[ "$use_stdout" == true || -z "$output_file" ]]; then
    cmd+=("-d")
  fi
  
  # Add output file if specified and not using stdout
  if [[ -n "$output_file" ]]; then
    cmd+=("-o" "$output_file")
  fi
  
  # Add input file if specified and not using stdin
  if [[ -n "$input_file" && "$use_stdin" == false ]]; then
    cmd+=("$input_file")
  fi
  
  # Add any passthrough arguments
  if [[ ${#gpg_args[@]} -gt 0 ]]; then
    cmd+=("${gpg_args[@]}")
  fi
  
  # Echo the command to stderr (hide password)
  local cmd_display=("${cmd[@]}")
  if [[ "$use_password" == true ]]; then
    # Replace password with ****** in display
    for i in "${!cmd_display[@]}"; do
      if [[ "${cmd_display[$i]}" == "--passphrase" ]]; then
        cmd_display[$((i+1))]="******"
      fi
    done
  fi
  >&2 echo -e "${ANSI}${TXTYLW}${cmd_display[*]}${ANSI}${TXTRST}"
  
  # Execute the command
  "${cmd[@]}"
}
export -f decrypt
