function load(dir, mode,    cmd, f, name) {
	cmd = "ls " dir " 2>/dev/null"
	while ((cmd | getline f) > 0) {
		name = f
		edits[name] = mode
		value[name] = slurp(dir "/" f)
	}
	close(cmd)
}

function slurp(path,    line, s, first) {
	first = 1
	while ((getline line < path) > 0) {
		s = first ? line : s "\n" line
		first = 0
	}
	close(path)
	return s
}

function scan(line,    i, c, n) {
	ended = 0
	n = length(line)
	for (i = 1; i <= n; i++) {
		c = substr(line, i, 1)
		if (incomment) {
			if (c == "*" && substr(line, i + 1, 1) == "/") { incomment = 0; i++ }
		} else if (instring) {
			if (c == "\\") i++
			else if (c == "\"") instring = 0
		} else if (c == "/" && substr(line, i + 1, 1) == "*") {
			incomment = 1; i++
		} else if (c == "/" && substr(line, i + 1, 1) == "/") {
			break
		} else if (c == "\"") {
			instring = 1
		} else if (c == "{") {
			depth++
		} else if (c == "}") {
			depth--
		} else if (c == ";" && depth == 0) {
			ended = i
			return
		}
	}
}

function declname(line,    s, eq) {
	eq = index(line, "=")
	if (eq == 0 || line ~ /^[ \t]*(#|\/\*|\*)/) return ""
	s = substr(line, 1, eq - 1)
	sub(/[ \t]*(\[[^]]*\][ \t]*)*$/, "", s)
	if (!match(s, /[A-Za-z_][A-Za-z0-9_]*$/)) return ""
	return substr(s, RSTART, RLENGTH)
}

BEGIN {
	load(dir "/replace", "replace")
	load(dir "/prepend", "prepend")
	load(dir "/define", "define")
	if ((getline line < (dir "/extra")) > 0) {
		close(dir "/extra")
		print slurp(dir "/extra")
	}
}

skipdefine {
	skipdefine = ($0 ~ /\\$/)
	next
}

skipping {
	scan($0)
	if (ended) skipping = 0
	next
}

/^[ \t]*#[ \t]*define[ \t]+[A-Za-z_][A-Za-z0-9_]*/ {
	name = $0
	sub(/^[ \t]*#[ \t]*define[ \t]+/, "", name)
	match(name, /^[A-Za-z_][A-Za-z0-9_]*/)
	name = substr(name, 1, RLENGTH)
	if ((name in edits) && edits[name] == "define") {
		print "#define " name " " value[name]
		done[name] = 1
		skipdefine = ($0 ~ /\\$/)
		next
	}
}

!incomment && !instring && depth == 0 {
	name = declname($0)
	if (name != "" && (name in edits) && edits[name] == "replace") {
		print substr($0, 1, index($0, "=")) " " value[name] ";"
		done[name] = 1
		depth = 0
		scan(substr($0, index($0, "=") + 1))
		if (!ended) skipping = 1
		next
	}
	if (name != "" && (name in edits) && edits[name] == "prepend") {
		brace = index(substr($0, index($0, "=")), "{")
		if (brace == 0) {
			print "dwl config: '" name "' has no '{' on its first line, can't add entries" > "/dev/stderr"
			failed = 1
		} else {
			brace += index($0, "=") - 1
			print substr($0, 1, brace)
			print value[name]
			rest = substr($0, brace + 1)
			if (rest ~ /[^ \t]/) print rest
			done[name] = 1
			scan($0)
			next
		}
	}
}

{
	scan($0)
	print
}

END {
	for (name in edits)
		if (!(name in done)) {
			print "dwl config: '" name "' isn't defined in config.def.h (with your patches applied). Typo, or does it need a patch?" > "/dev/stderr"
			failed = 1
		}
	exit failed
}
