import { describe, expect, it } from 'vitest';
import { simulate, validateContent, type RawFile } from '../../src/engine/content';
import { readContentDir } from '../../tools/content-fs';

/** Свежая копия настоящего контента из src/content, которую тест может портить. */
function content(): RawFile[] {
  const { entries, broken } = readContentDir();
  expect(broken).toEqual([]);
  return structuredClone(entries);
}

function file(entries: RawFile[], path: string) {
  const f = entries.find((e) => e.path === path);
  if (!f) throw new Error(`нет файла ${path}`);
  return f;
}

type Json = Record<string, unknown> & { [k: string]: any }; // eslint-disable-line @typescript-eslint/no-explicit-any

function clue(entries: RawFile[], id: string): Json {
  for (const e of entries.filter((x) => x.path.startsWith('clues/'))) {
    const found = (e.data as Json[]).find((c) => c.clue_id === id);
    if (found) return found;
  }
  throw new Error(`нет улики ${id}`);
}

const rules = (entries: RawFile[]) => validateContent(entries).errors.map((e) => e.rule);

describe('валидатор контента', () => {
  it('настоящий контент проходит без ошибок', () => {
    const report = validateContent(content());
    expect(report.errors).toEqual([]);
    expect(report.content?.targets.length).toBeGreaterThanOrEqual(2);
  });

  it('ловит сломанную улику: ссылка на несуществующую операцию', () => {
    const entries = content();
    clue(entries, 'clue_vargas_mortgage_desk').source.from = 'op_a1_recon_nowhere';
    const report = validateContent(entries);
    expect(report.errors).toContainEqual(
      expect.objectContaining({ rule: 'refs', file: 'clues/vargas.json', message: expect.stringContaining('op_a1_recon_nowhere') }),
    );
  });

  it('ловит ошибку схемы и сообщает её по-русски с путём внутри файла', () => {
    const entries = content();
    clue(entries, 'clue_vargas_hospital_calls').source.channel = 'telepathy';
    const [err] = validateContent(entries).errors;
    expect(err).toMatchObject({ rule: 'schema', file: 'clues/vargas.json' });
    expect(err?.where).toMatch(/^\[\d+\]\.source/);
    expect(err?.message).toMatch(/[а-я]/);
  });

  it('«Правило трёх улик»: цель, к которой ведут только два источника, — ошибка', () => {
    const entries = content();
    const target = file(entries, 'targets/tar_vargas_ellen.json').data as Json;
    target.unlock.clue_ids = ['clue_vargas_bank_position', 'clue_vargas_mortgage_desk'];
    expect(rules(entries)).toContain('three-clue');
  });

  it('«Правило трёх улик»: если без одного источника улик не хватает — тупик', () => {
    const entries = content();
    const target = file(entries, 'targets/tar_vargas_ellen.json').data as Json;
    target.unlock.clues_required = 3;
    const report = validateContent(entries);
    expect(report.errors.filter((e) => e.rule === 'three-clue')).toHaveLength(3);
  });

  it('ведущая ось MICE, которую вскрывают меньше трёх улик, — ошибка', () => {
    const entries = content();
    clue(entries, 'clue_calloway_vgu_profile').reveals = [];
    expect(rules(entries)).toContain('mice-three-clue');
  });

  it('софтлок: цель акта недостижима', () => {
    const entries = content();
    const campaign = file(entries, 'campaign.json').data as Json;
    // Добавляем в контент цель, которую невозможно открыть, и делаем её единственной целью акта.
    const ghost = structuredClone(file(entries, 'targets/tar_vargas_ellen.json'));
    Object.assign(ghost.data as Json, { target_id: 'tar_ghost' });
    (ghost.data as Json).unlock.clue_ids = ['clue_vargas_bank_position', 'clue_vargas_mortgage_desk', 'clue_vargas_closing_recount'];
    (ghost.data as Json).unlock.clues_required = 3;
    ghost.path = 'targets/tar_ghost.json';
    entries.push(ghost);
    campaign.acts[0].goal.recruit_any_of = ['tar_ghost'];
    expect(rules(entries)).toContain('softlock');
  });

  it('устойчивость: провал одной ветки не должен блокировать акт', () => {
    const entries = content();
    // Кэллоуэй становится открываемым только через агента Варгас → при провале Варгас тупик.
    for (const id of ['clue_calloway_rent_call', 'clue_calloway_eviction_notice']) clue(entries, id).reveals = [];
    const campaign = file(entries, 'campaign.json').data as Json;
    campaign.acts[0].goal.recruit_any_of = ['tar_calloway_martin'];
    const report = validateContent(entries);
    expect(report.errors).toContainEqual(
      expect.objectContaining({ rule: 'robustness', message: expect.stringContaining('tar_vargas_ellen') }),
    );
  });

  it('SDR: хвост, примета которого не повторяется, — ошибка', () => {
    const entries = content();
    const op = file(entries, 'ops/op_a1_recon_first_virginia.json').data as Json;
    op.sdr_route.waypoints[2].spotted_tags = ['brown_cap'];
    expect(rules(entries)).toContain('sdr');
  });

  it('SDR: повтор примет без хвоста — ложный сигнал', () => {
    const entries = content();
    const op = file(entries, 'ops/op_a1_recon_potomac_cellar.json').data as Json;
    op.sdr_route.waypoints[1].spotted_tags = ['green_volvo'];
    expect(rules(entries)).toContain('sdr');
  });

  it('документ длиннее 150 слов — ошибка', () => {
    const entries = content();
    clue(entries, 'clue_vargas_drawer_memo').text.ru = 'слово '.repeat(151);
    expect(rules(entries)).toContain('text-length');
  });

  it('повтор id — ошибка', () => {
    const entries = content();
    clue(entries, 'clue_calloway_rent_call').clue_id = 'clue_vargas_drawer_memo';
    expect(rules(entries)).toContain('duplicate');
  });

  it('неделя вне рамок акта — ошибка', () => {
    const entries = content();
    (file(entries, 'ops/op_a1_recon_potomac_cellar.json').data as Json).week = 12;
    expect(rules(entries)).toContain('weeks');
  });

  it('формула полиграфа с неизвестной переменной — ошибка', () => {
    const entries = content();
    const exam = file(entries, 'polygraph/exam_cia_may_1986.json').data as Json;
    exam.question_sequence[1].pass_formula = 'luck >= 50';
    expect(rules(entries)).toContain('polygraph');
  });
});

describe('симуляция «идеального игрока»', () => {
  it('в Акте I можно завербовать обе цели и получить все улики', () => {
    const report = validateContent(content());
    const res = simulate(report.content!, { maxAct: 1 });
    expect([...res.recruitedTargets].sort()).toEqual(['tar_calloway_martin', 'tar_vargas_ellen']);
    expect(res.clues.size).toBe(report.content!.clues.length);
  });

  it('если вербовка Варгас провалилась, Кэллоуэй всё равно достижим', () => {
    const report = validateContent(content());
    const res = simulate(report.content!, { maxAct: 1, failedTargets: new Set(['tar_vargas_ellen']) });
    expect(res.recruitedTargets.has('tar_calloway_martin')).toBe(true);
  });
});
