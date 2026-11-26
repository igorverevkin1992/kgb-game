import { useEffect } from 'react';
import { DESK_MODULES, isModuleUnlocked, type ModuleId } from '../../engine/modules';
import type { I18nKey } from '../../i18n';
import { useDeskStore, useT } from '../store';
import { ModulePanel } from './ModulePanel';
import './desk.css';

const key = (id: ModuleId, part: 'name' | 'object' | 'details') => `module.${id}.${part}` as I18nKey;

export function Desk() {
  const t = useT();
  const act = useDeskStore((s) => s.act);
  const openModule = useDeskStore((s) => s.openModule);
  const open = useDeskStore((s) => s.open);
  const close = useDeskStore((s) => s.close);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') close();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [close]);

  return (
    <main className="room">
      <header className="room__header">
        <h1>{t('game.title')}</h1>
        <p>
          {t('game.subtitle')} · <span data-testid="act">{t('desk.act', { act })}</span>
        </p>
      </header>

      <section className="desk" aria-label="desk">
        {DESK_MODULES.map((m) => {
          const unlocked = isModuleUnlocked(m, act);
          return (
            <button
              key={m.id}
              type="button"
              className={`desk-object desk-object--${m.id}`}
              data-testid={`desk-object-${m.id}`}
              disabled={!unlocked}
              onClick={() => open(m.id)}
              title={t(key(m.id, 'object'))}
            >
              <span className="desk-object__name">{t(key(m.id, 'name'))}</span>
              <span className="desk-object__caption">
                {unlocked ? t(key(m.id, 'object')) : t('desk.locked', { act: m.unlockAct })}
              </span>
            </button>
          );
        })}
        <div className="desk__lamp" aria-hidden />
      </section>

      {openModule && (
        <ModulePanel
          id={openModule}
          title={t(key(openModule, 'name'))}
          body={t('desk.placeholder', { details: t(key(openModule, 'details')) })}
          backLabel={t('desk.back')}
          backHint={t('desk.backHint')}
          onClose={close}
        />
      )}
    </main>
  );
}
