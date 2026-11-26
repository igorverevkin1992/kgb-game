import { create } from 'zustand';
import { getModule, isModuleUnlocked, parseAct, type Act, type ModuleId } from '../engine/modules';
import { parseLang, translate, type I18nKey, type Lang } from '../i18n';

const params = new URLSearchParams(typeof window === 'undefined' ? '' : window.location.search);

interface DeskState {
  act: Act;
  lang: Lang;
  openModule: ModuleId | null;
  open: (id: ModuleId) => void;
  close: () => void;
}

// Для отладки акт и язык можно задать в адресе: ?act=3&lang=en
export const useDeskStore = create<DeskState>((set, get) => ({
  act: parseAct(params.get('act')),
  lang: parseLang(params.get('lang')),
  openModule: null,
  open: (id) => {
    if (isModuleUnlocked(getModule(id), get().act)) set({ openModule: id });
  },
  close: () => set({ openModule: null }),
}));

export function useT() {
  const lang = useDeskStore((s) => s.lang);
  return (key: I18nKey, p?: Record<string, string | number>) => translate(lang, key, p);
}
