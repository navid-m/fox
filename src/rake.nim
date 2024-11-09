import
  re,
  strutils,
  os,
  times,
  tables,
  locks,
  osproc,
  threadpool


type
  FileInfo = object
    path: string
    lastModTime: Time

proc get_file_list(): seq[FileInfo] =
  result = @[]
  for file in walk_dir_rec(get_current_dir()):
    if file.ends_with(".nim"):
      result.add(
        FileInfo(
          path: file,
          lastModTime: get_last_modification_time(file)
        )
      )

proc find_first_nimble_file(): string =
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

proc get_executable_name(): string =
  var nimble_file = find_first_nimble_file()
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
  file_to_last_modded = init_table[string, float]()
  build_lock: Lock
  is_building = false
  main_program_process: Process

init_lock(build_lock)

proc run_main_proc() =
  let exec_name = get_executable_name()
  echo("Running " & exec_name)
  main_program_process = osproc.startProcess(exec_name)

proc process_initially() =
  for path in get_file_list():
    file_to_last_modded[path.path] = path.lastModTime.toUnixFloat

proc check() {.thread.} =
  if try_acquire(build_lock):
    try:
      if is_building:
        return

      for path in get_file_list():
        {.gcsafe.}:
          if file_to_last_modded[path.path] < path.lastModTime.toUnixFloat:
            osproc.terminate(main_program_process)
            echo("Project files changed, rebuilding...")
            is_building = true
            let exit_code = os.exec_shell_cmd("nimble build")
            if exit_code != 0:
              echo("Build failed, press any key to retry build")
              discard stdin.read_line()
            file_to_last_modded[path.path] = path.lastModTime.toUnixFloat
            is_building = false
            run_main_proc()
    finally:
      release(build_lock)

proc run_checks() =
  while true:
    sleep(1000)
    spawn check()

proc cleanup_lock() {.noconv.} =
  deinit_lock(build_lock)

add_quit_proc(cleanup_lock)

when is_main_module:
  process_initially()
  let fnim = find_first_nimble_file()

  if fnim == "":
    echo "No .nimble found, go to a directory where there is one."
    quit(1)

  run_main_proc()
  run_checks()
