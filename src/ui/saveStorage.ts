import type { SaveStorage } from '../engine/campaign';

const PREFIX = 'liniya-kr:';

/**
 * Сохранения в localStorage браузера. В приватном режиме или при запрете хранилища
 * игра продолжает работать, просто без автосохранения. В Electron (шаг 10) будет файл.
 */
export const localSaveStorage: SaveStorage = {
  read(slot) {
    try {
      return localStorage.getItem(PREFIX + slot);
    } catch {
      return null;
    }
  },
  write(slot, data) {
    try {
      localStorage.setItem(PREFIX + slot, data);
    } catch {
      /* хранилище недоступно — молча продолжаем без сохранения */
    }
  },
  remove(slot) {
    try {
      localStorage.removeItem(PREFIX + slot);
    } catch {
      /* то же */
    }
  },
};
