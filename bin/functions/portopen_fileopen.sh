# Who is holding open this damn port or file??
# usage: portopen 3000
# May only work on OS X and need tweaking for Linux!
portopen() {
	sudo lsof -P -i ":${1}"
}
fileopen() {
	sudo lsof "${1}"
}
