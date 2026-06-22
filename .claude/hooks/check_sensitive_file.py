import sys
import json
import re

d = json.load(sys.stdin)
p = d.get('tool_input', {}).get('file_path', '')

patterns = [
    r'\.tfvars$',
    r'(^|/)\.env$',
    r'credentials\.json$',
    r'secret(?!.*\.tf$)',
]

if any(re.search(pat, p) for pat in patterns):
    print(json.dumps({'decision': 'block', 'reason': f'Sensitive file blocked: {p}'}))
    sys.exit(2)
