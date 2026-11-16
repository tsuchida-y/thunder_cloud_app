import os, shutil, subprocess

# 英語（米国）用。promo_en.py で作った画像を、App Store Connect の4つのサイズに書き出す
promo = '/Users/tsuchida/.claude/jobs/9e15aab3/tmp/promo_en'
root = '/Users/tsuchida/Documents/Programming/Myapp/thunder_cloud_app/.claude/worktrees/plus-manage/docs/store-screenshots/en-US'

names = [
    ('1_0_home', '1_Home'),
    ('2_1_finder', '2_Direction guide'),
    ('3_2_finder_aligned', '3_Facing it'),
    ('4_4_settings', '4_Settings'),
]

for d in ['iPhone_6.9inch', 'iPhone_6.5inch', 'iPhone_6.3inch', 'iPad_13inch']:
    shutil.rmtree(f'{root}/{d}', ignore_errors=True)
    os.makedirs(f'{root}/{d}')

sizes = {'iPhone_6.9inch': None, 'iPhone_6.5inch': (2778, 1284), 'iPhone_6.3inch': (2622, 1206)}
for key, label in names:
    src = f'{promo}/iphone_{key}.png'
    for d, size in sizes.items():
        out = f'{root}/{d}/{label}.png'
        if size is None:
            shutil.copy(src, out)
        else:
            subprocess.run(['sips', '-z', str(size[0]), str(size[1]), src, '--out', out],
                           check=True, stdout=subprocess.DEVNULL)
    shutil.copy(f'{promo}/ipad_{key}.png', f'{root}/iPad_13inch/{label}.png')

for d in list(sizes) + ['iPad_13inch']:
    for f in sorted(os.listdir(f'{root}/{d}')):
        out = subprocess.run(['sips', '-g', 'pixelWidth', '-g', 'pixelHeight', '-g', 'hasAlpha', f'{root}/{d}/{f}'],
                             capture_output=True, text=True).stdout.split()
        print(d, f, out[-5] + 'x' + out[-3], 'alpha=' + out[-1])
