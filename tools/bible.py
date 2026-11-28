#!/usr/bin/env python3
"""Указатели библии игры (docs/game-bible.md) — собираются из content/ и вставляются между
метками <!-- AUTO:BEGIN --> и <!-- AUTO:END -->. Запуск после любой правки контента:
    python3 tools/bible.py
Текст до меток (эпоха, персонажи, линии) пишется вручную и правится вместе с сюжетом."""
import json, glob, os, datetime, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
C = lambda p: os.path.join(ROOT, 'content', p)
BIBLE = os.path.join(ROOT, 'docs', 'game-bible.md')

def L(x):
    return x.get('ru', '') if isinstance(x, dict) else (x or '')

def load(p):
    return json.load(open(p, encoding='utf-8'))

def items(folder):
    out = []
    for f in sorted(glob.glob(C(folder + '/*.json'))):
        d = load(f)
        out.extend(d if isinstance(d, list) else [d])
    return out

def short(t, n=160):
    t = re.sub(r'\s+', ' ', t).strip()
    return t if len(t) <= n else t[:n].rsplit(' ', 1)[0] + '…'

camp = load(C('campaign.json'))
acts = {a['act']: a for a in camp['acts']}
PHASE = {1: 'Первая', 2: 'Вторая', 3: 'Третья', 4: 'Четвёртая', 5: 'Пятая'}
MONTHS = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря']

def date(act, week):
    a = acts.get(act)
    if not a:
        return ''
    d = datetime.date.fromisoformat(a['start_date']) + datetime.timedelta(days=(week - a['weeks']['from']) * a.get('days_per_week', 7))
    return f'{d.day} {MONTHS[d.month - 1]} {d.year}'

targets = {t['target_id']: t for t in items('targets')}
FLAG = {'false_flag': 'под чужим флагом', 'true_flag': 'под своим флагом', 'contactless': 'бесконтактно', 'indirect': 'через посредника'}
CHANNEL = {'document': 'документ', 'field': 'выход в город', 'agent': 'донесение агента', 'meeting': 'беседа', 'evidence': 'вещдок'}
def who(tid):
    return L(targets[tid]['name']) if tid in targets else tid

out = []
w = out.append
w('<!-- AUTO:BEGIN — раздел собран tools/bible.py из content/, вручную не править -->')
w('')
w('## Приложение А. Указатели (собраны из контента)')
w('')
cnt = {k: len(items(k)) for k in ['targets', 'clues', 'cables', 'ops', 'dialogs', 'decisions', 'list', 'archive', 'tasks', 'evidence', 'achievements']}
w('Объём контента: ' + ', '.join(f'{k} — {v}' for k, v in cnt.items()) + '.')
w('')

w('### А.1. Фазы операции и календарь')
w('')
w('| Фаза | Название | Недели | Даты | Ход | Перевод Центра | Задача |')
w('|---|---|---|---|---|---|---|')
for n, a in sorted(acts.items()):
    g = a['goal']
    goal = 'завербовать: ' + ', '.join(who(t) for t in g['recruit_any_of'])
    if g.get('settle_promise'): goal += '; выплатить обещанное'
    if g.get('clues_all'): goal += '; добыть: ' + ', '.join(g['clues_all'])
    if g.get('flags_all'): goal += '; флаги: ' + ', '.join(g['flags_all'])
    w(f"| {n} | «{L(a['title'])}» | {a['weeks']['from']}–{a['weeks']['to']} | {date(n, a['weeks']['from'])} — {date(n, a['weeks']['to'])} | {a.get('days_per_week', 7)} дн. | {a.get('fund_usd', 0) or '—'} | {goal} |")
    for v in a.get('variants', []):
        if L(v.get('title')):
            w(f"| | вариант «{L(v['title'])}» | | | | | при флагах: {', '.join(v['flags_all'])} |")
w('')
w(f"Демоверсия заканчивается после фазы {camp.get('demo', {}).get('last_act', 0)}.")
w('')

w('### А.2. Кандидаты на вербовку (пирамида)')
w('')
w('| Кандидат | Фаза | Должность | Подход и легенда | Мотивы (истинные значения Д/И/К/С) | Обещание |')
w('|---|---|---|---|---|---|')
for t in sorted(targets.values(), key=lambda x: (x['act'], x['tier'])):
    m = t['mice_profile']
    mice = ' / '.join(str(m[k]['true_value']) for k in ['money', 'ideology', 'compromise', 'ego'])
    code = f" («{t['codename_kgb'].capitalize()}»)" if t.get('codename_kgb') else ''
    w(f"| {L(t['name'])}{code} | {t['act']} | {L(t['role'])} | {FLAG.get(t['approach']['flag_mode'], t['approach']['flag_mode'])}: {L(t['approach']['cover'])} | {mice} | {L(t['finance']['promise'])}, {t['finance']['promised_usd']} долл. |")
w('')

w('### А.3. Сведения (улики) по кандидатам')
w('')
for f in sorted(glob.glob(C('clues/*.json'))):
    base = os.path.splitext(os.path.basename(f))[0]
    tid = next((t for t in targets if base in t), '')
    w(f'**{who(tid) if tid else base}**')
    w('')
    for c in load(f):
        src = c.get('source', {})
        w(f"- {L(c.get('title'))} — {short(L(c.get('text')), 200)} _(канал: {CHANNEL.get(src.get('channel', ''), src.get('channel', ''))}, {src.get('from', '')})_")
    w('')

w('### А.4. Персонажи бесед и разговоров')
w('')
w('| Кто | Сцена | Вид | Когда | Условия |')
w('|---|---|---|---|---|')
for d in items('dialogs'):
    req = d.get('requires') or {}
    when = f"фаза {req.get('act', '')}" + (f", неделя {req['week']}" if req.get('week') else '')
    cond = ', '.join(req.get('flags', [])) or '—'
    person = L(d.get('person')) or who(d.get('target_id', ''))
    kind = {'conversation': 'разговор', 'handling': 'встреча на связи'}.get(d.get('kind', ''), 'вербовочная беседа')
    w(f"| {person} | {L(d['title'])} | {kind} | {when} | {cond} |")
w('')

w('### А.5. Подчинённые резидентуры')
w('')
for o in load(C('operatives/residency.json')):
    w(f"- **{L(o['name'])}** — {L(o['bio'])} (вероятность заметить наружку: {int(o['notice_chance'] * 100)} %)")
w('')

w('### А.6. Места на оперативной карте')
w('')
m = load(C('map/sites.json'))
w('| Место | Район | Роль |')
w('|---|---|---|')
role = {'landmark': 'ориентир', 'target': 'объект', 'stop': 'точка маршрута'}
for s in m['sites']:
    w(f"| {L(s.get('name'))} | {s.get('district', '')} | {role.get(s.get('role'), s.get('role'))} |")
w('')

w('### А.7. Выходы в город (мероприятия на карте)')
w('')
for o in items('ops'):
    w(f"- Фаза {o.get('act')}, неделя {o.get('week')} ({date(o.get('act'), o.get('week', 1))}): **{L(o.get('title'))}**" + (f" — требует: {', '.join(o.get('requires_flags', []))}" if o.get('requires_flags') else ''))
w('')

w('### А.8. Документы по неделям')
w('')
w('Директивы приходят на «Фиалку», остальное — во «Входящие». Документы с условием приходят только после указанного флага.')
w('')
cur = None
kinds = {'directive': 'указание Центра', 'vgu_note': 'ориентировка', 'press_clipping': 'вырезка', 'agent_report': 'рапорт',
         'intercept': 'перехват', 'personnel_file': 'справка', 'letter': 'письмо', 'anonymous': 'анонимное письмо'}
for c in sorted(items('cables'), key=lambda x: (x['act'], x['week'], x['cable_id'])):
    if (c['act'], c['week']) != cur:
        if cur is not None:
            w('')
        cur = (c['act'], c['week'])
        w(f"**{PHASE[c['act']]} фаза, неделя {c['week']} — {date(c['act'], c['week'])}**")
        w('')
    flags = f" _(если: {', '.join(c['requires_flags'])})_" if c.get('requires_flags') else ''
    rep = ' · есть ответ домой' if c.get('reply') else ''
    w(f"- {kinds.get(c['kind'], c['kind'])}, {L(c['sender'])}: «{L(c['subject'])}»{flags}{rep}")
w('')

w('### А.9. Решения резидента')
w('')
for d in sorted(items('decisions'), key=lambda x: (x['act'], x['trigger'].get('week', 0))):
    t = d['trigger']
    cond = ', '.join(x for x in [f"неделя {t['week']}" if t.get('week') else '', f"сведения {t['clue_id']}" if t.get('clue_id') else '', f"флаг {t['flag']}" if t.get('flag') else ''] if x)
    w(f"- **{L(d['title'])}** (фаза {d['act']}{', в любой фазе' if d.get('any_act') else ''}; {cond or 'сразу'}) — {short(L(d['text']), 220)}")
    for o in d['options']:
        fx = {k: v for k, v in o['effects'].items() if v not in (0, '', None)}
        w(f"  - {L(o['label'])} → {short(L(o['outcome']), 160)} `{fx}`")
w('')

w('### А.10. «Список»: восемнадцать дел')
w('')
w('| Дело | Кто | Ущерб | «Ховард» | Естественный провал | Игра |')
w('|---|---|---|---|---|---|')
for c in items('list'):
    w(f"| {L(c.get('name'))} | {L(c.get('role'))} | {c.get('damage')} | {'да' if c.get('howard') else '—'} | {'да' if c.get('natural') else '—'} | {'да' if c.get('game') else '—'} |")
w('')

w('### А.11. Задания Центра')
w('')
for t in items('tasks'):
    w(f"- Фаза {t['act']}, неделя {t['week']}, срок {t['due_weeks']} нед.: **{L(t['title'])}**" + (f" (если завербован: {who(t['requires_recruited'])})" if t.get('requires_recruited') else ''))
w('')

w('### А.12. Вещественные доказательства')
w('')
for it in items('evidence'):
    right = [L(d['label']) for s in it['sides'] for d in s['details'] if d.get('correct')]
    w(f"- Фаза {it['act']}, неделя {it['week']}: **{L(it['title'])}** — {L(it['source'])}. Важно: {'; '.join(right)}.")
w('')

w('### А.13. «Архив 1985»')
w('')
sec = {'history': 'История', 'technique': 'Техника', 'law': 'Законы', 'fiction': 'Факт и вымысел', 'epilogue': 'Эпилог'}
for s_id, s_name in sec.items():
    rows = [a for a in items('archive') if a['section'] == s_id]
    w(f"**{s_name}** ({len(rows)}): " + '; '.join(f"{L(a['title'])}" + (f" _[{a['unlock']}]_" if a.get('unlock') else '') for a in rows))
    w('')

w('### А.14. Достижения')
w('')
for a in items('achievements'):
    w(f"- {L(a.get('name') or a.get('title'))} — {L(a.get('description'))}")
w('')
w('<!-- AUTO:END -->')

text = open(BIBLE, encoding='utf-8').read() if os.path.exists(BIBLE) else '# Библия игры\n\n'
block = '\n'.join(out)
if '<!-- AUTO:BEGIN' in text:
    text = re.sub(r'<!-- AUTO:BEGIN.*?<!-- AUTO:END -->', lambda _: block, text, flags=re.S)
else:
    text = text.rstrip() + '\n\n' + block + '\n'
open(BIBLE, 'w', encoding='utf-8').write(text)
print('Указатели обновлены:', BIBLE, f'({len(block.split())} слов в приложении)')
