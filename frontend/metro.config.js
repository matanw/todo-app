const { getDefaultConfig } = require('expo/metro-config');

const config = getDefaultConfig(__dirname);

// Exclude nested node_modules from file watching — prevents EMFILE on macOS
// without needing watchman or raising system limits
config.resolver.blockList = [
  /node_modules\/.*\/node_modules\/.*/,
];

module.exports = config;
