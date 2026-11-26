import { create } from 'zustand';
import { loadContent } from '../content';
import { dispatch as engineDispatch, newCampaign, serialize, type Action, type CampaignState, type GameEvent } from '../engine/campaign';
import { getModule, isModuleUnlocked, parseAct, type Act } from '../engine/modules';
import { parseLang, translate, type I18nKey, type Lang } from '../i18n';
import { AUTOSAVE, IRONMAN_FLAG, loadSlot, persist, saveManual } from './saves';
import { localSaveStorage } from './saveStorage';
import type { View } from './views';

export const content = loadContent();

const params = new URLSearchParams(typeof window === 'undefined' ? '' : window.location.search);

/** Масштаб текста в документах и панелях (правило читаемости: 100–130%). */
export const TEXT_SCALES = [1, 1.15, 1.3] as const;
export type TextScale = (typeof TEXT_SCALES)[number];

export interface Settings {
  lang: Lang;
  textScale: TextScale;
}

const SETTINGS_KEY = 'settings';
function loadSettings(): Settings {
  const defaults: Settings = { lang: 'ru', textScale: 1 };
  try {
    const raw = JSON.parse(localSaveStorage.read(SETTINGS_KEY) ?? '{}') as Partial<Settings>;
    const textScale = TEXT_SCALES.find((x) => x === raw.textScale) ?? defaults.textScale;
    // Параметр ?lang= в адресе (отладка) сильнее сохранённой настройки.
    const lang = params.has('lang') ? parseLang(params.get('lang')) : parseLang(raw.lang);
    return { lang, textScale };
  } catch {
    return defaults;
  }
}

/** Продолжаем с автосохранения, если оно есть и подходит к текущему контенту. ?new — начать заново. */
function initialGame(): CampaignState {
  if (!params.has('new')) {
    const loaded = loadSlot(localSaveStorage, AUTOSAVE, content);
    if (loaded.ok) return loaded.state;
    if (loaded.error !== 'Слот пуст') console.warn(`[сохранение] ${loaded.error}. Начинаем новую кампанию.`);
  }
  const { state } = newCampaign(content);
  persist(localSaveStorage, null, state, content);
  return state;
}

interface GameStore {
  game: CampaignState;
  /** Отладка: ?act=N показывает стол так, будто идёт акт N (на сам движок не влияет). */
  debugAct: Act | null;
  settings: Settings;
  /** Текущий язык (= settings.lang), вынесен для удобства подписок. */
  lang: Lang;
  /** Открытый модуль или лоток входящих; null — виден весь стол. */
  view: View | null;
  /** События последнего действия — для подсветки изменений на столе. */
  lastEvents: GameEvent[];
  lastError: string | null;
  analystOpen: boolean;
  /** Служебная папка: сохранения и настройки (Esc на столе или клик по табличке). */
  serviceOpen: boolean;
  /** Время последнего сохранения — для индикатора «Сохранено». */
  savedAt: number;
  /** Черновик маршрута SDR на карте (фаза «День»): выбранная операция и точки по порядку. */
  mapDraft: { opId: string | null; stops: string[] };
  /**
   * Идущий выезд (фаза «Вечер»): сколько точек маршрута пройдено, открыт ли «Вердикт»,
   * какие приметы игрок обвёл в блокноте (`<номер точки>:<примета>`), итог.
   */
  sdrRun: {
    opId: string;
    step: number;
    verdict: boolean;
    marks: string[];
    result: 'clean' | 'tail_missed' | 'aborted' | null;
  } | null;

  act: () => Act;
  dispatch: (action: Action) => void;
  /** Новая кампания; `ironman` — режим «Железный занавес» (только автосохранение). */
  newGame: (opts?: { ironman?: boolean }) => void;
  /** Загрузить слот сохранения; возвращает текст ошибки или null. */
  loadGame: (slot: string) => string | null;
  saveToSlot: (slot: string) => boolean;
  /** Открыть модуль (если он уже доступен в этом акте) или лоток входящих. */
  open: (view: View) => void;
  close: () => void;
  toggleAnalyst: () => void;
  openService: () => void;
  updateSettings: (patch: Partial<Settings>) => void;
  setMapDraft: (draft: { opId: string | null; stops: string[] }) => void;
  setSdrRun: (run: GameStore['sdrRun']) => void;
}

const freshUi = { view: null, analystOpen: false, serviceOpen: false, mapDraft: { opId: null, stops: [] }, sdrRun: null, lastError: null };

export const useDeskStore = create<GameStore>((set, get) => {
  const settings = loadSettings();
  return {
    game: initialGame(),
    debugAct: params.has('act') ? parseAct(params.get('act')) : null,
    settings,
    lang: settings.lang,
    view: null,
    lastEvents: [],
    lastError: null,
    analystOpen: false,
    serviceOpen: false,
    savedAt: 0,
    mapDraft: { opId: null, stops: [] },
    sdrRun: null,

    act: () => get().debugAct ?? get().game.act,
    dispatch: (action) => {
      const prev = get().game;
      const result = engineDispatch(prev, content, action);
      if (result.error) {
        set({ lastError: result.error });
        return;
      }
      persist(localSaveStorage, prev, result.state, content);
      set({ game: result.state, lastEvents: result.events, lastError: null, savedAt: Date.now() });
    },
    newGame: (opts = {}) => {
      const { state, events } = newCampaign(content);
      if (opts.ironman) state.flags.push(IRONMAN_FLAG);
      persist(localSaveStorage, null, state, content);
      set({ ...freshUi, game: state, lastEvents: events, savedAt: Date.now() });
    },
    loadGame: (slot) => {
      const loaded = loadSlot(localSaveStorage, slot, content);
      if (!loaded.ok) return loaded.error;
      localSaveStorage.write(AUTOSAVE, serialize(loaded.state));
      set({ ...freshUi, game: loaded.state, lastEvents: [], savedAt: Date.now() });
      return null;
    },
    saveToSlot: (slot) => {
      const ok = saveManual(localSaveStorage, slot, get().game);
      if (ok) set({ savedAt: Date.now() });
      return ok;
    },
    open: (view) => {
      if (view === 'inbox' || isModuleUnlocked(getModule(view), get().act())) set({ view, analystOpen: false, serviceOpen: false });
    },
    close: () => set({ view: null, analystOpen: false, serviceOpen: false }),
    toggleAnalyst: () => set((s) => ({ analystOpen: !s.analystOpen })),
    openService: () => set({ serviceOpen: true, analystOpen: false }),
    updateSettings: (patch) => {
      const next = { ...get().settings, ...patch };
      localSaveStorage.write(SETTINGS_KEY, JSON.stringify(next));
      set({ settings: next, lang: next.lang });
    },
    setMapDraft: (mapDraft) => set({ mapDraft }),
    setSdrRun: (sdrRun) => set({ sdrRun }),
  };
});

export function useT() {
  const lang = useDeskStore((s) => s.lang);
  return (key: I18nKey, p?: Record<string, string | number>) => translate(lang, key, p);
}

/** Двуязычный текст из контента на текущем языке. */
export function useLocalized() {
  const lang = useDeskStore((s) => s.lang);
  return (text: { ru: string; en?: string }) => (lang === 'en' && text.en ? text.en : text.ru);
}
