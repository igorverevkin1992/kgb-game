import type { Cable } from '../../schemas';
import type { I18nKey } from '../../i18n';
import { useLocalized, useT } from '../store';
import './documents.css';

/**
 * Документ на столе. Визуальная дуальность (GDD, Блок 5): советские бумаги — серый бланк
 * по ГОСТ, машинопись, гриф и штамп; американские — глянцевая газетная вырезка;
 * перехват — телетайпная лента заглавными буквами.
 */
export function DocumentView({ cable }: { cable: Cable }) {
  const t = useT();
  const loc = useLocalized();
  const number = `${cable.week}/${cable.cable_id.length * 7 + cable.week}-КР`;

  if (cable.kind === 'press_clipping') {
    return (
      <article className="doc doc--clipping" data-testid="document" data-kind={cable.kind}>
        <p className="doc__masthead">{loc(cable.sender)}</p>
        <h3>{loc(cable.subject)}</h3>
        <p>{loc(cable.body)}</p>
      </article>
    );
  }

  if (cable.kind === 'intercept') {
    return (
      <article className="doc doc--intercept" data-testid="document" data-kind={cable.kind}>
        <p className="doc__tape-head">
          {loc(cable.sender).toUpperCase()} · {loc(cable.subject).toUpperCase()}
        </p>
        <p>{loc(cable.body).toUpperCase()}</p>
      </article>
    );
  }

  return (
    <article className="doc doc--form" data-testid="document" data-kind={cable.kind}>
      <header className="doc__form-head">
        <span className="doc__secret">{t('doc.secret')}</span>
        <span>{t('doc.copy')}</span>
      </header>
      <dl className="doc__fields">
        <div>
          <dt>{t('doc.from')}</dt>
          <dd>{loc(cable.sender)}</dd>
        </div>
        <div>
          <dt>{t('doc.number')}</dt>
          <dd>№ {number}</dd>
        </div>
        <div>
          <dt>{t('doc.kind')}</dt>
          <dd>{t(`doc.kind.${cable.kind}` as I18nKey)}</dd>
        </div>
      </dl>
      <h3>{loc(cable.subject)}</h3>
      <p className="doc__body">{loc(cable.body)}</p>
      <span className="doc__stamp">{t('doc.stamp')}</span>
    </article>
  );
}
