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
  is_building = false
  build_lock: Lock
  main_program_process: Process

proc run_main_proc() =
  let exec_name = get_executable_name()
  echo("Running " & exec_name)
  main_program_process = osproc.start_process(exec_name)

proc process_initially() =
  for path in get_file_list():
    file_to_last_modded[path.path] = path.lastModTime.toUnixFloat

proc rebuild_loop() =
  while(true):
    if os.exec_shell_cmd("nimble build") != 0:
      echo("Build failed, press any key to retry build")
      discard stdin.read_line()
      continue
    break

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
            rebuild_loop()
            file_to_last_modded[path.path] = path.lastModTime.toUnixFloat
            is_building = false
            run_main_proc()
    finally:
      release(build_lock)

proc run_checks() =
  while true:
    sleep(200)
    spawn check()

proc cleanup_lock() {.noconv.} =
  deinit_lock(build_lock)

when is_main_module:
  init_lock(build_lock)
  add_quit_proc(cleanup_lock)
  process_initially()

  if find_first_nimble_file() == "":
    echo "No .nimble found, go to a directory where there is one."
    quit(1)

  run_main_proc()
  run_checks()
