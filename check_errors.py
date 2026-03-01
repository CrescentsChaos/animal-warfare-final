import json, io, os

try:
    data = io.open('errors3.json', encoding='utf-16le').read()
    d = json.loads(data)
    errors = [e for e in d.get('diagnostics', []) if e.get('severity') == 'ERROR']
    
    if not errors:
        print("0 compile errors found!")
    else:
        print(f"{len(errors)} compile errors found:")
        for e in errors:
            loc = e.get("location", {})
            file = loc.get("file", "").split(os.sep)[-1]
            line = loc.get("range", {}).get("start", {}).get("line", "?")
            msg = e.get("problemMessage", "Unknown")
            print(f"{file}:{line} -> {msg}")
except Exception as e:
    print(f"Failed to parse errors: {e}")
