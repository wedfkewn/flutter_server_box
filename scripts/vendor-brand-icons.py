"""Vendor selected SVG logos at immutable upstream commits (no runtime CDN)."""
import concurrent.futures
import hashlib
import json
from pathlib import Path
import re
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/brands'
OUT.mkdir(parents=True, exist_ok=True)
HEADERS = {'User-Agent': 'ServerBox-brand-assets'}

def fetch(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=45).read()

def pinned(repo):
    return json.loads(fetch('https://api.github.com/repos/' + repo + '/commits?per_page=1'))[0]['sha']

repos = ['devicons/devicon', 'lukas-w/font-logos', 'simple-icons/simple-icons']
pins = {repo: pinned(repo) for repo in repos}
trees = {repo: {x['path'] for x in json.loads(fetch('https://api.github.com/repos/' + repo + '/git/trees/' + pins[repo] + '?recursive=1'))['tree']} for repo in repos}
jobs = []
programs = ['python', 'nginx', 'apache', 'nodejs', 'php', 'java', 'ruby', 'mysql', 'mariadb', 'postgresql', 'redis', 'mongodb', 'docker', 'podman', 'containerd', 'git', 'rabbitmq', 'elasticsearch', 'prometheus', 'grafana', 'caddy', 'traefik']
for name in programs:
    path = f'icons/{name}/{name}-original.svg'
    repo = repos[0]
    if path not in trees[repo]:
        repo = repos[2]
        path = f'icons/{name if name != "traefik" else "traefikproxy"}.svg'
    if path not in trees[repo]:
        raise RuntimeError('Missing program logo: ' + name)
    if name == 'nginx':
        repo, path = repos[2], 'icons/nginx.svg'
    jobs.append(('program-' + name, repo, path))

names = re.findall(r'^  (\w+)[,;]\s*$', (ROOT / 'lib/data/model/server/dist.dart').read_text(encoding='utf-8'), re.M)
aliases = dict(arch='archlinux', wrt='openwrt', rhel='redhat', raspbian='raspberry-pi', mint='linuxmint', popos='pop-os', kdeneon='kde-neon', mx='mxlinux', guix='gnu-guix', voidlinux='void', macos='apple', rocky='rocky-linux', kali='kali-linux', qubes='qubesos')
dev_alias = dict(arch='archlinux', rocky='rockylinux', rhel='redhat', macos='apple', wrt='openwrt', raspbian='raspberrypi', windows='windows11')
for name in names:
    if name in ['debian', 'alpine', 'gentoo', 'nixos']:
        continue  # Preserve the already-vendored original artwork and notices.
    dev_name = dev_alias.get(name, name)
    path = f'icons/{dev_name}/{dev_name}-original.svg'
    repo = repos[0]
    if path not in trees[repo]:
        repo = repos[1]
        path = 'vectors/' + aliases.get(name, name) + '.svg'
    if name in ['artix', 'netbsd']:
        # font-logos' empty pattern renders blank in flutter_svg; use the
        # alternative original SVG instead of rewriting the artwork.
        repo = repos[2]
        path = 'icons/' + ('artixlinux' if name == 'artix' else name) + '.svg'
    if path not in trees[repo]:
        print('No artwork:', name)
        continue
    if name == 'ubuntu':
        repo, path = repos[2], 'icons/ubuntu.svg'
    jobs.append(('distro-' + name, repo, path))

def download(job):
    name, repo, path = job
    url = f'https://raw.githubusercontent.com/{repo}/{pins[repo]}/{path}'
    data = fetch(url)
    if b'<svg' not in data:
        raise RuntimeError('Not SVG: ' + url)
    source_hash = hashlib.sha256(data).hexdigest()
    color = {'distro-ubuntu': 'E95420', 'program-nginx': '009639'}.get(name)
    if color:
        data = data.replace(b'<svg ', f'<svg fill="#{color}" '.encode(), 1)
    if name == 'program-nginx':
        data = data.replace(b'<path d=', b'<path fill="#fff" d="M12 0L1.605 6v12L12 24l10.395-6V6L12 0z"/><path d=', 1)
    (OUT / (name + '.svg')).write_bytes(data)
    record = dict(id=name, asset='assets/brands/' + name + '.svg', source=url, upstream=repo, commit=pins[repo], sha256=hashlib.sha256(data).hexdigest())
    if color:
        record.update(sourceSha256=source_hash, transformation=f'Apply official brand color #{color} to transparent symbol')
    if name == 'program-nginx':
        record['transformation'] = 'Apply official green #009639 and white symbol contrast to transparent hexagon'
    return record

with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
    assets = sorted(pool.map(download, jobs), key=lambda a: a['id'])
for repo in repos:
    path = 'LICENSE.md' if repo == repos[2] else 'LICENSE'
    (OUT / (repo.split('/')[1] + '-LICENSE.txt')).write_bytes(fetch(f'https://raw.githubusercontent.com/{repo}/{pins[repo]}/{path}'))
(OUT / 'manifest.json').write_text(json.dumps(assets, indent=2) + '\n', encoding='utf-8')
dart = '// Selected vendored logos. Sources and hashes: assets/brands/manifest.json.\nconst bundledDistroLogos = <String, String>{\n'
dart += ''.join("  '%s': '%s',\n" % (a['id'][7:], a['asset']) for a in assets if a['id'].startswith('distro-'))
dart += '};\n\nconst bundledProgramLogos = <String, String>{\n'
dart += ''.join("  '%s': '%s',\n" % (a['id'][8:], a['asset']) for a in assets if a['id'].startswith('program-'))
dart += '};\n'
monochrome = []
for asset in assets:
    svg = (ROOT / asset['asset']).read_text(encoding='utf-8').lower()
    colors = set(re.findall(r"(?:fill|stroke)=[\"']([^\"']+)", svg) + re.findall(r'(?:fill|stroke)\s*:\s*([^;}\"]+)', svg)) - {'none', 'transparent', 'currentcolor'}
    if colors <= {'#000', '#000000', 'black', '#fff', '#ffffff', 'white'} and not any(x in svg for x in ['<lineargradient', '<radialgradient', '<pattern']):
        monochrome.append(asset['asset'])
dart += '\n/// Single-tone symbols use foreground contrast in both app themes.\nconst themeAwareBrandAssets = <String>{\n'
dart += ''.join("  '%s',\n" % path for path in sorted(monochrome)) + '};\n'
(ROOT / 'lib/data/res/brand_assets.dart').write_text(dart, encoding='utf-8')
print('Vendored', len(assets), 'logos;', sum((OUT / (a['id'] + '.svg')).stat().st_size for a in assets), 'bytes')
