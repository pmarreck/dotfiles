#!/usr/bin/env bash

needs ocrmypdf
needs exiftool
needs pdftotext

# Re-OCR a scanned PDF with ocrmypdf
# Usage: ocr-pdf <input.pdf> <output.pdf>
ocr-pdf() {
  # check for dependencies
  if ! command -v ocrmypdf &> /dev/null; then
    echo "Error: ocrmypdf command not found." >&2
    echo "Please install it at least ephemerally, e.g., via nix: nix-shell -p ocrmypdf" >&2
    return 1
  fi
  # print about and usage if first argument is -h or --help
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "About: (Re-)OCR a scanned bitmap PDF with ocrmypdf" >&2
    echo "Usage: ocr-pdf <input.pdf> [<output.pdf>]" >&2
    return 0
  fi
  # check for at least 1 argument and that it ends in .pdf
  if [[ "$#" -lt 1 || "${1##*.}" != "pdf" ]]; then
    echo "Usage: ocr-pdf <input.pdf> [<output.pdf>]" >&2
    return 1
  fi
  # if 2nd argument not provided, use same filename with (OCR) suffix
  local input_file="$1"
  local output_file="$2"
  if [[ -z "$2" ]]; then
    output_file="${input_file%.*}_(OCR).pdf"
  fi
  ocrmypdf --redo-ocr -l eng --optimize 3 "$input_file" "$output_file"
}

# Simple function to edit standard PDF metadata fields using exiftool.
# Usage: edit-pdf-metadata key="value" [key="value"...] pdf_file
# Example: edit-pdf-metadata title="The Title" author="The Author" subject="Stuff" mydoc.pdf
# Common keys: title, author, subject, keywords, creator, producer
# Note: ExifTool PDF tags are case-sensitive (Title, Author, Subject, etc.)
edit-pdf-metadata() {
  # --- Dependency Check ---
  if ! command -v exiftool &> /dev/null; then
    echo "Error: exiftool command not found." >&2
    echo "Please install it at least ephemerally, e.g., via nix: nix-shell -p exiftool" >&2
    return 1
  fi

  # --- Argument Parsing ---
  if [[ "$#" -lt 2 ]]; then
    echo "Usage: edit-pdf-metadata key=\"value\" [key=\"value\"...] pdf_file" >&2
    echo "Example: edit-pdf-metadata title=\"New Title\" author=\"Me\" mydoc.pdf" >&2
    return 1
  fi

  # Extract the PDF filename (last argument)
  local pdf_file="${!#}"

  # Check if the file exists
  if [[ ! -f "$pdf_file" ]]; then
    echo "Error: File not found: '$pdf_file'" >&2
    return 1
  fi

  # --- Build ExifTool Arguments ---
  local exif_args=()
  local i arg key value pdf_tag
  for (( i=1; i<$#; i++ )); do
      arg="${!i}"
      # Split key=value (handles values with = inside if quoted correctly)
      key="${arg%%=*}"
      value="${arg#*=}"

      # Basic removal of potential surrounding quotes for convenience
      # Exiftool is generally robust, but this helps if quotes weren't intended literally.
      shopt -s extglob # Enable extended globbing for trim
      value="${value##\"}" # Remove leading "
      value="${value%%\"}" # Remove trailing "
      value="${value##\'}" # Remove leading '
      value="${value%%\'}" # Remove trailing '
      shopt -u extglob # Disable extended globbing

      # Map common lowercase keys to standard PDF Info dictionary tags (case-sensitive)
      case "$key" in
        title)    pdf_tag="Title" ;;
        author)   pdf_tag="Author" ;;
        subject)  pdf_tag="Subject" ;;
        keywords) pdf_tag="Keywords" ;; # Often a string list, exiftool handles it
        creator)  pdf_tag="Creator" ;;
        producer) pdf_tag="Producer" ;;
        # Add more mappings if you frequently use other standard PDF tags
        *)
          # Assume the user knows the correct ExifTool PDF tag name
          # Warn if it doesn't look like a standard one.
          if [[ ! "$key" =~ ^[A-Z] ]]; then
             echo "Warning: Key '$key' doesn't follow typical PDF tag capitalization. Using as-is." >&2
          fi
          pdf_tag="$key"
          ;;
      esac

      # Add the tag assignment to exiftool arguments
      exif_args+=("-$pdf_tag=$value")
  done

  # --- Execute ExifTool ---
  # -overwrite_original prevents creating a backup file (e.g., filename.pdf_original)
  # Remove -overwrite_original if you WANT the backup.
  # Use "-PDF-InfoDict:All=" first to clear existing info if desired (optional)
  echo "Updating metadata for '$pdf_file'..."
  if exiftool -overwrite_original "${exif_args[@]}" "$pdf_file"; then
    echo "Successfully updated metadata."
    return 0
  else
    echo "Error: exiftool command failed." >&2
    return 1
  fi
}

# --- Example Usage (place this outside the function definition) ---
# Create a dummy PDF if you don't have one handy (requires Ghostscript)
# gs -sDEVICE=pdfwrite -o dummy.pdf -c "/Helvetica findfont 12 scalefont setfont 72 72 moveto (Dummy Page) show showpage"

# Call the function
# edit-pdf-metadata title="The Devil Drives: A Life of Sir Richard Burton" \
#                   author="Fawn M. Brodie" \
#                   subject="Biography of Sir Richard Burton" \
#                   keywords="Biography, Exploration, Victorian Era" \
#                   dummy.pdf

# Check the metadata afterwards
# exiftool dummy.pdf | grep -E 'Title|Author|Subject|Keywords'

# Extracts existing text (native or OCR layer) from specified pages or the entire PDF.
# API: extract-pdf-text [<page_spec>] <pdf_file>  OR  extract-pdf-text --help
extract-pdf-text() {
  # --- Usage Message ---
  _usage() {
    cat >&2 <<EOF
Usage: extract-pdf-text [<page|range>] <pdf_file>
       extract-pdf-text --help

Extracts text from specified pages, or the entire document if no page/range
is given, from a PDF file to standard output.

Arguments:
  page|range  (Optional) Specifies the pages:
                - A single positive page number (e.g., 5)
                - A page range N-M (e.g., 3-10), where N and M are
                  positive integers and N <= M.
              If omitted, text from all pages is extracted.
  pdf_file    Path to the input PDF file (must end in .pdf or .PDF).
  --help      Display this help message and exit.

Requires: pdftotext (from poppler-utils)

Examples:
  extract-pdf-text mydocument.pdf          # Extract text from all pages
  extract-pdf-text 5 mydocument.pdf         # Extract text from page 5
  extract-pdf-text 3-7 mydocument.pdf       # Extract text from pages 3-7
EOF
  }

  local pdf_file=""
  local page_spec=""
  local start_page="" # Initialize to empty
  local end_page=""   # Initialize to empty
  local pdftotext_opts=() # Array for pdftotext page options (-f/-l)

  # --- Argument Count & Help Option Check ---
  if [[ "$#" -eq 1 && "$1" == "--help" ]]; then
    _usage
    return 0
  fi

  # --- Handle Argument Scenarios ---
  if [[ "$#" -eq 1 ]]; then
    # Scenario 1: Only PDF file provided -> process all pages
    pdf_file="$1"
    # No page spec, start/end_page remain empty, pdftotext_opts remains empty
  elif [[ "$#" -eq 2 ]]; then
    # Scenario 2: Page spec and PDF file provided
    page_spec="$1"
    pdf_file="$2"

    # Parse Page Specification
    if [[ "$page_spec" =~ ^([1-9][0-9]*)$ ]]; then
        # Single page number
        start_page="${BASH_REMATCH[1]}"
        end_page="$start_page"
    elif [[ "$page_spec" =~ ^([1-9][0-9]*)-([1-9][0-9]*)$ ]]; then
        # Page range N-M
        start_page="${BASH_REMATCH[1]}"
        end_page="${BASH_REMATCH[2]}"
        # Check if end page is less than start page
        if (( end_page < start_page )); then
           echo "Error: End page ($end_page) cannot be less than start page ($start_page) in range '$page_spec'." >&2
           _usage
           return 1
        fi
    else
        # Invalid format
        echo "Error: Invalid page specification '$page_spec'." >&2
        echo "       Use a single number (e.g., 5) or a range (e.g., 3-10)." >&2
        _usage
        return 1
    fi
    # Add page range flags if spec was valid and parsed
    pdftotext_opts+=("-f" "$start_page" "-l" "$end_page")
  else
    # Incorrect number of arguments (0 or >2)
    echo "Error: Incorrect number of arguments." >&2
    _usage
    return 1
  fi

  # --- Dependency Check ---
  if ! command -v pdftotext &> /dev/null; then
    echo "Error: pdftotext command not found." >&2
    echo "Please install poppler-utils (e.g., nix-env -iA nixpkgs.poppler_utils)" >&2
    return 1
  fi

  # --- Validate PDF File Argument (applies to both scenarios) ---
  if [[ ! "$pdf_file" =~ \.[pP][dD][fF]$ ]]; then
      echo "Error: PDF filename ('$pdf_file') does not end with .pdf or .PDF." >&2
      _usage
      return 1
  fi
  if [[ ! -f "$pdf_file" ]]; then
      echo "Error: PDF file not found: '$pdf_file'" >&2
      return 1
  fi

  # --- Execute pdftotext ---
  # Pass options array (empty if processing all pages)
  # - : output to stdout
  echo "DEBUG: Running: pdftotext ${pdftotext_opts[@]} \"$pdf_file\" -" >&2 # Debugging line
  if ! pdftotext "${pdftotext_opts[@]}" "$pdf_file" -; then
      local exit_status=$?
      echo "Error: pdftotext exited with status $exit_status while processing '$pdf_file'." >&2
      if [[ -n "$start_page" ]]; then
           echo "       Attempted pages: $start_page-$end_page" >&2
      else
           echo "       Attempted all pages." >&2
      fi
      return $exit_status
  fi

  # Remove debug line before final use if desired
  # >&2 because stdout is reserved for the extracted text
  echo "DEBUG: pdftotext completed successfully." >&2

  return 0 # Success
}

# --- Unit Test Examples (commented out) ---
# (Keep the _create_dummy_pdf and _test functions from the previous version if desired)
# _test() {
#   echo "--- Testing v2 ---"
#   _create_dummy_pdf
#   echo "Test 1: All pages (1 arg)"
#   extract-pdf-text test_doc.pdf | grep -c "Page" | grep -q "3" && echo "OK" || echo "FAIL"
#   echo "Test 2: Single page (2)"
#   extract-pdf-text 2 test_doc.pdf | grep "Page 2." && echo "OK" || echo "FAIL"
#   echo "Test 3: Range (1-2)"
#   extract-pdf-text 1-2 test_doc.pdf | grep -c "Page" | grep -q "2" && echo "OK" || echo "FAIL"
#   echo "Test 4: Invalid range (3-1)"
#   extract-pdf-text 3-1 test_doc.pdf || echo "OK (Expected failure)"
#   echo "Test 5: Invalid page spec (abc)"
#   extract-pdf-text abc test_doc.pdf || echo "OK (Expected failure)"
#   echo "Test 6: Wrong arg count (0)"
#   extract-pdf-text || echo "OK (Expected failure)"
#   echo "Test 7: Wrong arg count (3)"
#   extract-pdf-text 1 2 test_doc.pdf || echo "OK (Expected failure)"
#   echo "Test 8: Help"
#   extract-pdf-text --help && echo "OK" || echo "FAIL"
#   echo "Test 9: File not found"
#   extract-pdf-text non_existent.pdf || echo "OK (Expected failure)"
#   rm -f test_doc.pdf
#   echo "--- Testing Done ---"
# }
# _test
