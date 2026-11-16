import os, shutil, subprocess

promo = '/Users/tsuchida/.claude/jobs/9e15aab3/tmp/promo'
root = '/Users/tsuchida/Desktop/入道雲サーチ_ストア用'

names = [
    ('1_0_home', '1_ホーム'),
    ('2_1_finder', '2_方角ガイド'),
    ('3_2_finder_aligned', '3_向きが合ったとき'),
    ('4_4_settings', '4_設定'),
]

# 古い画像（通知・ウィジェット・Plus の絵を含む）を、フォルダごと消して作り直す
for d in ['iPhone_6.9インチ', 'iPhone_6.5インチ', 'iPhone_6.3インチ', 'iPad_13インチ']:
    shutil.rmtree(f'{root}/{d}', ignore_errors=True)
    os.makedirs(f'{root}/{d}')

sizes = {'iPhone_6.9インチ': None, 'iPhone_6.5インチ': (2778, 1284), 'iPhone_6.3インチ': (2622, 1206)}
for key, label in names:
    src = f'{promo}/iphone_{key}.png'
    for d, size in sizes.items():
        out = f'{root}/{d}/{label}.png'
        if size is None:
            shutil.copy(src, out)
        else:
            subprocess.run(['sips', '-z', str(size[0]), str(size[1]), src, '--out', out],
                           check=True, stdout=subprocess.DEVNULL)
    shutil.copy(f'{promo}/ipad_{key}.png', f'{root}/iPad_13インチ/{label}.png')

for d in list(sizes) + ['iPad_13インチ']:
    for f in sorted(os.listdir(f'{root}/{d}')):
        out = subprocess.run(['sips', '-g', 'pixelWidth', '-g', 'pixelHeight', '-g', 'hasAlpha', f'{root}/{d}/{f}'],
                             capture_output=True, text=True).stdout.split()
        print(d, f, out[-5] + 'x' + out[-3], 'alpha=' + out[-1])

for script in ['promo.py', 'place_sets.py']:
    shutil.copy(f'/Users/tsuchida/.claude/jobs/9e15aab3/tmp/{script}', f'{root}/作り方/')
