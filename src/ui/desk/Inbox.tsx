import { useState } from 'react';
import type { I18nKey } from '../../i18n';
import { DocumentView } from '../documents/DocumentView';
import { content, useDeskStore, useLocalized, useT } from '../store';

/** Лоток входящих: утренняя почта резидента. Открытый документ отмечается прочитанным. */
export function Inbox() {
  const t = useT();
  const loc = useLocalized();
  const game = useDeskStore((s) => s.game);
  const dispatch = useDeskStore((s) => s.dispatch);

  const docs = game.delivered_cables
    .map((id) => content.cables.find((c) => c.cable_id === id))
    .filter((c) => c !== undefined)
    .reverse(); // свежие сверху
  const firstUnread = docs.find((d) => !game.read_cables.includes(d.cable_id));
  const [selected, setSelected] = useState<string | null>(null);
  const current = docs.find((d) => d.cable_id === selected) ?? null;

  const select = (id: string) => {
    setSelected(id);
    if (!game.read_cables.includes(id)) dispatch({ type: 'read_cable', cable_id: id });
  };

  return (
    <div className="inbox">
      <header className="shell__header">
        <h2>{t('inbox.name')}</h2>
        <span className="shell__wip">{t('inbox.hint')}</span>
      </header>
      <div className="inbox__body">
        <ol className="inbox__list" data-testid="inbox-list">
          {docs.map((d) => {
            const unread = !game.read_cables.includes(d.cable_id);
            return (
              <li key={d.cable_id}>
                <button
                  type="button"
                  className={`inbox__item${unread ? ' inbox__item--unread' : ''}${d.cable_id === current?.cable_id ? ' inbox__item--current' : ''}`}
                  data-testid={`inbox-item-${d.cable_id}`}
                  onClick={() => select(d.cable_id)}
                >
                  <span className="inbox__kind">
                    {t(`doc.kind.${d.kind}` as I18nKey)} · {t('calendar.week', { week: d.week })}
                  </span>
                  <span className="inbox__subject">{loc(d.subject)}</span>
                </button>
              </li>
            );
          })}
        </ol>
        <div className="inbox__reader">
          {current ? (
            <DocumentView cable={current} />
          ) : (
            <p className="inbox__empty">{firstUnread ? t('inbox.pick') : t('inbox.allRead')}</p>
          )}
        </div>
      </div>
    </div>
  );
}
