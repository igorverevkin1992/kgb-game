import { RISKS, riskLevels, type GameEvent } from '../../engine/campaign';
import type { I18nKey } from '../../i18n';
import { formatUsd } from '../format';
import { content, useDeskStore, useLocalized, useT } from '../store';

/** Человекочитаемая строка журнала. null — событие слишком мелкое для журнала. */
function useEventText() {
  const t = useT();
  const loc = useLocalized();
  const nameOf = (kind: 'cable' | 'clue' | 'target' | 'op', id: string): string => {
    if (kind === 'cable') {
      const c = content.cables.find((x) => x.cable_id === id);
      return c ? loc(c.subject) : id;
    }
    if (kind === 'clue') {
      const c = content.clues.find((x) => x.clue_id === id);
      return c ? loc(c.title) : id;
    }
    if (kind === 'target') {
      const c = content.targets.find((x) => x.target_id === id);
      return c ? loc(c.name) : id;
    }
    const o = content.ops.find((x) => x.op_id === id);
    return o ? loc(o.title) : id;
  };

  return (e: GameEvent): string | null => {
    switch (e.type) {
      case 'cable_delivered':
        return t('event.cable_delivered', { name: nameOf('cable', e.cable_id) });
      case 'clue_found':
        return t('event.clue_found', { name: nameOf('clue', e.clue_id) });
      case 'target_unlocked':
        return t('event.target_unlocked', { name: nameOf('target', e.target_id) });
      case 'target_recruited':
        return t('event.target_recruited', { name: nameOf('target', e.target_id) });
      case 'target_lost':
        return t('event.target_lost', { name: nameOf('target', e.target_id) });
      case 'op_resolved':
        return t(`event.op_${e.outcome}` as I18nKey, { name: nameOf('op', e.op_id) });
      case 'risk_changed':
        return t('event.risk_changed', { risk: t(`risk.${e.risk}` as I18nKey), from: e.from, to: e.to });
      case 'trust_changed':
        return t('event.trust_changed', { from: e.from, to: e.to });
      case 'lie_uncovered':
        return t('event.lie_uncovered', { week: e.lie_week });
      case 'act_completed':
        return t('event.act_completed', { act: e.act });
      default:
        return null;
    }
  };
}

/** Расчётная сводка аналитика: четыре шкалы риска, доверие Центра, спецфонд, журнал. */
export function AnalystSummary() {
  const t = useT();
  const game = useDeskStore((s) => s.game);
  const lang = useDeskStore((s) => s.lang);
  const close = useDeskStore((s) => s.toggleAnalyst);
  const eventText = useEventText();
  const levels = riskLevels(game, content);

  const journal = game.log
    .map((entry) => ({ ...entry, text: eventText(entry.event) }))
    .filter((entry) => entry.text !== null)
    .slice(-12)
    .reverse();

  return (
    <div className="module-overlay" onClick={close}>
      <article className="module-panel analyst" data-testid="analyst" role="dialog" onClick={(e) => e.stopPropagation()}>
        <div className="module-panel__stamp">{t('analyst.stamp')}</div>
        <h2>{t('analyst.title')}</h2>

        <dl className="analyst__risks">
          {RISKS.map((r) => (
            <div key={r} className={`analyst__risk analyst__risk--${levels[r]}`} data-testid={`risk-${r}`}>
              <dt>{t(`risk.${r}` as I18nKey)}</dt>
              <dd>
                <span className="analyst__bar" style={{ width: `${game.risks[r]}%` }} />
                <i className="analyst__tick" style={{ left: `${content.balance.thresholds.warning}%` }} />
                <i className="analyst__tick analyst__tick--danger" style={{ left: `${content.balance.thresholds.danger}%` }} />
                <b>{game.risks[r]}%</b>
              </dd>
              <small className="analyst__at100">{t(`risk.${r}.at100` as I18nKey)}</small>
            </div>
          ))}
          <div className="analyst__risk" data-testid="centre-trust">
            <dt>{t('analyst.trust')}</dt>
            <dd>
              <span className="analyst__bar analyst__bar--trust" style={{ width: `${game.centre_trust}%` }} />
              <b>{game.centre_trust}%</b>
            </dd>
          </div>
        </dl>
        <p className="analyst__fund">{t('analyst.fund', { usd: formatUsd(game.fund_usd, lang) })}</p>

        <h3>{t('analyst.journal')}</h3>
        <ol className="analyst__journal" data-testid="journal">
          {journal.map((entry, i) => (
            <li key={i}>
              <span>{t('calendar.week', { week: entry.week })}</span> {entry.text}
            </li>
          ))}
        </ol>
      </article>
    </div>
  );
}
