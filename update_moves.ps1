$json = Get-Content -Raw assets/moves.json
$newMoves = Get-Content -Raw new_moves.json
$updatedJson = $json.TrimEnd().TrimEnd(']') + $newMoves + "]"
$updatedJson | Out-File -Encoding UTF8 assets/moves.json
