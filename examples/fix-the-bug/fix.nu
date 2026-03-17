#!/usr/bin/env nu

# Ralph loop that fixes a buggy Rust program by iterating until tests pass.
#
# Run from within the fix-the-bug/ directory:
#   nu fix.nu

use xs.nu *
overlay use -pr ~/gpt2099.nu/gpt
use ~/ralph.nu/ralph.nu

# Strip markdown code fences from LLM response
def extract-code []: string -> string {
  let lines = $in | lines
  if ($lines | first | default "" | str starts-with "```") {
    $lines | skip 1 | take while { not ($in | str starts-with "```") } | str join "\n"
  } else {
    $in | str join "\n"
  }
}

let code = open src/lib.rs
let result = do { cargo test } | complete

let prompt = $"Fix this Rust code. The test fails.

Error:
($result.stderr)

Code:
($code)

Reply with ONLY the corrected Rust code, no explanation."

$prompt | ralph -p milli -n 5 --judge {|response|
  # Apply the fix
  $response | extract-code | save -f src/lib.rs

  # Run tests
  let result = do { cargo test } | complete
  if $result.exit_code == 0 {
    print "tests pass!"
    null
  } else {
    let code = open src/lib.rs
    $"Tests still fail.

Error:
($result.stderr)

Current code:
($code)

Reply with ONLY the corrected Rust code, no explanation."
  }
}
