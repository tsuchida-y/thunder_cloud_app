import shutil, subprocess

base = '/Users/tsuchida/.claude/jobs/9e15aab3/tmp'
docs = '/Users/tsuchida/Documents/Programming/Myapp/thunder_cloud_app/.claude/worktrees/plus-manage/docs/design'
chrome = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'


def render(html_path, png_path):
    subprocess.run([chrome, '--headless=new', '--disable-gpu', '--hide-scrollbars',
                    '--window-size=390,844', '--force-device-scale-factor=3.3846',
                    '--virtual-time-budget=15000', f'--screenshot={png_path}', f'file://{html_path}'],
                   check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


# 通知: 見本の HTML から、設計メモの一行（長押しのボタンの説明）を消し、いまのアプリの値に合わせる
s = open(f'{docs}/Notify.html', encoding='utf-8').read()
note = '      <div style="font-size: 12px; color: #47597A; margin-top: 6px">通知を長押しすると出るボタン</div>\n'
assert note in s
s = s.replace(note, '')
for old, new in [
    ('8月12日 火曜日', '11月6日 金曜日'),
    ('>15:24<', '>9:41<'),
    ('南東の空に、入道雲が現れました', '北東の空に、入道雲が現れました'),
    ('約42km先。こぶし1つ半の高さを見上げてみて。', '約24km先。こぶし2つ半の高さを見上げてみて。'),
]:
    assert old in s, old
    s = s.replace(old, new)
open(f'{base}/design/Notify2.html', 'w', encoding='utf-8').write(s)
render(f'{base}/design/Notify2.html', f'{base}/design/Notify2.png')

# ウィジェット: ホーム画面風の背景に、見本のウィジェット（小・小（雲がないとき）・中）を並べる
icons = ''.join(
    f'<div style="width:62px;height:62px;border-radius:15px;background:rgba(255,255,255,{a});"></div>'
    for a in [.22, .18, .26, .2, .24, .18, .22, .26]
)
widget = f'''<!doctype html><html lang="ja"><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Outfit:wght@600&family=Zen+Maru+Gothic:wght@500;700&display=swap" rel="stylesheet">
<style>html,body{{margin:0}}</style></head><body>
<div style="width:390px;height:844px;box-sizing:border-box;position:relative;overflow:hidden;color:#fff;font-family:'Zen Maru Gothic',sans-serif;
 background:linear-gradient(170deg,#243B6B 0%,#5B7FB8 45%,#E7B7A3 100%);padding:80px 24px 24px;display:flex;flex-direction:column;gap:22px">
  <div style="display:flex;gap:22px">
    <div style="width:158px;height:158px;box-sizing:border-box;border-radius:26px;background:linear-gradient(180deg,#1C4FA8,#3A7BC8);padding:14px;display:flex;flex-direction:column;justify-content:space-between;box-shadow:0 8px 24px rgba(10,20,50,.25)">
      <div style="display:flex;justify-content:space-between;align-items:center">
        <div style="font-size:12px;font-weight:700">入道雲</div>
        <svg width="44" height="44" viewBox="0 0 44 44"><circle cx="22" cy="22" r="20" fill="#fff" fill-opacity=".18" stroke="#fff" stroke-opacity=".6"/>
          <text x="22" y="10" text-anchor="middle" font-family="Outfit,sans-serif" font-size="7" font-weight="600" fill="#fff">N</text>
          <circle cx="32" cy="12" r="5" fill="#fff"/><circle cx="22" cy="22" r="2.5" fill="#fff"/></svg>
      </div>
      <div><div style="font-size:26px;font-weight:700">北東</div>
        <div style="font-family:Outfit,sans-serif;font-size:15px;font-weight:600">24km</div></div>
    </div>
    <div style="width:158px;height:158px;box-sizing:border-box;border-radius:26px;background:linear-gradient(180deg,#2A62B8,#4F8AD0);padding:14px;display:flex;flex-direction:column;justify-content:space-between;box-shadow:0 8px 24px rgba(10,20,50,.25)">
      <div style="font-size:12px;font-weight:700">入道雲 ・ 家</div>
      <div style="font-size:18px;font-weight:700;line-height:1.3">静かな空</div>
    </div>
  </div>
  <div style="width:342px;height:158px;box-sizing:border-box;border-radius:26px;background:linear-gradient(180deg,#1C4FA8,#3A7BC8);padding:14px 16px;display:flex;gap:14px;align-items:center;box-shadow:0 8px 24px rgba(10,20,50,.25)">
    <svg width="120" height="120" viewBox="0 0 120 120"><circle cx="60" cy="60" r="56" fill="#fff" fill-opacity=".16" stroke="#fff" stroke-opacity=".6"/>
      <circle cx="60" cy="60" r="30" fill="none" stroke="#fff" stroke-opacity=".4" stroke-dasharray="2 4"/>
      <text x="60" y="16" text-anchor="middle" font-family="Outfit,sans-serif" font-size="10" font-weight="600" fill="#fff">N</text>
      <circle cx="92" cy="28" r="9" fill="#fff"/><circle cx="60" cy="60" r="4" fill="#fff"/></svg>
    <div style="display:flex;flex-direction:column;gap:4px">
      <div style="font-size:12px;font-weight:700">入道雲 ・ 滝沢市</div>
      <div style="font-size:20px;font-weight:700">北東に入道雲</div>
      <div style="font-size:13px">約24km先</div>
      <div style="font-size:13px">こぶし2つ半の高さ</div></div>
  </div>
  <div style="display:grid;grid-template-columns:repeat(4,62px);justify-content:space-between;row-gap:22px">{icons}</div>
  <div style="flex-grow:1"></div>
  <div style="height:86px;border-radius:34px;background:rgba(255,255,255,.22);display:flex;justify-content:space-around;align-items:center;padding:0 14px">
    <div style="width:62px;height:62px;border-radius:15px;background:rgba(255,255,255,.3)"></div>
    <div style="width:62px;height:62px;border-radius:15px;background:rgba(255,255,255,.3)"></div>
    <div style="width:62px;height:62px;border-radius:15px;background:rgba(255,255,255,.3)"></div>
    <div style="width:62px;height:62px;border-radius:15px;background:rgba(255,255,255,.3)"></div>
  </div>
</div></body></html>'''
open(f'{base}/design/Widget2.html', 'w', encoding='utf-8').write(widget)
render(f'{base}/design/Widget2.html', f'{base}/design/Widget2.png')

# Plus: 見本の HTML の見出しと説明を、いまのアプリの文に合わせる
s = open(f'{docs}/Plus.html', encoding='utf-8').read()
for old, new in [
    ('>もっと遠くの入道雲まで、<', '>もっと遠くまで、<'),
    ('>見張る。<', '>いくつもの空を。<'),
    ('家や学校、職場の空も見張る', '家や学校、職場の空も見張って、ホームで切り替え'),
]:
    assert old in s, old
    s = s.replace(old, new)
open(f'{base}/design/Plus2.html', 'w', encoding='utf-8').write(s)
render(f'{base}/design/Plus2.html', f'{base}/design/Plus2.png')

# iPhone の撮影用の置き場に入れる（Plus は、シミュレータがドル表示なので、見本の絵に置き換える）
shutil.copy(f'{base}/design/Plus2.png', f'{base}/shots/iphone/3_plus.png')
shutil.copy(f'{base}/design/Notify2.png', f'{base}/shots/iphone/5_notify.png')
shutil.copy(f'{base}/design/Widget2.png', f'{base}/shots/iphone/6_widget.png')
print('done')
