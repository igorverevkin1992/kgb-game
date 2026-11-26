import type { I18nKey } from '../../i18n';
import { isIronman } from '../saves';
import { useDeskStore, useT } from '../store';

/** Итог кампании. Полноценные концовки с эпилогом — шаг 15. */
export function EndingScreen() {
  const t = useT();
  const ending = useDeskStore((s) => s.game.ending);
  const week = useDeskStore((s) => s.game.week);
  const newGame = useDeskStore((s) => s.newGame);
  const openService = useDeskStore((s) => s.openService);
  const ironman = useDeskStore((s) => isIronman(s.game));
  const serviceOpen = useDeskStore((s) => s.serviceOpen);
  if (!ending || serviceOpen) return null;
  return (
    <div className="module-overlay">
      <article className="module-panel ending" data-testid="ending" data-ending={ending} role="dialog">
        <div className="module-panel__stamp">{t('ending.stamp')}</div>
        <h2>{t(`ending.${ending}.title` as I18nKey)}</h2>
        <p>{t(`ending.${ending}.text` as I18nKey, { week })}</p>
        <footer>
          {!ironman && (
            <button type="button" data-testid="ending-load" onClick={openService}>
              {t('ending.load')}
            </button>
          )}
          <button type="button" data-testid="new-game" onClick={() => newGame()}>
            {t('ending.new_game')}
          </button>
        </footer>
      </article>
    </div>
  );
}
