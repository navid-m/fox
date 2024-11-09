import
  os,
  times,
  tables,
  locks,
  osproc,
  threadpool,
  mods/filters

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
              continue
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


when is_main_module:
  add_quit_proc(cleanup_lock)
  process_initially()

  let fnim = find_first_nimble_file()

  if fnim == "":
    echo "No .nimble found, go to a directory where there is one."
    quit(1)

  run_main_proc()
  run_checks()
