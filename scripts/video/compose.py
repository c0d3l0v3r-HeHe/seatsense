import json, subprocess, sys, glob
LAV, PLUM, TEXT, PURPLE, WHITE = '#D5D2F0', '#4E3268', '#54456F', '#8264AA', '#FDFCFF'
VIOLET, VIOLET_D, ORANGE, ORANGE_D = '#8C84C6', '#7166B3', '#F59A12', '#D97A0B'
R_TR_U = "M 1712 -20 L 1712 36 A 92 92 0 0 0 1896 36 L 1896 -20"
R_BAND = "M -20 968 L 1940 968"
def road(d, w=92):
    return (f'<path d="{d}" fill="none" stroke="#AAA3D8" stroke-width="{w}" transform="translate(0 12)"/>'
            f'<path d="{d}" fill="none" stroke="{WHITE}" stroke-width="{w}"/>'
            f'<path d="{d}" fill="none" stroke="#CCC7EA" stroke-width="5" stroke-dasharray="26 20"/>')
def tree(x, g, h, r):
    cy = g - h - r * 0.55
    return (f'<ellipse cx="{x + r * 0.16:.0f}" cy="{cy:.0f}" rx="{r}" ry="{r * 1.22:.0f}" fill="{VIOLET_D}"/>'
            f'<ellipse cx="{x}" cy="{cy:.0f}" rx="{r}" ry="{r * 1.22:.0f}" fill="{VIOLET}"/>'
            f'<path d="M{x} {g} L{x} {cy - r * 0.55:.0f} M{x} {g - h * 0.55:.0f} L{x - r * 0.45:.0f} {cy:.0f}" stroke="{PLUM}" stroke-width="{max(4, r // 7)}" stroke-linecap="round" fill="none"/>')
def trees(x, g, s=1.0):
    return tree(x, g, 70 * s, 28 * s) + tree(x + 80 * s, g, 120 * s, 46 * s) + tree(x + 150 * s, g, 55 * s, 24 * s)
def pin(x, y, s=1.0):
    d = "M0 0 C -10 -18 -34 -38 -34 -62 A 34 34 0 1 1 34 -62 C 34 -38 10 -18 0 0 Z"
    return (f'<g transform="translate({x} {y}) scale({s})"><path d="{d}" fill="{ORANGE_D}" transform="translate(-6 2)"/>'
            f'<path d="{d}" fill="{ORANGE}"/><circle cx="0" cy="-62" r="13" fill="{WHITE}"/></g>')
def circle(cx, cy, r, fill): return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}"/>'
def scene(*parts): return '<svg class="deco" width="1920" height="1080" viewBox="0 0 1920 1080" xmlns="http://www.w3.org/2000/svg">' + ''.join(parts) + '</svg>'
import imageio_ffmpeg
FF = imageio_ffmpeg.get_ffmpeg_exe()
marks = dict(json.load(open('marks.json')))
video = glob.glob('rec/*.webm')[0]
dur = float(subprocess.run([FF, '-i', video], capture_output=True, text=True).stderr.split('Duration: ')[1].split(',')[0].split(':')[-1]) + 60
HOLD = 3.0
PX, PY, PW, PH = 1300, 70, 434, 940          # phone screen box in the 1920x1080 frame
segs = [
    ('intro', 0, marks['home'], 'TRANSPORT STACK HACKATHON 2026 · PROBLEM 2', 'SeatSense demo', 'A bus journey planner that shows how full your bus will be, counted from 2.56 million Delhi e-tickets.'),
    ('home', marks['home'], marks['results'], '1 · HOME', 'Where to?', 'Search, recent trips and suggestions. Tap a recent trip: Badarpur → Saket, weekday, leaving 8:30.'),
    ('results', marks['results'], marks['detail'], '2 · SUGGESTED TRIPS', 'Time and crowding, side by side', 'Each bus line is coloured by crowding: green seats likely, amber standing, red crowded. The fastest trip is crowded for 22 of 25 minutes; the best match has seats for 4 minutes more.'),
    ('detail', marks['detail'], marks['routes'], '3 · TRIP DETAIL', 'Stop by stop', 'Estimated times at every stop, and how full the bus usually is between them, for this hour and day type.'),
    ('routes', marks['routes'], marks['hotspots'], '4 · ROUTES', 'Any route, hour by hour', 'Route 717A: the busiest stretch for each hour. Tap 6 pm and the whole route redraws for the evening peak.'),
    ('hotspots', marks['hotspots'], marks['about'], '5 · HOTSPOTS', 'Where one more bus helps most', 'For operators: crowded stretches ranked by riders carried. At 9 am it is Asian Market → Saket; at 6 pm the commute flips direction.'),
    ('about', marks['about'], marks['end'], '6 · CHECKED', 'Tested on a week it never saw', 'Same crowding level as reality on 92 % of stretch-hours, correlation 0.96 with actual riders.'),
    ('end', marks['end'], dur + HOLD, 'TEAM c0d3l0v3r', 'Count what’s there. Show it simply.', 'Open source: github.com/c0d3l0v3r-HeHe/seatsense'),
]
deco = scene(circle(1520, 560, 470, '#C8C4EA'), road(R_TR_U), road(R_BAND), trees(150, 922, 0.9), trees(960, 922, 0.75), pin(1140, 900, 0.9))
fonts = '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Poppins:wght@400;700;800&family=DM+Sans:opsz,wght@9..40,400..700&display=swap">'
css = f"""*{{margin:0}} body{{width:1920px;height:1080px;overflow:hidden;background:{LAV};font-family:'DM Sans',sans-serif;position:relative}}
.deco{{position:absolute;left:0;top:0}} .txt{{position:absolute;left:140px;top:250px;width:980px}}
.eb{{font-family:Poppins;font-weight:700;font-size:26px;letter-spacing:3px;color:{PURPLE}}}
h1{{font-family:Poppins;font-weight:800;font-size:84px;line-height:1.05;color:{PLUM};margin-top:22px}}
p{{font-size:36px;line-height:1.4;color:{TEXT};margin-top:28px}}
.steps{{position:absolute;left:140px;top:150px;display:flex;gap:10px}} .dot{{width:46px;height:8px;border-radius:4px;background:#B9B3E0}} .dot.on{{background:{PLUM}}}"""
for i, (key, a, b, eb, h, body) in enumerate(segs):
    dots = '' if key in ('intro', 'end') else '<div class="steps">' + ''.join(f'<div class="dot{" on" if j <= i - 1 else ""}"></div>' for j in range(6)) + '</div>'
    open(f'bg_{i}.html', 'w').write(f'<!doctype html><html><head><meta charset="utf-8">{fonts}<style>{css}</style></head><body>{deco}{dots}'
                                    f'<div class="txt"><div class="eb">{eb}</div><h1>{h}</h1><p>{body}</p></div></body></html>')
# iPhone-style frame with a transparent screen
B = 16
frame = f"""<!doctype html><html><head><style>*{{margin:0}} body{{width:{PW+2*B+40}px;height:{PH+2*B+40}px;background:transparent}}
.f{{position:absolute;left:20px;top:20px;width:{PW}px;height:{PH}px;border:{B}px solid #121117;border-radius:58px;
box-shadow:0 0 0 4px #6A6478, 22px 26px 0 4px #A9A1D8}}</style></head><body><div class="f"></div></body></html>"""
open('frame.html', 'w').write(frame)
def shot(html, png, w, h, transparent=False):
    cmd = ['google-chrome', '--headless=new', '--disable-gpu', '--hide-scrollbars', f'--window-size={w},{h}', '--virtual-time-budget=4000', f'--screenshot={png}']
    if transparent: cmd.append('--default-background-color=00000000')
    subprocess.run(cmd + [f'file://{__import__("os").getcwd()}/{html}'], check=True, capture_output=True)
for i in range(len(segs)): shot(f'bg_{i}.html', f'bg_{i}.png', 1920, 1080)
shot('frame.html', 'frame.png', PW + 2 * B + 40, PH + 2 * B + 40, transparent=True)
cmd = [FF, '-y', '-loglevel', 'error']
for i, s in enumerate(segs):
    cmd += ['-loop', '1', '-framerate', '30', '-t', f'{s[2] - s[1]:.2f}', '-i', f'bg_{i}.png']
cmd += ['-i', video, '-i', 'frame.png']
n = len(segs)
fc = (''.join(f'[{i}:v]' for i in range(n)) + f'concat=n={n}:v=1:a=0,fps=30[bg];'
      f'[{n}:v]crop=412:892:0:0,scale={PW}:{PH}:flags=lanczos,fps=30,tpad=stop_mode=clone:stop_duration={HOLD}[ph];'
      f'[bg][ph]overlay={PX}:{PY}[a];[a][{n+1}:v]overlay={PX - B - 20}:{PY - B - 20},format=yuv420p[out]')
cmd += ['-filter_complex', fc, '-map', '[out]', '-c:v', 'libx264', '-preset', 'medium', '-crf', '20', '-movflags', '+faststart', 'seatsense_demo.mp4']
subprocess.run(cmd, check=True)
print('total', round(dur + HOLD, 1), 's')
