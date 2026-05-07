import React, { useState, useEffect, useCallback } from 'react';
import {
  View, Text, TextInput, TouchableOpacity, FlatList,
  StyleSheet, ActivityIndicator, KeyboardAvoidingView, Platform,
} from 'react-native';
import * as Google from 'expo-auth-session/providers/google';
import * as WebBrowser from 'expo-web-browser';
import { setGoogleToken, clearAuth, api } from './api';

WebBrowser.maybeCompleteAuthSession();

const GOOGLE_CLIENT_ID = process.env.EXPO_PUBLIC_GOOGLE_CLIENT_ID;

export default function App() {
  const [user, setUser]         = useState(null);
  const [todos, setTodos]       = useState([]);
  const [input, setInput]       = useState('');
  const [loading, setLoading]   = useState(false);
  const [saving, setSaving]     = useState(false);
  const [error, setError]       = useState(null);

  const [request, response, promptAsync] = Google.useAuthRequest({
    clientId: GOOGLE_CLIENT_ID,
    scopes: ['openid', 'email', 'profile'],
  });

  useEffect(() => {
    if (response?.type === 'success' && response.authentication?.idToken) {
      const token = response.authentication.idToken;
      setGoogleToken(token);
      setUser(token);
    }
  }, [response]);

  const loadTodos = useCallback(async () => {
    if (!user) return;
    setLoading(true);
    setError(null);
    try {
      const res = await api.get();
      setTodos(res.todos || []);
    } catch (e) {
      setError(e.message);
    } finally {
      setLoading(false);
    }
  }, [user]);

  useEffect(() => { loadTodos(); }, [loadTodos]);

  async function mutate(action, payload = {}) {
    setSaving(true);
    setError(null);
    try {
      const res = await api.post('', { action, ...payload });
      setTodos(res.todos || []);
    } catch (e) {
      setError(e.message);
    } finally {
      setSaving(false);
    }
  }

  async function addTodo() {
    const text = input.trim();
    if (!text) return;
    setInput('');
    await mutate('add', { text });
  }

  if (!user) {
    return (
      <View style={styles.center}>
        <Text style={styles.title}>Todo</Text>
        <TouchableOpacity
          style={[styles.btn, styles.btnPrimary, !request && styles.btnDisabled]}
          onPress={() => promptAsync()}
          disabled={!request}
        >
          <Text style={styles.btnTextLight}>Sign in with Google</Text>
        </TouchableOpacity>
        {error && <Text style={styles.error}>{error}</Text>}
      </View>
    );
  }

  return (
    <KeyboardAvoidingView
      style={styles.root}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.title}>Todo</Text>
        <TouchableOpacity onPress={() => { clearAuth(); setUser(null); setTodos([]); }}>
          <Text style={styles.signOut}>Sign out</Text>
        </TouchableOpacity>
      </View>

      {/* Error */}
      {error && <Text style={styles.error}>{error}</Text>}

      {/* List */}
      {loading ? (
        <ActivityIndicator style={{ flex: 1 }} size="large" color="#6C63FF" />
      ) : (
        <FlatList
          data={todos}
          keyExtractor={item => item.id}
          contentContainerStyle={styles.list}
          ListEmptyComponent={<Text style={styles.empty}>No todos yet. Add one below!</Text>}
          renderItem={({ item }) => (
            <View style={styles.row}>
              <TouchableOpacity
                style={[styles.checkbox, item.done && styles.checkboxDone]}
                onPress={() => mutate('toggle', { id: item.id })}
                disabled={saving}
              >
                {item.done && <Text style={styles.checkmark}>✓</Text>}
              </TouchableOpacity>
              <Text style={[styles.todoText, item.done && styles.todoTextDone]}>
                {item.text}
              </Text>
              <TouchableOpacity
                onPress={() => mutate('delete', { id: item.id })}
                disabled={saving}
                hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
              >
                <Text style={styles.deleteBtn}>✕</Text>
              </TouchableOpacity>
            </View>
          )}
        />
      )}

      {/* Input */}
      <View style={styles.inputRow}>
        <TextInput
          style={styles.input}
          placeholder="Add a todo..."
          value={input}
          onChangeText={setInput}
          onSubmitEditing={addTodo}
          returnKeyType="done"
          editable={!saving}
        />
        <TouchableOpacity
          style={[styles.btn, styles.btnPrimary, (!input.trim() || saving) && styles.btnDisabled]}
          onPress={addTodo}
          disabled={!input.trim() || saving}
        >
          <Text style={styles.btnTextLight}>{saving ? '…' : 'Add'}</Text>
        </TouchableOpacity>
      </View>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  root:          { flex: 1, backgroundColor: '#F7F7FB', paddingTop: Platform.OS === 'ios' ? 60 : 40 },
  center:        { flex: 1, justifyContent: 'center', alignItems: 'center', padding: 32 },
  header:        { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 20, paddingBottom: 12 },
  title:         { fontSize: 32, fontWeight: '800', color: '#6C63FF' },
  signOut:       { fontSize: 14, color: '#999' },
  list:          { paddingHorizontal: 16, paddingBottom: 16 },
  empty:         { textAlign: 'center', color: '#BBB', marginTop: 60, fontSize: 15 },
  row:           { flexDirection: 'row', alignItems: 'center', backgroundColor: '#FFF', borderRadius: 12, marginVertical: 5, padding: 14, shadowColor: '#000', shadowOpacity: 0.05, shadowRadius: 4, elevation: 2 },
  checkbox:      { width: 24, height: 24, borderRadius: 6, borderWidth: 2, borderColor: '#6C63FF', marginRight: 12, alignItems: 'center', justifyContent: 'center' },
  checkboxDone:  { backgroundColor: '#6C63FF' },
  checkmark:     { color: '#FFF', fontSize: 14, fontWeight: 'bold' },
  todoText:      { flex: 1, fontSize: 15, color: '#222' },
  todoTextDone:  { textDecorationLine: 'line-through', color: '#BBB' },
  deleteBtn:     { color: '#DDD', fontSize: 16, fontWeight: 'bold' },
  inputRow:      { flexDirection: 'row', padding: 16, paddingBottom: Platform.OS === 'ios' ? 32 : 16, borderTopWidth: 1, borderTopColor: '#EEE', backgroundColor: '#FFF' },
  input:         { flex: 1, borderWidth: 1, borderColor: '#E0E0E0', borderRadius: 10, paddingHorizontal: 14, paddingVertical: 10, fontSize: 15, marginRight: 10, backgroundColor: '#FAFAFA' },
  btn:           { borderRadius: 10, paddingHorizontal: 20, paddingVertical: 12, justifyContent: 'center' },
  btnPrimary:    { backgroundColor: '#6C63FF' },
  btnDisabled:   { opacity: 0.4 },
  btnTextLight:  { color: '#FFF', fontWeight: '600', fontSize: 15 },
  error:         { color: '#E53935', textAlign: 'center', paddingHorizontal: 20, marginBottom: 8, fontSize: 13 },
});
