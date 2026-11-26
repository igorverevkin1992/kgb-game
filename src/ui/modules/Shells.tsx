/**
 * Оболочки шести модулей стола. Каждая уже показывает живые данные кампании, а полноценная
 * механика появится в своём шаге плана (номер шага — в плашке «в разработке»).
 */
import type { ReactNode } from 'react';
import { availableOps, axisKnowledge } from '../../engine/campaign';
import type { ModuleId } from '../../engine/modules';
import type { MiceAxis } from '../../schemas';
import type { I18nKey } from '../../i18n';
import { MapArt, RecorderArt } from '../art/DeskArt';
import { sogMarks } from '../signals';
import { content, useDeskStore, useLocalized, useT } from '../store';
import './modules.css';

const PLAN_STEP: Record<ModuleId, number> = { map: 4, mice: 5, cipher: 6, dialog: 7, finance: 8, counterintel: 13 };

function Shell({ id, children, aside }: { id: ModuleId; children: ReactNode; aside?: ReactNode }) {
  const t = useT();
  return (
    <div className={`shell shell--${id}`}>
      <header className="shell__header">
        <h2>{t(`module.${id}.name` as I18nKey)}</h2>
        <span className="shell__wip">{t('shell.wip', { step: PLAN_STEP[id], details: t(`module.${id}.details` as I18nKey) })}</span>
      </header>
      <div className="shell__body">
        <div className="shell__main">{children}</div>
        {aside && <aside className="shell__aside">{aside}</aside>}
      </div>
    </div>
  );
}

export function MapModule() {
  const t = useT();
  const loc = useLocalized();
  const game = useDeskStore((s) => s.game);
  const ops = availableOps(game, content);
  return (
    <Shell
      id="map"
      aside={
        <>
          <h3>{t('map.ops')}</h3>
          {ops.length ? (
            <ul data-testid="map-ops">
              {ops.map((op) => (
                <li key={op.op_id}>{loc(op.title)}</li>
              ))}
            </ul>
          ) : (
            <p>{t('map.noOps')}</p>
          )}
          <p className="shell__note">{t('map.sogNote', { marks: sogMarks(game.risks.sog_heat) })}</p>
        </>
      }
    >
      <div className="shell__map">
        <MapArt sogMarks={sogMarks(game.risks.sog_heat)} />
      </div>
    </Shell>
  );
}

const AXES: MiceAxis[] = ['money', 'ideology', 'compromise', 'ego'];

export function MiceModule() {
  const t = useT();
  const loc = useLocalized();
  const game = useDeskStore((s) => s.game);
  const known = content.targets.filter((tg) => game.targets[tg.target_id]?.unlocked);
  const hidden = content.targets.filter((tg) => tg.act <= game.act && !game.targets[tg.target_id]?.unlocked).length;
  return (
    <Shell id="mice">
      <div className="shell__cork">
        <div className="dossiers" data-testid="dossiers">
          {known.map((tg) => {
            const ts = game.targets[tg.target_id]!;
            return (
              <article key={tg.target_id} className="dossier" data-testid={`dossier-${tg.target_id}`}>
                <h3>{loc(tg.name)}</h3>
                <p>{loc(tg.role)}</p>
                <dl>
                  {AXES.map((axis) => {
                    const k = axisKnowledge(game, content, tg.target_id, axis);
                    return (
                      <div key={axis} className={`dossier__axis dossier__axis--${k}`}>
                        <dt>{axis[0]!.toUpperCase()}</dt>
                        <dd>{t(`mice.${k}` as I18nKey)}</dd>
                      </div>
                    );
                  })}
                </dl>
                {ts.recruited && <span className="dossier__stamp">{t('mice.recruited')}</span>}
                {ts.lost && <span className="dossier__stamp">{t('mice.lost')}</span>}
              </article>
            );
          })}
          {hidden > 0 && <p className="dossiers__hidden">{t('mice.hidden', { count: hidden })}</p>}
        </div>
      </div>
    </Shell>
  );
}

export function CipherModule() {
  const t = useT();
  const loc = useLocalized();
  const game = useDeskStore((s) => s.game);
  const directives = content.cables.filter((c) => c.kind === 'directive' && game.delivered_cables.includes(c.cable_id));
  const last = directives.at(-1);
  return (
    <Shell id="cipher" aside={<p className="shell__note">{t('cipher.trust', { trust: game.centre_trust })}</p>}>
      <div className="teletype" data-testid="teletype">
        {last ? (
          <>
            <p className="teletype__head">
              {t('cipher.from')} {loc(last.sender)} · {loc(last.subject)}
            </p>
            <p>{loc(last.body).toUpperCase()}</p>
          </>
        ) : (
          <p>{t('cipher.empty')}</p>
        )}
      </div>
    </Shell>
  );
}

export function FinanceModule() {
  const t = useT();
  const game = useDeskStore((s) => s.game);
  return (
    <Shell id="finance">
      <div className="ledger-page" data-testid="ledger">
        <p>{t('finance.balance', { usd: game.fund_usd.toLocaleString('en-US') })}</p>
        <p className="shell__note">{t('finance.threshold')}</p>
      </div>
    </Shell>
  );
}

export function DialogModule() {
  const t = useT();
  return (
    <Shell id="dialog" aside={<p className="shell__note">{t('dialog.empty')}</p>}>
      <div className="shell__recorder">
        <RecorderArt />
      </div>
    </Shell>
  );
}

export function CounterintelModule() {
  const t = useT();
  return (
    <Shell id="counterintel">
      <p className="shell__note">{t('counterintel.empty')}</p>
    </Shell>
  );
}
