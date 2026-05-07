import * as Device from 'expo-device';
import * as SecureStore from 'expo-secure-store';
import Constants from 'expo-constants';

const API_URL  = Constants.expoConfig?.extra?.apiUrl  || process.env.EXPO_PUBLIC_API_URL  || '';
const APP_NAME = Constants.expoConfig?.extra?.appName || process.env.EXPO_PUBLIC_APP_NAME || '';

let _googleToken = null;
let _deviceId    = null;

async function getDeviceId() {
  if (_deviceId) return _deviceId;
  let id = await SecureStore.getItemAsync('device_id');
  if (!id) {
    id = `${Device.modelName ?? 'unknown'}-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    await SecureStore.setItemAsync('device_id', id);
  }
  _deviceId = id;
  return id;
}

export function setGoogleToken(token) { _googleToken = token; }
export function clearAuth()           { _googleToken = null;  }
export function isAuthenticated()     { return !!_googleToken; }

async function headers() {
  const h = { 'Content-Type': 'application/json', 'X-App-Name': APP_NAME };
  if (_googleToken) {
    h['Authorization'] = `Bearer ${_googleToken}`;
  } else {
    h['X-Device-ID'] = await getDeviceId();
  }
  return h;
}

async function request(path, options = {}) {
  const res = await fetch(`${API_URL}${path}`, { ...options, headers: await headers() });
  const body = await res.json();
  if (!res.ok) throw new Error(body.error || `HTTP ${res.status}`);
  return body;
}

export const api = {
  get:    (path = '')       => request(path),
  post:   (path = '', data) => request(path, { method: 'POST',   body: JSON.stringify(data) }),
  put:    (path = '', data) => request(path, { method: 'PUT',    body: JSON.stringify(data) }),
  delete: (path = '')       => request(path, { method: 'DELETE' }),
};
