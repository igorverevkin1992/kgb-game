import { useState } from 'react';
import type { I18nKey } from '../../i18n';
import { isIronman, listCheckpoints, MANUAL_SLOTS, slotInfo, AUTOSAVE, type SlotInfo } from '../saves';
import { localSaveStorage } from '../saveStorage';
import { content, TEXT_SCALES, useDeskStore, useT } from '../store';

/**
 * Служебная папка резидента: сохранения и настройки. Открывается клавишей Esc на столе
 * или кликом по табличке на стене. Правила дизайна №3 и №6 (`docs/best-practices.md`).
 */
export function ServiceFolder() {
  const t = useT();
  const [tab, setTab] = useState<'saves' | 'settings'>('saves');
  const close = useDeskStore((s) => s.close);
  return (
    <div className="module-overlay" onClick={close}>
      <article className="module-panel service" data-testid="service-folder" role="dialog" onClick={(e) => e.stopPropagation()}>
        <div className="module-panel__stamp">{t('service.stamp')}</div>
        <h2>{t('service.title')}</h2>
        <nav className="service__tabs">
          {(['saves', 'settings'] as const).map((x) => (
            <button key={x} type="button" data-testid={`service-tab-${x}`} aria-pressed={tab === x} onClick={() => setTab(x)}>
              {t(`service.tab.${x}` as I18nKey)}
            </button>
          ))}
        </nav>
        {tab === 'saves' ? <SavesTab /> : <SettingsTab />}
        <footer>
          <button type="button" data-testid="service-close" onClick={close}>
            {t('desk.back')} <kbd>Esc</kbd>
          </button>
        </footer>
      </article>
    </div>
  );
}

function useSlotLabel() {
  const t = useT();
  const lang = useDeskStore((s) => s.lang);
  return (info: SlotInfo) =>
    `${t('desk.act', { act: info.act })} · ${t('calendar.week', { week: info.week })} · ${t(`phase.${info.phase}` as I18nKey)} — ${new Date(
      info.savedAt,
    ).toLocaleString(lang === 'en' ? 'en-US' : 'ru-RU', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })}`;
}

function SavesTab() {
  const t = useT();
  const label = useSlotLabel();
  const game = useDeskStore((s) => s.game);
  const savedAt = useDeskStore((s) => s.savedAt); // перерисовка после записи
  const saveToSlot = useDeskStore((s) => s.saveToSlot);
  const loadGame = useDeskStore((s) => s.loadGame);
  const newGame = useDeskStore((s) => s.newGame);
  const [error, setError] = useState<string | null>(null);
  const [confirmNew, setConfirmNew] = useState(false);
  const [ironman, setIronman] = useState(false);
  const iron = isIronman(game);
  void savedAt;

  const load = (slot: string) => setError(loadGame(slot));
  const checkpoints = listCheckpoints(localSaveStorage)
    .map((slot) => slotInfo(localSaveStorage, slot, content))
    .filter((x) => x !== null)
    .reverse();
  const auto = slotInfo(localSaveStorage, AUTOSAVE, content);

  return (
    <section className="service__saves" data-testid="saves">
      <p className="service__note">
        {iron ? t('saves.ironmanOn') : t('saves.autosave')} {auto && <span data-testid="autosave-info">{label(auto)}</span>}
      </p>

      <h3>{t('saves.manual')}</h3>
      <ul className="service__slots">
        {MANUAL_SLOTS.map((slot, i) => {
          const info = slotInfo(localSaveStorage, slot, content);
          return (
            <li key={slot} data-testid={`slot-${slot}`}>
              <b>{t('saves.slot', { n: i + 1 })}</b>
              <span>{info ? label(info) : t('saves.empty')}</span>
              <button type="button" data-testid={`save-${slot}`} disabled={iron} onClick={() => saveToSlot(slot)}>
                {t('saves.write')}
              </button>
              <button type="button" data-testid={`load-${slot}`} disabled={iron || !info} onClick={() => load(slot)}>
                {t('saves.load')}
              </button>
            </li>
          );
        })}
      </ul>

      <h3>{t('saves.checkpoints')}</h3>
      {iron ? (
        <p className="service__note">{t('saves.ironmanNoCheckpoints')}</p>
      ) : checkpoints.length === 0 ? (
        <p className="service__note">{t('saves.noCheckpoints')}</p>
      ) : (
        <ul className="service__slots" data-testid="checkpoints">
          {checkpoints.map((info) => (
            <li key={info.slot}>
              <span>{label(info)}</span>
              <button type="button" data-testid={`load-${info.slot}`} onClick={() => load(info.slot)}>
                {t('saves.load')}
              </button>
            </li>
          ))}
        </ul>
      )}
      {error && <p className="service__error">{error}</p>}

      <h3>{t('saves.newTitle')}</h3>
      {!confirmNew ? (
        <button type="button" data-testid="new-campaign" onClick={() => setConfirmNew(true)}>
          {t('saves.new')}
        </button>
      ) : (
        <div className="service__new">
          <label>
            <input type="checkbox" data-testid="ironman-toggle" checked={ironman} onChange={(e) => setIronman(e.target.checked)} />
            {t('saves.ironman')}
          </label>
          <p className="service__note">{t('saves.ironmanHint')}</p>
          <button type="button" data-testid="new-campaign-confirm" onClick={() => newGame({ ironman })}>
            {t('saves.newConfirm')}
          </button>
          <button type="button" onClick={() => setConfirmNew(false)}>
            {t('saves.cancel')}
          </button>
        </div>
      )}
    </section>
  );
}

function SettingsTab() {
  const t = useT();
  const settings = useDeskStore((s) => s.settings);
  const update = useDeskStore((s) => s.updateSettings);
  return (
    <section className="service__settings" data-testid="settings">
      {/* Переключатель языка вернётся вместе с английской версией (см. docs/plan.md). */}
      <h3>{t('settings.textScale')}</h3>
      <div className="service__choices">
        {TEXT_SCALES.map((scale) => (
          <button
            key={scale}
            type="button"
            data-testid={`text-scale-${Math.round(scale * 100)}`}
            aria-pressed={settings.textScale === scale}
            onClick={() => update({ textScale: scale })}
          >
            {Math.round(scale * 100)}%
          </button>
        ))}
      </div>
      <p className="service__note">{t('settings.textScaleHint')}</p>
    </section>
  );
}
