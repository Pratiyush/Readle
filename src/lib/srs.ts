import { addDays } from "./dates";

/** Leitner boxes: the interval in days before a card in each box is due again. */
export const INTERVALS = [0, 1, 3, 7, 14, 30, 60];
export const MASTERED_BOX = 5;

export interface Card {
  box: number;
  due: string; // YYYY-MM-DD
}

export function newCard(today: string): Card {
  return { box: 0, due: today };
}

export function review(card: Card, correct: boolean, today: string): Card {
  const box = correct ? Math.min(card.box + 1, INTERVALS.length - 1) : 0;
  return { box, due: addDays(today, correct ? INTERVALS[box] : 0) };
}

export const isDue = (card: Card, today: string) => card.due <= today;
export const isMastered = (card: Card) => card.box >= MASTERED_BOX;
