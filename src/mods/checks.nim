import
  std/strutils,
  filters,
  logger,
  normal

proc run_rec_error_test*() =
  if get_executable_name() == normalize_binary_name("fox"):
    log(
        "Recursion issues may arise due to identical binary names, proceed anyway? (Y/N)"
    )
    if (to_lower_ascii(stdin.read_line()) != "y"):
      quit(0)
