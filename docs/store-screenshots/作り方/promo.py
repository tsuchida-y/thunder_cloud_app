import os, subprocess, sys

base = '/Users/tsuchida/.claude/jobs/9e15aab3/tmp'
out = f'{base}/promo'
os.makedirs(out, exist_ok=True)
chrome = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'

# (撮った画面, 見出し, 補足)。予想を思わせる言葉は使わない
slides = [
    ('0_home', '入道雲が見えたら、<br>すぐ知らせます', '気象庁のデータから、いまの空を見守ります'),
    ('1_finder', '方角と高さが、<br>ひと目で分かる', '矢印に合わせて、体ごと向けるだけ'),
    ('2_finder_aligned', 'この方向です、と<br>教えてくれます', '見えたかどうかは、ワンタップで記録'),
    ('4_settings', '見守る範囲も、<br>通知しない時間も', '夜のあいだは、自動でお休みします'),
]

devices = {
    'iphone': dict(w=1320, h=2868, shot_w=940, top=600, radius=96, bezel=16, h1=118, sub=50),
    'ipad': dict(w=2064, h=2752, shot_w=1400, top=660, radius=72, bezel=18, h1=118, sub=58),
}

only = sys.argv[1:] or list(devices)
for dev in only:
    d = devices[dev]
    for n, (shot, head, sub) in enumerate(slides, 1):
        src = f'{base}/shots/{dev}/{shot}.png'
        skip = set()
        if shot in skip or not os.path.exists(src):
            continue
        if dev == 'ipad' and shot == '4_settings':
            shot_html = (f'<canvas id="c" width="2064" height="2752" style="display:block;width:100%"></canvas>'
                         f'<script>var i=new Image();i.onload=function(){{var c=document.getElementById("c"),x=c.getContext("2d");'
                         f'x.drawImage(i,0,0);x.drawImage(i,0,2010,2064,30,0,1800,2064,170);}};i.src="file://{src}";</script>')
        else:
            shot_html = f'<img src="file://{src}">'
        html = f'''<!doctype html><html lang="ja"><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Zen+Maru+Gothic:wght@500;700&family=Zen+Old+Mincho:wght@700&display=swap" rel="stylesheet">
<style>
html,body{{margin:0;width:{d['w']}px;height:{d['h']}px;overflow:hidden}}
body{{background:linear-gradient(180deg,#1C4FA8 0%,#3F86D6 45%,#9CCDF3 78%,#EAF5FF 100%);position:relative;font-family:'Zen Maru Gothic',sans-serif;color:#fff}}
.glow{{position:absolute;left:50%;top:{d['top']+400}px;width:{d['shot_w']+500}px;height:{d['shot_w']+500}px;transform:translateX(-50%);border-radius:50%;background:radial-gradient(circle,rgba(191,227,255,.45),rgba(191,227,255,0) 65%)}}
h1{{position:absolute;left:0;right:0;top:{int(d['top']*0.17)}px;margin:0;text-align:center;font-family:'Zen Old Mincho',serif;font-weight:700;font-size:{d['h1']}px;line-height:1.28;letter-spacing:.04em;text-shadow:0 4px 24px rgba(10,30,80,.25)}}
p{{position:absolute;left:0;right:0;top:{int(d['top']*0.17)+int(d['h1']*2.56)+30}px;margin:0;text-align:center;font-size:{d['sub']}px;font-weight:500;opacity:.92}}
.shot{{position:absolute;left:50%;top:{d['top']}px;transform:translateX(-50%);width:{d['shot_w']}px;border-radius:{d['radius']}px;border:{d['bezel']}px solid #0E1B33;box-shadow:0 40px 90px rgba(8,22,60,.45);overflow:hidden;background:#0E1B33}}
.shot img{{display:block;width:100%}}
.credit{{position:absolute;left:0;right:0;text-align:center;bottom:46px;font-size:{int(d['sub']*0.5)}px;color:#47597A;opacity:.9}}
</style></head><body>
<div class="glow"></div>
<h1>{head}</h1><p>{sub}</p>
<div class="shot">{shot_html}</div>
</body></html>'''
        hp = f'{out}/{dev}_{n}.html'
        open(hp, 'w', encoding='utf-8').write(html)
        png = f'{out}/{dev}_{n}_{shot}.png'
        subprocess.run([chrome, '--headless=new', '--disable-gpu', '--hide-scrollbars',
                        f"--window-size={d['w']},{d['h']}", '--virtual-time-budget=15000',
                        f'--screenshot={png}', f'file://{hp}'], check=False,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print('made', png, flush=True)
