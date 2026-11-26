import type { ReactNode } from 'react';
import { getModule, isModuleUnlocked } from '../../engine/modules';
import { ConsoleArt, CorkBoardArt, FialkaArt, InboxArt, LedgerArt, MapArt, RecorderArt } from '../art/DeskArt';
import { CipherModule, CounterintelModule, DialogModule, FinanceModule, MapModule, MiceModule } from '../modules/Shells';
import { useDeskStore, useT } from '../store';
import { hotkeyOf, VIEWS, viewName, type View } from '../views';
import { Inbox } from './Inbox';

const MINI_ART: Record<View, () => ReactNode> = {
  map: () => <MapArt />,
  mice: () => <CorkBoardArt cards={3} />,
  cipher: () => <FialkaArt />,
  finance: () => <LedgerArt />,
  dialog: () => <RecorderArt />,
  counterintel: () => <ConsoleArt />,
  inbox: () => <InboxArt count={3} />,
};

const CONTENT: Record<View, () => ReactNode> = {
  map: () => <MapModule />,
  mice: () => <MiceModule />,
  cipher: () => <CipherModule />,
  finance: () => <FinanceModule />,
  dialog: () => <DialogModule />,
  counterintel: () => <CounterintelModule />,
  inbox: () => <Inbox />,
};

/**
 * Открытый модуль: предмет «приближен» и занимает стол, а по нижнему краю остаётся
 * кромка стола с остальными предметами — переход между модулями одним кликом или клавишей 1–7.
 */
export function ModuleView({ view }: { view: View }) {
  const t = useT();
  const act = useDeskStore((s) => s.debugAct ?? s.game.act);
  const open = useDeskStore((s) => s.open);
  const close = useDeskStore((s) => s.close);

  return (
    <div className="module-view">
      <article key={view} className={`module-frame module-frame--${view}`} data-testid={`module-panel-${view}`} role="dialog" aria-label={t(viewName(view))}>
        {CONTENT[view]()}
      </article>

      <nav className="desk-edge" aria-label={t('desk.edge')}>
        <button type="button" className="desk-edge__back" data-testid="module-close" onClick={close}>
          {t('desk.back')}
          <kbd>Esc</kbd>
        </button>
        {VIEWS.map((v) => {
          const unlocked = v === 'inbox' || isModuleUnlocked(getModule(v), act);
          return (
            <button
              key={v}
              type="button"
              className={`desk-edge__item${v === view ? ' desk-edge__item--current' : ''}`}
              data-testid={`edge-${v}`}
              disabled={!unlocked}
              aria-current={v === view}
              onClick={() => open(v)}
            >
              <span className="desk-edge__art">{MINI_ART[v]()}</span>
              <span className="desk-edge__label">
                {t(viewName(v))}
                {unlocked && <kbd>{hotkeyOf(v)}</kbd>}
              </span>
            </button>
          );
        })}
      </nav>
    </div>
  );
}
