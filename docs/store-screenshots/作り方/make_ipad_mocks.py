import re, shutil, subprocess

base = '/Users/tsuchida/.claude/jobs/9e15aab3/tmp'
chrome = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'

W, H = 516, 688  # 2倍で 1032×1376、保存すると 2064×2752（iPad 13インチ）


def render(html_path, png_path):
    subprocess.run([chrome, '--headless=new', '--disable-gpu', '--hide-scrollbars',
                    f'--window-size={W},{H}', '--force-device-scale-factor=2',
                    '--virtual-time-budget=15000', f'--screenshot={png_path}', f'file://{html_path}'],
                   check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


# 通知と Plus: スマホ用の絵（390×844）を、iPad の形（516×688）に広げて描く
for name in ['Notify2', 'Plus2']:
    s = open(f'{base}/design/{name}.html', encoding='utf-8').read()
    n = s.count('width: 390px; height: 844px')
    assert n == 1, (name, n)
    s = s.replace('width: 390px; height: 844px', f'width: {W}px; height: {H}px')
    open(f'{base}/design/{name}_ipad.html', 'w', encoding='utf-8').write(s)
    render(f'{base}/design/{name}_ipad.html', f'{base}/design/{name}_ipad.png')

# ウィジェット: スマホ用の絵を、iPad の幅に広げる
s = open(f'{base}/design/Widget2.html', encoding='utf-8').read()
for old, new in [
    ('width:390px;height:844px', f'width:{W}px;height:{H}px'),
    ('padding:80px 24px 24px', 'padding:44px 24px 24px'),
    ('gap:22px">\n  <div style="display:flex;gap:22px">', 'gap:22px">\n  <div style="display:flex;justify-content:space-between;width:468px">'),
    ('width:342px;height:158px', 'width:468px;height:158px'),
]:
    assert old in s, old
    s = s.replace(old, new)
s = s.replace('row-gap:22px">', 'row-gap:22px;height:62px;overflow:hidden">')
open(f'{base}/design/Widget2_ipad.html', 'w', encoding='utf-8').write(s)
render(f'{base}/design/Widget2_ipad.html', f'{base}/design/Widget2_ipad.png')

for src, dst in [('Notify2_ipad', '5_notify'), ('Widget2_ipad', '6_widget'), ('Plus2_ipad', '3_plus')]:
    shutil.copy(f'{base}/design/{src}.png', f'{base}/shots/ipad/{dst}.png')
print('done')
