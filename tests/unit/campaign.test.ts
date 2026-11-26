import { describe, expect, it } from 'vitest';
import { loadContent } from '../../src/content';
import {
  availableOps,
  axisKnowledge,
  deserialize,
  dispatch,
  memoryStorage,
  newCampaign,
  serialize,
  unreadCables,
  type Action,
  type CampaignState,
  type GameEvent,
} from '../../src/engine/campaign';

const content = loadContent();

/** Правильный маршрут SDR: три бытовые точки в трёх разных районах внутри 25-мильной зоны. */
const GOOD_ROUTE = ['site_peoples_drug_connecticut', 'site_georgetown_post_office', 'site_lee_highway_cleaners'];

/** Применяет действия по очереди. Отклонённое действие валит тест с понятным текстом. */
function play(state: CampaignState, actions: Action[]): { state: CampaignState; events: GameEvent[] } {
  const events: GameEvent[] = [];
  let s = state;
  for (const a of actions) {
    const r = dispatch(s, content, a);
    if (r.error) throw new Error(`Действие ${JSON.stringify(a)} отклонено: ${r.error}`);
    s = r.state;
    events.push(...r.events);
  }
  return { state: s, events };
}

const next: Action = { type: 'advance_phase' };
const report = (r: 'truth' | 'embellished' | 'silence'): Action => ({ type: 'submit_report', report: r });
/** Тихая неделя: утро → день → вечер → ночь → донесение. */
const quietWeek = (r: 'truth' | 'embellished' | 'silence' = 'truth'): Action[] => [next, next, next, report(r)];

describe('новая кампания', () => {
  it('стартует утром первой недели Акта I с числами из balance.json и свежей почтой', () => {
    const { state } = newCampaign(content);
    expect(state).toMatchObject({ act: 1, week: 1, phase: 'morning', centre_trust: 50, fund_usd: 40000 });
    expect(state.risks).toEqual({ sog_heat: 10, mole_hunt: 0, treasury: 0, moscow_pressure: 20 });
    expect(state.delivered_cables.sort()).toEqual(
      ['cable_a1_w1_directive', 'cable_a1_w1_file_vargas', 'cable_a1_w1_post_clipping'].sort(),
    );
    expect(state.clues.sort()).toEqual(['clue_calloway_post_review', 'clue_vargas_bank_position']);
    expect(unreadCables(state)).toHaveLength(3);
    expect(availableOps(state, content)).toEqual([]); // первая операция — со 2-й недели
  });
});

describe('три недели с разными решениями', () => {
  it('осторожный резидент: замечает хвост, сворачивает, возвращается и вербует Кэллоуэя', () => {
    let { state } = newCampaign(content);

    // Неделя 1: тихая, честный доклад.
    ({ state } = play(state, quietWeek()));
    expect(state).toMatchObject({ week: 2, phase: 'morning', centre_trust: 52 });
    expect(state.risks.sog_heat).toBe(6); // оперативная пауза: −4

    // Неделя 2: выход к банку, хвост замечен — свернул на бытовую легенду. Доложил правду о сбое.
    ({ state } = play(state, [
      next,
      { type: 'plan_op', op_id: 'op_a1_recon_first_virginia', route: GOOD_ROUTE },
      next,
      { type: 'resolve_op', op_id: 'op_a1_recon_first_virginia', decision: 'abort' },
      next,
      report('truth'),
    ]));
    expect(state.op_results.op_a1_recon_first_virginia).toBe('aborted');
    expect(state.centre_trust).toBe(47); // 52 − 5 за честный доклад о сбое
    expect(state.risks.moscow_pressure).toBe(28); // 20 + 8
    expect(state.risks.sog_heat).toBe(6); // хвост не получил ничего

    // Неделя 3: повторный выход к банку проходит чисто, плюс вечер в баре. Вербовка Кэллоуэя.
    const w3 = play(state, [
      next,
      { type: 'plan_op', op_id: 'op_a1_recon_first_virginia', route: GOOD_ROUTE },
      { type: 'plan_op', op_id: 'op_a1_recon_potomac_cellar', route: GOOD_ROUTE },
      next,
      { type: 'resolve_op', op_id: 'op_a1_recon_first_virginia', decision: 'continue' },
      { type: 'resolve_op', op_id: 'op_a1_recon_potomac_cellar', decision: 'continue' },
    ]);
    state = w3.state;
    expect(state.op_results.op_a1_recon_first_virginia).toBe('clean');
    // Свёрнутый выход до точки не доехал, поэтому повторным посещением он не считается.
    expect(state.risks.sog_heat).toBe(6);
    expect(state.targets.tar_vargas_ellen?.unlocked).toBe(true);
    expect(state.targets.tar_calloway_martin?.unlocked).toBe(true);
    expect(axisKnowledge(state, content, 'tar_calloway_martin', 'ego')).toBe('confirmed'); // 3 улики
    expect(axisKnowledge(state, content, 'tar_calloway_martin', 'money')).toBe('hypothesis');

    const end = play(state, [
      { type: 'recruitment', target_id: 'tar_calloway_martin', result: 'success' },
      next,
      report('truth'),
    ]);
    expect(end.state.targets.tar_calloway_martin?.recruited).toBe(true);
    expect(end.events).toContainEqual({ type: 'act_completed', act: 1 });
    expect(end.state.ending).toBe('campaign_complete'); // Акт II ещё не описан в campaign.json
    expect(end.state.risks.moscow_pressure).toBe(3); // 28 − 25 за выполненную цель акта
  });

  it('лихой резидент: пропускает хвост, проваливает Варгас, приукрашивает доклад', () => {
    let { state } = newCampaign(content);
    ({ state } = play(state, quietWeek()));

    // Неделя 2: хвост не замечен — улики добыты, но ФБР сфотографировало визит.
    ({ state } = play(state, [
      next,
      { type: 'plan_op', op_id: 'op_a1_recon_first_virginia', route: GOOD_ROUTE },
      next,
      { type: 'resolve_op', op_id: 'op_a1_recon_first_virginia', decision: 'continue' },
    ]));
    expect(state.op_results.op_a1_recon_first_virginia).toBe('tail_missed');
    expect(state.risks.sog_heat).toBe(31); // 6 + 25 из ignore_consequence операции
    expect(state.flags).toContain('fbi_noted_arlington_bank_visit');
    expect(state.targets.tar_vargas_ellen?.unlocked).toBe(true);

    // Компромат ещё не вскрыт — успешной вербовки быть не может.
    const premature = dispatch(state, content, { type: 'recruitment', target_id: 'tar_vargas_ellen', result: 'success' });
    expect(premature.error).toMatch(/компромат/);
    expect(premature.state).toBe(state);

    ({ state } = play(state, [
      { type: 'recruitment', target_id: 'tar_vargas_ellen', result: 'failed' },
      next,
      report('embellished'),
    ]));
    expect(state.targets.tar_vargas_ellen?.lost).toBe(true);
    expect(state.risks.sog_heat).toBe(46); // + 15 за проваленный подход
    expect(state.centre_trust).toBe(58); // 52 + 6 за приукрашенный доклад…
    expect(state.lies).toEqual([{ week: 2, kind: 'embellished' }]); // …но ложь записана

    // Неделя 3: Варгас потеряна, но к Кэллоуэю ведут другие пути («Правило трёх улик»).
    ({ state } = play(state, [
      next,
      { type: 'plan_op', op_id: 'op_a1_recon_potomac_cellar', route: GOOD_ROUTE },
      next,
      { type: 'resolve_op', op_id: 'op_a1_recon_potomac_cellar', decision: 'continue' },
      { type: 'recruitment', target_id: 'tar_calloway_martin', result: 'success' },
      next,
      report('silence'),
    ]));
    expect(state.targets.tar_calloway_martin?.recruited).toBe(true);
    expect(state.lies).toHaveLength(1); // умолчание без сбоев — не ложь
    expect(state.ending).toBe('campaign_complete');
  });

  it('бездействие: Центр теряет терпение и отзывает резидента', () => {
    let { state } = newCampaign(content);
    while (!state.ending) ({ state } = play(state, quietWeek()));
    expect(state.ending).toBe('recalled');
    // 3 недели льготы, затем +4/неделю до конца акта (6-я неделя), затем +12/неделю.
    expect(state.week).toBe(12);
    expect(state.risks.moscow_pressure).toBe(100);
    expect(state.risks.sog_heat).toBe(0);
  });
});

describe('правила фаз', () => {
  it('отклоняет действия не в свою фазу и не меняет состояние', () => {
    const { state } = newCampaign(content);
    for (const a of [
      { type: 'plan_op', op_id: 'op_a1_recon_first_virginia', route: GOOD_ROUTE },
      { type: 'submit_report', report: 'truth' },
      { type: 'recruitment', target_id: 'tar_vargas_ellen', result: 'success' },
    ] as Action[]) {
      const r = dispatch(state, content, a);
      expect(r.error).toBeTruthy();
      expect(r.state).toBe(state);
      expect(r.events).toEqual([]);
    }
  });

  it('нельзя уйти из вечера, не разыграв запланированные операции', () => {
    let { state } = newCampaign(content);
    ({ state } = play(state, [...quietWeek(), next, { type: 'plan_op', op_id: 'op_a1_recon_first_virginia', route: GOOD_ROUTE }, next]));
    expect(dispatch(state, content, next).error).toMatch(/Не разыграны/);
  });

  it('лимит операций на неделю берётся из balance.json', () => {
    let { state } = newCampaign(content);
    ({ state } = play(state, [...quietWeek(), ...quietWeek(), next]));
    const ops = availableOps(state, content);
    expect(ops.length).toBeGreaterThanOrEqual(2);
    ({ state } = play(state, ops.slice(0, 2).map((o) => ({ type: 'plan_op', op_id: o.op_id, route: GOOD_ROUTE }) as Action)));
    expect(state.planned_ops).toHaveLength(content.balance.ops.per_week);
  });

  it('исходное состояние не мутируется', () => {
    const { state } = newCampaign(content);
    const snapshot = structuredClone(state);
    play(state, quietWeek());
    expect(state).toEqual(snapshot);
  });
});

describe('ложь в донесениях', () => {
  it('результат сверки детерминирован: одно и то же зерно — один и тот же итог', () => {
    const run = () => {
      let { state } = newCampaign(content);
      for (let i = 0; i < 8 && !state.ending; i++) ({ state } = play(state, quietWeek('embellished')));
      return state;
    };
    const a = run();
    const b = run();
    expect(a).toEqual(b);
    expect(a.lies.length).toBeLessThanOrEqual(1); // сверки на 4-й и 8-й неделе очистили список
  });
});

describe('сохранение и загрузка', () => {
  it('сохранение и загрузка дают то же состояние, и игра продолжается одинаково', () => {
    let { state } = newCampaign(content);
    ({ state } = play(state, [...quietWeek('embellished'), next, { type: 'plan_op', op_id: 'op_a1_recon_first_virginia', route: GOOD_ROUTE }]));

    const storage = memoryStorage();
    storage.write('autosave', serialize(state));
    const loaded = deserialize(storage.read('autosave')!, content);
    if (!loaded.ok) throw new Error(loaded.error);
    expect(loaded.state).toEqual(state);

    const rest: Action[] = [
      next,
      { type: 'resolve_op', op_id: 'op_a1_recon_first_virginia', decision: 'continue' },
      next,
      report('embellished'),
      ...quietWeek('embellished'),
      ...quietWeek('embellished'),
    ];
    expect(play(loaded.state, rest).state).toEqual(play(state, rest).state);
  });

  it('повреждённое сохранение не загружается, а объясняет почему', () => {
    expect(deserialize('{не json', content)).toEqual({ ok: false, error: expect.stringContaining('не JSON') });
    const { state } = newCampaign(content);
    const broken = JSON.parse(serialize(state));
    broken.state.week = 'вторник';
    expect(deserialize(JSON.stringify(broken), content)).toMatchObject({ ok: false, error: expect.stringContaining('week') });
  });

  it('сохранение со ссылкой на удалённый из контента id не загружается', () => {
    const { state } = newCampaign(content);
    const save = JSON.parse(serialize(state));
    save.state.clues.push('clue_deleted_long_ago');
    expect(deserialize(JSON.stringify(save), content)).toMatchObject({
      ok: false,
      error: expect.stringContaining('clue_deleted_long_ago'),
    });
  });
});

describe('наружка', () => {
  it('повторный выход на ту же точку поднимает SOG Heat', () => {
    let { state } = newCampaign(content);
    ({ state } = play(state, [
      ...quietWeek(),
      ...quietWeek(),
      next,
      { type: 'plan_op', op_id: 'op_a1_recon_first_virginia', route: GOOD_ROUTE },
      next,
      { type: 'resolve_op', op_id: 'op_a1_recon_first_virginia', decision: 'abort' },
      next,
      report('truth'),
      next,
      { type: 'plan_op', op_id: 'op_a1_recon_first_virginia', route: GOOD_ROUTE },
      next,
      { type: 'resolve_op', op_id: 'op_a1_recon_first_virginia', decision: 'continue' },
      next,
      report('truth'),
      next,
      { type: 'plan_op', op_id: 'op_a1_closing_time_vargas', route: GOOD_ROUTE },
      next,
    ]));
    const before = state.risks.sog_heat;
    ({ state } = play(state, [{ type: 'resolve_op', op_id: 'op_a1_closing_time_vargas', decision: 'continue' }]));
    expect(state.risks.sog_heat).toBe(before + content.balance.sog_heat.site_reuse_per_use);
  });
});

describe('маршрут SDR', () => {
  const GEORGETOWN_ONLY = ['site_georgetown_post_office', 'site_wisconsin_bookshop', 'site_m_street_tobacconist'];
  /** Утро → день 2-й недели: первые операции уже доступны. */
  const week2Day = () => play(newCampaign(content).state, [...quietWeek(), next]).state;
  const counts = (obs: string[][]) => {
    const m = new Map<string, number>();
    for (const stop of obs) for (const tag of new Set(stop)) m.set(tag, (m.get(tag) ?? 0) + 1);
    return m;
  };

  it('правильный маршрут через три района: хвост мелькает ровно дважды, остальное не повторяется', () => {
    // Проверяем на разных зёрнах, чтобы правило не держалось на удаче.
    for (let seed = 1; seed <= 25; seed++) {
      const s0 = { ...week2Day(), rng: seed };
      const { state } = play(s0, [{ type: 'plan_op', op_id: 'op_a1_recon_first_virginia', route: GOOD_ROUTE }]);
      const obs = state.routes.op_a1_recon_first_virginia!.observations;
      const c = counts(obs);
      expect(c.get('light_blue_ford_ltd')).toBe(2);
      for (const [tag, n] of c) if (tag !== 'light_blue_ford_ltd') expect(n, tag).toBe(1);
    }
  });

  it('маршрут в одном районе: хвост мелькает один раз — заметить его нельзя', () => {
    const { state } = play(week2Day(), [{ type: 'plan_op', op_id: 'op_a1_recon_first_virginia', route: GEORGETOWN_ONLY }]);
    expect(counts(state.routes.op_a1_recon_first_virginia!.observations).get('light_blue_ford_ltd')).toBe(1);
  });

  it('без хвоста ни одна примета не повторяется', () => {
    let state = play(newCampaign(content).state, [...quietWeek(), ...quietWeek(), next]).state;
    ({ state } = play(state, [{ type: 'plan_op', op_id: 'op_a1_recon_potomac_cellar', route: GOOD_ROUTE }]));
    for (const [, n] of counts(state.routes.op_a1_recon_potomac_cellar!.observations)) expect(n).toBe(1);
  });

  it('неверный маршрут отклоняется', () => {
    const s = week2Day();
    const bad: string[][] = [
      GOOD_ROUTE.slice(0, 2),
      [GOOD_ROUTE[0]!, GOOD_ROUTE[0]!, GOOD_ROUTE[1]!],
      [GOOD_ROUTE[0]!, GOOD_ROUTE[1]!, 'site_potomac_cellar'],
      [GOOD_ROUTE[0]!, GOOD_ROUTE[1]!, 'site_nowhere'],
    ];
    for (const route of bad) {
      expect(dispatch(s, content, { type: 'plan_op', op_id: 'op_a1_recon_first_virginia', route }).error).toMatch(/Проверочный маршрут/);
    }
  });

  it('точка за 25 милями поднимает наружку, даже если операцию свернули', () => {
    const route = ['site_leesburg_antiques', 'site_georgetown_post_office', 'site_lee_highway_cleaners'];
    let state = week2Day();
    const before = state.risks.sog_heat;
    ({ state } = play(state, [
      { type: 'plan_op', op_id: 'op_a1_recon_first_virginia', route },
      next,
      { type: 'resolve_op', op_id: 'op_a1_recon_first_virginia', decision: 'abort' },
    ]));
    expect(state.risks.sog_heat).toBe(before + content.balance.sog_heat.outside_25_mile_zone);
    expect(state.routes).toEqual({});
  });

  it('отмена операции убирает маршрут', () => {
    const { state } = play(week2Day(), [
      { type: 'plan_op', op_id: 'op_a1_recon_first_virginia', route: GOOD_ROUTE },
      { type: 'cancel_op', op_id: 'op_a1_recon_first_virginia' },
    ]);
    expect(state.routes).toEqual({});
    expect(state.planned_ops).toEqual([]);
  });
});
