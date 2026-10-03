import { getApp, getApps, initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";

// The web app registered for the admin panel. Not a secret: every Firebase
// web app ships its config to the browser. Who may read and change what is
// decided by the Firestore rules and the worker, not by this.
const config = {
  apiKey: "AIzaSyDJi3e5X6hR94XrOB9zmAjNfJmucr3iWjg",
  authDomain: "forex-9f21b.firebaseapp.com",
  projectId: "forex-9f21b",
  storageBucket: "forex-9f21b.firebasestorage.app",
  messagingSenderId: "815922431965",
  appId: "1:815922431965:web:42d82919ccef90bb241834",
};

export const app = getApps().length ? getApp() : initializeApp(config);
export const auth = getAuth(app);
export const db = getFirestore(app);

/** Accounts sign in with a username; Firebase knows them by this address. */
export const emailFor = (username: string) =>
  `${username.trim().replace(/^@/, "").toLowerCase()}@users.forex-9f21b.app`;

/** The stats worker, whose /admin route makes every change. */
export const WORKER = "https://forex-trading-stats.forex-trading-stats.workers.dev";
