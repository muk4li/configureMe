"use client";

import { useSyncExternalStore } from "react";
import { selectionSchema, type PublicSelection } from "@/lib/public-planning";
import { freshSelection, publicSessionKey, restorePublicSelection } from "@/lib/public-session";

const serverSnapshot = { selection: freshSelection(), ready: false, note: "" };
let current = serverSnapshot;
let initialized = false;
const listeners = new Set<() => void>();
const unavailable = "Browser storage is unavailable. Changes stay in memory until reload.";
function subscribe(listener: () => void) {
  listeners.add(listener);
  if (!initialized) {
    initialized = true;
    let selection = freshSelection();
    let note = "";
    try {
      const saved = sessionStorage.getItem(publicSessionKey);
      const restored = restorePublicSelection(saved);
      if (restored) selection = restored;
      else if (saved) { sessionStorage.removeItem(publicSessionKey); note = "An incompatible saved selection was discarded."; }
    } catch { note = unavailable; }
    current = { selection, ready: true, note };
    listener();
  }
  return () => { listeners.delete(listener); };
}
function saveSelection(input: PublicSelection) {
  const selection = selectionSchema.parse(input);
  let note = current.note;
  try { sessionStorage.setItem(publicSessionKey, JSON.stringify(selection)); }
  catch { note = unavailable; }
  current = { selection, ready: true, note };
  listeners.forEach(listener => listener());
}
export function usePublicSelection() {
  const state = useSyncExternalStore(subscribe, () => current, () => serverSnapshot);
  return { ...state, saveSelection };
}
