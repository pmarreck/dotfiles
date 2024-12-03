#!/usr/bin/awk -f
# file: rpn.awk
# RPN interpreter with stack operations
BEGIN {
	# Initialize empty stack
	stack_size = 0
}

function push(val) {
	stack[stack_size++] = val
}

function pop() {
	if (stack_size <= 0) {
		print "Error: Stack underflow" > "/dev/stderr"
		exit 1
	}
	return stack[--stack_size]
}

function peek() {
	if (stack_size <= 0) {
		print "Error: Stack empty" > "/dev/stderr"
		exit 1
	}
	return stack[stack_size - 1]
}

# Math operations
function add() { push(pop() + pop()) }

function subtract() { 
	b = pop()
	a = pop()
	push(a - b)
}

function multiply() { push(pop() * pop()) }

function divide() {
	b = pop()
	a = pop()
	if (b == 0) {
		print "Error: Division by zero" > "/dev/stderr"
		exit 1
	}
	push(a / b)
}

# Stack operations
function dup() { 
	a = peek()
	push(a)
}

function swap() {
	if (stack_size < 2) {
		print "Error: Need at least 2 items to swap" > "/dev/stderr"
		exit 1
	}
	b = pop()
	a = pop()
	push(b)
	push(a)
}
function drop() { pop() }

# Binary operations
function bitwise_and() {
	b = pop()
	a = pop()
	# Perform bitwise AND using arithmetic
	push(band(a, b))
}

function bitwise_or() {
	b = pop()
	a = pop()
	# Perform bitwise OR using arithmetic
	push(bor(a, b))
}

# Implement bitwise AND, OR as functions
function band(a, b) {
	result = 0
	mask = 1
	while (a > 0 || b > 0) {
		if ((a % 2 == 1) && (b % 2 == 1)) {
			result += mask
		}
		a = int(a / 2)
		b = int(b / 2)
		mask *= 2
	}
	return result
}

function bor(a, b) {
	result = 0
	mask = 1
	while (a > 0 || b > 0) {
		if ((a % 2 == 1) || (b % 2 == 1)) {
			result += mask
		}
		a = int(a / 2)
		b = int(b / 2)
		mask *= 2
	}
	return result
}

function bitwise_xor() {
	b = pop()
	a = pop()
	push(bxor(a, b))
}

function bxor(a, b) {
	result = 0
	mask = 1
	while (a > 0 || b > 0) {
		if ((a % 2 != b % 2)) {
			result += mask
		}
		a = int(a / 2)
		b = int(b / 2)
		mask *= 2
	}
	return result
}

# Output operations
function dot() {
	print pop()
}

function peek_print() {
	print peek()
}

# Main processing
{
	# Process each line of input
	for (i = NF; i >= 1; i--) {
		val = $i
		
		# Handle quoted strings
		if (val ~ /^".*"$/) {
			# Strip quotes and push as string
			push(substr(val, 2, length(val)-2))
			continue
		}
		
		# Handle numbers
		if (val ~ /^[+-]?([0-9]*[.])?[0-9]+$/) {
			push(val + 0)  # Convert to number
			continue
		}
		
		# Handle operators
		switch (val) {
			case "+":    add(); break
			case "-":    subtract(); break
			case "*":    multiply(); break
						case "\\*":   multiply(); break
			case "/":    divide(); break
			case "dup":  dup(); break
			case "swap": swap(); break
			case "drop": drop(); break
			case "and":  bitwise_and(); break
			case "or":   bitwise_or(); break
			case "xor":  bitwise_xor(); break
			case ".":    dot(); break
			case ".s":   peek_print(); break
			default:
				print "Error: Unknown operator " val > "/dev/stderr"
				exit 1
		}
	}
}
END {
	if (stack_size > 0) {
		print "Warning: " stack_size " items left on stack" > "/dev/stderr"
	}
}
