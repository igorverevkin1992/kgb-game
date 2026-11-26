import { useLayoutEffect, useState, type ReactNode } from 'react';

export const STAGE_W = 1600;
export const STAGE_H = 900;

/** Масштабирует сцену 1600×900 под размер окна, сохраняя пропорции 16:9. */
export function Stage({ children }: { children: ReactNode }) {
  const [scale, setScale] = useState(1);
  useLayoutEffect(() => {
    const fit = () => setScale(Math.min(window.innerWidth / STAGE_W, window.innerHeight / STAGE_H));
    fit();
    window.addEventListener('resize', fit);
    return () => window.removeEventListener('resize', fit);
  }, []);
  return (
    <div className="stage-viewport">
      <div className="stage" data-testid="stage" style={{ transform: `translate(-50%, -50%) scale(${scale})` }}>
        {children}
      </div>
    </div>
  );
}
