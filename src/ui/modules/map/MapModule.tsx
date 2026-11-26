import { availableOps } from '../../../engine/campaign';
import { analyzeRoute, siteById, type RouteIssue } from '../../../engine/map';
import type { I18nKey } from '../../../i18n';
import type { Op } from '../../../schemas';
import { sogMarks } from '../../signals';
import { content, useDeskStore, useLocalized, useT } from '../../store';
import { districtColor, MapCanvas } from './MapCanvas';
import './map.css';

const opById = (id: string | null | undefined): Op | undefined => content.ops.find((o) => o.op_id === id);

function useIssueText() {
  const t = useT();
  const loc = useLocalized();
  return (issue: RouteIssue): string => {
    switch (issue.kind) {
      case 'few_districts':
        return t('sdr.warn.fewDistricts', { districts: issue.districts });
      case 'outside_zone':
        return t('sdr.warn.outsideZone', { name: loc(siteById(content, issue.site_id)?.name ?? { ru: issue.site_id }) });
      default:
        return t('sdr.warn.invalid');
    }
  };
}

/** День: выбор операции и прокладка маршрута из трёх бытовых точек. */
function PlanPanel() {
  const t = useT();
  const loc = useLocalized();
  const issueText = useIssueText();
  const game = useDeskStore((s) => s.game);
  const draft = useDeskStore((s) => s.mapDraft);
  const setDraft = useDeskStore((s) => s.setMapDraft);
  const dispatch = useDeskStore((s) => s.dispatch);

  const ops = availableOps(game, content);
  const op = ops.find((o) => o.op_id === draft.opId);
  const limitReached = game.planned_ops.length >= content.balance.ops.per_week;
  const analysis = analyzeRoute(content, draft.stops);
  const toggle = (id: string) =>
    setDraft({
      opId: draft.opId,
      stops: draft.stops.includes(id) ? draft.stops.filter((x) => x !== id) : draft.stops.length < 3 ? [...draft.stops, id] : draft.stops,
    });

  const stopsByDistrict = Object.entries(content.map.districts)
    .map(([id, name]) => ({ id, name, stops: content.map.sites.filter((s) => s.role === 'stop' && s.district === id) }))
    .filter((d) => d.stops.length);

  return (
    <>
      <h3>{t('sdr.plan.title')}</h3>
      {ops.length === 0 && <p className="map-panel__note">{t('map.noOps')}</p>}
      <div className="map-panel__ops">
        {ops.map((o) => (
          <button
            key={o.op_id}
            type="button"
            data-testid={`op-${o.op_id}`}
            className={`map-panel__op${o.op_id === draft.opId ? ' map-panel__op--current' : ''}`}
            disabled={limitReached}
            onClick={() => setDraft({ opId: o.op_id, stops: [] })}
          >
            <b>{loc(o.title)}</b>
            <span>{loc(siteById(content, o.location.site_id)?.name ?? { ru: '' })}</span>
          </button>
        ))}
      </div>
      {limitReached && <p className="map-panel__note">{t('sdr.plan.limit', { n: content.balance.ops.per_week })}</p>}

      {op && (
        <section className="map-panel__route" data-testid="route-builder">
          <p className="map-panel__note">{t('sdr.plan.hint')}</p>
          <ol className="map-panel__slots">
            {[0, 1, 2].map((i) => {
              const site = draft.stops[i] ? siteById(content, draft.stops[i]!) : undefined;
              return (
                <li key={i} className={site ? 'filled' : ''}>
                  {site ? (
                    <>
                      <b>{loc(site.name)}</b>
                      <span>
                        {loc(content.map.districts[site.district] ?? { ru: site.district })} · {site.cover_reason ? loc(site.cover_reason) : ''}
                      </span>
                    </>
                  ) : (
                    <span>{t('sdr.plan.empty')}</span>
                  )}
                </li>
              );
            })}
          </ol>
          {analysis.warnings.length > 0 && draft.stops.length === 3 && (
            <ul className="map-panel__warnings" data-testid="route-warnings">
              {analysis.warnings.map((w, i) => (
                <li key={i}>{issueText(w)}</li>
              ))}
            </ul>
          )}
          <div className="map-panel__actions">
            <button
              type="button"
              data-testid="confirm-route"
              disabled={analysis.blocking.length > 0}
              onClick={() => {
                dispatch({ type: 'plan_op', op_id: op.op_id, route: draft.stops });
                setDraft({ opId: null, stops: [] });
              }}
            >
              {t('sdr.plan.confirm')}
            </button>
            <button type="button" onClick={() => setDraft({ opId: draft.opId, stops: [] })}>
              {t('sdr.plan.reset')}
            </button>
          </div>

          <div className="map-panel__stops">
            {stopsByDistrict.map((d) => (
              <div key={d.id}>
                <h4>
                  <i className="map-panel__swatch" style={{ background: districtColor(d.id) }} />
                  {loc(d.name)}
                </h4>
                {d.stops.map((s) => (
                  <button
                    key={s.site_id}
                    type="button"
                    data-testid={`stop-${s.site_id}`}
                    className={draft.stops.includes(s.site_id) ? 'picked' : ''}
                    onClick={() => toggle(s.site_id)}
                  >
                    {draft.stops.includes(s.site_id) && <kbd>{draft.stops.indexOf(s.site_id) + 1}</kbd>} {loc(s.name)}
                  </button>
                ))}
              </div>
            ))}
          </div>
        </section>
      )}
      <PlannedList cancellable />
    </>
  );
}

/** Запланированные на эту неделю выходы. */
function PlannedList({ cancellable = false, departable = false }: { cancellable?: boolean; departable?: boolean }) {
  const t = useT();
  const loc = useLocalized();
  const game = useDeskStore((s) => s.game);
  const dispatch = useDeskStore((s) => s.dispatch);
  const setRun = useDeskStore((s) => s.setSdrRun);
  if (game.planned_ops.length === 0) return null;
  return (
    <section className="map-panel__planned" data-testid="planned-ops">
      <h3>{t('sdr.planned')}</h3>
      {game.planned_ops.map((id) => {
        const op = opById(id)!;
        const stops = game.routes[id]?.stops.map((s) => loc(siteById(content, s)?.name ?? { ru: s }).split(',')[0]) ?? [];
        return (
          <div key={id} className="map-panel__planned-item">
            <b>{loc(op.title)}</b>
            <span>{stops.join(' → ')}</span>
            {cancellable && (
              <button type="button" data-testid={`cancel-${id}`} onClick={() => dispatch({ type: 'cancel_op', op_id: id })}>
                {t('sdr.cancel')}
              </button>
            )}
            {departable && (
              <button type="button" data-testid={`depart-${id}`} onClick={() => setRun({ opId: id, step: 1, result: null })}>
                {t('sdr.depart')}
              </button>
            )}
          </div>
        );
      })}
    </section>
  );
}

/** Вечер: выезд по маршруту. Карточки наблюдений всплывают точка за точкой. */
function SdrRunPanel() {
  const t = useT();
  const loc = useLocalized();
  const game = useDeskStore((s) => s.game);
  const run = useDeskStore((s) => s.sdrRun)!;
  const setRun = useDeskStore((s) => s.setSdrRun);
  const dispatch = useDeskStore((s) => s.dispatch);
  const lastEvents = useDeskStore((s) => s.lastEvents);
  const op = opById(run.opId)!;
  const target = siteById(content, op.location.site_id);
  const cueText = (tag: string) => loc(content.cues.find((c) => c.tag === tag)?.text ?? { ru: tag });

  const resolve = (decision: 'continue' | 'abort') => {
    dispatch({ type: 'resolve_op', op_id: op.op_id, decision });
    const outcome = useDeskStore.getState().game.op_results[op.op_id] ?? null;
    setRun({ ...run, result: outcome });
  };

  if (run.result) {
    const found = lastEvents.flatMap((e) => (e.type === 'clue_found' ? [content.clues.find((c) => c.clue_id === e.clue_id)] : [])).filter((c) => c !== undefined);
    const unlocked = lastEvents.flatMap((e) => (e.type === 'target_unlocked' ? [content.targets.find((x) => x.target_id === e.target_id)] : [])).filter((x) => x !== undefined);
    return (
      <section className="sdr-result" data-testid="sdr-result" data-result={run.result === 'aborted' ? 'aborted' : 'done'}>
        <h3>{run.result === 'aborted' ? t('sdr.result.aborted') : t('sdr.result.done')}</h3>
        <p>{run.result === 'aborted' ? t('sdr.result.abortedText') : t('sdr.result.doneText', { name: loc(target?.name ?? { ru: '' }) })}</p>
        {found.length > 0 && (
          <ul>
            {found.map((c) => (
              <li key={c.clue_id}>{t('event.clue_found', { name: loc(c.title) })}</li>
            ))}
            {unlocked.map((x) => (
              <li key={x.target_id}>
                <b>{t('event.target_unlocked', { name: loc(x.name) })}</b>
              </li>
            ))}
          </ul>
        )}
        <button type="button" data-testid="sdr-done" onClick={() => setRun(null)}>
          {t('sdr.backToMap')}
        </button>
      </section>
    );
  }

  const route = game.routes[op.op_id];
  if (!route) return null;
  return (
    <section className="sdr-run" data-testid="sdr-run">
      <h3>{loc(op.title)}</h3>
      <p className="map-panel__note">{t('sdr.run.rule')}</p>
      <ol className="sdr-run__stops">
        {route.stops.slice(0, run.step).map((id, i) => {
          const site = siteById(content, id)!;
          return (
            <li key={id} className={i === run.step - 1 ? 'current' : ''} data-testid={`sdr-stop-${i + 1}`}>
              <h4>
                {i + 1}. {loc(site.name)}
              </h4>
              <span className="sdr-run__cover">{site.cover_reason ? loc(site.cover_reason) : ''}</span>
              <ul>
                {route.observations[i]!.map((tag) => (
                  <li key={tag} className="sdr-card" data-cue={tag}>
                    {cueText(tag)}
                  </li>
                ))}
              </ul>
            </li>
          );
        })}
      </ol>
      <div className="map-panel__actions">
        {run.step < 3 ? (
          <button type="button" data-testid="sdr-next" onClick={() => setRun({ ...run, step: run.step + 1 })}>
            {t('sdr.run.next')}
          </button>
        ) : (
          <button type="button" data-testid="sdr-continue" onClick={() => resolve('continue')}>
            {t('sdr.run.toTarget', { name: loc(target?.name ?? { ru: '' }).split(',')[0]! })}
          </button>
        )}
        <button type="button" className="danger" data-testid="sdr-abort" onClick={() => resolve('abort')}>
          {t('sdr.run.abort')}
        </button>
      </div>
    </section>
  );
}

/** Оперативная карта Вашингтона и Северной Вирджинии (GDD, Блок 3, модуль 1). */
export function MapModule() {
  const t = useT();
  const game = useDeskStore((s) => s.game);
  const draft = useDeskStore((s) => s.mapDraft);
  const setDraft = useDeskStore((s) => s.setMapDraft);
  const run = useDeskStore((s) => s.sdrRun);

  const planning = game.phase === 'day' && draft.opId !== null;
  const runningRoute = run && !run.result ? game.routes[run.opId] : undefined;
  const route = runningRoute?.stops ?? (planning ? draft.stops : []);
  const targetId = run ? (opById(run.opId)?.location.site_id ?? null) : planning ? (opById(draft.opId)?.location.site_id ?? null) : null;

  const toggle = (id: string) =>
    setDraft({
      opId: draft.opId,
      stops: draft.stops.includes(id) ? draft.stops.filter((x) => x !== id) : draft.stops.length < 3 ? [...draft.stops, id] : draft.stops,
    });

  let panel;
  if (run) panel = <SdrRunPanel />;
  else if (game.phase === 'day') panel = <PlanPanel />;
  else if (game.phase === 'evening')
    panel = (
      <>
        <h3>{t('sdr.evening.title')}</h3>
        {game.planned_ops.length === 0 && <p className="map-panel__note">{t('sdr.evening.none')}</p>}
        <PlannedList departable />
      </>
    );
  else
    panel = (
      <>
        <p className="map-panel__note">{t('sdr.idle')}</p>
        <PlannedList />
      </>
    );

  return (
    <div className="map-module">
      <header className="shell__header">
        <h2>{t('module.map.name')}</h2>
        <span className="shell__wip">{t(`phase.${game.phase}` as I18nKey)} · {t('sdr.legend')}</span>
      </header>
      <div className="map-module__body">
        <div className="map-module__sheet">
          <MapCanvas
            route={route}
            targetId={targetId}
            selectable={planning && !run}
            onSelectStop={toggle}
            progress={runningRoute ? run!.step : undefined}
            sogMarks={sogMarks(game.risks.sog_heat)}
            visitedSites={Object.keys(game.site_visits)}
            zoneLabel={t('sdr.zoneLabel')}
          />
        </div>
        <aside className="map-panel" data-testid="map-panel">
          {panel}
        </aside>
      </div>
    </div>
  );
}
