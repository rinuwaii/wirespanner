# Wirespanner - A Roblox Studio that lets you build ropes / wires easier

> [!WARNING]
> THIS IS NOT FINISHED YET! Expect issues!

[Download Beta Here](https://github.com/rinuwaii/wirespanner/releases/latest)

DevForum Link: TBD

Please do not publish this plugin! It is not finished and it is not yours!!

# Options Breakdown
#### Wire
| Option | Property | Function |
|-----:|-----------|-----------|
| Color| `RopeConstraint.Color` | BrickColor of all segments of the rope. Roblox will find the closest BrickColor to whatever color that gets picked. |
| Width | `RopeConstraint.Thickness` | Width of all segments of the rope. |
| Add Tags | | Non-functional at the moment |
#### Slack
| Option | Property | Function |
|-----:|-----------|-----------|
| Add Slack to Wire | `RopeConstraint.Length` | Toggles adding a random ammount of slack to each rope, defined by the min and max below. |
| Random Slack Range | `RopeConstraint.Length` | The min and max of how much extra gets added. 
#### Model
| Option | Function |
|-----:|-----------|
| Model Span Mode | Toggles model span mode. |
| Random Slack Behaviour in Model | How random slack gets added to all ropes in models. "Each wire in model is same" will give every rope between two models the same amount of slack. "Random slack per wire" will make every rope between two models have its own random slack. |

# Example
https://github.com/rinuwaii/wirespanner/assets/36645011/50c856a1-5885-4ecb-8ce4-e9dba30a3237

# Credits
[stravant](https://github.com/stravant) for the [SharedToolbar](/src/modules/SharedToolbar.lua) module
