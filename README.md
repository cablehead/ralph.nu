# ralph

Stream-driven iterative refinement loop for [gpt2099](https://github.com/cablehead/gpt2099.nu).

Ralph follows the [cross.stream](https://github.com/cablehead/xs) event stream reactively. When an
assistant response arrives, a judge closure fires. If the judge returns feedback, ralph appends the
next turn and triggers another call -- the response arrives on the same stream, triggering the judge
again. No polling, no blocking waits.

## Prerequisites

A working `gpt -p milli` setup. See [gpt2099 getting started](https://github.com/cablehead/gpt2099.nu/blob/main/docs/getting-started.md).

## Usage

```nushell
use xs.nu *
overlay use -pr /path/to/gpt2099.nu/gpt
use ralph.nu
```

### Single call (no loop)

```nushell
"What is 2+2?" | ralph -p milli
```

### With a judge closure

The judge receives the response text. Return null to stop, or a string to continue with.

```nushell
"Write a haiku about rust" | ralph -p milli -n 5 --judge {|response|
  if "borrow" in ($response | str downcase) { null } else { "Include the borrow checker" }
}
```

### LLM-as-judge

Use `ralph ask` inside the judge to make a separate LLM call:

```nushell
"Write a haiku about the ocean" | ralph -p milli -n 3 --judge {|response|
  let verdict = $"Rate this haiku. Reply ONLY DONE if evocative, or give a brief suggestion.

Haiku:
($response)" | ralph ask -p milli
  if "DONE" in ($verdict | str upcase) { null } else { $verdict }
}
```

## Options

- `-p, --provider-ptr` -- provider alias (e.g. `milli`, `kilo`)
- `-j, --judge` -- judge closure: `{|response| null | string}`
- `-n, --max` -- max iterations (default: 5)
