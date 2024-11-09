import
  re,
  strutils,
  os,
  times,
  tables,
  locks,
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

var
  file_to_last_modded = initTable[string, float]()
  build_lock: Lock
  is_building = false

initLock(build_lock)

proc process_initially() =
  for path in get_file_list():
    file_to_last_modded[path.path] = path.lastModTime.toUnixFloat

proc check() {.thread.} =
  if tryAcquire(build_lock):
    try:
      if is_building:
        return

      for path in get_file_list():
        {.gcsafe.}:
          if file_to_last_modded[path.path] < path.lastModTime.toUnixFloat:
            echo("Project files changed, rebuilding...")
            is_building = true
            let exit_code = os.execShellCmd("nimble build")
            if exit_code != 0:
              echo("Build failed, press any key to retry build")
              discard stdin.readLine()
            file_to_last_modded[path.path] = path.lastModTime.toUnixFloat
            is_building = false
    finally:
      release(build_lock)

proc run_checks() =
  while true:
    sleep(1000)
    spawn check()

proc cleanupLock() {.noconv.} =
  deinitLock(build_lock)

addQuitProc(cleanupLock)

when is_main_module:
  process_initially()
  let fnim = find_first_nimble_file()
  if fnim == "":
    echo "No .nimble found, go to a directory where there is one."
    quit(1)
  run_checks()
