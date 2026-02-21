$newMoves = Get-Content complex_moves.json -Raw
# Strip the outer brackets [ and ]
$newMoves = $newMoves.Trim().Substring(1, $newMoves.Trim().Length - 2)

$originalMoves = Get-Content assets/moves.json -Raw
# Remove the final ]
$originalMoves = $originalMoves.Trim().Substring(0, $originalMoves.Trim().LastIndexOf(']'))

# Construct the new JSON
$finalJson = $originalMoves + "," + $newMoves + "]"
$finalJson | Set-Content assets/moves.json
