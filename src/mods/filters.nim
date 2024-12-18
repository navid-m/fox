import
  std /
  [
    os,
    strutils,
    re,
  ],
  models,
  normal

let extensions_to_watch = @[
  "nim",
  "html",
  "mustache",
  "hbs",
  "js",
  "jsx",
  "htm",
  "css"
]

proc extract_text(input: string): string =
  let start_index = input.find("@[\"")
  let end_index = input.find("\"]")
  if start_index != -1 and end_index != -1 and end_index > start_index:
    return input[start_index + 3 .. end_index - 1]
  return ""

proc find_first_nimble_file*(): string =
  for entry in walk_dir(os.get_current_dir()):
    if entry.path.ends_with(".nimble"):
      return entry.path
  return ""

proc get_file_list*(): seq[CustomFileInfo] =
  result = @[]
  for file in walk_dir_rec(get_current_dir()):
    {.gcsafe.}:
      for ext in extensions_to_watch:
        if file.ends_with("." & ext):
          result.add(
            CustomFileInfo(
              path: file,
              lastModTime: get_last_modification_time(file)
            )
          )

proc get_executable_name*(): string =
  var exec_name = ""

  for match in find_all(
    read_file(find_first_nimble_file()),
    re"bin\s*=\s*@\[(.*?)\]"
  ):
    exec_name = extract_text(match)

  if exec_name.len == 0:
    raise new_exception(
      ValueError,
      "No executable name found in nimble file"
    )

  return normalize_binary_name(exec_name)
