"use client";

import { onAuthStateChanged, signInWithEmailAndPassword, signOut, type User } from "firebase/auth";
import { doc, getDoc } from "firebase/firestore";
import { createContext, useContext, useEffect, useMemo, useState } from "react";
import { auth, db, emailFor } from "./firebase";
import { can as allowed, roleFrom, type Role } from "./roles";

type Access = "checking" | "admin" | "not-admin" | "signed-out";

type SessionValue = {
  user: User | null;
  access: Access;
  /** Owner, admin or moderator, once known. */
  role: Role | null;
  /** Whether this person may do [action]: the worker decides, this hides what it would refuse. */
  can: (action: string) => boolean;
  signIn: (username: string, password: string) => Promise<void>;
  signOut: () => Promise<void>;
};

const Ctx = createContext<SessionValue | null>(null);

/** Who is signed in, and whether they are listed under admins/. */
export function Session({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [access, setAccess] = useState<Access>("checking");
  const [role, setRole] = useState<Role | null>(null);

  useEffect(
    () =>
      onAuthStateChanged(auth, async (u) => {
        setUser(u);
        setRole(null);
        if (!u) return setAccess("signed-out");
        setAccess("checking");
        try {
          // The rules let each person read their own entry.
          const entry = await getDoc(doc(db, "admins", u.uid));
          setRole(roleFrom(entry.data()));
          setAccess(entry.exists() ? "admin" : "not-admin");
        } catch {
          setAccess("not-admin");
        }
      }),
    [],
  );

  const value = useMemo<SessionValue>(
    () => ({
      user,
      access,
      role,
      can: (action: string) => allowed(role, action),
      signIn: async (username, password) => {
        await signInWithEmailAndPassword(auth, emailFor(username), password);
      },
      signOut: () => signOut(auth),
    }),
    [user, access, role],
  );

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useSession() {
  const v = useContext(Ctx);
  if (!v) throw new Error("useSession outside <Session>");
  return v;
}
