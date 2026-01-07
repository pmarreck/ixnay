#!/usr/bin/env bash

ixnay_add_parse_args() {
	local scope=""
	local branch=""
	local package=""
	local token

	for token in "$@"; do
		case "$token" in
			user|system)
				if [ -n "$scope" ]; then
					echo "duplicate scope token" >&2
					return 1
				fi
				scope="$token"
				;;
			stable|unstable|master)
				if [ -n "$branch" ]; then
					echo "duplicate branch token" >&2
					return 1
				fi
				branch="$token"
				;;
			*)
				if [ -n "$package" ]; then
					echo "multiple package tokens" >&2
					return 1
				fi
				package="$token"
				;;
		esac
	done

	if [ -z "$scope" ] || [ -z "$branch" ] || [ -z "$package" ]; then
		echo "missing arguments" >&2
		return 1
	fi

	echo "$scope $branch $package"
}

ixnay_add_target_file() {
	local scope="$1"
	local platform="${IXNAY_ADD_PLATFORM:-}"

	case "$platform" in
		""|nixos|linux|wsl)
			echo "${IXNAY_NIXOS_CONFIG:-/etc/nixos/configuration.nix}"
			;;
		macos)
			local default_path="$HOME/.config/nix/flake.nix"
			echo "${IXNAY_DARWIN_FLAKE:-$default_path}"
			;;
		*)
			echo "unsupported platform '$platform'" >&2
			return 1
			;;
	esac
}

ixnay_add_fetch_description() {
	local _branch="$1"
	local package="$2"
	local nix_bin="${IXNAY_NIX_BIN:-nix}"

	"$nix_bin" eval --raw "nixpkgs#${package}.meta.description"
}

ixnay_add_lua_bin() {
	if [ -n "${IXNAY_LUA_BIN:-}" ]; then
		echo "$IXNAY_LUA_BIN"
		return 0
	fi
	if command -v luajit >/dev/null 2>&1; then
		echo "luajit"
		return 0
	fi
	if command -v lua >/dev/null 2>&1; then
		echo "lua"
		return 0
	fi
	echo "Unable to find luajit or lua; set IXNAY_LUA_BIN to a valid interpreter" >&2
	return 1
}

ixnay_add_insert_package() {
	local file_path="$1"
	local scope="$2"
	local attr_expr="$3"
	local description="$4"
	local target_user="${IXNAY_ADD_USER:-$USER}"
	local platform="${IXNAY_ADD_PLATFORM:-}"

	if [ ! -f "$file_path" ]; then
		echo "target file '$file_path' not found" >&2
		return 1
	fi

	local LUA_BIN
	if ! LUA_BIN=$(ixnay_add_lua_bin); then
		return 1
	fi

	local start_marker=""
	local end_marker=""
	case "$scope" in
		system)
			start_marker="# IXNAY SYSTEM PACKAGES START - DO NOT REMOVE"
			end_marker="# IXNAY SYSTEM PACKAGES END - DO NOT REMOVE"
			;;
		user)
			if [ -z "$target_user" ]; then
				echo "user scope requires IXNAY_ADD_USER or USER" >&2
				return 1
			fi
			start_marker="# IXNAY USER PACKAGES (${target_user}) START - DO NOT REMOVE"
			end_marker="# IXNAY USER PACKAGES (${target_user}) END - DO NOT REMOVE"
			;;
		*)
			echo "unknown scope '$scope'" >&2
			return 1
			;;
	esac

	ixnay_add_ensure_markers "$file_path" "$scope" "$start_marker" "$end_marker" "$target_user" "$platform" || return 1

	"$LUA_BIN" - "$file_path" "$attr_expr" "$description" "$start_marker" "$end_marker" "$target_user" <<'LUA'
local path = arg[1]
local attr_expr = arg[2]
local description = arg[3]
local start_marker = arg[4]
local end_marker = arg[5]

local function read_lines(file_path)
	local lines = {}
	local fh, err = io.open(file_path, "r")
	if not fh then
		io.stderr:write(err, "\n")
		os.exit(1)
	end
	for line in fh:lines() do
		table.insert(lines, line)
	end
	fh:close()
	return lines
end

local function write_lines(file_path, lines)
	local fh, err = io.open(file_path, "w")
	if not fh then
		io.stderr:write(err, "\n")
		os.exit(1)
	end
	fh:write(table.concat(lines, "\n"))
	fh:write("\n")
	fh:close()
end

local function trim(text)
	return (text:match("^%s*(.-)%s*$") or "")
end

local function leading_ws(line)
	return (line:match("^(%s*)") or "")
end

local function find_marker_line(lines, marker, from_index)
	for i = from_index or 1, #lines do
		if lines[i]:find(marker, 1, true) then
			return i
		end
	end
	return nil
end

local lines = read_lines(path)

local start_idx = find_marker_line(lines, start_marker, 1)
if not start_idx then
	io.stderr:write("missing ixnay marker block for scope in ", path, "\n")
	os.exit(1)
end

local end_idx = find_marker_line(lines, end_marker, start_idx + 1)
if not end_idx then
	io.stderr:write("missing ixnay marker block for scope in ", path, "\n")
	os.exit(1)
end

local indent = leading_ws(lines[start_idx])
local marker_indent = leading_ws(lines[end_idx])

local function package_key(attr)
	local base = attr:match("([^%.]+)$")
	return base or attr
end

local function parse_entry(line)
	local stripped = trim(line)
	if stripped == "" or stripped:sub(1, 1) == "#" then
		return nil
	end
	local pkg = stripped
	local comment = ""
	local hash_pos = stripped:find("#", 1, true)
	if hash_pos then
		pkg = trim(stripped:sub(1, hash_pos - 1))
		comment = trim(stripped:sub(hash_pos + 1))
	end
	local display = pkg
	if comment ~= "" then
		display = pkg .. " # " .. comment
	end
	return { attr = pkg, display = display, base = package_key(pkg) }
end

local entries = {}
for i = start_idx + 1, end_idx - 1 do
	local parsed = parse_entry(lines[i])
	if parsed then
		table.insert(entries, parsed)
	end
end

local existing_packages = {}
local existing_by_base = {}
for _, entry in ipairs(entries) do
	existing_packages[entry.attr] = true
	if not existing_by_base[entry.base] then
		existing_by_base[entry.base] = entry.attr
	end
end

local new_base = package_key(attr_expr)
if existing_packages[attr_expr] then
	print(attr_expr .. " already present; skipping")
	os.exit(0)
end

if existing_by_base[new_base] then
	io.stderr:write(string.format(
		"%s already present via %s; run 'ixnay remove' first to switch to %s\n",
		new_base,
		existing_by_base[new_base],
		attr_expr
	))
	os.exit(1)
end

local sanitized_description = trim((description:gsub("\n", " ")))
local display = attr_expr
if sanitized_description ~= "" then
	display = display .. " # " .. sanitized_description
end

table.insert(entries, { attr = attr_expr, display = display, base = new_base })

table.sort(entries, function(a, b)
	if a.base == b.base then
		return a.attr < b.attr
	end
	return a.base < b.base
end)

local new_block = {}
for _, entry in ipairs(entries) do
	table.insert(new_block, indent .. entry.display)
end

local new_lines = {}
for i = 1, start_idx do
	table.insert(new_lines, lines[i])
end

for _, line in ipairs(new_block) do
	table.insert(new_lines, line)
end

table.insert(new_lines, marker_indent .. end_marker)

for i = end_idx + 1, #lines do
	table.insert(new_lines, lines[i])
end

local end_idx_new = start_idx + #new_block + 1
local closing_idx = end_idx_new + 1
local desired_closing = marker_indent .. "];"

if closing_idx > #new_lines then
	table.insert(new_lines, desired_closing)
else
	local existing = new_lines[closing_idx] or ""
	if trim(existing) ~= "];" then
		table.insert(new_lines, closing_idx, desired_closing)
	else
		new_lines[closing_idx] = desired_closing
	end
end

write_lines(path, new_lines)
LUA
}

ixnay_add_ensure_markers() {
	local file_path="$1"
	local scope="$2"
	local start_marker="$3"
	local end_marker="$4"
	local target_user="$5"
	local platform="$6"

	local LUA_BIN
	if ! LUA_BIN=$(ixnay_add_lua_bin); then
		return 1
	fi

	"$LUA_BIN" - "$file_path" "$scope" "$start_marker" "$end_marker" "$target_user" "$platform" <<'LUA'
local path = arg[1]
local scope = arg[2]
local start_marker = arg[3]
local end_marker = arg[4]
local target_user = arg[5]
local platform = arg[6] or ""

local function read_file(file_path)
	local fh, err = io.open(file_path, "r")
	if not fh then
		io.stderr:write(err, "\n")
		os.exit(1)
	end
	local text = fh:read("*a") or ""
	fh:close()
	return text
end

local function write_file(file_path, content)
	local fh, err = io.open(file_path, "w")
	if not fh then
		io.stderr:write(err, "\n")
		os.exit(1)
	end
	if not content:match("\n$") then
		content = content .. "\n"
	end
	fh:write(content)
	fh:close()
end

local function trim(text)
	return (text:match("^%s*(.-)%s*$") or "")
end

local function find_matching_brace(text, brace_open)
	local depth = 1
	local pos = brace_open + 1
	while pos <= #text do
		local char = text:sub(pos, pos)
		if char == '{' then
			depth = depth + 1
		elseif char == '}' then
			depth = depth - 1
			if depth == 0 then
				return pos
			end
		end
		pos = pos + 1
	end
	return nil
end

local function skip_ws_and_comments(text, pos)
	while pos <= #text do
		local char = text:sub(pos, pos)
		if char:match("%s") then
			pos = pos + 1
		elseif char == '#' then
			local newline = text:find("\n", pos, true)
			if not newline then
				return #text + 1
			end
			pos = newline + 1
		else
			break
		end
	end
	return pos
end

local function is_ident_char(char)
	return char:match("[%w_%-]") ~= nil
end

local function read_identifier(text, pos)
	local start = pos
	while pos <= #text do
		local char = text:sub(pos, pos)
		if is_ident_char(char) then
			pos = pos + 1
		else
			break
		end
	end
	if pos > start then
		return text:sub(start, pos - 1)
	end
	return nil
end

local function skip_with_clause(text, pos)
	if text:sub(pos, pos + 3) ~= "with" then
		return pos
	end
	local after = text:sub(pos + 4, pos + 4)
	if after ~= "" and not after:match("%s") then
		return pos
	end
	local semi = text:find(";", pos + 4, true)
	if not semi then
		return pos
	end
	return skip_ws_and_comments(text, semi + 1)
end

local function find_named_list_definition(text, name)
	local search_from = 1
	while search_from <= #text do
		local idx = text:find(name, search_from, true)
		if not idx then
			return nil
		end
		local before = idx > 1 and text:sub(idx - 1, idx - 1) or ""
		local after = text:sub(idx + #name, idx + #name)
		if (idx == 1 or not is_ident_char(before)) and (after == "" or not is_ident_char(after)) then
			local eq = text:find("=", idx + #name, true)
			if eq then
				local pos = skip_ws_and_comments(text, eq + 1)
				pos = skip_with_clause(text, pos)
				if text:sub(pos, pos) == "[" then
					return pos
				end
			end
		end
		search_from = idx + #name
	end
	return nil
end

local function find_anchor_block(text, anchor)
	local idx = text:find(anchor, 1, true)
	if not idx then
		return nil
	end
	local brace_open = text:find("{", idx, true)
	if not brace_open then
		return nil
	end
	local brace_close = find_matching_brace(text, brace_open)
	if not brace_close then
		return nil
	end
	local pos = skip_ws_and_comments(text, brace_close + 1)
	if text:sub(pos, pos) == ":" then
		pos = skip_ws_and_comments(text, pos + 1)
		if text:sub(pos, pos) == "{" then
			local brace2 = pos
			local close2 = find_matching_brace(text, brace2)
			if close2 then
				return brace2, close2
			end
		end
	end
	return brace_open, brace_close
end

local function find_list_after_assignment(text, assign_idx, limit)
	local eq = text:find("=", assign_idx, true)
	if not eq or (limit and eq > limit) then
		return nil
	end
	local pos = skip_ws_and_comments(text, eq + 1)
	pos = skip_with_clause(text, pos)
	if text:sub(pos, pos) == "[" then
		return pos
	end
	local name = read_identifier(text, pos)
	if name then
		local list_idx = find_named_list_definition(text, name)
		if list_idx and (not limit or list_idx < limit) then
			return list_idx
		end
	end
	return nil
end

local function find_list_end(text, open_idx)
	local depth = 0
	local pos = open_idx
	local closing_idx
	while pos <= #text do
		local char = text:sub(pos, pos)
		if char == '#' then
			local newline = text:find("\n", pos, true)
			if not newline then
				break
			end
			pos = newline + 1
			goto continue
		elseif char == '[' then
			depth = depth + 1
		elseif char == ']' then
			depth = depth - 1
			if depth == 0 then
				closing_idx = pos
				break
			end
		end
		pos = pos + 1
		::continue::
	end
	return closing_idx
end

local function find_open_bracket_after(text, pattern, from_idx, limit)
	local search_from = from_idx or 1
	while true do
		local idx = text:find(pattern, search_from, true)
		if not idx then
			break
		end
		local open_bracket = text:find("[", idx, true)
		if open_bracket and (not limit or open_bracket < limit) then
			return open_bracket
		end
		search_from = idx + #pattern
	end
	return nil
end

local function detect_entry_indent(text, open_idx)
	local pos = open_idx + 1
	while pos <= #text do
		local char = text:sub(pos, pos)
		if char == '\n' then
			pos = pos + 1
			local indent = {}
			while pos <= #text do
				char = text:sub(pos, pos)
				if char == ' ' or char == '\t' then
					table.insert(indent, char)
					pos = pos + 1
				else
					break
				end
			end
			if #indent > 0 then
				return table.concat(indent)
			end
		elseif char == ' ' or char == '\t' then
			pos = pos + 1
		else
			break
		end
	end
	return "\t\t"
end

local function find_system_packages_list(text)
	local idx = text:find("environment.systemPackages", 1, true)
	if idx then
		local direct = find_list_after_assignment(text, idx, nil)
		if direct then
			return direct
		end
	end

	local pattern = "environment%s*=%s*%{"
	local search_from = 1
	while true do
		local s, e = text:find(pattern, search_from)
		if not s then
			break
		end
		local brace_open = e
		local brace_close = find_matching_brace(text, brace_open)
		if not brace_close then
			break
		end
		local block = text:sub(brace_open, brace_close)
		local rel = block:find("systemPackages", 1, true)
		if rel then
			local global_idx = brace_open + rel - 1
			local open_bracket = find_list_after_assignment(text, global_idx, brace_close)
			if open_bracket then
				return open_bracket
			end
		end
		search_from = e + 1
	end
	return nil
end

local function find_user_packages_list(text, user)
	local direct_patterns = {
		"users.users." .. user .. ".packages",
		"home-manager.users." .. user .. ".home.packages",
		"home-manager.users." .. user .. ".packages",
	}
	for _, pattern in ipairs(direct_patterns) do
		local open_bracket = find_open_bracket_after(text, pattern, 1, nil)
		if open_bracket then
			return open_bracket
		end
	end

	local function find_in_block(anchor, keys)
		local brace_open, brace_close = find_anchor_block(text, anchor)
		if not brace_open or not brace_close then
			return nil
		end
		for _, key in ipairs(keys) do
			local open_bracket = find_open_bracket_after(text, key, brace_open, brace_close)
			if open_bracket then
				return open_bracket
			end
		end
		return nil
	end

	local open_bracket = find_in_block("users.users." .. user, { "packages" })
	if open_bracket then
		return open_bracket
	end

	open_bracket = find_in_block("home-manager.users." .. user, { "home.packages", "packages" })
	if open_bracket then
		return open_bracket
	end

	return nil
end

local text = read_file(path)
if text:find(start_marker, 1, true) and text:find(end_marker, 1, true) then
	os.exit(0)
end

local open_bracket
if scope == "system" then
	open_bracket = find_system_packages_list(text)
	if not open_bracket then
		io.stderr:write("could not find environment.systemPackages list in ", path, "\n")
		os.exit(1)
	end
elseif scope == "user" then
	if target_user == "" then
		io.stderr:write("missing target user for user scope\n")
		os.exit(1)
	end
	open_bracket = find_user_packages_list(text, target_user)
	if not open_bracket and platform == "macos" then
		open_bracket = find_system_packages_list(text)
	end
	if not open_bracket then
		io.stderr:write("could not find packages list for ", target_user, " in ", path, "\n")
		os.exit(1)
	end
else
	io.stderr:write("unknown scope ", scope, "\n")
	os.exit(1)
end

local closing_idx = find_list_end(text, open_bracket)
if not closing_idx then
	io.stderr:write("could not find end of packages list for scope ", scope, "\n")
	os.exit(1)
end

local entry_indent = detect_entry_indent(text, open_bracket)
local insertion = "\n" .. entry_indent .. start_marker .. "\n" .. entry_indent .. end_marker

local prefix = text:sub(1, closing_idx - 1)
local suffix = text:sub(closing_idx)
local new_text = prefix .. insertion .. suffix

write_file(path, new_text)
LUA
}

ixnay_add_remove_package() {
	local file_path="$1"
	local scope="$2"
	local attr_expr="$3"
	local target_user="${IXNAY_ADD_USER:-$USER}"
	local platform="${IXNAY_ADD_PLATFORM:-}"

	if [ ! -f "$file_path" ]; then
		echo "target file '$file_path' not found" >&2
		return 1
	fi

	local start_marker=""
	local end_marker=""
	case "$scope" in
		system)
			start_marker="# IXNAY SYSTEM PACKAGES START - DO NOT REMOVE"
			end_marker="# IXNAY SYSTEM PACKAGES END - DO NOT REMOVE"
			;;
		user)
			if [ -z "$target_user" ]; then
				echo "user scope requires IXNAY_ADD_USER or USER" >&2
				return 1
			fi
			start_marker="# IXNAY USER PACKAGES (${target_user}) START - DO NOT REMOVE"
			end_marker="# IXNAY USER PACKAGES (${target_user}) END - DO NOT REMOVE"
			;;
		*)
			echo "unknown scope '$scope'" >&2
			return 1
			;;
	esac

	ixnay_add_ensure_markers "$file_path" "$scope" "$start_marker" "$end_marker" "$target_user" "$platform" || return 1

	local LUA_BIN
	if ! LUA_BIN=$(ixnay_add_lua_bin); then
		return 1
	fi

	"$LUA_BIN" - "$file_path" "$attr_expr" "$start_marker" "$end_marker" <<'LUA'
local path = arg[1]
local attr_expr = arg[2]
local start_marker = arg[3]
local end_marker = arg[4]

local function read_lines(file_path)
	local fh, err = io.open(file_path, "r")
	if not fh then
		io.stderr:write(err, "\n")
		os.exit(1)
	end
	local lines = {}
	for line in fh:lines() do
		table.insert(lines, line)
	end
	fh:close()
	return lines
end

local function write_lines(file_path, lines)
	local fh, err = io.open(file_path, "w")
	if not fh then
		io.stderr:write(err, "\n")
		os.exit(1)
	end
	fh:write(table.concat(lines, "\n"))
	fh:write("\n")
	fh:close()
end

local function trim(text)
	return (text:match("^%s*(.-)%s*$") or "")
end

local function find_marker_line(lines, marker, from_index)
	for i = from_index or 1, #lines do
		if lines[i]:find(marker, 1, true) then
			return i
		end
	end
	return nil
end

local lines = read_lines(path)
local start_idx = find_marker_line(lines, start_marker, 1)
local end_idx = start_idx and find_marker_line(lines, end_marker, start_idx + 1) or nil
if not start_idx or not end_idx then
	io.stderr:write("missing ixnay marker block in ", path, "\n")
	os.exit(1)
end

local remaining = {}
local matches = 0
for i = start_idx + 1, end_idx - 1 do
	local raw_line = lines[i]
	local stripped = trim(raw_line)
	if stripped ~= "" and stripped:sub(1, 1) ~= "#" then
		local pkg = stripped
		local hash_pos = stripped:find("#", 1, true)
		if hash_pos then
			pkg = trim(stripped:sub(1, hash_pos - 1))
		end
		if pkg == attr_expr then
			matches = matches + 1
			goto continue
		end
	end
	table.insert(remaining, raw_line)
	::continue::
end

if matches == 0 then
	io.stderr:write(attr_expr, " not found\n")
	os.exit(1)
end
if matches > 1 then
	io.stderr:write("multiple entries found for ", attr_expr, "\n")
	os.exit(1)
end

local new_lines = {}
for i = 1, start_idx do
	table.insert(new_lines, lines[i])
end
for _, line in ipairs(remaining) do
	table.insert(new_lines, line)
end
for i = end_idx, #lines do
	table.insert(new_lines, lines[i])
end

write_lines(path, new_lines)
LUA
}
