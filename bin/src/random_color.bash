#!/usr/bin/env bash

# 4-bit ANSI colors (16 colors)
echo_rand_4bit_color() {
    local c=($(seq 30 37) $(seq 90 97))
    echo -e "\e[${c[$((RANDOM % 16))]}m$*\e[0m"
}

# 8-bit colors (256 colors)
echo_rand_8bit_color() {
    echo -e "\e[38;5;$((RANDOM % 256))m$*\e[0m"
}

# 24-bit true color (16.7M colors)
echo_rand_24bit_color() {
    echo -e "\e[38;2;$((RANDOM % 256));$((RANDOM % 256));$((RANDOM % 256))m$*\e[0m"
}

# Test terminal color support
max_bits_color_support() {
    if [[ "$COLORTERM" =~ ^(truecolor|24bit)$ ]]; then
        echo 24
    elif [[ "$TERM" =~ ^(.*-256color|.*-direct)$ ]] || [[ "${COLORTERM}" == "direct" ]]; then
        echo 8
    else
        echo 4
    fi
}

# Set the default based on terminal capabilities
alias echo_rand_color="echo_rand_$(max_bits_color_support)bit_color"

# Demo function
demo_colors() {
    echo "4-bit color demo:"
    for i in {1..5}; do
        echo_rand_4bit_color "Hello, World!"
    done
    echo -e "\n8-bit color demo:"
    for i in {1..5}; do
        echo_rand_8bit_color "Hello, World!"
    done
    echo -e "\n24-bit color demo:"
    for i in {1..5}; do
        echo_rand_24bit_color "Hello, World!"
    done
    echo -e "\nCurrent terminal support: $(max_bits_color_support)bit"
    echo "Default echo_rand_color demo:"
    for i in {1..5}; do
        echo_rand_color "Hello, World!"
    done
}
