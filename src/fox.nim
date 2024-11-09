import
  std/[
    os,
    times,
    tables,
    locks,
    osproc,
    exitprocs,
    threadpool,
  ],
  mods/[
    filters,
    checks,
    logger
  ]

var
  file_to_last_modded = init_table[string, float]()
  is_building = false
  build_cmd = "nimble build -d:nodebug -d:nochecks --opt:none --warnings:off"
  build_lock: Lock
  main_program_process: Process

proc run_main_proc() =
  let exec_name = get_executable_name()
  log("Running " & exec_name)
  main_program_process = osproc.start_process(
    exec_name,
    options = {po_parent_streams}
  )

proc process_initially() =
  log("Running initial build...")
  discard os.exec_shell_cmd(build_cmd)
  for path in get_file_list():
    file_to_last_modded[path.path] = path.last_mod_time.to_unix_float

proc rebuild_loop() =
  while true:
    if os.exec_shell_cmd(build_cmd) != 0:
      log("Build failed, press any key to retry build")
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
          if file_to_last_modded[path.path] < path.last_mod_time.to_unix_float:
            osproc.terminate(main_program_process)
            log("Project files changed, rebuilding...")
            is_building = true
            rebuild_loop()
            file_to_last_modded[path.path] = path.last_mod_time.to_unix_float
            is_building = false
            run_main_proc()
    finally:
      release(build_lock)

proc run_checks() =
  while true:
    sleep(10)
    spawn check()

proc cleanup_lock() {.noconv.} =
  deinit_lock(build_lock)
  log("Bye")

when is_main_module:
  run_rec_error_test()
  init_lock(build_lock)
  exitprocs.add_exit_proc(cleanup_lock)
  process_initially()

  if find_first_nimble_file() == "":
    log("No .nimble found, go to a directory where there is one.")
    quit(1)

  run_main_proc()
  run_checks()
