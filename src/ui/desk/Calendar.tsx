import { currentActDef, weekDate, type Report } from '../../engine/campaign';
import type { I18nKey } from '../../i18n';
import { content, useDeskStore, useT } from '../store';

const REPORTS: Report[] = ['truth', 'embellished', 'silence'];

/** Перекидной календарь на столе: неделя, фаза и кнопка перехода. Ночью — выбор донесения. */
export function Calendar() {
  const t = useT();
  const game = useDeskStore((s) => s.game);
  const lang = useDeskStore((s) => s.lang);
  const dispatch = useDeskStore((s) => s.dispatch);
  const error = useDeskStore((s) => s.lastError);
  const toggleAnalyst = useDeskStore((s) => s.toggleAnalyst);
  const savedAt = useDeskStore((s) => s.savedAt);

  const date = weekDate(content, game.act, game.week);
  const dateText = date?.toLocaleDateString(lang === 'en' ? 'en-US' : 'ru-RU', {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
    timeZone: 'UTC',
  });
  const actDef = currentActDef(game, content);

  return (
    <section className="calendar" data-testid="calendar" aria-label={t('calendar.label')}>
      <div className="calendar__sheet">
        <div className="calendar__week" data-testid="calendar-week">
          {t('calendar.week', { week: game.week })}
        </div>
        <div className="calendar__date">{dateText}</div>
        <div className="calendar__phase" data-testid="calendar-phase">
          {t(`phase.${game.phase}` as I18nKey)}
        </div>
        {actDef && (
          <div className="calendar__act">
            {t('desk.act', { act: game.act })} · {lang === 'en' && actDef.title.en ? actDef.title.en : actDef.title.ru}
          </div>
        )}
      </div>

      <div className="calendar__controls">
        <p className="calendar__hint">{t(`phase.${game.phase}.hint` as I18nKey)}</p>
        {game.phase === 'night' ? (
          <div className="calendar__reports">
            {REPORTS.map((r) => (
              <button
                key={r}
                type="button"
                data-testid={`report-${r}`}
                title={t(`report.${r}.hint` as I18nKey)}
                onClick={() => dispatch({ type: 'submit_report', report: r })}
              >
                {t(`report.${r}` as I18nKey)}
              </button>
            ))}
          </div>
        ) : (
          <button type="button" data-testid="advance-phase" onClick={() => dispatch({ type: 'advance_phase' })}>
            {t('calendar.next')}
          </button>
        )}
        <button type="button" className="calendar__analyst" data-testid="analyst-toggle" onClick={toggleAnalyst}>
          {t('analyst.open')}
        </button>
        {savedAt > 0 && (
          <span key={savedAt} className="calendar__saved" data-testid="save-indicator" role="status">
            {t('saves.saved')}
          </span>
        )}
        {error && (
          <p className="calendar__error" role="alert" data-testid="engine-error">
            {error}
          </p>
        )}
      </div>
    </section>
  );
}
