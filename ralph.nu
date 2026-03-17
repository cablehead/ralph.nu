# ralph - stream-driven iterative refinement loop
#
# Operates reactively on the event stream:
#   1. Appends a user turn + gpt.call to kick things off
#   2. Follows the stream -- when an assistant response arrives, the judge fires
#   3. If the judge returns feedback, appends the next turn + call
#   4. The response to that call arrives on the same stream, triggering the judge again
#   5. Stops when the judge returns null/empty
#
# The judge receives the response text and returns:
#   - null or empty string: done
#   - a string: feedback for the next iteration

export def main [
  --provider-ptr (-p): string # provider alias
  --judge (-j): closure # {|response| null to stop, string to continue}
  --max (-n): int = 5 # max iterations
] {
  let goal = $in

  # Kick off: append user turn + gpt.call
  let user_meta = {
    role: "user"
    content_type: "application/json"
    options: ({} | if ($provider_ptr | is-not-empty) { insert provider_ptr $provider_ptr } else { $in })
  }
  let user_turn = [{type: "text" text: $goal}] | to json | .append gpt.turn --meta $user_meta
  let call = .append gpt.call --meta {continues: $user_turn.id}

  if $judge == null {
    # No judge: just wait for the single response
    let response = .cat -f --after $call.id
      | where { ($in.topic in ["gpt.turn" "gpt.error"]) and ($in.meta?.frame_id? == $call.id) }
      | first
    if $response.topic == "gpt.error" {
      print $"error: ($response.meta?.error?)"
    } else {
      print (extract-text $response)
    }
    return
  }

  # Follow the stream reactively
  .cat -f --after $call.id
  | where { $in.topic in ["gpt.turn" "gpt.error"] and $in.meta?.role? == "assistant" }
  | enumerate
  | take while {|it|
    let frame = $it.item
    let iteration = $it.index

    if $frame.topic == "gpt.error" {
      print $"error: ($frame.meta?.error?)"
      return false
    }

    let text = extract-text $frame
    print $text

    if $iteration >= ($max - 1) {
      print $"--- ralph: hit max iterations \(($max)\) ---"
      return false
    }

    let feedback = do $judge $text
    if ($feedback | is-empty) {
      return false
    }

    print $"--- ralph iteration ($iteration + 2) ---"

    # Append next turn + call -- the response will arrive on this same stream
    let user_meta = {role: "user" content_type: "application/json" continues: $frame.id}
    let user_turn = [{type: "text" text: $feedback}] | to json | .append gpt.turn --meta $user_meta
    .append gpt.call --meta {continues: $user_turn.id}
    true
  }
  | ignore
}

# Extract text content from a response frame
def extract-text [frame: record] {
  .cas $frame.hash | from json
  | where type == "text"
  | get text
  | str join "\n"
}
