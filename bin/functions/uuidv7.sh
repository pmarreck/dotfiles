#!/bin/sh

# Initialize sequence init and sequence counter
_uuidv7_sequence_init() {
  od -An -N2 -i /dev/urandom | awk '{printf "%d", $1 % 32768}'
}
_uuidv7_sequence_counter=$(_uuidv7_sequence_init)
# Initialize _uuidv7_last_time_ms and _uuidv7_current_time_ms variables
_uuidv7_last_time_ms=$(date +%s%3N)
_uuidv7_current_time_ms=_uuidv7_last_time_ms
_uuidv7_sequencer() {
  # Get current timestamp in milliseconds
  _uuidv7_current_time_ms=$(date +%s%3N)
  # Check if timestamp has changed and reset sequence counter if it has
  if [ "$_uuidv7_current_time_ms" != "$_uuidv7_last_time_ms" ]; then
    _uuidv7_sequence_counter=$(_uuidv7_sequence_init) # Reset and randomize within first half of the sequence space
  else
    _uuidv7_sequence_counter=$((_uuidv7_sequence_counter + 1))
    if [ $_uuidv7_sequence_counter -gt 0xFFFF ]; then
        _uuidv7_sequence_counter=0
    fi
  fi
  _uuidv7_last_time_ms=$current_time_ms
  echo $_uuidv7_sequence_counter
}

uuidv7() {
    # random bytes
    rand_bytes=$(dd if=/dev/urandom bs=1 count=16 2>/dev/null | od -An -tx1 | tr -d ' \n')

    # current timestamp in ms
    timestamp=$(date +%s%3N)
    t_hex=$(printf "%012x" "$timestamp")

    # timestamp
    value_0=${t_hex:0:2}
    value_1=${t_hex:2:2}
    value_2=${t_hex:4:2}
    value_3=${t_hex:6:2}
    value_4=${t_hex:8:2}
    value_5=${t_hex:10:2}

    _uuidv7_sequence_counter=$(_uuidv7_sequencer)

    # version / sequence bits
    value_6=$(printf "%02x" $((0x70 | ((sequence_counter >> 12) & 0x0F)))) # Version 7 in the high 4 bits
    value_7=$(printf "%02x" $((sequence_counter >> 4 & 0xFF))) # Next 8 bits of sequence counter

    # variant and sequence bits
    value_8=$(printf "%02x" $((0x80 | ((sequence_counter & 0x0F))))) # Variant 10xx and last 4 bits of sequence counter

    # rand_b
    value_9=${rand_bytes:18:2}
    value_10=${rand_bytes:20:2}
    value_11=${rand_bytes:22:2}
    value_12=${rand_bytes:24:2}
    value_13=${rand_bytes:26:2}
    value_14=${rand_bytes:28:2}
    value_15=${rand_bytes:30:2}

    case "$1" in
      --hyphen|--hyphens|-h)
        echo "$value_0$value_1$value_2$value_3-$value_4$value_5-$value_6$value_7-$value_8$value_9-$value_10$value_11$value_12$value_13$value_14$value_15"
        ;;
      *)
        echo "$value_0$value_1$value_2$value_3$value_4$value_5$value_6$value_7$value_8$value_9$value_10$value_11$value_12$value_13$value_14$value_15"
        ;;
    esac
}
