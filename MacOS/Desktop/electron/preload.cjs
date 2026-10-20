const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('miniVoice', {
  command: (action, payload = {}) => ipcRenderer.invoke('engine:command', { action, payload }),
  subscribe: callback => {
    const listener = (_, message) => callback(message);
    ipcRenderer.on('engine:event', listener);
    return () => ipcRenderer.removeListener('engine:event', listener);
  }
});
