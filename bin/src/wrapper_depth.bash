# shellcheck shell=bash
# Nesting guard for the wrappers that shadow a tool on PATH and hand off to
# the next one (chmod, cp, git, sed, ...). Each hand-off gives the native tool
# DOTFILES_WRAPPER_DEPTH one higher, an exported variable, so the tool and
# everything it starts inherit the count. When two wrappers each take the
# other for the native tool (a second copy of the tree on PATH, a fixture that
# execs back into a wrapper), the chain would otherwise grow without bound;
# once DOTFILES_WRAPPER_DEPTH_MAX hand-offs are nested, the next refuses.
#
# The limit is small on purpose. A wrapper that consults its native tool twice
# (a --help or --version probe, then the real call) doubles the work of a loop
# at every level, so a loop costs up to 2^limit short runs, one at a time,
# before it ends. Real chains of nested dotfiles wrappers are a few deep.
DOTFILES_WRAPPER_DEPTH_MAX=10

# dotfiles_wrapper_depth NAME: set _dotfiles_wrapper_next to the depth the
# native tool should see, or explain and return 126 at the limit. Wrappers that
# run only as executables export the result for the rest of their process;
# wrappers that may run as functions in an interactive shell pass it on the
# native command alone (DOTFILES_WRAPPER_DEPTH=$_dotfiles_wrapper_next CMD),
# so the shell's own count never changes.
dotfiles_wrapper_depth() {
	local depth=${DOTFILES_WRAPPER_DEPTH:-0}
	# Anything but a small count is noise from outside; a huge one is a loop.
	[[ $depth =~ ^[0-9]+$ ]] || depth=0
	((${#depth} <= 6)) || depth=$DOTFILES_WRAPPER_DEPTH_MAX
	if ((depth >= DOTFILES_WRAPPER_DEPTH_MAX)); then
		printf '%s: refusing to hand off: %s dotfiles wrappers are already nested (DOTFILES_WRAPPER_DEPTH); one is probably running another in a loop\n' \
			"$1" "$depth" >&2
		return 126
	fi
	_dotfiles_wrapper_next=$((depth + 1))
}
