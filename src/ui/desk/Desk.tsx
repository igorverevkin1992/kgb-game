import { useEffect, type ReactNode } from 'react';
import { unreadCables } from '../../engine/campaign';
import { getModule, isModuleUnlocked } from '../../engine/modules';
import { ConsoleArt, CorkBoardArt, FialkaArt, InboxArt, LampArt, LedgerArt, MapArt, RecorderArt, WindowArt } from '../art/DeskArt';
import { sogMarks } from '../signals';
import { useDeskStore, useT } from '../store';
import { hotkeyOf, viewByHotkey, viewName, viewObject, type View } from '../views';
import { AnalystSummary } from './AnalystSummary';
import { Calendar } from './Calendar';
import { EndingScreen } from './EndingScreen';
import { ModuleView } from './ModuleView';
import './desk.css';

/** Физический предмет на столе или на стене. Клик открывает модуль (без меню). */
function DeskObject({ view, art, badge }: { view: View; art: ReactNode; badge?: ReactNode }) {
  const t = useT();
  const act = useDeskStore((s) => s.debugAct ?? s.game.act);
  const open = useDeskStore((s) => s.open);
  const unlockAct = view === 'inbox' ? 1 : getModule(view).unlockAct;
  const unlocked = view === 'inbox' || isModuleUnlocked(getModule(view), act);
  return (
    <button
      type="button"
      className={`desk-object desk-object--${view}`}
      data-testid={`desk-object-${view}`}
      disabled={!unlocked}
      onClick={() => open(view)}
      title={t(viewObject(view))}
    >
      <span className="desk-object__art">{art}</span>
      {badge}
      <span className="desk-object__tag">
        {t(viewName(view))}
        {unlocked ? <kbd>{hotkeyOf(view)}</kbd> : <em>{t('desk.locked', { act: unlockAct })}</em>}
      </span>
    </button>
  );
}

export function Desk() {
  const t = useT();
  const act = useDeskStore((s) => s.debugAct ?? s.game.act);
  const game = useDeskStore((s) => s.game);
  const view = useDeskStore((s) => s.view);
  const analystOpen = useDeskStore((s) => s.analystOpen);
  const open = useDeskStore((s) => s.open);
  const close = useDeskStore((s) => s.close);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const el = e.target as HTMLElement | null;
      if (el && ['INPUT', 'TEXTAREA', 'SELECT'].includes(el.tagName)) return;
      if (e.key === 'Escape') return close();
      if (e.ctrlKey || e.metaKey || e.altKey) return;
      const target = viewByHotkey(e.key);
      if (target) open(target);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [close, open]);

  const unread = unreadCables(game).length;
  const dossiers = Object.values(game.targets).filter((ts) => ts.unlocked).length;

  return (
    <main className="room">
      <div className="room__wall" aria-hidden />
      <div className="room__desk" aria-hidden />
      <div className="room__lamp-light" aria-hidden />

      <header className="plaque">
        <h1>{t('game.title')}</h1>
        <p>
          {t('game.subtitle')} · <span data-testid="act">{t('desk.act', { act })}</span>
        </p>
      </header>

      <div className="room__window" aria-hidden>
        <WindowArt />
      </div>
      <div className="room__lamp" aria-hidden>
        <LampArt />
      </div>

      <DeskObject view="mice" art={<CorkBoardArt cards={dossiers} />} />
      <DeskObject view="counterintel" art={<ConsoleArt />} />
      <DeskObject view="map" art={<MapArt sogMarks={sogMarks(game.risks.sog_heat)} />} />
      <DeskObject view="cipher" art={<FialkaArt />} />
      <DeskObject
        view="inbox"
        art={<InboxArt count={unread} />}
        badge={
          unread > 0 ? (
            <span className="desk-object__badge" data-testid="inbox-unread">
              {unread}
            </span>
          ) : null
        }
      />
      <DeskObject view="finance" art={<LedgerArt />} />
      <DeskObject view="dialog" art={<RecorderArt />} />

      <Calendar />

      {view && <ModuleView view={view} />}
      {analystOpen && <AnalystSummary />}
      <EndingScreen />
    </main>
  );
}
