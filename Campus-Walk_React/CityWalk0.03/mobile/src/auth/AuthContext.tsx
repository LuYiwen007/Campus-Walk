import React, { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import * as Api from '../api/client';
import type { UserDTO } from '../api/types';

type AuthCtx = {
  ready: boolean;
  user: UserDTO | null;
  error: string | null;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  refreshMe: () => Promise<void>;
};

const Ctx = createContext<AuthCtx | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [ready, setReady] = useState(false);
  const [user, setUser] = useState<UserDTO | null>(null);
  const [error, setError] = useState<string | null>(null);

  const refreshMe = useCallback(async () => {
    const t = await Api.getToken();
    if (!t) {
      setUser(null);
      return;
    }
    try {
      const u = await Api.me();
      setUser(u);
      setError(null);
    } catch (e) {
      await Api.setToken(null);
      setUser(null);
      setError(e instanceof Error ? e.message : String(e));
    }
  }, []);

  useEffect(() => {
    (async () => {
      await refreshMe();
      setReady(true);
    })();
  }, [refreshMe]);

  const login = useCallback(async (email: string, password: string) => {
    setError(null);
    const res = await Api.login(email.trim(), password);
    await Api.setToken(res.access_token);
    setUser(res.user);
  }, []);

  const logout = useCallback(async () => {
    await Api.setToken(null);
    setUser(null);
  }, []);

  const v = useMemo(
    () => ({ ready, user, error, login, logout, refreshMe }),
    [ready, user, error, login, logout, refreshMe]
  );

  return <Ctx.Provider value={v}>{children}</Ctx.Provider>;
}

export function useAuth(): AuthCtx {
  const x = useContext(Ctx);
  if (!x) throw new Error('useAuth must be inside AuthProvider');
  return x;
}
