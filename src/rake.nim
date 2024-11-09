import
  re,
  strutils,
  os,
  times,
  tables,
  threadpool


type
  FileInfo = object
    path: string
    lastModTime: Time

proc get_file_list(): seq[FileInfo] =
  result = @[]
  for file in walk_dir_rec(getCurrentDir()):
    if file.endsWith(".nim"):
      result.add(
        FileInfo(
          path: file,
          lastModTime: get_last_modification_time(file)
        )
      )

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

var file_to_last_modded = initTable[string, float]()

proc process_initially() =
  for path in get_file_list():
    file_to_last_modded[path.path] = path.lastModTime.toUnixFloat


proc check() {.thread.} =
  for path in get_file_list():
    {.gcsafe.}:
      if file_to_last_modded[path.path] < path.lastModTime.toUnixFloat:
        echo("Some shit happened here")
        file_to_last_modded[path.path] = path.lastModTime.toUnixFloat
      else:
        echo("f_t_l_m = " & $file_to_last_modded[path.path])
        echo("p_tounixfloat = " & $path.lastModTime.toUnixFloat)
        echo("ok nothing happened")

proc run_checks() =
  while true:
    sleep(1000)
    spawn check()

when is_main_module:
  process_initially()
  let fnim = find_first_nimble_file()
  if fnim == "":
    echo "No .nimble found, go to a directory where there is one."
    quit(1)
  run_checks()
