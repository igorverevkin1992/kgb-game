import { create } from 'zustand';
import { loadContent } from '../content';
import {
  deserialize,
  dispatch as engineDispatch,
  newCampaign,
  serialize,
  type Action,
  type CampaignState,
  type GameEvent,
} from '../engine/campaign';
import { getModule, isModuleUnlocked, parseAct, type Act, type ModuleId } from '../engine/modules';
import { parseLang, translate, type I18nKey, type Lang } from '../i18n';
import { localSaveStorage } from './saveStorage';

export const content = loadContent();

const params = new URLSearchParams(typeof window === 'undefined' ? '' : window.location.search);
const AUTOSAVE = 'autosave';

/** Продолжаем с автосохранения, если оно есть и подходит к текущему контенту. ?new — начать заново. */
function initialGame(): CampaignState {
  if (!params.has('new')) {
    const saved = localSaveStorage.read(AUTOSAVE);
    if (saved) {
      const loaded = deserialize(saved, content);
      if (loaded.ok) return loaded.state;
      console.warn(`[сохранение] ${loaded.error}. Начинаем новую кампанию.`);
    }
  }
  return newCampaign(content).state;
}

interface GameStore {
  game: CampaignState;
  /** Отладка: ?act=N показывает стол так, будто идёт акт N (на сам движок не влияет). */
  debugAct: Act | null;
  lang: Lang;
  openModule: ModuleId | null;
  /** События последнего действия — для подсветки изменений на столе. */
  lastEvents: GameEvent[];
  lastError: string | null;
  analystOpen: boolean;

  act: () => Act;
  dispatch: (action: Action) => void;
  newGame: () => void;
  open: (id: ModuleId) => void;
  close: () => void;
  toggleAnalyst: () => void;
}

export const useDeskStore = create<GameStore>((set, get) => ({
  game: initialGame(),
  debugAct: params.has('act') ? parseAct(params.get('act')) : null,
  lang: parseLang(params.get('lang')),
  openModule: null,
  lastEvents: [],
  lastError: null,
  analystOpen: false,

  act: () => get().debugAct ?? get().game.act,
  dispatch: (action) => {
    const result = engineDispatch(get().game, content, action);
    if (result.error) {
      set({ lastError: result.error });
      return;
    }
    localSaveStorage.write(AUTOSAVE, serialize(result.state));
    set({ game: result.state, lastEvents: result.events, lastError: null });
  },
  newGame: () => {
    const { state, events } = newCampaign(content);
    localSaveStorage.write(AUTOSAVE, serialize(state));
    set({ game: state, lastEvents: events, lastError: null, openModule: null, analystOpen: false });
  },
  open: (id) => {
    if (isModuleUnlocked(getModule(id), get().act())) set({ openModule: id });
  },
  close: () => set({ openModule: null, analystOpen: false }),
  toggleAnalyst: () => set((s) => ({ analystOpen: !s.analystOpen })),
}));

export function useT() {
  const lang = useDeskStore((s) => s.lang);
  return (key: I18nKey, p?: Record<string, string | number>) => translate(lang, key, p);
}

/** Двуязычный текст из контента на текущем языке. */
export function useLocalized() {
  const lang = useDeskStore((s) => s.lang);
  return (text: { ru: string; en?: string }) => (lang === 'en' && text.en ? text.en : text.ru);
}
