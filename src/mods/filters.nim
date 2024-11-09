import
  os,
  strutils,
  re,
  models

proc find_first_nimble_file*(): string =
  for entry in walk_dir(os.get_current_dir()):
    if entry.path.ends_with(".nimble"):
      return entry.path
  return ""

proc extract_text(input: string): string =
  let start_index = input.find("@[\"")
  let end_index = input.find("\"]")
  if start_index != -1 and end_index != -1 and end_index > start_index:
    result = input[start_index + 3 .. end_index - 1]
  else:
    result = ""

proc get_file_list*(): seq[CustomFileInfo] =
  result = @[]
  for file in walk_dir_rec(get_current_dir()):
    if file.ends_with(".nim"):
      result.add(
        CustomFileInfo(
          path: file,
          lastModTime: get_last_modification_time(file)
        )
      )

proc get_executable_name*(): string =
  var content = read_file(find_first_nimble_file())
  var exec_name = ""

  for match in find_all(content, re"bin\s*=\s*@\[(.*?)\]"):
    exec_name = extract_text(match)

  if exec_name.len == 0:
    raise new_exception(ValueError, "No executable name found in nimble file")

  when defined windows:
    exec_name.add(".exe")

  return exec_name
