"""Build native Flutter data from an exported Lucide icon-node JSON object.

Usage: python3 tool/generate_item_icon_data.py /path/to/lucide-item-nodes.json
The node data is copied from Lucide without changing its geometry.
"""
import json
import sys
from pathlib import Path

nodes = json.loads(Path(sys.argv[1]).read_text())
lines = [
    '// Generated from Lucide v1.8.0. See assets/icons/LICENSE.',
    '// Regenerate with tool/generate_item_icon_data.py; do not edit geometry.',
    'const itemIconNodes = <String, List<(String, Map<String, String>)>>{',
]
for name, shapes in nodes.items():
    lines.append(f'  {json.dumps(name)}: [')
    for tag, attrs in shapes:
        values = ', '.join(f'{json.dumps(k)}: {json.dumps(str(v))}' for k, v in attrs.items())
        lines.append(f'    ({json.dumps(tag)}, {{{values}}}),')
    lines.append('  ],')
lines.append('};\n')
Path('lib/widgets/item_icon_data.dart').write_text('\n'.join(lines))
print(f'Generated {len(nodes)} item icons.')
