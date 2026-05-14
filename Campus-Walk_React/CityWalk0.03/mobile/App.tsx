import { NavigationContainer, DefaultTheme } from '@react-navigation/native';
import type { Theme as NavigationTheme } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import ExpoGaodeMapModule from 'expo-gaode-map';
import { StatusBar } from 'expo-status-bar';
import React, { useEffect } from 'react';
import { ActivityIndicator, View } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { AuthProvider, useAuth } from './src/auth/AuthContext';
import { MainShell } from './src/navigation/MainShell';
import { LoginScreen } from './src/screens/LoginScreen';
import { Theme as CWTheme } from './src/theme';

const Stack = createNativeStackNavigator();

const navTheme: NavigationTheme = {
  ...DefaultTheme,
  colors: {
    ...DefaultTheme.colors,
    background: '#fff',
    primary: CWTheme.brandBlue,
    text: CWTheme.textPrimary,
    card: '#fff',
    border: CWTheme.borderSubtle,
    notification: CWTheme.brandBlue,
  },
};

function Gate() {
  const { ready, user } = useAuth();
  if (!ready) {
    return (
      <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: '#fff' }}>
        <ActivityIndicator />
      </View>
    );
  }
  return (
    <Stack.Navigator screenOptions={{ headerShown: false }}>
      {user ? (
        <Stack.Screen name="Main" component={MainShell} />
      ) : (
        <Stack.Screen name="Login" component={LoginScreen} />
      )}
    </Stack.Navigator>
  );
}

export default function App() {
  /** 开发阶段：直接标记隐私已同意以便地图 SDK 初始化。上架前请改为用户点击同意后再调用。 */
  useEffect(() => {
    const st = ExpoGaodeMapModule.getPrivacyStatus();
    if (!st.isReady) {
      ExpoGaodeMapModule.setPrivacyConfig({
        hasShow: true,
        hasContainsPrivacy: true,
        hasAgree: true,
        privacyVersion: '2026-03-13',
      });
    }
  }, []);

  return (
    <SafeAreaProvider>
      <AuthProvider>
        <NavigationContainer theme={navTheme}>
          <Gate />
          <StatusBar style="dark" />
        </NavigationContainer>
      </AuthProvider>
    </SafeAreaProvider>
  );
}
