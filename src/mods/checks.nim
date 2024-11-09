import
    std/strutils,
    filters,
    logger

proc run_rec_error_test*() =
    var to_check_for = "fox"

    when defined windows:
        to_check_for = to_check_for & ".exe"

    if get_executable_name() == to_check_for:
        log(
            "Recursion issues may arise due to identical binary names, proceed anyway? (Y/N)"
        )
        if (to_lower_ascii(stdin.read_line()) != "y"):
            quit(0)
