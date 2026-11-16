import re, subprocess, sys, time

# 使い方: capture2.py 機器のID 保存先 ログ 合図のファイル 最初の待ち秒
udid, outdir, log, signal = sys.argv[1:5]
first_wait = int(sys.argv[5]) if len(sys.argv) > 5 else 25
names = ['home', 'finder', 'finder_aligned', 'plus', 'settings']


def log_text():
    try:
        return open(log, encoding='utf-8', errors='ignore').read()
    except FileNotFoundError:
        return ''


open(signal, 'w').write('0')
deadline = time.time() + 1200
while time.time() < deadline and 'TOUR 0' not in log_text():
    time.sleep(2)
time.sleep(first_wait)

for i, name in enumerate(names):
    open(signal, 'w').write(str(i))
    t = time.time() + 20
    while i > 0 and time.time() < t and f'TOUR {i} ' not in log_text():
        time.sleep(0.5)
    time.sleep(7)
    subprocess.run(['xcrun', 'simctl', 'io', udid, 'screenshot', f'{outdir}/{i}_{name}.png'], check=False)
    print('shot', i, name, flush=True)
