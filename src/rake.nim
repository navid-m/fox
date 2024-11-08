import
  re,
  strutils,
  os


proc find_first_nimble_file(): string =
  for entry in walkDir(os.getCurrentDir()):
    if entry.path.endsWith(".nimble"):
      return entry.path
  return ""

proc extract_text(input: string): string =
  let start_index = input.find("@[\"")
  let end_index = input.find("\"]")
  if start_index != -1 and end_index != -1 and end_index > start_index:
    result = input[start_index + 3 .. end_index - 1]
  else:
    result = ""

proc get_executable_name(nimble_file: string): string =
  var content = read_file(nimble_file)
  var exec_name = ""
  let bin_pattern = re"bin\s*=\s*@\[(.*?)\]"

  for match in find_all(content, bin_pattern):
    exec_name = extract_text(match)

  if exec_name.len == 0:
    raise new_exception(ValueError, "No executable name found in nimble file")

  when defined windows:
    exec_name.add(".exe")

  return exec_name

when is_main_module:
  let fnim = find_first_nimble_file()

  if fnim == "":
    echo "No .nimble found, go to a directory where there is one."
    quit(1)

  echo get_executable_name(fnim)
