import React, { useState } from 'react';
import {
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { useAuth } from '../auth/AuthContext';
import { Theme } from '../theme';

export function LoginScreen() {
  const { login, error } = useAuth();
  const [email, setEmail] = useState('demo@campuswalk.local');
  const [password, setPassword] = useState('CampusWalk2026!');
  const [busy, setBusy] = useState(false);
  const [localErr, setLocalErr] = useState<string | null>(null);

  const onLogin = async () => {
    setLocalErr(null);
    setBusy(true);
    try {
      await login(email.trim(), password);
    } catch (e) {
      setLocalErr(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  };

  const err = localErr ?? error;

  return (
    <KeyboardAvoidingView
      style={styles.root}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <View style={styles.inner}>
        <Text style={styles.title}>Campus Walk</Text>
        <Text style={styles.sub}>使用邮箱登录以同步对话与路线</Text>

        <View style={styles.field}>
          <Text style={styles.label}>邮箱</Text>
          <TextInput
            value={email}
            onChangeText={setEmail}
            autoCapitalize="none"
            keyboardType="email-address"
            placeholder="you@example.com"
            style={styles.input}
          />
        </View>
        <View style={styles.field}>
          <Text style={styles.label}>密码</Text>
          <TextInput
            value={password}
            onChangeText={setPassword}
            secureTextEntry
            placeholder="密码"
            style={styles.input}
          />
        </View>

        {err ? <Text style={styles.err}>{err}</Text> : null}

        <Pressable
          onPress={onLogin}
          disabled={busy || !email || !password}
          style={({ pressed }) => [
            styles.btn,
            (busy || !email || !password) && styles.btnDisabled,
            pressed && styles.btnPressed,
          ]}
        >
          {busy ? <ActivityIndicator color="#fff" /> : <Text style={styles.btnText}>登录</Text>}
        </Pressable>

        <Text style={styles.hint}>测试账号：demo@campuswalk.local / CampusWalk2026!</Text>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#fff' },
  inner: { flex: 1, padding: 24, paddingTop: 80 },
  title: { fontSize: 34, fontWeight: '700', textAlign: 'center', color: Theme.textPrimary },
  sub: {
    marginTop: 8,
    fontSize: 15,
    color: Theme.textSecondary,
    textAlign: 'center',
    marginBottom: 24,
  },
  field: { marginBottom: 16 },
  label: { fontSize: 12, color: Theme.textSecondary, marginBottom: 8 },
  input: {
    borderRadius: Theme.cornerCard,
    backgroundColor: Theme.surfaceGray50,
    paddingHorizontal: 12,
    paddingVertical: 12,
    fontSize: 16,
    color: Theme.textPrimary,
  },
  err: { color: '#DC2626', fontSize: 13, textAlign: 'center', marginBottom: 12 },
  btn: {
    marginTop: 8,
    backgroundColor: Theme.brandBlue,
    borderRadius: Theme.cornerCard,
    paddingVertical: 14,
    alignItems: 'center',
  },
  btnDisabled: { opacity: 0.55 },
  btnPressed: { opacity: 0.9 },
  btnText: { color: '#fff', fontSize: 17, fontWeight: '600' },
  hint: {
    marginTop: 16,
    fontSize: 11,
    color: Theme.textMuted,
    textAlign: 'center',
  },
});
