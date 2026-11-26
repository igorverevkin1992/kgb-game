import type { ModuleId } from '../../engine/modules';

interface Props {
  id: ModuleId;
  title: string;
  body: string;
  backLabel: string;
  backHint: string;
  onClose: () => void;
}

/** Временная «папка» модуля. Каждый модуль получит свой экран на шагах 4–8. */
export function ModulePanel({ id, title, body, backLabel, backHint, onClose }: Props) {
  return (
    <div className="module-overlay" onClick={onClose}>
      <article
        className="module-panel"
        data-testid={`module-panel-${id}`}
        role="dialog"
        aria-label={title}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="module-panel__stamp">СЕКРЕТНО · Экз. №1</div>
        <h2>{title}</h2>
        <p>{body}</p>
        <footer>
          <button type="button" onClick={onClose} data-testid="module-close">
            {backLabel}
          </button>
          <small>{backHint}</small>
        </footer>
      </article>
    </div>
  );
}
