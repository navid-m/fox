proc normalize_binary_name*(root: string): string =
  result = root
  when defined windows:
    result = root & ".exe"
